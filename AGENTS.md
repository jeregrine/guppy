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
- IR validation should reject unknown node keys; if a key is allowed it should be validated, decoded, and rendered or deliberately documented
- prevalidated IR wrappers may skip Elixir-side validation, but must unwrap before native decode
- native/main-thread requests carry deadlines; stale queued requests must not mutate native state after caller timeout
- `window_close_requested` is informational today, not a synchronous veto protocol

## Important current implementation details

### Elixir side

- `Guppy.Server` is the central runtime server
- there is **not** a forwarding NIF GenServer anymore
- `Guppy.Native.Nif` is now a direct Elixir wrapper module around the NIF functions
- `Guppy.Window` is the preferred assign-based per-window process abstraction
- `Guppy.Component` / `~GUI` is the preferred template authoring path
- `Guppy.Markdown` is an Elixir-side Markdown-to-IR component for a small subset; do not add Zed markdown crates unless explicitly designing that dependency
- `Guppy.IR.validated/1` and `Guppy.IR.validated!/1` wrap trusted/static IR after one validation pass; server APIs unwrap before native dispatch
- `Guppy.Window` monitors the Guppy runtime server and reopens from current assigns after supervised server restart; while reopen retry has `view_id: nil`, rerenders are skipped/deferred instead of rendering to an unknown view
- runtime telemetry events exist for native NIF calls (`[:guppy, :native, :nif]`), server-mediated native requests (`[:guppy, :native, :request]`), native event routing (`[:guppy, :event, :route]`), and `Guppy.Window` rerenders (`[:guppy, :window, :rerender]`)
- native root views bind Tab/Shift-Tab for GPUI tab-stop traversal, track keyboard-vs-mouse focus-visible state for `focus_visible_style`, and emit window focus/blur/move/resize lifecycle events from GPUI window observers
- div-like nodes support a narrow native opacity animation spec keyed by stable animation id
- app/runtime menus are process-owned via `Guppy.set_menus/1` / `Guppy.set_menus/2`; menu callback actions route back through `Guppy.Server` and menus are cleared when the owner exits
- app command helpers include `Guppy.App.command_bindings/1`, `Guppy.App.open_command_palette/1`, and `Guppy.App.open_context_menu/3` for command-backed shortcuts and transient overlays
- semantic `data_table` and `tree` primitives are first-pass virtualized/list-backed nodes; Elixir owns sort, selection, expansion, and context-menu state
- `canvas` is a bounded data-only native painting primitive for rect, rounded-rect, and slash-pattern rect commands with coarse click/context-menu events

### Native side

- NIF entrypoints enqueue requests directly into the main-thread runtime queue
- NIF request wrappers use timeout-aware waits and pass deadlines into queued main-thread requests; expired queued requests are dropped before mutation
- main-thread request drain scheduling is coalesced with an atomic scheduled flag
- ETF IR field lookup keys are cached in Rust
- native style lists use `Arc<[StyleOp]>`
- native compilation/loading is wired through `RustlerPrecompiled`; source builds are forced by default until release artifacts/checksums exist
- the RustlerPrecompiled target list is intentionally limited to currently supported precompiled targets (`aarch64-apple-darwin` today); do not add planned platforms until CI build/load validation exists
- native event emission is implemented in Rust through Rustler `OwnedEnv`/`LocalPid` support
- the registered event target is monitored with a Rustler resource; monitor generations prevent stale `down` callbacks from clearing newer registrations
- event-target loss clears native event delivery state and enqueues best-effort native window cleanup
- native performance counters track Rust boundary IR/options encode-decode timing and native event send timing/failures
- native tests include GPUI simulated-click coverage for event bridge delivery
- virtual `uniform_list`/`list`/`data_table`/`tree` renderers size their GPUI list element to the styled wrapper viewport; list-like nodes need a concrete viewport size in IR/style
- generic list-row `div` decode uses a restricted static-row path and avoids duplicate native decode/validation of nested row IR
- native canvas rendering uses GPUI `canvas`, `PaintQuad` fills, and `pattern_slash`; it currently retains no canvas-specific native resources beyond stable node identity

### Performance guidance

For interactive demos and manual performance work, use an optimized native build. Either run under prod:

```bash
MIX_ENV=prod mix run examples/stress_test.exs
```

or keep Mix in dev while forcing native release mode:

```bash
GUPPY_NATIVE_RELEASE=1 mix compile --force
```

Debug native builds can feel much worse than release builds.

`examples/stress_test.exs` is the current IR-bridge stress probe. It prints fps, render-call timings, native encode/decode counters, BEAM memory, mailbox depth, event deltas, and a stop summary. Keep current baselines, interpretation, and performance-specific next steps in `docs/performance.md`.

Do **not** add default scroll debounce, high-frequency event coalescing, keyed diffing, or `Guppy.Window` rerender batching as a blind fix. First prove the cause with `examples/stress_test.exs`, benchmarks, `Guppy.native_performance_counters/0`, or telemetry.

