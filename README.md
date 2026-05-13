# Guppy

Guppy is an Elixir UI framework for native desktop windows built on [GPUI](https://www.gpui.rs/). Your Elixir process owns state, renders it to a small IR tree, and a Rustler NIF renders that tree through GPUI.

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
      <text id="count_label" class="text-2xl font-bold">count = {count}</text>
      <button id="increment_button" click="increment" class="p-2 rounded-md border-1">
        Increment
      </button>
    </div>
    """
  end

  def handle_event("increment", _event_data, window) do
    {:noreply, update(window, :count, &(&1 + 1))}
  end
end

{:ok, _pid} = CounterWindow.start_link(:ok)
```

## Status

Guppy is unreleased and macOS-first today. It can open native GPUI windows, render full trees, keep retained native state such as focus/scroll/text-input state by stable node identity, and route native events back to BEAM processes.

The preferred authoring model is:

- `use Guppy.Window`
- assign/update helpers
- `~G` templates
- local function components
- full-tree rerendering from Elixir-owned state

Guppy is not trying to expose all of GPUI. It currently targets a documented subset; see [`docs/gpui-compliance.md`](docs/gpui-compliance.md) for the compatibility matrix.

## Quick start

Run a small example. The Rust NIF builds automatically during normal Mix compilation, so the source-build alpha path requires a working Rust toolchain:

```bash
mix run examples/hello_world.exs
```

For interactive demos, especially scroll-heavy examples, use an optimized native build:

```bash
GUPPY_NATIVE_RELEASE=1 mix run examples/super_demo.exs
```

Run tests:

```bash
mix test
```

Full local check suite:

```bash
scripts/check
```

Generated package smoke:

```bash
scripts/package_smoke
```

## Examples

```bash
GUPPY_NATIVE_RELEASE=1 mix run examples/super_demo.exs
```

Broad tour of the bridge: multiple node kinds, multiple windows, scrolling, focus, pointer/keyboard events, actions, shortcuts, drag/drop, and owner cleanup.

```bash
GUPPY_NATIVE_RELEASE=1 mix run examples/kanban_todo.exs
```

Best app-style example of `use Guppy.Window`, assigns, `handle_event/3`, `render/1`, `~G`, and local function components.

```bash
mix run examples/hello_world.exs
```

Shortest bring-up smoke test.

## Supported UI surface

Native node kinds:

- `text` (including rich text runs)
- `div`
- `scroll`
- `uniform_list`
- `list`
- `popover`
- `select`
- `button`
- `checkbox`
- `radio`
- `text_input`
- `textarea`
- `image`
- `icon`
- `spacer`

Template tags:

- `<div>`
- `<text>`
- `<rich_text />`
- `<button>`
- `<checkbox>`
- `<radio>`
- `<scroll>`
- `<uniform_list />`
- `<list />`
- `<popover>`
- `<select />`
- `<image />`
- `<icon />`
- `<spacer />`
- `<text_input />`
- `<textarea />`

Native event coverage includes click, close, hover, focus/blur, key down/up, shortcut actions, context menu, drag/drop, mouse down/up/move, scroll wheel, checkbox/radio/select changes, uniform-list item clicks, popover callbacks, text input/textarea changes and focus/blur, and window close lifecycle events. Tab and Shift-Tab traverse retained GPUI tab stops.

Popovers support optional anchor corner, anchor position/offset, local/window anchor positioning, snap-fit mode, snap margin, close-on-outside-click behavior, and deferred-layer priority.

`window_close_requested` is informational: native close requests are not vetoable from Elixir today, and a successful close is followed by `window_closed`.

## Public API

Top-level API:

- `Guppy.open_window/1`
- `Guppy.open_window/2` (`Guppy.open_window(ir, opts)`)
- `Guppy.open_window/3` (`Guppy.open_window(ir, opts, timeout)`)
- `Guppy.render/2`
- `Guppy.close_window/1`
- `Guppy.ping/0`
- `Guppy.native_view_count/0`
- `Guppy.native_build_info/0`
- `Guppy.native_runtime_status/0`
- `Guppy.native_gui_status/0`
- `Guppy.native_performance_counters/0`

Preferred window abstraction:

- `use Guppy.Window`
- `Guppy.Markdown.render/1` for a small Elixir-side Markdown viewer component

IR helpers:

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

## Window processes

`Guppy.Window` modules can be supervised directly via their generated `child_spec/1` and use these callbacks:

- `mount(arg, window)`
- `render(window)`
- optional `handle_event(event_name, event_data, window)`
- optional `handle_info(message, window)`

Missing optional callbacks and unmatched callback clauses are treated as no-op handlers that skip rerendering.

Helpers imported by `use Guppy.Window` include:

- `assign/2`
- `assign/3`
- `update/3`
- `put_private/3`
- `put_window_opts/2`

`Guppy.Window` monitors the Guppy runtime server. If the supervised server restarts, the window process reopens from its current assigns. Lower-level callers using `Guppy.open_window/1..3` own their own recovery policy.

Preferred `Guppy.Window` modules treat `window_closed` as lifecycle-driving today. `window_close_requested` remains informational for lower-level owners and is not exposed as a veto callback by `Guppy.Window`.

## Templates and components

`Guppy.Component` provides `~G` templates and first-pass function components.

Local lower-case tags call a function in the same module:

```elixir
<stat_badge stat={stat} />
```

Remote tags call `render/1` on the referenced module:

```elixir
<Guppy.UI.Badge id="release_badge" label="Beta ready" />
```

Nested content is passed as `@children`.

Components can declare props with `prop/3` and `prop/4` for required props, defaults, unknown prop rejection, and simple type validation.

`Guppy.Markdown` is a remote component for a small Markdown subset (headings, paragraphs, unordered lists, bold/italic/code runs). It intentionally renders to Guppy IR in Elixir instead of depending on Zed's markdown crates, which are not part of Guppy's active `gpui = 0.2.2` dependency surface.

## Window options

Configure native GPUI window behavior during `mount/2`:

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

Supported options match the `gpui = 0.2.2` surface Guppy uses:

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

## Styling

Styles are ordered lists of style ops:

```elixir
style: [:flex, :flex_col, :p_4, {:bg, :gray}, {:bg, :blue}]
```

Later ops win over earlier ones, and order is preserved through the bridge.

Stateful style lists are explicit:

- `hover_style`
- `focus_style`
- `focus_visible_style`
- `in_focus_style`
- `active_style`
- `disabled_style`

Text nodes and div-like nodes support the current style-token surface where applicable. Grid style ops include `:grid`, `{:grid_cols, n}`, `{:grid_rows, n}`, `{:col_span, n}`, `:col_span_full`, `{:row_span, n}`, and `:row_span_full`.

Div-like nodes can also opt into a native opacity animation with `animation: %{id: "stable_id", duration_ms: 500, repeat: true, from: 0.4, to: 1.0}`.

## Distribution

Guppy is source-build first. Rustler builds and copies the NIF into `priv/native/` during normal Mix compilation. The macOS source-build path, clean-install/load smoke, and generated package smoke are covered by CI.

Current source-build support:

| Target | Status |
| --- | --- |
| `aarch64-apple-darwin` | supported / primary development target |
| `x86_64-apple-darwin` | planned, needs CI confirmation |
| `aarch64-unknown-linux-gnu` | planned, needs GPUI runtime validation |
| `x86_64-unknown-linux-gnu` | planned, needs GPUI runtime validation |
| `x86_64-pc-windows-msvc` | planned, needs GPUI/runtime validation |

`rustler_precompiled` is wired in for those GPUI-aligned targets, but source builds remain the default until release artifacts and checksums are published. `GUPPY_NATIVE_PRECOMPILED=1` is only an explicit artifact-path probe until then. See [`docs/distribution.md`](docs/distribution.md).

## Known limits

Still missing or intentionally narrow unless explicitly scoped:

- full editor parity and advanced text layout beyond current rich text runs
- richer select/dropdown menu semantics beyond the current Elixir-owned select
- stateful controls inside generic virtualized list rows and custom scrollbar parity
- exact focus-visible and traversal edge-case parity beyond current Tab/Shift-Tab semantics
- full popover parity, including nested/deferred layer edge cases
- advanced animation effects beyond current opacity animation, gradient, canvas/custom painting, pattern painting, and menu APIs
- published precompiled native artifacts

## Hacking on Guppy

For meaningful changes:

```bash
scripts/check
```

If you touch native code:

```bash
mix compile --force
mix test
```

If you care about interactive feel:

```bash
GUPPY_NATIVE_RELEASE=1 mix run examples/kanban_todo.exs
```

The active GPUI dependency is currently `gpui = "0.2.2"` from crates.io.
