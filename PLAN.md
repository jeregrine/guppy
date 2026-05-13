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

Required work:

1. Add bounded native request deadlines.
   - Thread caller timeout/deadline through `Guppy.Server`, `Guppy.Native.Nif`, and Rust request helpers.
   - Replace unbounded native reply waits with timeout-aware waits.
   - Return structured errors such as `{:error, :native_timeout}` or `{:error, :runtime_unavailable}` instead of leaving the server blocked.
   - Add failure-injection tests for a native bridge that never replies.
2. Make restart behavior explicit and tested.
   - On `Guppy.Server` init/restart, re-register the native event target.
   - Add a Rustler resource-backed monitor for the registered event-target pid using `Env::monitor` / `Resource::down`.
   - Store the native event target with a monitor generation/token so stale `down` callbacks cannot clear a newer restarted target.
   - When the monitored event-target pid exits, clear `EVENT_TARGET` and enqueue best-effort native cleanup such as `close_all`/`reset_views` if that is the chosen policy.
   - Add a native `close_all`/`reset_views` request if needed so restarted server state cannot be inconsistent with orphaned native windows.
   - Ensure `Guppy.Window` can observe Guppy runtime/server loss and reopen from current assigns/rendered state after restart.
   - Document behavior for lower-level `Guppy.open_window/1..4` owners that do not use `Guppy.Window`; they may need to reopen explicitly after runtime restart.
   - Add tests that crash/restart `Guppy.Server`, verify monitor-driven event-target clearing, verify event-target re-registration, verify native view cleanup or explicit invalidation, and verify a `Guppy.Window` can recover by reopening.
3. Fix reviewed interaction correctness bugs.
   - Disabled checkbox and radio nodes must not emit click/key change callbacks.
   - Window close-request semantics must be either explicitly informational or changed to a real veto/decision protocol.
   - IR validation should reject unknown keys so typos do not silently cross the bridge.
4. Tighten native boundary errors.
   - Preserve decode/runtime error reasons where useful instead of collapsing everything to `BadArg` or generic unavailability.
   - Remove panics/unwraps/expectations from request/event paths where a recoverable error can be returned.
   - Keep unsafe blocks documented at the boundary where Rust cannot prove safety.
5. Release/distribution gates before any public production claim.
   - Move GPUI `test-support` usage out of normal native builds if possible.
   - Keep source-build CI green.
   - Add clean-install/load tests before advertising any precompiled artifact.

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
