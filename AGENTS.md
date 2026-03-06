# Guppy

## What is this?

Guppy is an Elixir UI framework targeting GPUI through a NIF-backed native runtime.

Current architectural direction:

- Elixir processes own UI state
- Elixir renders to a tree/IR description
- native side builds GPUI elements from that IR
- GPUI handles layout, paint, focus, and windowing

Today, the tracer-shot implementation proves:

- a Cargo-built NIF can load successfully
- a small C shim plus Rust core can be linked into one native artifact
- macOS main-thread bootstrap can happen through OTP/wx-style runtime hooks
- Elixir can open a real GPUI window
- Elixir can mount/update minimal IR and trigger rerender
- owner-process cleanup closes native windows on `DOWN`

## Repository scope

This `AGENTS.md` applies to the `./guppy` repo only.

Important:

- the jj/git repo is rooted at `./guppy`
- do **not** initialize or commit from the parent directory unless explicitly asked
- use `jj` commands from inside `./guppy`

## Project layout

### Files inside this repo

- `mix.exs` — Elixir app entry
- `config/config.exs` — NIF path and native module config
- `lib/guppy.ex` — public API
- `lib/guppy/server.ex` — ownership, view tracking, request routing
- `lib/guppy/native/nif.ex` — Elixir NIF wrapper and load path
- `lib/guppy/ir.ex` — minimal Elixir IR helpers
- `lib/mix/tasks/guppy.native.build.ex` — builds and installs the native library
- `native/guppy_nif/c_src/guppy_nif.c` — C shim / NIF entry / main-thread bootstrap
- `native/guppy_nif/src/lib.rs` — Rust runtime core / command routing
- `native/guppy_nif/src/hello_window.rs` — current tracer-shot GPUI window bridge
- `examples/hello_world.exs` — runnable tracer-shot example
- `test/guppy_test.exs` — bring-up / lifecycle tests
- `README.md` — user-facing bring-up docs

### Reference-only paths

These are **not** part of the `./guppy` repo's source of truth, but are useful references.

- `../zed` — reference checkout of Zed
- `../zed/crates/gpui` — GPUI source reference
- `../guppy-plan.md` — evolving project plan
- `~/projects/otp` — OTP/wx internals, especially NIF/main-thread patterns

## Current native architecture

The current implementation is intentionally NIF-first, not Port-first.

Key points:

- shipping target is a single native NIF artifact per target
- C shim owns low-level NIF bootstrap concerns
- Rust owns most runtime logic
- on macOS, the C shim currently uses `erl_drv_steal_main_thread`, following the wx pattern
- the native app is booted once and kept alive
- Elixir requests go through a native queue before reaching the main-thread GPUI app

Important practical notes:

- the current tracer shot uses `gpui = "0.2.2"` from crates.io
- do **not** reintroduce `gpui_platform` unless there's a compelling reason
- do **not** reintroduce `dispatch2`; the current implementation uses GPUI's own async/task facilities to poll the request queue on the main thread
- the local `../zed` checkout is for reading/reference, not for the active dependency path

## Current public API surface

Useful functions today:

- `Guppy.ping/0`
- `Guppy.open_window/0`
- `Guppy.mount/2`
- `Guppy.update/2`
- `Guppy.update_window_text/2`
- `Guppy.close_window/1`
- `Guppy.native_view_count/0`
- `Guppy.native_build_info/0`
- `Guppy.native_runtime_status/0`
- `Guppy.native_gui_status/0`
- `Guppy.IR.text/2`
- `Guppy.IR.div/2`

## Current tracer-shot limitations

The current bridge is still intentionally narrow:

- native rendering now goes through a `BridgeView`
- minimal IR validation exists on the Elixir side
- supported native nodes are still intentionally small (`:div` + `:text`)
- click and window-close are the only native event roundtrips today
- style mapping exists, but only as a small explicit subset on `:div`
- explicit node ids now exist, but richer keyed/stateful behaviors are still ahead

So if you are extending the project, the next likely architectural moves are:

- keep expanding style/event coverage carefully without breaking the simple IR model
- keep the full-tree replacement invariant
- add more events only after the identity model stays stable

## Main-thread / macOS guidance

This project has already proven that a real GPUI window can open from the NIF path.

When working on the native bootstrap:

- be very careful with main-thread ownership
- prefer studying OTP wx before changing bootstrap behavior
- relevant OTP files live under `~/projects/otp/lib/wx/c_src/`
- especially study:
  - `wxe_main.cpp`
  - `wxe_nif.c`

The current design assumption is that GUI bootstrap on macOS is a special case and may require runtime tricks similar to wx.

## Build and test workflow

From inside `./guppy`:

### Build/install native NIF

```bash
mix guppy.native.build
```

Release build:

```bash
mix guppy.native.build --release
```

### Run tests

```bash
mix test
```

### Run the tracer-shot example

```bash
mix run examples/hello_world.exs
```

## Expected example behavior

The example should:

- load the NIF
- open a real focused GPUI window
- mount IR text
- update IR text after a short delay
- close the window after a few seconds

## When changing native code

If you touch any of these:

- `native/guppy_nif/c_src/guppy_nif.c`
- `native/guppy_nif/src/lib.rs`
- `native/guppy_nif/src/hello_window.rs`

then you should normally run:

```bash
mix guppy.native.build
mix test
```

## Commit guidance

This repo uses jj on top of git.

Typical flow from `./guppy`:

```bash
jj status
jj commit -m "your message"
jj log
```

## Non-goals right now

Avoid spending time on these unless explicitly requested:

- wx API compatibility
- Port sidecar transport
- HEEx-first APIs
- full styling/token system before the bridge view exists
- broad widget/event coverage before minimal IR is solid

## Short version for future agents

If you need to orient quickly:

1. read `README.md`
2. read `lib/guppy.ex`, `lib/guppy/server.ex`, and `lib/guppy/native/nif.ex`
3. read `native/guppy_nif/c_src/guppy_nif.c`
4. read `native/guppy_nif/src/lib.rs` and `native/guppy_nif/src/hello_window.rs`
5. run `mix guppy.native.build`
6. run `mix test`
7. run `mix run examples/hello_world.exs`
