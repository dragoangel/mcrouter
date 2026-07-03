#!/usr/bin/env bash
# Package the built mcrouter install tree into two .deb files:
#   mcrouter_<ver>_<arch>.deb          - stripped runtime (the container installs this)
#   mcrouter-dbgsym_<ver>_<arch>.deb   - detached debug symbols, installable alongside
#
# The install tree is self-contained (it bundles folly/fbthrift/wangle/fizz/mvfst),
# so the runtime package's only external Depends are the system libraries the
# binaries link — resolved from what they actually load. The package also creates
# a dedicated system user, owns its runtime dirs, and ships a systemd unit for
# host installs.
#
# Usage: deb-gen-package.sh <install-dir> <mcrouter-version> <out-dir>
set -euo pipefail

install_dir="$1"
ver="${2#v}"; ver="${ver:-0.0.0}"
out_dir="$3"
arch="$(dpkg --print-architecture)"
prefix=/usr/local/mcrouter/install

# --- Trim build-only artifacts -------------------------------------------------
rm -rf "$install_dir/include"
rm -f "$install_dir/bin/thrift1"          # fbthrift compiler: build-only
find "$install_dir" -name '*.a' -delete   # static libs already linked into the binaries

# --- Split debug info, then strip ---------------------------------------------
# Detached debug goes under /usr/lib/debug/<binary-path>.debug so gdb finds it via
# the debug link once the -dbgsym package is installed.
dbg_root="$(mktemp -d)"
for bin in "$install_dir"/bin/*; do
  name="$(basename "$bin")"
  dbg="$dbg_root/usr/lib/debug${prefix}/bin/${name}.debug"
  mkdir -p "$(dirname "$dbg")"
  objcopy --only-keep-debug "$bin" "$dbg"
  strip --strip-unneeded "$bin"
  objcopy --add-gnu-debuglink="$dbg" "$bin"
done

# --- Resolve runtime library Depends ------------------------------------------
# readlink -f normalizes the noble usrmerge /lib -> /usr/lib paths so dpkg -S matches.
depends="$( { find "$install_dir" -type f -name '*.so*'; find "$install_dir/bin" -type f; } \
  | while read -r f; do ldd "$f" 2>/dev/null; done \
  | awk '/=> \//{print $3}' | grep -v "^$install_dir/" \
  | while read -r p; do readlink -f "$p"; done | sort -u \
  | xargs dpkg -S 2>/dev/null | cut -d: -f1 | sort -u | paste -sd, )"

# --- Assemble the runtime package ---------------------------------------------
root="$(mktemp -d)"
mkdir -p "$root/DEBIAN" "$root${prefix%/*}" "$root/usr/bin" \
         "$root/etc/ld.so.conf.d" "$root/etc/default" "$root/etc/mcrouter" \
         "$root/lib/systemd/system" \
         "$root/var/mcrouter/stats" "$root/var/mcrouter/fifos" \
         "$root/var/mcrouter/config" "$root/var/spool/mcrouter"
cp -a "$install_dir" "$root$prefix"
ln -s "$prefix/bin/mcrouter" "$root/usr/bin/mcrouter"
ln -s "$prefix/bin/mcpiper"  "$root/usr/bin/mcpiper"
printf '%s\n%s\n' "$prefix/lib" "$prefix/lib64" > "$root/etc/ld.so.conf.d/mcrouter.conf"

cat > "$root/etc/default/mcrouter" <<'EOF'
# Options passed to mcrouter by the systemd service. Configure a pool/route
# (edit /etc/mcrouter/config.json) before enabling the service.
MCROUTER_OPTS="-p 5000 --config-file=/etc/mcrouter/config.json"
EOF

cat > "$root/lib/systemd/system/mcrouter.service" <<'EOF'
[Unit]
Description=mcrouter (memcached protocol router)
Documentation=https://github.com/dragoangel/mcrouter
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=mcrouter
Group=mcrouter
EnvironmentFile=/etc/default/mcrouter
ExecStart=/usr/bin/mcrouter $MCROUTER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

chmod -R g=u "$root/var/mcrouter" "$root/var/spool/mcrouter"

cat > "$root/DEBIAN/control" <<EOF
Package: mcrouter
Version: $ver
Architecture: $arch
Maintainer: Dmytro Alieksieiev (dragoangel)
Section: net
Priority: optional
Homepage: https://github.com/dragoangel/mcrouter
Depends: $depends
Description: memcached protocol router (facebook/mcrouter)
EOF

cat > "$root/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
case "$1" in
  configure)
    getent group mcrouter >/dev/null || groupadd -g 1001 mcrouter
    getent passwd mcrouter >/dev/null || \
      useradd -u 1001 -g mcrouter -M -d /var/mcrouter -s /usr/sbin/nologin -c mcrouter mcrouter
    chown -R mcrouter:mcrouter /var/mcrouter /var/spool/mcrouter
    ldconfig
    [ -d /run/systemd/system ] && systemctl daemon-reload >/dev/null 2>&1 || true
    ;;
esac
EOF
chmod 0755 "$root/DEBIAN/postinst"

dpkg-deb --build --root-owner-group "$root" "$out_dir/mcrouter_${ver}_${arch}.deb"

# --- Assemble the debug-symbols package ---------------------------------------
mkdir -p "$dbg_root/DEBIAN"
cat > "$dbg_root/DEBIAN/control" <<EOF
Package: mcrouter-dbgsym
Version: $ver
Architecture: $arch
Maintainer: Dmytro Alieksieiev (dragoangel)
Section: debug
Priority: optional
Homepage: https://github.com/dragoangel/mcrouter
Depends: mcrouter (= $ver)
Description: debug symbols for mcrouter
EOF

dpkg-deb --build --root-owner-group "$dbg_root" "$out_dir/mcrouter-dbgsym_${ver}_${arch}.deb"