After the recent primitive expansion, prioritize a measured native cleanup/de-slopification pass before adding new primitives. Look for duplicated decode/render helpers, avoidable clones and string allocations, repeated full-tree conversion work, and style/color conversion duplication. Keep cleanups behavior-preserving, test-backed, and benchmarked when they touch hot paths.

## Current public API surface

Useful top-level API:

- `Guppy.ping/0`
- `Guppy.ping/1`
- `Guppy.open_window/1`
- `Guppy.open_window/2` (`Guppy.open_window(ir, opts)`)
- `Guppy.open_window/3` (`Guppy.open_window(ir, opts, timeout)`)
- `Guppy.render/2`
- `Guppy.render/3`
- `Guppy.close_window/1`
- `Guppy.close_window/2`
- `Guppy.set_menus/1`
- `Guppy.set_menus/2`
- `Guppy.open_file_dialog/0`
- `Guppy.open_file_dialog/1`
- `Guppy.open_file_dialog/2`
- `Guppy.choose_directory_dialog/0`
- `Guppy.choose_directory_dialog/1`
- `Guppy.choose_directory_dialog/2`
- `Guppy.save_file_dialog/0`
- `Guppy.save_file_dialog/1`
- `Guppy.save_file_dialog/2`
- `Guppy.read_clipboard_text/0`
- `Guppy.read_clipboard_text/1`
- `Guppy.write_clipboard_text/1`
- `Guppy.write_clipboard_text/2`
- `Guppy.native_view_count/0`
- `Guppy.native_view_count/1`
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
- `Guppy.IR.rich_text/2`
- `Guppy.IR.div/2`
- `Guppy.IR.scroll/2`
- `Guppy.IR.uniform_list/2`
- `Guppy.IR.list/2`
- `Guppy.IR.data_table/3`
- `Guppy.IR.tree/2`
- `Guppy.IR.canvas/2`
- `Guppy.IR.popover/4`
- `Guppy.ContextMenu.render/2`
- `Guppy.IR.select/2`
- `Guppy.IR.button/2`
- `Guppy.IR.checkbox/3`
- `Guppy.IR.radio/4`
- `Guppy.IR.text_input/2`
- `Guppy.IR.textarea/2`
- `Guppy.IR.image/2`
- `Guppy.IR.icon/2`
- `Guppy.IR.spacer/1`
- `Guppy.Markdown.render/1`

## Current supported node kinds

Supported native nodes today:

- `:text`
- `:div`
- `:scroll`
- `:uniform_list`
- `:list`
- `:data_table`
- `:tree`
- `:canvas`
- `:popover`
- `:select`
- `:button`
- `:checkbox`
- `:radio`
- `:text_input`
- `:textarea`
- `:image`
- `:icon`
- `:spacer`

Still missing higher-value nodes/primitives:

- full editor parity and advanced text layout beyond current rich text runs/highlights
- full popover parity / nested overlay edge cases
- advanced data-table/tree semantics beyond current first-pass virtualized primitives
- richer select/popover/overlay lifecycle and positioning
- advanced canvas commands such as paths/text/images and fine-grained hit testing
- dock menus and element-local/context menu primitives

## Current preferred authoring model

Prefer this style unless the task is explicitly lower-level:

- `use Guppy.Window`
- assign helpers (`update/3` remains available for HEEx-style compatibility but is not preferred over clear `assign` calls)
- `~GUI`
- dotted local function components (`<.my_fun>`)
- prop declarations with `prop/3` / `prop/4`

Current `Guppy.Window` callback shape:

- `mount(arg, window)`
- `render(window)`
- optional `handle_event(event_name, event_data, window)`
- optional/conventional `handle_info(message, window)` without `@impl Guppy.Window`

`use Guppy.Window` generates `child_spec/1`; missing optional callbacks and unmatched callback clauses are no-op handlers that skip rerendering. Preferred `Guppy.Window` modules currently drive lifecycle from `window_closed`; `window_close_requested` remains lower-level informational state and is not exposed as a veto callback.

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
- `lib/guppy/component.ex` — `~GUI` and component helpers
- `lib/guppy/component/compiler.ex` — template compiler
- `lib/guppy/native/nif.ex` — direct Elixir NIF wrapper
- `lib/guppy/ir.ex` — Elixir IR validation/helpers
- `native/guppy_nif/src/lib.rs` — Rustler NIF bootstrap, public NIF entrypoints, and request path
- `native/guppy_nif/src/native_events.rs` — native event C shims and event payload encoding
- `native/guppy_nif/src/native_event_test_support.rs` — native event snapshot helpers for tests
- `native/guppy_nif/src/main_thread_runtime.rs` — GPUI app bootstrap, request drain, window registry
- `native/guppy_nif/src/main_thread_runtime_tests.rs` — focused main-thread request/deadline tests
- `native/guppy_nif/src/bridge_view.rs` — native root renderer
- `native/guppy_nif/src/bridge_view_tests.rs` — root renderer retention/simulated-event tests
- `native/guppy_nif/src/bridge_view/` — render pass, style mapping, event bridge, identity, per-node renderers and focused renderer tests
- `native/guppy_nif/src/bridge_view/render_canvas.rs` — canvas/custom painting renderer
- `native/guppy_nif/src/bridge_text_input.rs` — retained text input/textarea implementation
- `native/guppy_nif/src/ir.rs` — native IR and ETF decoding
- `native/guppy_nif/src/ir_allowed.rs` — native IR allowed field/event schema
- `native/guppy_nif/src/ir_tests.rs` — focused native IR decode/validation tests
- `native/guppy_nif/src/menu.rs` — native app-menu decode/mapping/action dispatch
- `native/guppy_nif/src/menu_tests.rs` — focused native menu decode/mapping/action tests
- `native/guppy_nif/src/window_options_tests.rs` — focused native window option decode tests
- `examples/` — runnable demos
- `examples/stress_test.exs` — IR bridge stress probe with CLI performance output and isolation knobs
- `test/guppy_test.exs` — current coverage

