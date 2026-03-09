# Guppy

Guppy is an Elixir UI framework that opens real native windows through GPUI.

The basic idea is simple:

- your Elixir process owns the UI state
- your Elixir code renders that state into a tree-shaped IR
- native code turns that IR into GPUI elements
- GPUI handles layout, paint, focus, scrolling, and windows
- native events come back to the owning Elixir process

Guppy is still early, but it is already useful as a real architecture prototype, not just a toy. It can load a native NIF, boot GPUI on macOS, open real windows, render full trees, preserve retained native state where needed, and route native events back into BEAM processes.

## What Guppy feels like today

If you want the shortest honest description:

- **state lives in Elixir**
- **rendering is full-tree replacement**
- **windows can be owned by normal Elixir processes**
- **the preferred authoring path is `use Guppy.Window` + `~G`**
- **the low-level IR stays close to GPUI concepts**

This means Guppy is a good fit for exploring a LiveView-style desktop UI loop, while still keeping the native renderer fairly explicit and predictable.

## Current status

Guppy currently supports these native node kinds:

- `text`
- `div`
- `scroll`
- `button`
- `checkbox`
- `text_input`
- `image`
- `icon`
- `spacer`

Current native event coverage includes:

- click
- hover
- focus / blur
- key down / key up
- shortcut-dispatched actions
- context menu
- drag start / drag move / drop
- mouse down / mouse up / mouse move
- scroll wheel
- checkbox change
- text input change
- window closed

That is still intentionally selective. Guppy is not pretending to be a complete widget toolkit yet.

## Quick start

Build and install the native library:

```bash
cd guppy
mix guppy.native.build
```

For interactive examples, especially scroll-heavy ones, use a release native build:

```bash
cd guppy
mix guppy.native.build --release
```

Run tests:

```bash
cd guppy
mix test
```

Sanity check the native runtime:

```bash
cd guppy
mix run -e 'IO.inspect(Guppy.Native.Nif.load_status()); IO.inspect(Guppy.native_build_info()); IO.inspect(Guppy.native_runtime_status()); IO.inspect(Guppy.native_gui_status()); IO.inspect(Guppy.ping())'
```

A healthy result looks roughly like:

```elixir
:ok
{:ok, "guppy_nif_rust_core"}
{:ok, "started"}
{:ok, "started"}
{:ok, :pong}
```

## Recommended examples

### Best overall demo

```bash
cd guppy
mix guppy.native.build --release
mix run examples/super_demo.exs
```

This gives the broadest tour of the bridge today:

- multiple node kinds
- multiple windows
- scroll behavior
- focus behavior
- pointer and keyboard events
- actions and shortcuts
- drag and drop
- owner cleanup

### Flagship app-style example

```bash
cd guppy
mix guppy.native.build --release
mix run examples/kanban_todo.exs
```

This is the best example of the preferred Elixir authoring model:

- `use Guppy.Window`
- assign-based state
- `handle_event/3`
- `render/1`
- `~G` templates
- local function components
- full-tree rerendering from Elixir-owned state

### Small bring-up example

```bash
cd guppy
mix guppy.native.build
mix run examples/hello_world.exs
```

Use this when you want the shortest happy-path check.

## The main mental model

A useful way to think about Guppy today:

1. your Elixir process owns the state
2. Guppy opens a native window for that process
3. your process renders a full IR tree
4. native decodes the IR and renders it through `BridgeView`
5. retained native bits like focus handles, scroll handles, and text inputs are reused by stable node identity
6. native events go back to the owning process
7. your process updates assigns and renders the next full tree

Important invariant:

- **rendering is full-tree replacement from Elixir's point of view**

That is the right thing to keep in your head while reading or extending the system.

## Public API worth knowing

Top-level API:

- `Guppy.open_window/1`
- `Guppy.open_window/2`
- `Guppy.open_window/3`
- `Guppy.open_window/4`
- `Guppy.render/2`
- `Guppy.close_window/1`
- `Guppy.ping/0`
- `Guppy.native_view_count/0`
- `Guppy.native_build_info/0`
- `Guppy.native_runtime_status/0`
- `Guppy.native_gui_status/0`

Preferred window abstraction:

- `use Guppy.Window`

IR helpers:

- `Guppy.IR.text/2`
- `Guppy.IR.div/2`
- `Guppy.IR.scroll/2`
- `Guppy.IR.button/2`
- `Guppy.IR.checkbox/3`
- `Guppy.IR.text_input/2`
- `Guppy.IR.image/2`
- `Guppy.IR.icon/2`
- `Guppy.IR.spacer/1`

## Window processes

`Guppy.Window` is the preferred Elixir-side abstraction.

A window module looks like this:

```elixir
defmodule CounterWindow do
  use Guppy.Window

  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 760, height: 560],
       titlebar: [title: "Counter"]
     )
     |> assign(:count, 0)}
  end

  def render(window) do
    count = window.assigns.count

    ~G"""
    <div class="flex flex-col gap-2 p-4 bg-[#0f172a] text-[#f8fafc]">
      <text id="count_label">count = {count}</text>
      <button id="increment_button" click="increment">Increment</button>
    </div>
    """
  end

  def handle_event("increment", _event_data, window) do
    {:noreply, update(window, :count, &(&1 + 1))}
  end
end
```

Start it like any normal process:

```elixir
{:ok, pid} = CounterWindow.start_link(:ok)
```

