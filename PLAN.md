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

The next work should be stabilization, real-user bug fixes, production-readiness hardening, documentation/examples, and explicitly scoped features. Do not expand the primitive or runtime surface speculatively.

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

For performance-sensitive changes, run benchmarks or probes from `docs/performance.md` before optimizing.

## Current priorities

1. Keep `scripts/check`, `mix guppy.native.build`, and the macOS source-build CI path green.
2. Harden native request failure behavior so `Guppy.Server` cannot be wedged by a stalled main-thread/native reply.
3. Implement OTP-style runtime recovery: let supervised Guppy processes crash/restart, keep Guppy-owned state minimal and reconstructable, and treat native windows as disposable projections of owner state.
4. Fix correctness bugs found by review, real example usage, or tests before adding surface area.
5. Keep `README.md`, `docs/gpui-compliance.md`, `docs/distribution.md`, and `examples/super_demo.exs` current when behavior changes.
6. Improve existing primitives only when the gap is clearly identified in the compliance matrix or by real usage.
7. Add new primitives only when explicitly prioritized and implemented end-to-end.
8. Add `rustler_precompiled` only when release/publishing work is explicitly prioritized.

## Production readiness hardening

### Runtime failure model

Use OTP semantics as the default recovery model:

- Guppy-owned server state should be small, ephemeral, and reconstructable.
- Elixir owner processes remain the source of truth for UI state.
- Native windows, native view registries, focus handles, scroll handles, and text-input entities are disposable projections/caches.
- Rustler/native code may monitor BEAM pids for cleanup notifications, but native code should not become the owner of OTP lifecycle.
- Prefer crashing/restarting supervised Elixir processes over complex in-place repair when state can be rebuilt.
- Do not attempt to reconcile arbitrary native windows after `Guppy.Server` restart unless there is a tested reason to keep them. Prefer Rustler monitor-driven event-target cleanup, best-effort native window cleanup, and owner-driven reopen/rerender.
- A BEAM-killing NIF crash or unrecoverable GPUI process failure is outside in-VM OTP recovery; document that such failures require external application restart.

No required remaining production-hardening work is currently tracked in this plan.

The current hardening baseline includes:

- timeout-aware native requests with stale main-thread request expiry before mutation
- normalized native timeout/unavailable errors at the Elixir public boundary
- event-target re-registration, Rustler monitor cleanup, generation-guarded stale `down` handling, and best-effort native view cleanup on server restart
- `Guppy.Window` reopen recovery that tolerates `view_id: nil` between failed reopen attempts and scheduled retries
- strict IR unknown-key checks, including validated/decoded/rendered text style support
- disabled checkbox/radio callback suppression
- informational `window_close_requested` semantics documented consistently; a veto/decision protocol should be a new explicit design if needed later
- native request/event path panic reduction for recoverable runtime conditions
- source-build, clean-install/load, format, lint, Elixir test, and native test gates

Keep `scripts/check`, `mix guppy.native.build`, source-build CI, and `scripts/clean_install_load_test` green before any public production-readiness claim. Add `rustler_precompiled` only when release/publishing work is explicitly prioritized.

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
- full editor/rich-text parity
- arbitrary per-item `uniform_list` renderers
- variable-height list / `ListState` parity
- nested/full popover parity
- animation lifecycle primitives
- gradient style primitives
- grid layout primitives
- custom painting/canvas and pattern painting
- menu APIs
- full data-table/tree virtualization parity
- keyed subtree diffing without benchmark evidence
- cross-platform/precompiled artifact support beyond the documented source-build baseline

## Non-goals for now

- reintroducing a C shim
- claiming full GPUI compatibility without matrix evidence
- optimizing based on anecdotes instead of benchmarks
- semantic theme tokens in core IR
- packaging/precompiled artifacts before release/publishing work is explicitly prioritized
