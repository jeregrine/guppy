# Guppy

## What this repo is

Guppy is an Elixir UI framework that renders through GPUI using a NIF-backed native runtime.

The intended architecture is:

- Elixir processes own UI state
- Elixir renders that state into a simple IR tree
- native code turns that IR into GPUI elements
- GPUI handles layout, paint, focus, scrolling, and windows
- native events roundtrip back to the owning Elixir process

This project is still unreleased. Do **not** preserve backwards compatibility just because some older internal shape existed.

## Repository scope

This `AGENTS.md` applies to the `./guppy` repo only.

Important repo rules:

- do **not** keep compatibility shims just because they already exist
- if a current design is in the way, replace it cleanly
- optimize for architectural clarity and correctness
- the jj/git repo root is `./guppy`
- do **not** initialize or commit from the parent directory unless explicitly asked
- use `jj` from inside `./guppy`

## Current architecture

Current high-level flow:

1. Elixir builds IR and calls the public API in `lib/guppy.ex`
2. `Guppy.Server` owns view ids, ownership, and event routing
3. `Guppy.Native.Nif` dispatches directly into NIF entrypoints
4. Rustler handles NIF bootstrap, exports, and BEAM interop
5. Rust decodes ETF into native IR
6. Rust enqueues main-thread requests directly into the GPUI runtime queue
7. `BridgeView` renders IR into GPUI elements
8. native events go back through Rustler into the BEAM
9. `Guppy.Server` forwards them to the owning Elixir process

Important current invariants:

- Elixir is the source of truth for UI state
- rendering is full-tree replacement from Elixir's point of view
- retained native state must be keyed by stable identity and pruned aggressively
- explicit node ids win over generated path ids
- style-op lists are ordered and order must be preserved
- prevalidated IR wrappers may skip Elixir-side validation, but must unwrap before native decode

## Important current implementation details

### Elixir side

- `Guppy.Server` is the central runtime server
- there is **not** a forwarding NIF GenServer anymore
- `Guppy.Native.Nif` is now a direct Elixir wrapper module around the NIF functions
- `Guppy.Window` is the preferred assign-based per-window process abstraction
- `Guppy.Component` / `~G` is the preferred template authoring path
- `Guppy.IR.validated/1` and `Guppy.IR.validated!/1` wrap trusted/static IR after one validation pass; server APIs unwrap before native dispatch
- runtime telemetry events exist for native NIF calls (`[:guppy, :native, :nif]`), server-mediated native requests (`[:guppy, :native, :request]`), native event routing (`[:guppy, :event, :route]`), and `Guppy.Window` rerenders (`[:guppy, :window, :rerender]`)

### Native side

- the old C shim was removed; Rustler now owns NIF entrypoints and BEAM interop
- the extra Rust runtime thread was removed
- NIF entrypoints enqueue requests directly into the main-thread runtime queue
- main-thread request drain scheduling is coalesced with an atomic scheduled flag
- ETF IR field lookup keys are cached in Rust
- native style lists use `Arc<[StyleOp]>`
- native event emission is implemented in Rust through Rustler `OwnedEnv`/`LocalPid` support
- native performance counters track Rust boundary IR/options encode-decode timing and native event send timing/failures
- native tests include GPUI simulated-click coverage for event bridge delivery

### Performance guidance

For interactive demos, especially scroll-heavy examples like the kanban board:

```bash
mix guppy.native.build --release
```

Debug native builds can feel much worse than release builds.

Do **not** add default scroll debounce, high-frequency event coalescing, or `Guppy.Window` rerender batching as a blind fix. Existing measurements did not justify defaults; first prove native-to-Elixir event traffic or repeated rerenders are actually the cause using benchmarks, `Guppy.native_performance_counters/0`, or the telemetry events above.

## Current public API surface

Useful top-level API:

