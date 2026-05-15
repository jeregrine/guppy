# Distribution and native artifacts

Guppy is currently source-build first, with `rustler_precompiled` wired in for the future artifact path. The native runtime is a single Rustler NIF built from `native/guppy_nif`; Rustler builds and copies it into `priv/native/` during normal Mix compilation.

The current runtime baseline has production-hardening coverage for bounded native requests, stale queued request expiry, Rustler-monitored event-target cleanup, server restart cleanup/reopen behavior, clean-install NIF loading, and generated package smoke loading. Distribution defaults to source builds until CI publishes checksummed precompiled artifacts.

## Current supported path

Local source builds are the supported path today:

```sh
mix compile
mix test
```

For interactive demos, prefer an optimized native build:

```sh
GUPPY_NATIVE_RELEASE=1 mix run examples/super_demo.exs
```

`GUPPY_NATIVE_RELEASE=1` selects Rustler's release-mode native build at compile time. Keep the environment variable set for subsequent Mix commands that should use that optimized build. To switch back to a debug native build, unset the variable and clean/recompile, for example:

```sh
mix clean
mix compile --force
```

`GUPPY_NATIVE_PRECOMPILED=1` is an explicit probe of the future artifact-download path for currently supported precompiled targets. It is expected to fail until release artifacts and `checksum-*.exs` files are published; do not document it as a supported install mode before then.

## Current platform assumptions

Current development and smoke coverage are macOS-first.

Important assumptions:

- the active GPUI dependency is `gpui = "0.2.2"` from crates.io
- precompiled target scope should stay aligned with platforms GPUI itself supports
- native bootstrap uses Rustler directly; there is no C shim
- the app uses the OTP/wx-style macOS main-thread strategy
- the shipped native artifact shape should remain one NIF per target
- local source builds must continue to work after precompiled artifacts are published

## CI status

`.github/workflows/check.yml` runs the current macOS source-build gate:

1. install Erlang/Elixir and Rust
2. fetch Mix dependencies
3. run `scripts/check`
4. run `scripts/clean_install_load_test` to verify a fresh Mix project can depend on Guppy and load the built NIF
5. run `scripts/package_smoke` to verify the generated Hex package contents can compile and load Guppy

This validates the fallback source-build path while precompiled artifacts are not yet published. `.github/workflows/precompiled-nif.yml` follows RustlerPrecompiled's GitHub Actions guidance for artifact builds, but its matrix is intentionally limited to currently supported precompiled targets.

## Latest local source-build verification

On 2026-05-14, local macOS/aarch64 source-build verification passed:

- `scripts/check` (including bounded stress-test IR validation)
- `scripts/clean_install_load_test`
- `scripts/package_smoke`
- `mix hex.build --unpack --output /tmp/guppy-hex-unpack`
- `GUPPY_NATIVE_RELEASE=1 mix compile --force && GUPPY_NATIVE_RELEASE=1 mix run examples/hello_world.exs`

This is a source-build/package smoke result, not a precompiled-artifact release claim.

## Release process draft

Until precompiled artifacts exist, a release is source-only:

1. Run `scripts/check`.
2. Run `scripts/clean_install_load_test`.
3. Run `scripts/package_smoke`.
4. Audit package contents with `mix hex.build --unpack --output /tmp/guppy-hex-unpack`.
5. Run `GUPPY_NATIVE_RELEASE=1 mix run examples/hello_world.exs` on macOS.
6. Confirm `docs/gpui-compliance.md` still records the current `../zed/crates/gpui` reference.
7. Update `CHANGELOG.md` and the package version for the release.
8. Do not attach native artifacts unless they were built by CI and load-tested. Use `scripts/package_smoke` as the minimum local package load smoke before expanding to artifact-specific CI jobs.

Future native artifact release flow:

1. CI builds one NIF artifact per supported target.
2. CI load-tests each artifact in a clean package install.
3. macOS artifacts are signed or ad-hoc signed as required by the target packaging model.
4. Release notes list every target triple and whether source-build fallback remains available.
5. Failed or untested targets are omitted rather than published optimistically.

## Precompiled artifact plan

`rustler_precompiled` is now part of the NIF module, but Guppy still forces source builds by default because no release artifacts or checksum file are published yet. The remaining work is the artifact/release process:

1. Keep the RustlerPrecompiled target list constrained to currently supported and CI-built targets.
2. Build the NIF artifact with `.github/workflows/precompiled-nif.yml` for every target in `Guppy.Native.Nif`'s `@precompiled_targets` list.
3. Add CI jobs that install/load the produced artifact and run at least `mix test` before claiming precompiled support.
4. Generate and package the required `checksum-*.exs` file with `mix rustler_precompiled.download Guppy.Native.Nif --all --print` after release artifacts exist; `mix.exs` includes any generated `checksum-*.exs` file when present while keeping source-only package smoke builds green before artifacts exist.
5. Document how release artifacts are produced, signed when needed, and attached.
6. Flip the default from source-build to precompiled-download only after the advertised artifact set is built and load-tested.
7. Keep Rustler source compilation as the fallback path.
8. Keep `scripts/check`, `mix compile`, `scripts/clean_install_load_test`, and `scripts/package_smoke` green for source builds.

## Initial target matrix

| Target | Status | Notes |
| --- | --- | --- |
| `aarch64-apple-darwin` | source-build supported; precompiled artifact workflow configured | primary local development target; only current RustlerPrecompiled target |
| `x86_64-apple-darwin` | source-build/precompiled planned | needs CI/build-host confirmation |
| `aarch64-unknown-linux-gnu` | source-build/precompiled planned | GPUI runtime behavior needs validation |
| `x86_64-unknown-linux-gnu` | source-build/precompiled planned | GPUI runtime behavior needs validation |
| `x86_64-pc-windows-msvc` | source-build/precompiled planned | GPUI/runtime bootstrap needs validation |

Do not claim a target as precompiled-supported until CI builds and load-tests the artifact. Do not add planned targets to `Guppy.Native.Nif`'s `@precompiled_targets` or the precompiled artifact workflow until they are supported. Avoid publishing broader RustlerPrecompiled defaults such as musl, Windows GNU, ARMv7, or RISC-V unless GPUI support and CI load tests prove them viable.
