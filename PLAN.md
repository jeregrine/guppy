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

Required remaining work:

1. Close the native-timeout late-side-effect gap.
   - Bounded waits exist, but `native/guppy_nif/src/lib.rs` still enqueues a main-thread request and then waits with `recv_timeout`; if the wait times out, the queued request may still run later.
   - Thread absolute deadlines, cancellation, or request generations through `MainThreadRequest` so stale queued requests cannot mutate native state after their caller has timed out.
   - Specifically fix `open_window` ambiguity: a timed-out open must not leave an untracked native window or allow a later reused `view_id` to point at stale native state.
   - Add failure-injection tests for requests that time out and then drain later, including `open_window`, `render`, `close_window`, `close_all`, and `view_count` where applicable.
2. Fix remaining native/Elixir error normalization holes.
   - `lib/guppy/native/nif.ex`: `dispatch({:view_count, []}, timeout)` currently wraps native results as `{:ok, native_view_count(timeout)}`; native `{:error, reason}` values must be normalized instead of returned as successful payloads.
   - Add coverage for `view_count` timeout/unavailable errors returning `{:error, reason}` at the public API boundary.
3. Complete restart/reopen recovery edge cases.
   - `lib/guppy/window.ex`: after a failed reopen sets `view_id: nil`, normal messages/events must not call `Guppy.render(nil, ...)` and crash/stop on `:unknown_view_id`.
   - Add a `rerender/1` path for `view_id == nil` that reopens, skips, or defers rendering until a native view exists.
   - Add a test for a message arriving between a failed reopen and the scheduled retry, plus restart tests that verify `Guppy.Window` reopens from current assigns.
4. Tighten event-target monitor semantics.
   - `native/guppy_nif/src/lib.rs`: if `Env::monitor` returns `None`, `native_set_event_target/1` should return a structured error instead of registering an unmonitored event target.
   - Keep the event-target generation/token stale-`down` guard covered by tests.
5. Resolve the strict-IR validation mismatch.
   - `lib/guppy/ir.ex`: `:text` currently allows `:style`, but text style is not validated, decoded, or rendered natively.
   - Either remove `:style` from text allowed keys or implement text style validation, native ETF decode, and native rendering.
   - Add regression coverage so unsupported/unknown text keys do not silently cross the bridge.
6. Remove remaining avoidable native event-path unwraps/panics.
   - `native/guppy_nif/src/lib.rs`: add `button` to `rustler::atoms!` and replace mouse-event `Atom::from_str(...).unwrap()` calls.
   - Continue auditing request/event paths for `unwrap`/`expect`/`panic` that can occur from external input or runtime state; keep only impossible static construction or test-only uses, and document why.
   - Keep unsafe blocks documented at FFI/string-pointer boundaries where Rust cannot prove safety.
7. Make close-request semantics consistent across docs and tracking.
   - The current API documents `window_close_requested` as informational and not vetoable; keep `README.md`, `docs/gpui-compliance.md`, and this plan aligned with that decision.
   - If a veto/decision protocol becomes required, design it as a new explicit synchronous protocol instead of overloading the current informational event.
8. Keep production-claim gates explicit.
   - Keep `scripts/check`, `mix guppy.native.build`, source-build CI, and `scripts/clean_install_load_test` green before any public production-readiness claim.
   - Add `rustler_precompiled` only when release/publishing work is explicitly prioritized.

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