- `Guppy.ping/0`
- `Guppy.open_window/1`
- `Guppy.open_window/2`
- `Guppy.open_window/3`
- `Guppy.open_window/4`
- `Guppy.render/2`
- `Guppy.close_window/1`
- `Guppy.native_view_count/0`
- `Guppy.native_build_info/0`
- `Guppy.native_runtime_status/0`
- `Guppy.native_gui_status/0`
- `Guppy.native_performance_counters/0`
- `use Guppy.Window`

Useful IR helpers today:

- `Guppy.IR.validated/1`
- `Guppy.IR.validated!/1`
- `Guppy.IR.unwrap/1`
- `Guppy.IR.text/2`
- `Guppy.IR.div/2`
- `Guppy.IR.scroll/2`
- `Guppy.IR.button/2`
- `Guppy.IR.checkbox/3`
- `Guppy.IR.radio/4`
- `Guppy.IR.text_input/2`
- `Guppy.IR.textarea/2`
- `Guppy.IR.image/2`
- `Guppy.IR.icon/2`
- `Guppy.IR.spacer/1`

## Current supported node kinds

Supported native nodes today:

- `:text`
- `:div`
- `:scroll`
- `:button`
- `:checkbox`
- `:radio`
- `:text_input`
- `:textarea`
- `:image`
- `:icon`
- `:spacer`

Still missing higher-value nodes/primitives:

- full editor/rich-text parity
- select primitive
- list / uniform list primitive
- tooltip / popover primitives

## Current preferred authoring model

Prefer this style unless the task is explicitly lower-level:

- `use Guppy.Window`
- assign/update helpers
- `~G`
- local function components
- prop declarations with `prop/3` / `prop/4`

Current `Guppy.Window` callback shape:

- `mount(arg, window)`
- `handle_event(event_name, event_data, window)`
- `handle_info(message, window)`
- `render(window)`

## Window options

Window options are passed as keyword lists and validated on the Elixir side before native decode.

Support is intentionally aligned to actual `gpui = 0.2.2`, not newer local upstream APIs.

Useful supported options include:

- `window_bounds`
- `titlebar`
- `focus`
- `show`
- `kind`
- `is_movable`
- `is_resizable`
- `is_minimizable`
- `display_id`
- `window_background`
- `app_id`
- `window_min_size`
- `window_decorations`
- `tabbing_identifier`

## Native bootstrap guidance

The native side is intentionally NIF-first.

Keep these assumptions unless there is a strong reason to replace them:

- ship a single native NIF artifact per target
- keep NIF bootstrap and BEAM interop in Rustler/Rust
- keep most runtime logic in Rust
- on macOS, preserve the OTP/wx-style main-thread strategy unless replacing it deliberately
- do **not** reintroduce `gpui_platform` casually
- do **not** reintroduce `dispatch2`
- the active dependency is `gpui = "0.2.2"` from crates.io
- `../zed` is for reference only, not as the active dependency source

For macOS bootstrap work, study OTP wx first:

- `~/projects/otp/lib/wx/c_src/wxe_main.cpp`
- `~/projects/otp/lib/wx/c_src/wxe_nif.c`

## Key files

Files you will most often need:

- `README.md` — user-facing docs
- `mix.exs` — Elixir app entry
- `config/config.exs` — native configuration
- `lib/guppy.ex` — public API
- `lib/guppy/server.ex` — ownership, lifecycle, event routing
- `lib/guppy/window.ex` — per-window Elixir abstraction
- `lib/guppy/component.ex` — `~G` and component helpers
- `lib/guppy/component/compiler.ex` — template compiler
- `lib/guppy/native/nif.ex` — direct Elixir NIF wrapper
- `lib/guppy/ir.ex` — Elixir IR validation/helpers
- `native/guppy_nif/src/lib.rs` — Rustler NIF entrypoints, event encoding, and request path
- `native/guppy_nif/src/main_thread_runtime.rs` — GPUI app bootstrap, request drain, window registry
- `native/guppy_nif/src/bridge_view.rs` — native root renderer
- `native/guppy_nif/src/bridge_view/` — render pass, style mapping, event bridge, identity, per-node renderers
- `native/guppy_nif/src/bridge_text_input.rs` — retained text input/textarea implementation
- `native/guppy_nif/src/ir.rs` — native IR and ETF decoding
- `examples/` — runnable demos
- `test/guppy_test.exs` — current coverage

