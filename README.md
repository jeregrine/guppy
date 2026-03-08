# Guppy

Guppy is an Elixir UI framework that renders through GPUI using a NIF-backed native runtime.

## What Guppy is trying to be

The intended model is:

- Elixir processes own UI state
- Elixir renders that state into a simple IR tree
- the native runtime turns that IR into GPUI elements
- GPUI handles layout, painting, focus, scrolling, and windows
- native events roundtrip back to the owning Elixir process

This repo is still early, but it is past the toy stage: it can boot a real native GPUI app, open real windows, render IR, handle updates, and send events back into the BEAM.

## Current status

Today Guppy can:

- load a Cargo-built NIF
- bootstrap a GPUI app on macOS via a wx-style main-thread handoff
- open and close real native windows from Elixir
- render and replace a full IR tree per window
- render native trees through `BridgeView`
- preserve retained native state where needed across rerenders
- send native events back to the owning Elixir process
- close windows automatically when the owner process dies

Supported node kinds today:

- `text`
- `div`
- `scroll`
- `button`
- `text_input`

Supported interaction surface today includes:

- click
- hover
- focus / blur
- key down / key up
- shortcut-dispatched actions
- context menu
- drag start / drag move / drop
- mouse down / mouse up / mouse move
- scroll wheel
- window closed
- text input change

This is still not a full UI framework yet. Coverage is intentionally selective, and the bridge still prefers explicit, narrow behavior over broad abstraction.

## The core architectural intent

A useful way to think about Guppy today:

1. `Guppy.Server` owns window ownership and event routing on the Elixir side.
2. Elixir sends full-tree replacement IR updates to native.
3. Rust decodes ETF into native IR.
4. `BridgeView` renders that IR into GPUI.
5. Retained native bits like scroll handles, focus handles, and text inputs are reused across rerenders by stable node identity.
6. Native callbacks emit messages back through the C shim into the BEAM.

Important current invariant:

- **rendering is full-tree replacement from Elixir's point of view**

Important current non-goal:

- **do not contort the code around backwards compatibility yet**

## Quick start

Build and install the native library:

```bash
cd guppy
mix guppy.native.build
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

### Main demo

```bash
cd guppy
mix guppy.native.build
mix run examples/super_demo.exs
```

This is the best current overview of the bridge. It exercises:

- multiple node kinds
- scroll behavior
- focus behavior
- click / pointer / keyboard events
- actions and shortcuts
- drag and drop roundtrips
- full-tree rerendering from Elixir
- multiple windows and owner cleanup

### Kanban todo board (`Guppy.Window`)

```bash
cd guppy
mix guppy.native.build
mix run examples/kanban_todo.exs
```

This demonstrates a more app-like `Guppy.Window` flow:

- a window struct with assigns
- event names routed into `handle_event/3`
- full-tree rerendering from assign updates
- a multi-column board rendered from Elixir-owned state

### Small bring-up example (`Guppy.Window`)

```bash
cd guppy
mix guppy.native.build
mix run examples/hello_world.exs
```

This verifies the basic happy path through `Guppy.Window`:

- start a window process
- open a window with initial IR
- rerender with a replacement IR tree
- stop the process and let ownership cleanup close the window

## Public API surface worth knowing

Window lifecycle:

- `Guppy.open_window/1`
- `Guppy.open_window/2`
- `Guppy.render/2`
- `Guppy.close_window/1`
- `use Guppy.Window`

Native status / diagnostics:

- `Guppy.ping/0`
- `Guppy.native_view_count/0`
- `Guppy.native_build_info/0`
- `Guppy.native_runtime_status/0`
- `Guppy.native_gui_status/0`

IR helpers:

- `Guppy.IR.text/2`
- `Guppy.IR.div/2`
- `Guppy.IR.scroll/2`
- `Guppy.IR.button/2`
- `Guppy.IR.text_input/2`

## Window processes

Guppy now also has a minimal per-window process abstraction via `Guppy.Window`.

A window module can:

- own its own window struct with assigns
- open its native window with initial IR during `mount/2`
- receive native events in `handle_event/3`
- receive normal process messages in `handle_info/2`
- rerender automatically after returning `{:noreply, window}`

The intended shape is:

```elixir
defmodule CounterWindow do
  use Guppy.Window
  import Guppy.Window, only: [assign: 3, update: 3]

  def mount(_arg, window) do
    {:ok, assign(window, :count, 0)}
  end

  def render(window) do
    count = window.assigns.count

    Guppy.IR.div([
      Guppy.IR.text("count = #{count}"),
      Guppy.IR.text("increment", events: %{click: "increment"})
    ])
  end

  def handle_event("increment", _event_data, window) do
    {:noreply, update(window, :count, &(&1 + 1))}
  end
