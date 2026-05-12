# Guppy Hardening Plan

This is the active plan. Older scratch plans were removed because they described completed or superseded architecture work.

## Standard

Guppy should be treated as a serious Elixir/GPUI bridge, not a demo. The bar is:

- TDD-driven development from here forward
- small commits with clear descriptions of what was done and why
- one clear NIF boundary
- no bespoke C shim unless proven impossible
- native tests green
- measurable performance
- explicit GPUI compatibility tracking
- examples that double as regression coverage

## Current blunt assessment

Guppy has a promising architecture:

- Elixir owns UI state
- render output is a tree IR
- GPUI renders native windows
- native events route back to BEAM owners
- retained native state exists for focus, scroll, and text input

But it is not hardened yet:

- the native Rust test suite currently fails to compile
- there is no benchmark suite
- there is no GPUI compliance matrix
- the C NIF layer is too large and owns too much application logic
- high-frequency events are not coalesced
- GPUI example/test parity is unknown

## Decision: move to Rustler without a C shim

The Rustler migration should not be a cautious side spike. It should be the next architectural cleanup.

### Target

Remove `native/guppy_nif/c_src/guppy_nif.c` entirely.

Rustler should own:

- `ERL_NIF_INIT`
- NIF exports
- dirty scheduler flags
- argument decoding
- return encoding
- event payload encoding
- panic containment
- load/unload lifecycle hooks
- BEAM process references/resources where appropriate

Rust should still own:

- GPUI application/runtime state
- macOS main-thread startup
- request queueing to the GPUI main thread
- window registry
- BridgeView rendering
- retained GPUI state

### Main-thread requirement

The current C shim calls OTP's main-thread stealing APIs on macOS. The Rustler rewrite should call those APIs directly from Rust using `extern "C"` declarations if still required:

- `erl_drv_steal_main_thread`
- `erl_drv_stolen_main_thread_join`

If Rust can link and call those symbols directly, there is no justification for keeping a shim. If it cannot, document the exact linker/symbol issue before reintroducing any native shim.

### Desired boundary

```text
Elixir
  -> Rustler NIF module
    -> Rust GPUI runtime API
      -> GPUI main-thread request loop
```

There should be no C event-construction layer and no C request-decoding layer.

## Phase 0: restore baseline quality

Before large changes:

- work test-first: write or expose the failing check before implementation
- fix native test compile failure in `render_text_input.rs`
- make these commands green:

```sh
mix test
cd native/guppy_nif && cargo test
cd native/guppy_nif && cargo clippy --all-targets -- -D warnings
mix format --check-formatted
cd native/guppy_nif && cargo fmt --check
```

Add a single local check command or script that runs the full suite.

## Phase 1: Rustler rewrite

1. Add `:rustler` to Mix deps.
2. Add `rustler` crate dependency to `native/guppy_nif/Cargo.toml`.
3. Replace C NIF exports with Rustler functions:
   - `native_ping/0`
   - `native_build_info/0`
   - `native_runtime_status/0`
   - `native_gui_status/0`
   - `native_open_window/3`
   - `native_set_event_target/1`
   - `native_render/2`
   - `native_close_window/1`
   - `native_view_count/0`
4. Use Rustler dirty scheduling for calls that block on the GPUI main-thread request queue.
5. Move event sending into Rust using Rustler `OwnedEnv`/PID support.
6. Delete `c_src/` and the C build path from `build.rs`.
7. Keep the Elixir public API stable while replacing internals.

Exit criteria:

- no C source remains in the NIF implementation
- all current examples still open and render
- event routing still works
- native tests/clippy are green

## Phase 2: performance discipline

Add benchmarks before adding more widgets.

Required benchmark areas:

- `~G` template render cost for 10/100/1_000 nodes
- IR validation cost
- NIF encode/decode cost
- `Guppy.render/2` request latency p50/p95/p99
- event-to-rerender latency
- high-frequency event pressure: mouse move, drag move, scroll wheel
- kanban scenario: initial render, add card, move card, edit card, scroll

Required changes after measurement:

- coalesce high-frequency native events
- batch/debounce `Guppy.Window` rerenders where appropriate
- avoid repeated validation for static or trusted subtrees
- add telemetry/logging hooks for render and native request latency

## Phase 3: GPUI compliance matrix

Create a tracked matrix for upstream GPUI examples and high-level test cases.

Use the latest cloned Zed/GPUI repository as the source of truth, and periodically refresh the matrix against upstream changes so Guppy does not accidentally target stale examples or tests.

For each GPUI example/test:

- source path and upstream commit/reference
- Guppy port path
- status: supported / partial / unsupported / intentionally out of scope
- missing primitives
- automated smoke coverage if possible
- manual verification notes if not automatable yet

Initial examples to port first:

- `hello_world`
- `scrollable`
- `input`
- `drag_drop`
- `tab_stop`
- `image` / `svg`
- `window_positioning`

Known likely gaps:

- uniform list / virtualized list
- popover / anchored overlays
- editor / textarea
- custom painting / canvas
- animation
- menus
- advanced text layout and rich text runs
- grid/data-table parity

## Phase 4: supported surface contract

Update README to be precise:

- Guppy is not yet all of GPUI from Elixir.
- Guppy is an Elixir-owned state/render loop targeting a documented GPUI subset.
- The supported subset must be listed and tested.

Every new primitive needs:

- Elixir IR validation
- Rust decode
- render implementation
- event behavior if interactive
- retained-state behavior if applicable
- unit/integration tests
- example or compliance-port coverage

## Phase 5: hardening after Rustler/perf/compliance

Only after the above:

- add missing primitives in priority order
- consider keyed subtree diffing if benchmarks demand it
- strengthen supervision/restart behavior for native runtime failures
- expand cross-platform strategy beyond macOS

## Phase 6: distribution and precompiled artifacts

After the Rustler rewrite, tests, benchmarks, and compliance matrix are in place, add `rustler_precompiled` for user-friendly installation.

This is intentionally last because precompiled artifact distribution should package a stable native boundary, not hide churn.

Exit criteria:

- local source builds still work
- precompiled loading works on supported targets
- release process documents how native artifacts are produced
- CI builds and validates artifacts before publishing

## Non-goals for now

- adding more widgets before the Rustler rewrite
- preserving the existing C shim
- claiming full GPUI compatibility without a matrix
- optimizing based on anecdotes instead of benchmarks
- adding `rustler_precompiled` before the native boundary is stable
