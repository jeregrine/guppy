# Guppy Forward Plan

This file tracks future work only. Implementation history belongs in commit history, docs, examples, and the GPUI compliance matrix.

## Current mode

Guppy has a useful baseline for:

- Elixir-owned window state and full-tree rendering
- the Rustler/GPUI native bridge
- the current documented primitive set
- runtime lifecycle telemetry and native request containment
- GPUI compliance tracking
- source-build package/distribution readiness

The production-hardening and source-build alpha-readiness passes tracked here have landed. The next work should be stabilization, real-user bug fixes, documentation/examples, compliance-matrix maintenance, release/distribution execution when explicitly prioritized, and explicitly scoped features. Do not expand the primitive or runtime surface speculatively.

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
scripts/package_smoke
```

For performance-sensitive changes, run benchmarks or probes from `docs/performance.md` before optimizing.

## Current priorities

1. Keep `scripts/check`, `mix compile`, `scripts/clean_install_load_test`, `scripts/package_smoke`, and the macOS source-build CI path green.
2. Fix correctness bugs found by review, real example usage, or tests before adding surface area.
3. Keep `README.md`, `AGENTS.md`, `PLAN.md`, `docs/gpui-compliance.md`, `docs/distribution.md`, `docs/performance.md`, and examples current when behavior changes.
4. Improve existing primitives only when the gap is clearly identified in the compliance matrix or by real usage.
5. Add new primitives only when explicitly prioritized and implemented end-to-end.
6. Publish precompiled artifacts only after artifact CI, load tests, and checksums exist.

## GPUI compliance feature priorities

When feature work is explicitly prioritized, improve GPUI compliance in this order:

1. **Anchored overlays / popover parity**: explicit anchor placement, close lifecycle, nested/deferred overlay behavior, and stronger popover semantics.
2. **Select/dropdown primitive**: native-quality option list positioning, close behavior, keyboard navigation, and event roundtrips.
3. **Generic and variable-height lists**: arbitrary row IR renderers, closer `ListState` parity, retained scroll/item state, and better virtualization behavior.
4. **Focus traversal and focus-visible behavior**: tab ordering, focus-visible styling semantics, and stronger form-control keyboard behavior.
5. **Rich text runs before full editor parity**: styled runs, highlights, and layout controls without committing immediately to full editor semantics.
6. **Grid layout primitives**: enough grid support to port GPUI grid examples and data/table-like layouts more directly.
7. **Animation lifecycle primitives**: timing/lifecycle APIs designed around Elixir-owned full-tree rendering.

Canvas/custom painting can wait until after these GPUI-compliance gaps are addressed.

## Source-build release verification

Before cutting or claiming a source-build release, rerun and audit:

```sh
scripts/check
scripts/clean_install_load_test
scripts/package_smoke
mix hex.build --unpack --output /tmp/guppy-hex-unpack
GUPPY_NATIVE_RELEASE=1 mix run examples/hello_world.exs
```

Also confirm `docs/gpui-compliance.md` still records the current GPUI reference, update `CHANGELOG.md` and the package version for the release, and do not attach native artifacts unless CI built and load-tested every advertised artifact and generated the required checksums.

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

- release versioning/changelog maintenance and publication execution
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

## Other deferred work

These are not active work unless explicitly reprioritized separately from the GPUI compliance feature priorities above:

- menu APIs
- gradient style primitives
- full data-table/tree virtualization beyond the grid/list work above
- keyed subtree diffing without benchmark evidence
- custom painting/canvas and pattern painting until after the GPUI compliance feature priorities above
