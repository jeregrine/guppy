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
- render nested `:div` / `:text` trees through a native `BridgeView`
- roundtrip minimal click events back into the owning Elixir process
- close native windows when the owning Elixir process dies

The current tracer-shot API is intentionally small:

- `Guppy.open_window/0`
- `Guppy.mount/2`
- `Guppy.update/2`
- `Guppy.close_window/1`
- `Guppy.IR.text/2`
- `Guppy.IR.div/2`

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

## Examples

### Super demo (recommended)

```bash
cd guppy
mix guppy.native.build
mix run examples/super_demo.exs
```

What it does:

- shows native bridge/runtime status inside the UI instead of printing it to the terminal
- opens in a larger resizable window so the full demo fits more comfortably
- shows a demo list on the left and the selected demo content on the right
- uses a scrollable detail panel so individual demos can grow without pushing the whole UI off-screen
- includes a dedicated Scroll demo so scroll behavior is easy to verify at the default/minimum window sizes
- exercises div clicks and text clicks in one window
- exercises full-tree replacement updates from both clicks and timers
- exercises minimal style tokens and palette changes
- opens/closes an auxiliary window owned by the main process
- spawns and kills a child-owner window to test owner `DOWN` cleanup
- lets you manually close the main window to test `window_closed`

### Hello world

```bash
cd guppy
mix guppy.native.build
mix run examples/hello_world.exs
```

What it does:

- opens a real focused GPUI window from Elixir
- mounts a small `div/text` IR tree
- updates that tree after 1 second
- closes the window after 5 seconds

### Timer counter

```bash
cd guppy
mix guppy.native.build
mix run examples/counter.exs
```

What it does:

- opens a real GPUI window
- mounts a counter view owned by Elixir state
- sends repeated full-tree replacement updates
- closes the window after several rerenders

### Click counter

```bash
cd guppy
mix guppy.native.build
mix run examples/click_counter.exs
```

What it does:

- opens a real GPUI window
- mounts a clickable IR tree
- receives `{:guppy_event, view_id, %{type: :click, id: "increment_button", callback: "increment"}}`
- updates the window from Elixir when clicked
- stops cleanly when the window is manually closed

### Text clicks

```bash
cd guppy
mix guppy.native.build
mix run examples/text_clicks.exs
```

What it does:

- opens a real GPUI window
- mounts clickable text nodes
- distinguishes click events by text node id
- rerenders from Elixir based on which text was clicked

### Style gallery

```bash
cd guppy
mix guppy.native.build
mix run examples/style_gallery.exs
```

What it does:

- opens a real GPUI window
- renders a few styled clickable swatches
- updates a preview block using the current minimal style token support
- demonstrates full-tree replacement driven by click events

## Event shape today

Minimal native events are delivered to the owning Elixir process as:

```elixir
{:guppy_event, view_id, %{type: :click, id: node_id, callback: callback_id}}
{:guppy_event, view_id, %{type: :window_closed}}
```

You can attach a stable node id and click callback id to a `div` or `text` node like this:

```elixir
Guppy.IR.div(
  [
    Guppy.IR.text("Click me", id: "button_label", events: %{click: "increment"})
  ],
  id: "increment_button",
  events: %{click: "increment"}
)
```

Identity rules today:

- if an IR node has an explicit `id`, native rendering uses it as the GPUI element id
- otherwise Guppy falls back to a generated path-based id

Style tokens are represented as an ordered list, for example:

```elixir
style: [:flex, :flex_col, :p_4, {:bg, :gray}, {:bg, :blue}]
```

Later tokens are applied after earlier tokens, so order is preserved across the bridge.

Minimal `:div` style tokens currently supported:

- flags: `flex`, `flex_col`, `flex_row`, `flex_wrap`, `flex_nowrap`, `flex_none`, `flex_auto`, `flex_grow`, `flex_shrink`, `flex_shrink_0`, `flex_1`, `size_full`, `w_full`, `h_full`, `w_32`, `w_64`, `w_96`, `h_32`, `min_w_32`, `max_h_32`, `max_h_96`, `gap_1`, `gap_2`, `gap_4`, `p_1`, `p_2`, `p_4`, `p_6`, `p_8`, `px_2`, `py_2`, `pt_2`, `pr_2`, `pb_2`, `pl_2`, `m_2`, `mx_2`, `my_2`, `mt_2`, `mr_2`, `mb_2`, `ml_2`, `relative`, `absolute`, `top_0`, `right_0`, `bottom_0`, `left_0`, `inset_0`, `top_1`, `right_1`, `top_2`, `right_2`, `bottom_2`, `left_2`, `items_start`, `items_center`, `items_end`, `justify_start`, `justify_center`, `justify_end`, `justify_between`, `justify_around`, `cursor_pointer`, `rounded_md`, `border_1`, `border_t_1`, `border_r_1`, `border_b_1`, `border_l_1`, `shadow_sm`, `shadow_md`, `shadow_lg`, `overflow_scroll`, `overflow_x_scroll`, `overflow_y_scroll`, `overflow_hidden`, `overflow_x_hidden`, `overflow_y_hidden`
- color ops: `{:bg, color}`, `{:text_color, color}`, `{:border_color, color}`
- color tokens: `:red`, `:green`, `:blue`, `:yellow`, `:black`, `:white`, `:gray`

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
3. mount/update terms are copied into owned ETF binaries before the NIF returns
4. Rust owns most of the native runtime logic and decodes ETF into native IR
5. native click handlers send messages back into the BEAM through the C shim
6. `Guppy.Server` routes native events back to the owning Elixir process
7. Elixir sends full-tree replacement updates back to native
8. GPUI renders and rerenders from Elixir-driven state

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

- native rendering only supports a minimal IR shape today
- supported nodes are effectively `:div` and `:text`
- only a minimal click event path exists today (`:div` and `:text` click)
- style mapping exists, but only for a small explicit subset on `:div`
- explicit node ids are supported, but there is not yet broader keyed/stateful UI behavior built on top of them
- `update_window_text/2` is now just a convenience wrapper over `update(view_id, Guppy.IR.text(text))`

## Development workflow

Common commands:

```bash
cd guppy
mix guppy.native.build
mix test
mix run examples/hello_world.exs
mix run examples/counter.exs
mix run examples/super_demo.exs
mix run examples/hello_world.exs
mix run examples/counter.exs
mix run examples/click_counter.exs
mix run examples/text_clicks.exs
mix run examples/style_gallery.exs
```

If you change native code under `native/guppy_nif/`, rebuild before testing.
