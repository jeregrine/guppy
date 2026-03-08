# Guppy

## Mission

Guppy is an Elixir UI framework that renders through GPUI using a NIF-backed native runtime.

Optimize for this architecture:

- Elixir processes own UI state
- Elixir renders UI state into an IR tree
- native code builds GPUI elements from that IR
- GPUI owns layout, paint, focus, scrolling, and windows
- native events roundtrip back to the owning Elixir process

The project is still early and unreleased. Prefer the architecture that makes the system cleaner and more correct over preserving any previous internal shape.

## Repository scope

This `AGENTS.md` applies to the `./guppy` repo only.

Important repo rules:

- do **not** preserve backwards compatibility just because an older approach exists
- if a current design is limiting, replace it cleanly
- optimize for architectural clarity and correctness, not compatibility shims
- the jj/git repo root is `./guppy`
- do **not** initialize or commit from the parent directory unless explicitly asked
- use `jj` from inside `./guppy`

## Current intent

What Guppy is proving right now:

- a Cargo-built NIF can load successfully
- a C shim plus Rust core can ship as one native artifact
- macOS main-thread bootstrap can work through OTP/wx-style runtime hooks
- Elixir can open, update, and close real GPUI windows
- Elixir can render a tree-shaped IR through a native `BridgeView`
- stable node identity can support retained native state across rerenders
- owner-process cleanup can close native windows on `DOWN`

What matters more than breadth right now:

- stable identity
- correct retained-state pruning
- simple full-tree replacement semantics
- correct owner/event routing
- clean native runtime structure

## Current architecture

High-level flow:

1. Elixir code builds IR and calls the public API in `lib/guppy.ex`
2. `Guppy.Server` owns window ownership and request routing
3. the Elixir NIF wrapper forwards requests to native
4. the C shim handles NIF bootstrap and macOS main-thread handoff
5. Rust decodes ETF into native IR and queues work for the main-thread runtime
6. `BridgeView` renders the IR into GPUI elements
7. native events go back through the C shim into the BEAM
8. `Guppy.Server` forwards them to the owning Elixir process

Important invariants:

- Elixir is the source of truth for UI state
- native rendering is full-tree replacement from Elixir's point of view
- retained native state must be keyed by stable identity and pruned aggressively
- explicit node ids override generated path ids
- ordered style-op lists must preserve order

## Current public surface

Useful APIs today:

- `Guppy.ping/0`
- `Guppy.open_window/1`
- `Guppy.open_window/2`
- `Guppy.render/2`
- `Guppy.close_window/1`
- `Guppy.native_view_count/0`
- `Guppy.native_build_info/0`
- `Guppy.native_runtime_status/0`
- `Guppy.native_gui_status/0`
- `Guppy.IR.text/2`
- `Guppy.IR.div/2`
- `Guppy.IR.scroll/2`
- `Guppy.IR.button/2`
- `Guppy.IR.text_input/2`

Current supported native nodes are intentionally limited:

- `:text`
- `:div`
- `:scroll`
- `:button`
- `:text_input`

## Project layout

Files you will most often need:

- `README.md` — user-facing status and usage
- `mix.exs` — Elixir app entry
- `config/config.exs` — native module configuration
- `lib/guppy.ex` — public API
- `lib/guppy/server.ex` — ownership, lifecycle, and native event routing
- `lib/guppy/native/nif.ex` — Elixir NIF wrapper and load path
- `lib/guppy/ir.ex` — Elixir IR validation/helpers
- `lib/mix/tasks/guppy.native.build.ex` — native build/install task
- `native/guppy_nif/c_src/guppy_nif.c` — C shim, NIF entrypoints, main-thread bootstrap
- `native/guppy_nif/src/lib.rs` — Rust runtime core and command routing
- `native/guppy_nif/src/main_thread_runtime.rs` — GPUI app bootstrap, request drain, window registry
- `native/guppy_nif/src/bridge_view.rs` — root native renderer
- `native/guppy_nif/src/bridge_view/` — render pass, identity, styles, event bridge, per-node renderers
- `native/guppy_nif/src/bridge_text_input.rs` — retained text input implementation
- `native/guppy_nif/src/ir.rs` — native IR and ETF decoding
- `examples/` — runnable demos
- `test/guppy_test.exs` — lifecycle/integration coverage

