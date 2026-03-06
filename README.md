# Guppy

Guppy is an Elixir UI framework targeting GPUI.

Current status: early tracer-shot bring-up.

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

After building, you can sanity check the native bridge:

```bash
cd guppy
mix run -e 'IO.inspect(Guppy.Native.Nif.load_status()); IO.inspect(Guppy.native_build_info()); IO.inspect(Guppy.ping())'
```

Expected output after a successful build/install is roughly:

```elixir
:ok
{:ok, "guppy_nif_rust_core"}
{:ok, :pong}
```

## Example

Run the hello-world tracer shot:

```bash
cd guppy
mix guppy.native.build
mix run examples/hello_world.exs
```

What it does:

- opens a real GPUI window from Elixir
- updates the text after 1 second
- closes the window after 5 seconds

## Packaging direction

The intended packaging model is a single shipped NIF artifact per target:

- a small C shim for low-level Erlang/ERTS bootstrap
- a Rust core linked into the same final native library
- no separate sidecar process
- no separate shipped C artifact