end
```

Start it like any other process:

```elixir
{:ok, pid} = CounterWindow.start_link(:ok)
```

This is still intentionally minimal, but it is now explicitly shaped like a LiveView-style loop:

- `mount/2`
- `handle_event/3`
- `handle_info/2`
- `render/1`
- assign/update helpers on the window struct

## Identity and retained state

Native retained state depends on stable node identity.

Rules today:

- if a node has an explicit `id`, that wins
- otherwise Guppy generates a path-based id like `guppy-{view_id}-{path}`

That identity is what lets the native side safely retain and prune:

- scroll handles
- focus handles
- focus subscriptions
- text input entities

If you are building dynamic UI, prefer explicit ids for nodes whose retained native behavior matters.

## Events today

Events are delivered to the owning Elixir process as `{:guppy_event, view_id, payload}`.

Representative payloads include:

```elixir
%{type: :click, id: node_id, callback: callback_id}
%{type: :hover, id: node_id, callback: callback_id, hovered: boolean}
%{type: :focus, id: node_id, callback: callback_id}
%{type: :blur, id: node_id, callback: callback_id}
%{type: :change, id: node_id, callback: callback_id, value: String.t()}
%{type: :action, id: node_id, callback: callback_id, action: String.t(), shortcut: String.t()}
%{type: :window_closed}
```

There is broader support than those examples, but the important mental model is:

- event payloads carry the stable node id
- event payloads carry the callback id you declared in the IR
- Elixir decides what to do next and sends a new full tree

## Styling today

Styling is intentionally explicit and ordered.

A `div` style is an ordered list of style ops, not a map:

```elixir
style: [:flex, :flex_col, :p_4, {:bg, :gray}, {:bg, :blue}]
```

Later ops win over earlier ones, and order is preserved through the bridge.

There is also explicit support for ordered stateful style lists on `div`:

- `hover_style`
- `focus_style`
- `in_focus_style`
- `active_style`
- `disabled_style`

Current style coverage is useful but still intentionally partial.

## Current architecture in the repo

Key files:

- `lib/guppy.ex` — public API
- `lib/guppy/server.ex` — ownership, lifecycle, and native event routing
- `lib/guppy/native/nif.ex` — Elixir NIF wrapper
- `lib/guppy/ir.ex` — Elixir IR validation/helpers
- `native/guppy_nif/c_src/guppy_nif.c` — C shim and NIF entrypoints
- `native/guppy_nif/src/lib.rs` — Rust runtime core and command routing
- `native/guppy_nif/src/main_thread_runtime.rs` — GPUI main-thread runtime and window management
- `native/guppy_nif/src/bridge_view.rs` — root native IR renderer
- `native/guppy_nif/src/bridge_view/` — render passes, events, identity, styles, per-node renderers

The runtime is intentionally NIF-first:

- single native artifact
- small C bootstrap layer
- Rust owns most runtime logic
- no Port sidecar

## Known limits

Guppy is still early. In particular:

- node/widget coverage is still small
- style coverage is still selective
- retained identity is present, but richer keyed/stateful behavior is still ahead
- the rendering model is still simple full-tree replacement
- the bridge favors explicit hand-written mappings over general magic

## What matters most next

The most valuable next steps are architectural, not cosmetic:

1. keep the identity and retained-state model solid
2. keep the full-tree replacement model simple and correct
3. expand node/style/event support carefully
4. add tests around retained native behavior and event dispatch
5. continue moving from tracer-shot naming to runtime-oriented naming and structure

## Notes for contributors

If you touch native code under `native/guppy_nif/`, usually run:

```bash
mix guppy.native.build
mix test
```

For macOS bootstrap work, study OTP wx first:

- `~/projects/otp/lib/wx/c_src/wxe_main.cpp`
- `~/projects/otp/lib/wx/c_src/wxe_nif.c`

The active GPUI dependency is currently `gpui = "0.2.2"` from crates.io.
