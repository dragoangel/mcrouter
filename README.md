<img src="resources/logo.svg" alt="mcrouter" width="96" align="right">

# mcrouter — container images

[![CI](https://github.com/dragoangel/mcrouter/actions/workflows/ci.yml/badge.svg)](https://github.com/dragoangel/mcrouter/actions/workflows/ci.yml)
[![Publish Image](https://github.com/dragoangel/mcrouter/actions/workflows/publish-image.yml/badge.svg)](https://github.com/dragoangel/mcrouter/actions/workflows/publish-image.yml)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Builds [facebook/mcrouter](https://github.com/facebook/mcrouter) from source on Ubuntu 24.04 and
publishes multi-arch, cosign-signed images to `ghcr.io/dragoangel/mcrouter`. Upstream ships no images
or packages for external users; this fills that gap. No upstream code is vendored — the build clones
mcrouter at a pinned version and applies any local [`patches/`](patches/).

## Image

```sh
docker pull ghcr.io/dragoangel/mcrouter:latest
docker pull ghcr.io/dragoangel/mcrouter:v2026.06.29.00

docker run --rm --network host ghcr.io/dragoangel/mcrouter:latest \
  --config-str='{"pools":{"A":{"servers":["127.0.0.1:11211"]}},"route":"PoolRoute|A"}' -p 5000
```

Verify the signature (keyless / OIDC):

```sh
cosign verify ghcr.io/dragoangel/mcrouter:latest \
  --certificate-identity-regexp '^https://github.com/dragoangel/mcrouter/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Debian package

Each release attaches, per arch (amd64 + arm64):

- `mcrouter_<version>_<arch>.deb` — self-contained runtime (bundles the Meta libs,
  pulls system libs via apt, creates the `mcrouter` user, ships a systemd unit).
- `mcrouter-dbgsym_<version>_<arch>.deb` — detached debug symbols for gdb,
  installable alongside.

```sh
apt-get install ./mcrouter_<version>_<arch>.deb        # stripped runtime
systemctl edit --full mcrouter                         # then configure /etc/mcrouter/config.json
apt-get install ./mcrouter-dbgsym_<version>_<arch>.deb  # optional: debug symbols
```

The container image installs only the stripped runtime package.

## Layout

| Path | Purpose |
|---|---|
| [`build.mcrouter.lock`](build.mcrouter.lock) | Upstream version built and tagged (tag or SHA) |
| [`build.deps.lock`](build.deps.lock) | Pinned Meta dep commits (folly/fbthrift/…); upstream ships none, so `scripts/build-deps-update-lock.sh` locks them to the mcrouter tag's era |
| [`patches/`](patches/) | Local patches (empty = clean upstream build) |
| [`Dockerfile`](Dockerfile) | Clone upstream at that version, apply `patches/`, build (CMake), slim runtime |
| [`compose.yml`](compose.yml) | Local smoke test — mcrouter + memcached |
| [`.github/`](.github/) | CI/CD workflows (see below) + Dependabot |
| [`scripts/`](scripts/) | Maintenance helpers (see below) |
| [`charts/mcrouter`](charts/mcrouter) | Helm chart for the image |

### Workflows

| Workflow | Purpose |
|---|---|
| `ci.yml` | On PR: build-verify the image + lint/render the chart + schema/README drift check |
| `publish-image.yml` | Build + push + cosign-sign multi-arch image; GitHub release with per-arch `.deb`s |
| `update-mcrouter-version.yml` | Weekly PR bumping `build.mcrouter.lock` + `build.deps.lock` + chart |
| `release-chart.yml` | Publish the Helm chart to `gh-pages` (chart-releaser) + Artifact Hub metadata |

### Scripts

| Script | Purpose |
|---|---|
| `deb-gen-package.sh` | Build the runtime + `-dbgsym` `.deb`s (invoked by the Dockerfile) |
| `build-deps-update-lock.sh` | Regenerate `build.deps.lock` for the pinned version |
| `helm-gen-docs-and-schema.sh` | Regenerate the chart's `values.schema.json` + `README.md` |

## Build / pin locally

```sh
docker build --build-arg MCROUTER_VERSION="$(cat build.mcrouter.lock)" -t mcrouter:local .
```

Change the built version by editing [`build.mcrouter.lock`](build.mcrouter.lock) (a `v20YY.MM.DD.NN` tag or
a SHA); the auto-update workflow does this when upstream tags a newer one.

### Compose

[`compose.yml`](compose.yml) runs mcrouter in front of a single memcached:

```sh
docker compose up                                  # published image
MCROUTER_IMAGE=mcrouter:local docker compose up    # a local build

# test -> STORED / VALUE k 0 1 / 1 / END
printf 'set k 0 0 1\r\n1\r\nget k\r\nquit\r\n' | nc 127.0.0.1 5000
```

## Attribution

mcrouter is © Facebook/Meta, MIT-licensed — see the upstream [repo](https://github.com/facebook/mcrouter).
This repository holds only original build/CI tooling by Dmytro Alieksieiev (dragoangel), also MIT ([LICENSE](LICENSE)).
