# Guppy Forward Plan

This file tracks future work only. Implementation history belongs in commit history, docs, examples, and the GPUI compliance matrix.

## Current mode

Guppy has a useful baseline for:

- Elixir-owned window state and full-tree rendering
- the Rustler/GPUI native bridge
- the current documented primitive set
- runtime lifecycle telemetry and native request containment
- GPUI compliance tracking
- source-build distribution planning

The production-hardening pass tracked here has landed. The next work should be stabilization, real-user bug fixes, documentation/examples, compliance-matrix maintenance, release/distribution preparation when explicitly prioritized, and explicitly scoped features. Do not expand the primitive or runtime surface speculatively.

## Required checks

Before and after meaningful changes, keep this green:

```sh
scripts/check
```

That covers:

```sh
mix test
mix format --check-formatted
cd native/guppy_nif && cargo test
cd native/guppy_nif && cargo clippy --all-targets -- -D warnings
cd native/guppy_nif && cargo fmt --check
```

For native/runtime changes, also run:

```sh
mix compile --force
mix run examples/hello_world.exs
```

Before public release/distribution claims, also run:

```sh
scripts/clean_install_load_test
```

For performance-sensitive changes, run benchmarks or probes from `docs/performance.md` before optimizing.

## Current priorities

1. Complete the source-build alpha release readiness gate below before adding surface area.
2. Keep `scripts/check`, `mix compile`, `scripts/clean_install_load_test`, and the macOS source-build CI path green.
3. Fix correctness bugs found by review, real example usage, or tests before adding surface area.
4. Keep `README.md`, `AGENTS.md`, `PLAN.md`, `docs/gpui-compliance.md`, `docs/distribution.md`, `docs/performance.md`, and examples current when behavior changes.
5. Improve existing primitives only when the gap is clearly identified in the compliance matrix or by real usage.
6. Add new primitives only when explicitly prioritized and implemented end-to-end.
7. Publish precompiled artifacts only after artifact CI, load tests, and checksums exist.

## Alpha release readiness gate

Do not call Guppy alpha-ready until the source-build package is shippable and the preferred public APIs feel idiomatic. Precompiled artifacts may remain post-alpha, but the source-build path must work from the package users will actually install.

Required before a source-build alpha:

1. **Package/release metadata**
   - `mix hex.build` succeeds with description, licenses, links, and intentional package metadata.
   - Add a `LICENSE` file and a minimal changelog or release-notes policy.
   - Define explicit package files: include `lib`, `mix.exs`, docs needed by users, and the native Rust sources required for fallback builds (`native/guppy_nif/src`, `Cargo.toml`, `Cargo.lock`, and any required build metadata).
   - Exclude generated native artifacts such as `priv/native/guppy_nif.so` and `native/guppy_nif/target` from packages.
   - Add a package smoke that verifies the built package/tarball can compile and load Guppy, not only a path dependency checkout.

2. **RustlerPrecompiled/source-build semantics**
   - Keep source-build fallback as the default until release artifacts and `checksum-*.exs` exist.
   - Treat `GUPPY_NATIVE_PRECOMPILED=1` as an explicit artifact-path probe; it is expected to fail until artifacts are published and must not be documented as supported earlier.
   - Before flipping the default to downloads, CI must build every advertised target, load-test each artifact, and generate/package the required checksum file.
   - Resolve or document the `GUPPY_NATIVE_RELEASE=1` compile-env switch: users must know to keep the env var for subsequent Mix commands or clean/recompile when switching back to debug builds. Prefer a less footgun-prone release-build workflow if possible.

3. **Public API and OTP ergonomics**
   - `use Guppy.Window` should generate an idiomatic `child_spec/1` so window modules can be supervised directly.
   - Revisit public `Guppy.open_window/*` arities before alpha. The common case should support `Guppy.open_window(ir, opts)`; owner-specific calls should be lower-level/internal unless there is a clear public need.
   - Optional `Guppy.Window` callbacks must either have safe default implementations or the docs must stop implying event callbacks are optional when templates emit events.
   - Decide whether preferred `Guppy.Window` users can observe `window_close_requested`; if not, document that the preferred abstraction only treats `window_closed` as lifecycle-driving today.

4. **Product-surface hygiene**
   - Include examples and benchmarks in formatting, then format them.
   - Remove obvious dead/sloppy code such as no-op compiler branches.
   - Split the monolithic ExUnit file into focused IR, compiler, server/native, and window lifecycle tests before it becomes harder to review.
   - Keep tests non-flaky; avoid assertions that depend on zero-timeout native request races.

5. **Alpha verification commands**
   - `scripts/check`
   - `scripts/clean_install_load_test`
   - package/tarball smoke from the generated Hex package contents
   - `mix hex.build --unpack` or equivalent package-content audit
   - one optimized native smoke on macOS, for example `GUPPY_NATIVE_RELEASE=1 mix run examples/hello_world.exs`

## Production readiness baseline

### Runtime failure model

Use OTP semantics as the default recovery model:

- Guppy-owned server state should be small, ephemeral, and reconstructable.
- Elixir owner processes remain the source of truth for UI state.
- Native windows, native view registries, focus handles, scroll handles, and text-input entities are disposable projections/caches.
- Rustler/native code may monitor BEAM pids for cleanup notifications, but native code should not become the owner of OTP lifecycle.
- Prefer crashing/restarting supervised Elixir processes over complex in-place repair when state can be rebuilt.
- Do not attempt to reconcile arbitrary native windows after `Guppy.Server` restart unless there is a tested reason to keep them. Prefer Rustler monitor-driven event-target cleanup, best-effort native window cleanup, and owner-driven reopen/rerender.
- A BEAM-killing NIF crash or unrecoverable GPUI process failure is outside in-VM OTP recovery; document that such failures require external application restart.

Future production/release work, when explicitly prioritized, should focus on:

- release packaging/versioning/changelog policy
- precompiled artifact CI, checksum generation, and load tests per advertised target
- broader platform validation beyond the current macOS-first source-build path
- more manual and automated example smoke coverage, especially around window lifecycle and interactive controls
- clearer user-facing guidance for external restart requirements after BEAM-killing NIF crashes or unrecoverable GPUI process failures

`rustler_precompiled` is wired in, but source builds remain the default until release artifacts and checksums exist.

## New primitive definition of done

Every future primitive needs:

- Elixir IR helper and validation in `lib/guppy/ir.ex`
- template/compiler support in `Guppy.Component` / `~G` when author-facing
- Rust ETF decode in `native/guppy_nif/src/ir.rs`
- native render implementation under `native/guppy_nif/src/bridge_view/`
- native event behavior if interactive
- retained-state behavior if stateful
- ExUnit coverage for IR/template/server behavior
- Rust coverage for decode/render/event behavior
- example or compliance-port coverage
- `README.md` supported-surface update
- `docs/gpui-compliance.md` matrix update

## Deferred work

These are not active work unless explicitly reprioritized:

- select/dropdown primitives with real anchored overlay behavior
- menu APIs
- nested/full popover parity
- animation lifecycle primitives
- gradient style primitives
- grid layout primitives
- arbitrary per-item `uniform_list` renderers
- variable-height list / `ListState` parity
- full data-table/tree virtualization parity
- keyed subtree diffing without benchmark evidence
- full editor/rich-text parity
- custom painting/canvas and pattern painting