The current callback shape is:

- `mount(arg, window)`
- `handle_event(event_name, event_data, window)`
- `handle_info(message, window)`
- `render(window)`

Helpers imported by `use Guppy.Window` include:

- `assign/2`
- `assign/3`
- `update/3`
- `put_private/3`
- `put_window_opts/2`

## Templates and components

`Guppy.Component` provides the `~G` sigil.

Built-in template tags currently include:

- `<div>`
- `<text>`
- `<button>`
- `<checkbox>`
- `<scroll>`
- `<image />`
- `<icon />`
- `<spacer />`
- `<text_input />`

It also supports first-pass function components.

Local lower-case tags call a function in the same module with assigns:

```elixir
<stat_badge stat={stat} />
```

Remote tags call `render/1` on the referenced module:

```elixir
<Guppy.UI.Badge id="release_badge" label="Beta ready" />
```

Nested content is passed as `@children`.

Components can declare props with `prop/3` and `prop/4` for:

- required props
- defaults
- unknown prop rejection
- simple type validation

## Window options

You can configure native GPUI window behavior during `mount/2`:

```elixir
def mount(_arg, window) do
  {:ok,
   window
   |> put_window_opts(
     window_bounds: [width: 960, height: 760],
     window_min_size: [width: 760, height: 560],
     titlebar: [title: "Style gallery"],
     focus: true,
     show: true,
     is_resizable: true,
     is_movable: true,
     is_minimizable: true,
     kind: :normal,
     window_background: :opaque,
     window_decorations: :server
   )}
end
```

Current supported window options match the `gpui = 0.2.2` surface Guppy is actually using:

- `window_bounds: [width: integer, height: integer, x: integer, y: integer, state: :windowed | :maximized | :fullscreen]`
- `titlebar: false | [title: String.t(), appears_transparent: boolean, traffic_light_position: [x: non_neg_integer, y: non_neg_integer]]`
- `focus: boolean`
- `show: boolean`
- `kind: :normal | :popup | :floating`
- `is_movable: boolean`
- `is_resizable: boolean`
- `is_minimizable: boolean`
- `display_id: non_neg_integer`
- `window_background: :opaque | :transparent | :blurred`
- `app_id: String.t()`
- `window_min_size: [width: integer, height: integer]`
- `window_decorations: :server | :client`
- `tabbing_identifier: String.t()`

Notes:

- omitted options use GPUI defaults
- validation happens on the Elixir side before going native
- Guppy intentionally tracks the real crates.io dependency surface, not newer upstream-only APIs

## Styling today

Styling is explicit and ordered.

A style is an ordered list of style ops, not a map:

```elixir
style: [:flex, :flex_col, :p_4, {:bg, :gray}, {:bg, :blue}]
```

Later ops win over earlier ones, and that order is preserved through the bridge.

Stateful style lists are also explicit:

- `hover_style`
- `focus_style`
- `in_focus_style`
- `active_style`
- `disabled_style`

This is intentionally simple and close to the native renderer.

## Identity and retained state

Retained native behavior depends on stable node identity.

Rules today:

- explicit `id` wins
- otherwise Guppy generates a stable path-based id like `guppy-{view_id}-{path}`

That identity is what lets native safely retain and prune things like:

- scroll handles
- focus handles
- focus subscriptions
- text input entities

If a node has stateful or retained native behavior, prefer explicit ids.

## Performance note

For interactive demos, especially big scrollable UIs like the kanban example, use:

```bash
mix guppy.native.build --release
```

Debug native builds are much slower and can make scrolling feel worse than the architecture really is.

## Project layout

Key files:

- `lib/guppy.ex` — public API
- `lib/guppy/server.ex` — ownership, lifecycle, and event routing
- `lib/guppy/window.ex` — per-window Elixir process abstraction
- `lib/guppy/component.ex` — `~G` and component helpers
- `lib/guppy/component/compiler.ex` — template compiler
- `lib/guppy/native/nif.ex` — direct Elixir wrapper around the NIF module
- `lib/guppy/ir.ex` — Elixir IR validation/helpers
- `native/guppy_nif/c_src/guppy_nif.c` — C shim and NIF entrypoints
- `native/guppy_nif/src/lib.rs` — Rust NIF entrypoints and request path
- `native/guppy_nif/src/main_thread_runtime.rs` — GPUI main-thread runtime and window registry
- `native/guppy_nif/src/bridge_view.rs` — root native renderer
- `native/guppy_nif/src/bridge_view/` — per-node renderers, style mapping, events, identity
- `native/guppy_nif/src/bridge_text_input.rs` — retained text input implementation
- `native/guppy_nif/src/ir.rs` — native IR and ETF decoding

## Known limits

Still missing or intentionally narrow:

- `textarea/editor`
- radio/select primitives
- list/uniform-list primitive
- tooltip/popover primitives
- richer text runs/highlights
- letter spacing

## Contributing / hacking on it

If you touch native code, usually run:

```bash
mix guppy.native.build
mix test
```

If you care about interactive feel, also check with a release build:

```bash
mix guppy.native.build --release
mix run examples/kanban_todo.exs
```

For macOS bootstrap changes, study OTP wx first:

- `~/projects/otp/lib/wx/c_src/wxe_main.cpp`
- `~/projects/otp/lib/wx/c_src/wxe_nif.c`

The active GPUI dependency is currently `gpui = "0.2.2"` from crates.io.
