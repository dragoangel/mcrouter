FROM ubuntu:26.04 AS builder

# Upstream ref to build: a tag (v2026.06.29.00) or SHA. Empty = default branch.
ARG MCROUTER_VERSION=
ARG MCROUTER_REPO=https://github.com/facebook/mcrouter.git
ENV DEBIAN_FRONTEND=noninteractive

# Prerequisites a bare image lacks: sudo (dep build scripts call it), git (clone
# + patches), python (fb code generators invoke `python`; noble ships only
# python3). cmake/ninja/pkg-config are installed by the deps script.
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo ca-certificates git python-is-python3

RUN if [ -n "$MCROUTER_VERSION" ]; then \
        git clone --depth 1 --branch "$MCROUTER_VERSION" "$MCROUTER_REPO" /src; \
    else \
        git clone --depth 1 "$MCROUTER_REPO" /src; \
    fi
WORKDIR /src

COPY patches/ /patches/
RUN for p in /patches/*.patch; do [ -e "$p" ] || continue; echo "Applying $p"; git apply -v "$p"; done

# Pin the Meta deps to the mcrouter tag's era. Upstream ships no pins, so the
# recipes otherwise clone folly/fbthrift/wangle/fizz/mvfst at HEAD and drift.
# folly/fbthrift/wangle/fizz honor these *_COMMIT files; mvfst's recipe has no
# hook, so inject a checkout of the pinned rev.
COPY build.deps.lock /tmp/build.deps.lock
RUN set -eu; . /tmp/build.deps.lock; \
    printf '%s\n' "$FOLLY_COMMIT"    > mcrouter/FOLLY_COMMIT; \
    printf '%s\n' "$FBTHRIFT_COMMIT" > mcrouter/FBTHRIFT_COMMIT; \
    printf '%s\n' "$WANGLE_COMMIT"   > mcrouter/WANGLE_COMMIT; \
    printf '%s\n' "$FIZZ_COMMIT"     > mcrouter/FIZZ_COMMIT; \
    sed -i '/cd "\$PKG_DIR\/mvfst"/a\    git checkout '"$MVFST_COMMIT" \
      mcrouter/scripts/recipes/mvfst.sh

# Build the dependency stack (folly/fbthrift/wangle/fizz/mvfst/fmt) into
# /build/install, leaving their sources under /build/pkgs.
RUN ./mcrouter/scripts/install_ubuntu_24.04.sh /build deps

# thrift1 (fbthrift compiler) runs during mcrouter's codegen and must find the
# freshly built folly/fbthrift shared libs.
ENV LD_LIBRARY_PATH=/build/install/lib:/build/install/lib64

# Build mcrouter via CMake, not autotools: the autotools link list is stale
# against modern fbthrift, whereas CMake links deps through their exported
# targets (correct libs/ABI) and defaults BUILD_TESTS=OFF. mcrouter's CMakeLists
# expects the fbcode_builder CMake helpers (shipped by folly/fbthrift) under
# build/fbcode_builder/CMake; vendor them from the dep sources.
RUN mkdir -p build/fbcode_builder && \
    cp -r "$(find /build/pkgs -type d -path '*/build/fbcode_builder/CMake' | head -1)" \
      build/fbcode_builder/CMake
RUN cmake -S . -B build-cmake -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_TESTS=OFF \
      -DMCROUTER_PACKAGE_VERSION="${MCROUTER_VERSION:-dev}" \
      -DCMAKE_PREFIX_PATH=/build/install \
      -DCMAKE_INSTALL_PREFIX=/build/install && \
    cmake --build build-cmake && \
    cmake --install build-cmake

# Package the install tree into a stripped runtime .deb + a detached debug-symbols
# .deb (see scripts/deb-gen-package.sh). The runtime .deb drives the stage below and
# ships as a release asset alongside the debug package.
COPY --chmod=0755 scripts/deb-gen-package.sh /usr/local/bin/deb-gen-package
RUN deb-gen-package /build/install "$MCROUTER_VERSION" /build

# Export stage: `--target deb --output type=local,dest=.` yields the .deb files.
FROM scratch AS deb
COPY --from=builder /build/*.deb /

FROM ubuntu:26.04

ARG MCROUTER_VERSION
ENV DEBIAN_FRONTEND=noninteractive

# Install the stripped runtime .deb via a bind mount (no layer bloat); its
# postinst creates the mcrouter user (uid 1001), owns the runtime dirs, and runs
# ldconfig. apt resolves the system-library Depends from the archive.
RUN --mount=type=bind,from=builder,source=/build,target=/mnt/build \
    apt-get update \
    && apt-get install -y --no-install-recommends /mnt/build/mcrouter_*.deb \
    && rm -rf /var/lib/apt/lists/*

LABEL org.opencontainers.image.title="mcrouter" \
      org.opencontainers.image.description="memcached protocol router" \
      org.opencontainers.image.authors="Dmytro Alieksieiev (dragoangel)" \
      org.opencontainers.image.source="https://github.com/dragoangel/mcrouter" \
      org.opencontainers.image.version="${MCROUTER_VERSION}" \
      org.opencontainers.image.licenses="MIT"

USER 1001
ENTRYPOINT ["/usr/bin/mcrouter"]
CMD ["--help"]
