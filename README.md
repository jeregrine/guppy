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
    ~GUI"""
    <div class="flex flex-col gap-2 p-4 bg-[#0f172a] text-[#f8fafc]">
      <text id="count_label" class="text-2xl font-bold">count = {@count}</text>
      <button id="increment_button" click="increment" class="p-2 rounded-md border-1">
        Increment
      </button>
    </div>
    """
  end

  def handle_event("increment", _event_data, window) do
    {:noreply, assign(window, :count, window.assigns.count + 1)}
  end
end

{:ok, pid} = CounterWindow.start_link(:ok)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end

```

## Status

Guppy is unreleased and macOS-first today. It can open native GPUI windows, render full trees, keep retained native state such as focus/scroll/text-input state by stable node identity, and route native events back to BEAM processes.

## What is this? (Human Authored Section)

The goal of guppy was to see if I could use an LLM (codex 5.3->5.5 specifically) to create this complex nif for GPUI. I wondered if given the OTP source code, the zed/gpui source code and specific direction to follow the architectue of the OTP Wx modules would an LLM be able to take on this sort of large, monotonous task.

To my surprise it was able to, kinda, the history of this project is almost 100% AI commits and it actually kind of nicely documents my experices using these tools in a sort of "hands off, let the ai code" way. The first version of this code strictly worked, but it was kinda sloppy and slow and hand-rolled its own rustler(lol). Over time we've gotten closer and closer thanks to some free tokens from friends.

To be clear the AI left to its own devices would have gotten trapped in a slop-pit and never recovered. Multiple iterations of my course correcting and specificying a better api were absolutely required. Its still got some slop but I believe with enough time, patience, and tokens I will be able to get us really close to where I want to be. This is totally usable for local applications with native rendering, if you find issues please submit a PR or issues, very open to AI changes so long as its within reason.

I am not a rust expert by any means and it shows, I am slowly building up the correct understanding and vocabulary to get us closer, but any rust help would be greatly appreciated!

## Quick start

Run a small example. The Rust NIF builds automatically during normal Mix compilation, so the source-build alpha path requires a working Rust toolchain:

```bash
mix run examples/hello_world.exs
```

For interactive demos, especially scroll-heavy examples, use an optimized native build:

```bash
MIX_ENV=prod mix run examples/super_demo.exs
```

Run tests:

```bash
mix test
```

## Examples

```bash
MIX_ENV=prod mix run examples/super_demo.exs
```

Broad tour of the bridge: multiple node kinds, multiple windows, scrolling, focus, pointer/keyboard events, actions, shortcuts, drag/drop, and owner cleanup.

```bash
MIX_ENV=prod mix run examples/kanban_todo.exs
```

Best app-style example of `use Guppy.Window`, assigns, `handle_event/3`, `render/1`, `~GUI`, and local function components.

```bash
MIX_ENV=prod mix run examples/stress_test.exs
```

To show a very high-churn stress test of the UI.

```bash
mix run examples/list_row_controls.exs
```

Focused generic `list` example with row-local button, checkbox, and radio controls plus structured `list_id` / `row_id` / `control_id` events.

```bash
mix run examples/menu_demo.exs
```

App-level menu example with callback actions routed to the installing window process and Edit menu items wired to focused text input actions.

```bash
mix run examples/data_table_tree.exs
```

Semantic data-table/tree example with Elixir-owned expansion, selection, and sorting over native virtual rows.

```bash
mix run examples/canvas_pattern.exs
```

Data-only canvas example with ordered rect/rounded-rect draw commands, GPUI slash-pattern painting, and a coarse canvas click callback. This will likely be added to Easel

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
- `data_table`
- `tree`
- `canvas`
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
- `<data_table />`
- `<tree />`
- `<canvas />`
- `<popover>`
- `<select />`
- `<image />`
- `<icon />`
- `<spacer />`
- `<text_input />`
- `<textarea />`

Native event coverage includes click, close, hover, focus/blur, key down/up, shortcut actions, app-menu callback actions, context menu, drag/drop, mouse down/up/move, scroll wheel, checkbox/radio/select changes, uniform-list item clicks, canvas clicks, popover callbacks, text input/textarea changes and focus/blur, and window close lifecycle events. Tab and Shift-Tab traverse retained GPUI tab stops.

Popovers support optional anchor corner, anchor position/offset, local/window anchor positioning, snap-fit mode, snap margin, close-on-outside-click behavior, and deferred-layer priority.

`list` rows support static/layout children (`text`, `spacer`, and nested static `div`) plus row-local `button`, `checkbox`, and `radio` controls with explicit control ids. Row-control events include `list_id`, `row_id`, and `control_id`; Elixir remains the source of truth for checked/selected values.

`data_table` and `tree` are semantic virtualized primitives for Elixir-owned table selection/sort state and tree selection/expansion state. Data-table columns support `:auto`, `{:px, value}`, and weighted `{:fr, positive_integer}` widths. Data-table events include `table_id`, `row_id`, and/or `column_id`; tree events include `tree_id` and `item_id`. `selected_row_id`, `selected_cell`, and `selected_id` are semantic state only; native rendering does not add default selection highlights, so apply explicit row/cell/item styles from Elixir when visual selection is needed. First-pass table cells intentionally support static `text`, `spacer`, and nested static `div` content.

`canvas` is a data-only drawing primitive for bounded custom painting. It supports ordered `:rect`, `:rounded_rect`, and `:pattern_rect` commands with existing named/hex color validation, unit slash-pattern parameters, wrapper style/viewport sizing, and a coarse optional `:click` callback. Elixir code does not run during native paint; path/text/image canvas commands and per-command hit testing remain deferred.

`Guppy.set_menus/1` installs app/runtime menus for the calling process. Custom menu actions use `%{id:, label:, callback:}` and arrive as `{:guppy_menu_event, %{type: :menu_action, id: id, callback: callback}}`; Edit menu items can use `%{id:, label:, os_action: :cut | :copy | :paste | :select_all}` to target focused native text inputs. Call `Guppy.set_menus([])` to clear menus; menus are also cleared when the installing process exits.

`window_close_requested` is informational: native close requests are not vetoable from Elixir today, and a successful close is followed by `window_closed`.

## Window processes

`Guppy.Window` modules can be supervised directly via their generated `child_spec/1` and use these callbacks:

- `mount(arg, window)`
- `render(window)`
- optional `handle_event(event_name, event_data, window)`

Define `handle_info(message, window)` without `@impl Guppy.Window` when the process should handle ordinary messages or timers.

Missing optional handlers and unmatched handler clauses are treated as no-op handlers that skip rerendering.

Helpers imported by `use Guppy.Window` include:

- `assign/2`
- `assign/3`
- `update/3`
- `put_private/3`
- `put_window_opts/2`

`Guppy.Window` monitors the Guppy runtime server. If the supervised server restarts, the window process reopens from its current assigns. Lower-level callers using `Guppy.open_window/1..3` own their own recovery policy.

Preferred `Guppy.Window` modules treat `window_closed` as lifecycle-driving today. `window_close_requested` remains informational for lower-level owners and is not exposed as a veto callback by `Guppy.Window`.

## Templates and components

`Guppy.Component` provides `~GUI` templates and first-pass function components. Inside a `render(assigns)` or `render(window)` function, `@name` reads from the assigns map or window assigns.

Dotted local tags call a function in the same module:

```elixir
<.stat_badge stat={stat} />
```

Remote tags call `render/1` on the referenced module:

```elixir
<Guppy.UI.Badge id="release_badge" label="Beta ready" />
```

Nested content is passed as `@children`.

Components can declare props with `prop/3` and `prop/4` for required props, defaults, unknown prop rejection, and simple type validation.

## Markdown

`Guppy.Markdown` is a remote component for a small Markdown subset (headings, paragraphs, unordered/ordered lists, bold/italic/code runs, and link-ish inline runs). It is also a fun example of how this can work! It intentionally renders to Guppy IR in Elixir instead of depending on Zed's markdown crates, which are not part of Guppy's active `gpui = 0.2.2` dependency surface.

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
- `display_id: non_neg_integer` (matched against active GPUI displays; unknown ids are ignored)
- `window_background: :opaque | :transparent | :blurred`
- `app_id: String.t()`
- `window_min_size: [width: integer, height: integer]`
- `window_decorations: :server | :client`
- `tabbing_identifier: String.t()`

## Styling

Styles are ordered lists of style ops, these follow the tailwind inspired styles of gpui-rs. The style-surface parity pass is moving new surface area to property-first canonical tuples generated from `data/gpui_style_catalog.json`.

```elixir
style: [:flex, :flex_col, Guppy.Style.p(4), {:padding, :y, {:rem, 0.25}}, {:bg, :gray}, {:bg, :blue}]
```

Box-spacing, size/aspect ratio, position, display, visibility, overflow visible/clip/hidden/scroll, scroll behavior booleans, cursor, border, radius, named/hex/gradient/pattern color including text background, opacity, scrollbar width, shadow, flex grow/shrink/alignment/self-alignment/basis, core text/font size/line-height/weight/family/fallbacks/features/decoration/strikethrough, line clamp, grid count/span/full-span/line placement, and image-only object-fit/grayscale helpers/classes already use canonical tuple ops or image option tuples: `Guppy.Style.py(1)` and template `class="py-1"` both produce `{:padding, :y, {:rem, 0.25}}`; `Guppy.Style.mx(:auto)` produces `{:margin, :x, :auto}`; `Guppy.Style.gap_x("px")` produces `{:gap, :x, {:px, 1}}`; `Guppy.Style.w("full")` produces `{:width, {:fraction, 1}}`; `Guppy.Style.aspect_ratio(1.5)` produces `{:aspect_ratio, 1.5}`; `Guppy.Style.top(-2)` produces `{:inset, :top, {:rem, -0.5}}`; `class="hidden invisible overflow-visible overflow-x-clip overflow-x-scroll scroll-concurrent scroll-axis-restricted cursor-pointer border-1 rounded-sm bg-[#0f172a] bg-pattern-slash-[red,1,4] opacity-50 scrollbar-w-[12px] text-white text-bg-yellow shadow-md flex-col basis-1/2 grow-[2] shrink-[0.5] aspect-video items-stretch self-stretch justify-evenly text-xl text-[14px] leading-[18px] font-bold font-[650] font-family-[Monaco] font-fallbacks-[Monaco,Menlo] font-features-[calt=0,kern=1] font-ligatures-none underline decoration-red decoration-wavy line-through strikethrough-red strikethrough-2 line-clamp-2 grid-cols-3 col-start-2 col-span-full"` produces display, visibility, overflow, scroll behavior, cursor, border-width, border-radius, color, pattern background, text-background, opacity, scrollbar-width, shadow, flex grow/shrink/alignment/self-alignment/basis, aspect ratio, text/font-size/line-height/weight/family/fallbacks/features/decoration/strikethrough, line-clamp, and grid tuple ops. On `<image>`, `class="object-cover grayscale"` maps to image `object_fit` and `grayscale` options. Later ops win over earlier ones, and order is preserved through the bridge. In `~GUI` templates, `class` may be a string or a dynamic list of strings; `nil` and `false` list entries are ignored. Raw `style` values must be canonical style lists (for example `style={Guppy.Style.py(1)}` or `style={[Guppy.Style.py(1)]}`); use `class` for class-token strings.

Stateful style lists are explicit:

- `hover_style`
- `focus_style`
- `focus_visible_style`
- `in_focus_style`
- `active_style`
- `disabled_style`

Text nodes and div-like nodes support the current style-token surface where applicable. Grid style ops include `:grid`, `{:grid_cols, n}`, `{:grid_rows, n}`, `{:col_span, n}`, `:col_span_full`, `{:row_span, n}`, and `:row_span_full`.

Div-like nodes support two-stop background linear gradients:

```elixir
style: [
  {:bg_linear_gradient, [angle: 135, from: {"#0f172a", 0.0}, to: {"#2563eb", 1.0}]}
]
```

The equivalent template class form is `bg-linear-gradient-[135,#0f172a:0,#2563eb:1]`.

Div-like nodes can also opt into a native opacity animation with `animation: %{id: "stable_id", duration_ms: 500, repeat: true, from: 0.4, to: 1.0}`.

## Distribution

Guppy is source-build first. Rustler builds and copies the NIF into `priv/native/` during normal Mix compilation. The macOS source-build path, clean-install/load smoke, and generated package smoke are covered by CI.

Current source-build support:

| Target                      | Status                                 |
| --------------------------- | -------------------------------------- |
| `aarch64-apple-darwin`      | supported / primary development target |
| `x86_64-apple-darwin`       | planned, needs CI confirmation         |
| `aarch64-unknown-linux-gnu` | planned, needs GPUI runtime validation |
| `x86_64-unknown-linux-gnu`  | planned, needs GPUI runtime validation |
| `x86_64-pc-windows-msvc`    | planned, needs GPUI/runtime validation |

`rustler_precompiled` is wired only for the currently supported `aarch64-apple-darwin` target today; broader targets stay out of the precompiled matrix until they are validated. Source builds remain the default until release artifacts and checksums are published. `GUPPY_NATIVE_PRECOMPILED=1` is only an explicit artifact-path probe until then. See [`docs/distribution.md`](docs/distribution.md).