Reference-only paths:

- `../zed` — Zed checkout for GPUI reference
- `../zed/crates/gpui` — GPUI source reference
- `PLAN.md` — active forward-looking project plan
- `docs/performance.md` — benchmark commands, telemetry/counter notes, and baseline results
- `docs/gpui-compliance.md` — GPUI compatibility matrix
- `docs/distribution.md` — source-build and future precompiled artifact plan
- `bench/native_event_probe.exs` — manual GPUI-generated event timing probe
- `~/projects/otp` — OTP/wx internals

## Build and test workflow

From inside `./guppy`:

Build Elixir and native code:

```bash
mix compile --force
```

Release build:

```bash
GUPPY_NATIVE_RELEASE=1 mix compile --force
```

Equivalent prod-mode compile/run path:

```bash
MIX_ENV=prod mix compile --force
```

Run tests:

```bash
mix test
```

Run the full local check suite, including bounded stress-test IR validation:

```bash
scripts/check
```

Before public release/distribution claims, also run:

```bash
scripts/clean_install_load_test
scripts/package_smoke
mix hex.build --unpack --output /tmp/guppy-hex-unpack
GUPPY_NATIVE_RELEASE=1 mix run examples/hello_world.exs
```

Run the main examples:

```bash
mix run examples/super_demo.exs
mix run examples/kanban_todo.exs
mix run examples/hello_world.exs
mix run examples/style_gallery.exs
mix run examples/list_row_controls.exs
mix run examples/menu_demo.exs
mix run examples/data_table_tree.exs
mix run examples/canvas_pattern.exs
MIX_ENV=prod mix run examples/stress_test.exs
```

If you touch native code, usually run at least:

```bash
mix compile --force
mix test
```

If interactive feel matters, also test with:

```bash
GUPPY_NATIVE_RELEASE=1 mix run examples/kanban_todo.exs
```

For performance-sensitive changes, run:

```bash
MIX_ENV=prod mix run examples/stress_test.exs
mix run bench/guppy_bench.exs
mix run bench/guppy_bench.exs --native
```

For manual GPUI-generated event timing, run:

```bash
mix run bench/native_event_probe.exs --events=20
```

Especially if you change:

- `native/guppy_nif/src/lib.rs`
- `native/guppy_nif/src/native_events.rs`
- `native/guppy_nif/src/main_thread_runtime.rs`
- `native/guppy_nif/src/bridge_view.rs`
- anything under `native/guppy_nif/src/bridge_view/`
- `native/guppy_nif/src/bridge_text_input.rs`
- `native/guppy_nif/src/ir.rs`
- `native/guppy_nif/src/menu.rs`

## What to prioritize next

`PLAN.md` tracks prospective work. Operationally, keep the project in stabilization/maintenance mode unless the user explicitly scopes new feature work. Prefer bug fixes, evidence-backed hardening, documentation/examples, and compliance-matrix maintenance over speculative new surface area.

Current priority order:

1. keep `scripts/check`, `mix compile`, `scripts/clean_install_load_test`, `scripts/package_smoke`, and the macOS source-build CI path green
2. perform the native cleanup/de-slopification pass in `PLAN.md`: duplicated decode/render helpers, unnecessary clones/allocations, style/color conversion duplication, and hot-path full-tree replacement costs
3. fix bugs found by real example usage or tests
4. keep `README.md`, `AGENTS.md`, `PLAN.md`, `docs/gpui-compliance.md`, `docs/distribution.md`, `docs/performance.md`, and examples current when behavior changes
5. harden existing primitives only when a real gap is identified, especially select/popover overlays, data-table/tree keyboard/focus behavior, richer text/editor parity, list row controls, canvas commands, gradients/animations, and menus
6. add brand-new primitives or publish precompiled artifacts only when explicitly prioritized and validated

Performance hardening has a useful baseline now; keep using measurements before optimizing and keep detailed baselines/next steps in `docs/performance.md`. Do not add default scroll debounce, high-frequency event coalescing, keyed diffing, or `Guppy.Window` rerender batching without stress-test, benchmark, counter, or telemetry evidence.

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
