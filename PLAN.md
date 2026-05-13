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

The first-pass GPUI compliance feature baseline has landed. Current end-to-end surface now covers:

1. **Anchored overlays / popover parity**: explicit anchor placement options, close lifecycle events, close-on-outside-click controls, and deferred-layer priority.
2. **Select/dropdown primitive**: Elixir-owned select IR/template support, native anchored option lists, close behavior, keyboard toggling/navigation, and event roundtrips.
3. **Generic and variable-height lists**: `Guppy.IR.list/2` / `<list />` backed by GPUI `ListState`, retained list state, variable-height static/layout row IR, and native item click routing.
4. **Focus traversal and focus-visible behavior**: Tab/Shift-Tab traversal bindings, `focus_visible_style`, focus/blur coverage for form controls including text inputs, and keyboard activation hardening.
5. **Rich text runs before full editor parity**: `Guppy.IR.rich_text/2` / `<rich_text />` styled runs and native highlight rendering without committing to full editor semantics.
6. **Grid layout primitives**: grid display, row/column counts, row/column spans, and full-span style ops sufficient for basic GPUI grid layouts.
7. **Animation lifecycle primitives**: stable-id native opacity animations with duration, repeat, and from/to opacity designed for Elixir-owned full-tree rendering.

Remaining exact-parity gaps are tracked in `docs/gpui-compliance.md` and should be picked up as explicitly scoped hardening work. Canvas/custom painting can still wait until after those narrower compliance gaps are prioritized.

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
