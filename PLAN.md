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
mix guppy.native.build
mix run examples/hello_world.exs
```

Before public release/distribution claims, also run:

```sh
scripts/clean_install_load_test
```

For performance-sensitive changes, run benchmarks or probes from `docs/performance.md` before optimizing.

## Current priorities

1. Keep `scripts/check`, `mix guppy.native.build`, `scripts/clean_install_load_test`, and the macOS source-build CI path green.
2. Fix correctness bugs found by review, real example usage, or tests before adding surface area.
3. Keep `README.md`, `AGENTS.md`, `PLAN.md`, `docs/gpui-compliance.md`, `docs/distribution.md`, `docs/performance.md`, and examples current when behavior changes.
4. Improve existing primitives only when the gap is clearly identified in the compliance matrix or by real usage.
5. Add new primitives only when explicitly prioritized and implemented end-to-end.
6. Add `rustler_precompiled` only when release/publishing work is explicitly prioritized.

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
- precompiled artifact CI and load tests per advertised target
- broader platform validation beyond the current macOS-first source-build path
- more manual and automated example smoke coverage, especially around window lifecycle and interactive controls
- clearer user-facing guidance for external restart requirements after BEAM-killing NIF crashes or unrecoverable GPUI process failures

Add `rustler_precompiled` only when release/publishing work is explicitly prioritized.

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
