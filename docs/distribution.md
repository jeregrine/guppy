# Distribution and native artifacts

Guppy is currently source-build first. The native runtime is a single Rustler NIF built from `native/guppy_nif` and copied into `priv/native/` by `mix guppy.native.build`.

## Current supported path

Local source builds are the supported path today:

```sh
mix guppy.native.build
mix test
```

For interactive demos, prefer a release native build:

```sh
mix guppy.native.build --release
mix run examples/super_demo.exs
```

On macOS, the build task codesigns the copied NIF artifact in `priv/native/` to avoid stale ad-hoc signature kills after rebuilds.

## Current platform assumptions

Current development and smoke coverage are macOS-first.

Important assumptions:

- the active GPUI dependency is `gpui = "0.2.2"` from crates.io
- native bootstrap uses Rustler directly; there is no C shim
- the app uses the OTP/wx-style macOS main-thread strategy
- the shipped native artifact shape should remain one NIF per target
- local source builds must continue to work even after precompiled artifacts are added

## Precompiled artifact plan

Do not add `rustler_precompiled` until the source-build path and runtime behavior stay stable.

When adding precompiled artifacts, preserve these gates:

1. Keep `mix guppy.native.build` as the fallback path.
2. Define target triples and artifact names before publishing.
3. Add CI jobs that build the NIF for every advertised target.
4. Add CI jobs that install/load the produced artifact and run at least `mix test`.
5. Document how release artifacts are produced, signed when needed, and attached.
6. Keep `scripts/check` green for source builds.

## Initial target matrix

| Target | Status | Notes |
| --- | --- | --- |
| macOS arm64 | source-build supported | primary local development target |
| macOS x86_64 | planned | needs CI/build-host confirmation |
| Linux x86_64 | planned | GPUI runtime behavior needs validation |
| Windows x86_64 | deferred | GPUI/runtime bootstrap needs separate validation |

Do not claim a target as precompiled-supported until CI builds and load-tests the artifact.
