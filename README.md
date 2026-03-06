# Guppy

Guppy is an Elixir UI framework targeting GPUI through a NIF-backed native runtime.

Current status: early tracer-shot bring-up, but with a real native GPUI window opening from Elixir.

## What works today

Today the project can:

- load a Cargo-built NIF
- bootstrap a native GPUI app on macOS using a wx-style main-thread handoff
- open a real GPUI window from Elixir
- focus/activate that window
- mount minimal Elixir IR into the window
- replace that IR and rerender
- close native windows when the owning Elixir process dies

The current tracer-shot API is intentionally small:

- `Guppy.open_window/0`
- `Guppy.mount/2`
- `Guppy.update/2`
- `Guppy.close_window/1`
- `Guppy.IR.text/1`
- `Guppy.IR.div/1`

## Native build

Build and install the native NIF into `priv/native`:

```bash
cd guppy
mix guppy.native.build
```

Release profile:

```bash
cd guppy
mix guppy.native.build --release
```

## Sanity check the native bridge

```bash
cd guppy
mix run -e 'IO.inspect(Guppy.Native.Nif.load_status()); IO.inspect(Guppy.native_build_info()); IO.inspect(Guppy.native_runtime_status()); IO.inspect(Guppy.native_gui_status()); IO.inspect(Guppy.ping())'
```

Expected output after a successful build/install is roughly:

```elixir
:ok
{:ok, "guppy_nif_rust_core"}
{:ok, "started"}
{:ok, "started"}
{:ok, :pong}
```

## Hello-world example

Run the current tracer-shot example:

```bash
cd guppy
mix guppy.native.build
mix run examples/hello_world.exs
```

What it does:

- opens a real focused GPUI window from Elixir
- mounts minimal IR text
- updates that IR after 1 second
- closes the window after 5 seconds

## Current architecture

The current implementation is NIF-first.

Packaging direction:

- a small C shim for low-level Erlang/ERTS bootstrap
- a Rust core linked into the same final native library
- one native NIF artifact per target
- no separate sidecar process
- no separate shipped C artifact

High-level flow:

1. Elixir calls into the NIF wrapper
2. the C shim owns NIF bootstrap and macOS main-thread handoff
3. Rust owns most of the native runtime logic
4. Elixir requests go through a native queue
5. the main-thread GPUI app drains requests and mutates UI state
6. GPUI renders and rerenders from Elixir-driven state

## Reference repositories

The active dependency is currently `gpui = "0.2.2"` from crates.io.

Useful references while developing:

- `../zed` — reference checkout of Zed
- `../zed/crates/gpui` — GPUI source reference
- `../guppy-plan.md` — project plan
- `~/projects/otp` — OTP/wx internals, especially:
  - `lib/wx/c_src/wxe_main.cpp`
  - `lib/wx/c_src/wxe_nif.c`

## Known limitations

The tracer shot is real, but still intentionally narrow:

- native rendering is still backed by a specialized `HelloWindow` root view
- Elixir IR helpers include `:div` and `:text`, but native handling is effectively text-first today
- there is not yet a general recursive `BridgeView` rendering arbitrary IR trees
- event routing is still minimal
- style mapping is still minimal

## Development workflow

Common commands:

```bash
cd guppy
mix guppy.native.build
mix test
mix run examples/hello_world.exs
```

If you change native code under `native/guppy_nif/`, rebuild before testing.
