# Distribution and native artifacts

Guppy ships a checksummed precompiled NIF for supported targets and falls back to source builds (`GUPPY_NATIVE_FORCE_BUILD=1` forces them; the repo itself always source-builds via `mise.toml`). The native runtime is a single Rustler NIF built from `native/guppy_nif`; Rustler builds and copies it into `priv/native/` during normal Mix compilation.

The current runtime baseline has production-hardening coverage for bounded native requests, stale queued request expiry, Rustler-monitored event-target cleanup, server restart cleanup/reopen behavior, clean-install NIF loading, and generated package smoke loading. Consumers download the published artifact by default; the packaged crate keeps the source-build fallback working.

## Hex release runbook

Precompiled artifacts and checksums are required before the first hex cut; do not publish a source-build-only package. The order of operations:

1. Make sure `scripts/check`, `scripts/clean_install_load_test`, `scripts/package_smoke`, and `mix hex.build --unpack` are green.
2. Finalize the `CHANGELOG.md` entry and tag `vX.Y.Z`; pushing the tag runs `.github/workflows/precompiled-nif.yml`, which builds and attaches the `aarch64-apple-darwin` NIF artifact to the GitHub release.
3. Validate the artifact: with `GUPPY_NATIVE_FORCE_BUILD` unset and a clean build, `mix compile` must download and load it, and `mix test` must pass.
4. Generate and commit the checksum file with `mix rustler_precompiled.download Guppy.Native.Nif --all --print` (`mix.exs` already packages any `checksum-*.exs`).
5. Flip `Guppy.Native.Nif` from force-source-build to precompiled-by-default (keep an env var to force source builds), and re-run every gate in step 1 plus step 3.
6. `mix hex.publish`.

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

| Target                      | Status                                                           | Notes                                                                    |
| --------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `aarch64-apple-darwin`      | source-build supported; precompiled artifact workflow configured | primary local development target; only current RustlerPrecompiled target |
| `x86_64-apple-darwin`       | source-build/precompiled planned                                 | needs CI/build-host confirmation                                         |
| `aarch64-unknown-linux-gnu` | source-build/precompiled planned                                 | GPUI runtime behavior needs validation                                   |
| `x86_64-unknown-linux-gnu`  | source-build/precompiled planned                                 | GPUI runtime behavior needs validation                                   |
| `x86_64-pc-windows-msvc`    | source-build/precompiled planned                                 | GPUI/runtime bootstrap needs validation                                  |

Do not claim a target as precompiled-supported until CI builds and load-tests the artifact. Do not add planned targets to `Guppy.Native.Nif`'s `@precompiled_targets` or the precompiled artifact workflow until they are supported. Avoid publishing broader RustlerPrecompiled defaults such as musl, Windows GNU, ARMv7, or RISC-V unless GPUI support and CI load tests prove them viable.
