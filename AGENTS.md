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
- native root views bind Tab/Shift-Tab for GPUI tab-stop traversal and track keyboard-vs-mouse focus-visible state for `focus_visible_style`
- div-like nodes support a narrow native opacity animation spec keyed by stable animation id

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
- virtual `uniform_list`/`list` renderers size their GPUI list element to the styled wrapper viewport; list-like nodes need a concrete viewport size in IR/style
- generic list-row `div` decode uses a restricted static-row path and avoids duplicate native decode/validation of nested row IR

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

## Current public API surface

Useful top-level API:

- `Guppy.ping/0`
- `Guppy.open_window/1`
- `Guppy.open_window/2` (`Guppy.open_window(ir, opts)`)
- `Guppy.open_window/3` (`Guppy.open_window(ir, opts, timeout)`)
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
- `Guppy.IR.rich_text/2`
- `Guppy.IR.div/2`
- `Guppy.IR.scroll/2`
- `Guppy.IR.uniform_list/2`
- `Guppy.IR.list/2`
- `Guppy.IR.popover/4`
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
- advanced grid/data-table semantics beyond current grid style ops

## Current preferred authoring model

Prefer this style unless the task is explicitly lower-level:

- `use Guppy.Window`
- assign helpers
- `~GUI`
- local function components
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
- `native/guppy_nif/src/lib.rs` — Rustler NIF entrypoints, event encoding, and request path
- `native/guppy_nif/src/main_thread_runtime.rs` — GPUI app bootstrap, request drain, window registry
- `native/guppy_nif/src/bridge_view.rs` — native root renderer
- `native/guppy_nif/src/bridge_view/` — render pass, style mapping, event bridge, identity, per-node renderers
- `native/guppy_nif/src/bridge_text_input.rs` — retained text input/textarea implementation
- `native/guppy_nif/src/ir.rs` — native IR and ETF decoding
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

Run the full local check suite:

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
- `native/guppy_nif/src/main_thread_runtime.rs`
- `native/guppy_nif/src/bridge_view.rs`
- anything under `native/guppy_nif/src/bridge_view/`
- `native/guppy_nif/src/bridge_text_input.rs`
- `native/guppy_nif/src/ir.rs`

## What to prioritize next

`PLAN.md` tracks only the forward feature plan. Operationally, keep the project in stabilization/maintenance mode unless the user explicitly scopes new feature work. Prefer bug fixes, evidence-backed hardening, documentation/examples, and compliance-matrix maintenance over speculative new surface area.

Current priority order:

1. keep `scripts/check`, `mix compile`, `scripts/clean_install_load_test`, `scripts/package_smoke`, and the macOS source-build CI path green
2. fix bugs found by real example usage or tests
3. keep `README.md`, `AGENTS.md`, `PLAN.md`, `docs/gpui-compliance.md`, `docs/distribution.md`, `docs/performance.md`, and examples current when behavior changes
4. improve existing primitives only when a real gap is identified
5. add new primitives or publish precompiled artifacts only when explicitly prioritized

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