Reference-only paths:

- `../zed` — Zed checkout for GPUI reference
- `../zed/crates/gpui` — GPUI source reference
- `../guppy-plan.md` — evolving project plan
- `~/projects/otp` — OTP/wx internals, especially main-thread patterns

## Native implementation guidance

The native side is intentionally NIF-first.

Keep these decisions unless there is a strong reason to change them:

- ship a single native NIF artifact per target
- keep the C layer focused on bootstrap and BEAM interop
- keep most runtime logic in Rust
- on macOS, preserve the OTP/wx-style main-thread strategy unless replacing it deliberately
- do **not** reintroduce `gpui_platform` casually
- do **not** reintroduce `dispatch2`
- the active GPUI dependency is `gpui = "0.2.2"` from crates.io
- the local `../zed` checkout is for reading, not as the active dependency path

When working on bootstrap or GUI lifecycle code, be extra careful about:

- main-thread ownership
- runtime startup/shutdown behavior
- request queue draining behavior
- window close semantics
- owner-process cleanup

For macOS bootstrap changes, study OTP wx first:

- `~/projects/otp/lib/wx/c_src/wxe_main.cpp`
- `~/projects/otp/lib/wx/c_src/wxe_nif.c`

## Bridge-view guidance

The bridge is no longer just a tracer-shot text bridge. Treat it as the core of the rendering architecture.

Important assumptions:

- `BridgeView` is the native root renderer
- rendering is driven from native IR, not ad hoc native widget state
- retained native state lives outside the per-render pass
- render passes collect live retained ids and pruning happens after render
- explicit node ids are preferred for retained or eventful elements
- generated ids must stay stable for unchanged paths

Current retained native state includes:

- scroll handles
- focus handles
- focus subscriptions
- text input entities

When extending the bridge:

- keep identity logic centralized
- keep event emission centralized
- keep node renderers focused and phase-structured
- preserve ordered style-op semantics
- add tests for identity, pruning, and other regression-prone behavior

## What to prioritize next

Good next steps:

1. keep improving native renderer decomposition when files grow large
2. add high-value tests around retained state and event behavior
3. expand widget/style/event support carefully, not broadly
4. keep tracer-shot naming and structure moving toward runtime-oriented naming
5. preserve the simplicity of the full-tree replacement model

Things to avoid unless explicitly requested:

- wx API compatibility
- Port sidecar transport
- HEEx-first APIs
- compatibility shims for older internal designs
- over-generalized abstractions before the bridge proves they help
- broad widget coverage before identity and retained behavior are solid

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

Run the main demo:

```bash
mix run examples/super_demo.exs
```

Run the small bring-up example:

```bash
mix run examples/hello_world.exs
```

If you touch native code, usually run at least:

```bash
mix guppy.native.build
mix test
```

Especially if you change:

- `native/guppy_nif/c_src/guppy_nif.c`
- `native/guppy_nif/src/lib.rs`
- `native/guppy_nif/src/main_thread_runtime.rs`
- `native/guppy_nif/src/bridge_view.rs`
- anything under `native/guppy_nif/src/bridge_view/`
- `native/guppy_nif/src/bridge_text_input.rs`
- `native/guppy_nif/src/ir.rs`

## Commit guidance

This repo uses jj on top of git.

Typical flow from `./guppy`:

```bash
jj status
jj commit -m "your message"
jj log
```

If the user asked to review before commit, stop and report back first.

## Short orientation checklist

If you need to get oriented quickly:

1. read `README.md`
2. read `lib/guppy.ex`, `lib/guppy/server.ex`, and `lib/guppy/native/nif.ex`
3. read `lib/guppy/ir.ex`
4. read `native/guppy_nif/c_src/guppy_nif.c`
5. read `native/guppy_nif/src/lib.rs` and `native/guppy_nif/src/main_thread_runtime.rs`
6. read `native/guppy_nif/src/bridge_view.rs` and the relevant files under `native/guppy_nif/src/bridge_view/`
7. run `mix guppy.native.build`
8. run `mix test`
9. run `mix run examples/super_demo.exs` if you need a full interactive smoke test