Reference-only paths:

- `../zed` — Zed checkout for GPUI reference
- `../zed/crates/gpui` — GPUI source reference
- `PLAN.md` — active forward-looking project plan
- `docs/performance.md` — benchmark commands, telemetry/counter notes, and baseline results
- `docs/gpui-compliance.md` — GPUI compatibility matrix
- `bench/native_event_probe.exs` — manual GPUI-generated event timing probe
- `~/projects/otp` — OTP/wx internals

## Build and test workflow

From inside `./guppy`:

Build/install native code:

```bash
mix guppy.native.build
```

Release build:

```bash
mix guppy.native.build --release
```

Run tests:

```bash
mix test
```

Run the full local check suite:

```bash
scripts/check
```

Run the main examples:

```bash
mix run examples/super_demo.exs
mix run examples/kanban_todo.exs
mix run examples/hello_world.exs
```

If you touch native code, usually run at least:

```bash
mix guppy.native.build
mix test
```

If interactive feel matters, also test with:

```bash
mix guppy.native.build --release
mix run examples/kanban_todo.exs
```

For performance-sensitive changes, run:

```bash
mix run bench/guppy_bench.exs
mix run bench/guppy_bench.exs --native
```

For manual GPUI-generated event timing, run:

```bash
mix run bench/native_event_probe.exs --events=20
```

On macOS, `mix guppy.native.build` codesigns the copied NIF artifact in `priv/native/` to avoid stale ad-hoc signature kills after rebuilds.

Especially if you change:

- `native/guppy_nif/src/lib.rs`
- `native/guppy_nif/src/main_thread_runtime.rs`
- `native/guppy_nif/src/bridge_view.rs`
- anything under `native/guppy_nif/src/bridge_view/`
- `native/guppy_nif/src/bridge_text_input.rs`
- `native/guppy_nif/src/ir.rs`

## What to prioritize next

Follow `PLAN.md`. The active phase is primitive expansion: add missing high-value primitives end-to-end, with IR validation, template support, native decode/rendering, retained state when needed, tests, examples, README updates, and GPUI matrix updates.

Current priority order:

1. select primitive for common form controls
2. list / uniform-list primitive for larger repeated UI and scroll retention
3. tooltip/popover primitives after form/list work
4. full editor/rich-text parity only if explicitly scoped
5. runtime and distribution hardening after the primitive surface is more useful

Performance hardening has a sufficient baseline now; keep using measurements before optimizing. Do not add default scroll debounce, high-frequency event coalescing, keyed diffing, or `Guppy.Window` rerender batching without benchmark/counter/telemetry evidence.

Continue keeping `docs/gpui-compliance.md`, `README.md`, and examples current as compatibility work continues.

Do **not** push semantic theme-token ideas into core IR unless the user explicitly changes direction. Keep higher-level theming in Elixir.

## Commit guidance

This repo uses jj on top of git.

Typical flow from `./guppy`:

```bash
jj status
jj commit -m "your message"
jj log
```

If the user asks to push, use `jj` for that too.

If the user asked to review before commit, stop and report back first.

## Short orientation checklist

If you need to get oriented quickly:

1. read `README.md`
2. read `lib/guppy.ex`, `lib/guppy/server.ex`, `lib/guppy/window.ex`, and `lib/guppy/native/nif.ex`
3. read `lib/guppy/component.ex`, `lib/guppy/component/compiler.ex`, and `lib/guppy/ir.ex`
4. read `native/guppy_nif/src/lib.rs` and `native/guppy_nif/src/main_thread_runtime.rs`
5. read `native/guppy_nif/src/bridge_view.rs` and the relevant files under `native/guppy_nif/src/bridge_view/`
6. run `mix guppy.native.build`
7. run `mix test`
8. run `mix run examples/kanban_todo.exs` or `mix run examples/super_demo.exs` for an interactive smoke test
