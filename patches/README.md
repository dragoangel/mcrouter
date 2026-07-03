# Patches

`patches/*.patch` are applied with `git apply` (from the upstream checkout root,
so `-p1` paths) in lexical order during the image build. Empty = clean upstream
build.

Add one with `git format-patch -1 -o patches/` from an upstream checkout.

Planned: folly fiber-pool reclaim fix for memory growth under load (upstream
[#297](https://github.com/facebook/mcrouter/issues/297)). The related
[#198](https://github.com/facebook/mcrouter/issues/198) is an env-var mitigation
(`GLIBCXX_FORCE_NEW=1`), not a patch.
