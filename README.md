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
mix run examples/multi_window_app.exs
```

`Guppy.App` example with app-owned window supervision, stylesheet/theme resources, commands, menus, keymap data, a secondary window, and the built-in command-palette overlay.

```bash
mix run examples/overlay_demo.exs
```

Overlay hardening example with form-like select keyboard behavior, popover positioning/close semantics, element-local context menus, and nested non-overlay panels.

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

Native event coverage includes click, close, hover, focus/blur, key down/up, shortcut actions, app-menu callback actions, context menu, drag/drop, mouse down/up/move, scroll wheel, checkbox/radio/select changes, uniform-list item click/context-menu callbacks, canvas clicks, popover callbacks, text input/textarea changes, focus/blur, context menus, and explicit shortcut actions, app lifecycle events (`app_activated`, `app_deactivated`), and window lifecycle events (`window_focused`, `window_blurred`, `window_moved`, `window_resized`, `window_close_requested`, `window_closed`). Tab and Shift-Tab traverse retained GPUI tab stops; nodes with `context_menu` handlers can also invoke that event from the keyboard with Shift-F10 or the context-menu key.

`Guppy.ContextMenu.render/2` renders validated item data into ordinary IR buttons/dividers for element-local menus. Pair it with a node's `context_menu` event and keep open/close/selection state in the owning process. `Guppy.App.open_context_menu/3` returns focus to the source app window by default when opened from an app-supervised window; pass `return_focus_to: window_id` to choose a specific app window.

Popovers support optional anchor corner, anchor position/offset, local/window anchor positioning, snap-fit mode, snap margin, Escape/outside-click close behavior, and deferred-layer priority. Select list overlays support keyboard navigation/typeahead plus anchor offset/fit/margin controls. See `docs/overlays.md` for lifecycle, positioning, focus-return, and nested-overlay semantics, `docs/focus-keyboard.md` for the current focus scopes and roving-focus model, and `docs/accessibility.md` for the current GPUI accessibility/semantics audit.

`uniform_list` items and `list` rows with `:click`/`:context_menu` callbacks are keyboard-focusable: Up/Down moves between items/rows, Enter/Space activate `:click`, and Shift-F10/context-menu key invokes `:context_menu`. Keyboard-focused retained rows/items get a default focus-visible border while focus-visible mode is active. `list` rows also support static/layout children (`text`, `spacer`, and nested static `div`) plus row-local `button`, `checkbox`, and `radio` controls with explicit control ids. Row-control events include `list_id`, `row_id`, and `control_id`; Elixir remains the source of truth for checked/selected values.

`data_table` and `tree` are semantic virtualized primitives for Elixir-owned table selection/sort state and tree selection/expansion state. Data-table columns support `:auto`, `{:px, value}`, and weighted `{:fr, positive_integer}` widths. Data-table events include `table_id`, `row_id`, and/or `column_id`, including optional row/cell context-menu callbacks; sortable headers, clickable rows/cells, and row/cell context menus are keyboard-actionable when callbacks are present, and table headers/body rows/cells support arrow-key focus movement including Left/Right between sortable headers, Home/End across body rows/cells, Right from a row into its first cell, Left from a first cell back to its row, Down from a sortable header into its column, and Up back to that header. Tree events include `tree_id` and `item_id`, including optional row `:context_menu` callbacks for command-backed context menus; tree rows with select/toggle/context-menu callbacks are keyboard-actionable for Up/Down/Home/End row focus movement, Left focus return to a parent row, Right focus entry into the first child row, Enter selection, Space/Left/Right disclosure toggles, and keyboard context-menu invocation. Keyboard-focused retained headers/rows/cells/items get a default focus-visible border while focus-visible mode is active. `selected_row_id`, `selected_cell`, and `selected_id` are semantic state only; native rendering does not add default selection highlights, so apply explicit row/cell/item styles from Elixir when visual selection is needed. First-pass table cells intentionally support static `text`, `spacer`, and nested static `div` content.

`canvas` is a data-only drawing primitive for bounded custom painting. It supports ordered `:rect`, `:rounded_rect`, and `:pattern_rect` commands with existing named/hex color validation, unit slash-pattern parameters, wrapper style/viewport sizing, and coarse optional `:click` / `:context_menu` callbacks. Elixir code does not run during native paint; path/text/image canvas commands and per-command hit testing remain deferred.

`Guppy.set_menus/1` installs app/runtime menus for the calling process. `Guppy.set_dock_menu/1` installs the Dock/app-icon menu from the same menu item shape. Custom app-menu actions use `%{id:, label:, callback:}` and arrive as `{:guppy_menu_event, %{type: :menu_action, id: id, callback: callback}}`; Dock menu actions arrive with `type: :dock_menu_action`. Edit menu items can use `%{id:, label:, os_action: :cut | :copy | :paste | :select_all}` to target focused native text inputs. macOS Services can be included as `%{label: "Services", system_menu: :services}`. Call `Guppy.set_menus([])` / `Guppy.set_dock_menu([])` to clear menus; menus are also cleared when the installing process exits.

`Guppy.set_app_badge/1` sets a process-owned app/Dock badge label on supported platforms (macOS today); pass `nil` to clear it. The badge is cleared automatically when the installing process exits. App coordinators can also own the badge via `:app_badge` config and `Guppy.App.set_app_badge/2`, which reinstall after runtime-server restart. GPUI 0.2.2 does not expose desktop notification APIs, so notifications remain deferred.

`Guppy.open_file_dialog/0`, `Guppy.choose_directory_dialog/0`, and `Guppy.save_file_dialog/0` provide narrow platform file dialogs through the native runtime. Open/choose support `:multiple`, `:prompt`, `:directory`, and extension allow-list `:filters`; save supports `:directory`, `:default_name`, and `:filters`; all support `:owner_view_id` for caller-owned window liveness checks. Dialog cancellation returns `{:ok, nil}`. GPUI 0.2.2 does not expose sheet-style owner-window APIs, so `:owner_view_id` is a logical association rather than a native modal sheet parent.

`Guppy.read_clipboard_text/0` and `Guppy.write_clipboard_text/1` provide narrow text clipboard access through the native runtime. Reads return `{:ok, text}` or `{:ok, nil}` when no text is available; writes accept binaries only.

`app_activated`/`app_deactivated` are sent to the claimed app owner as `{:guppy_app_event, event}` when native window activation changes make the app active/inactive; `use Guppy.App` modules can handle them as `handle_event("app_activated", data, state)` / `handle_event("app_deactivated", data, state)`. `window_focused`/`window_blurred` are emitted from GPUI window activation changes, and `Guppy.focus_window/1` activates a caller-owned native window. `window_moved`/`window_resized` include `x`, `y`, `width`, and `height` in logical pixels when GPUI reports bounds changes. `window_close_requested` is informational: native close requests are not vetoable from Elixir today, and a successful close is followed by `window_closed`.

## App processes

`Guppy.App` is the optional app-level coordinator for larger programs. A `Guppy.App` process owns app-global resources such as configured windows, themes, stylesheets, commands, keymaps, menus, and packaging metadata. `Guppy.Window` remains the rendering/process abstraction for each window.

```elixir
defmodule MyApp do
  use Guppy.App,
    windows: [%{id: "main", module: MyApp.MainWindow}],
    commands: [%{id: "new_file", label: "New File"}],
    keymap: [%{key: "cmd-n", command: "new_file"}],
    menus: [%{label: "File", items: [%{id: "new_file", label: "New", callback: "new_file"}]}],
    stylesheet: %{classes: %{"card" => %{style: "p-4 rounded-lg", hover_style: "bg-blue"}}},
    package: %{bundle_id: "dev.example.my_app"},
    exit_on_last_window_closed: true

  def handle_command("new_file", payload, state) do
    # menu/keymap/palette dispatch lands here asynchronously
    {:noreply, state}
  end
end

{:ok, _supervisor} = MyApp.start_link([])
```

Window ids are strings. The first configured window starts by default unless `start: false`; additional windows start when `Guppy.App.open_window/3` is called or when their spec sets `start: true`. App windows run under an app-owned `DynamicSupervisor`; the coordinator registry exposes `Guppy.App.windows/1`, `Guppy.App.window_pid/2`, `Guppy.App.open_window/3`, `Guppy.App.focus_window/2`, and `Guppy.App.close_window/2`. Set `exit_on_last_window_closed: true` for example-style apps that should terminate their app supervisor when the last app-owned window closes.

App config is plain Elixir data validated into structs. Use child-spec/start options and optional `init/1` for final config assembly. App-owned menus and Dock menus dispatch callbacks to `handle_command/3`; callback items that reference registered commands inherit the command's disabled state when native menus are installed. App-owned badge labels use `:app_badge` config or `Guppy.App.set_app_badge/2`. App-supervised windows can route native `:action` shortcut events to `handle_command/3` by using `Guppy.App.command_bindings/1` on a focusable root element (or `Guppy.App.command_callback/0` as the IR action callback). Keymap entries are checked in declaration order, skipping disabled commands. `Guppy.App.open_command_palette/1` opens a minimal built-in command-palette overlay backed by the same command registry; `Guppy.App.open_context_menu/3` opens a transient popup for command-backed context menu items. Use `Guppy.App.set_command_enabled/3` to toggle a command without replacing the full registry; disabled commands stay visible in the palette/context/Dock menus but do not dispatch. Standalone `Guppy.Window` modules and low-level `Guppy.open_window/1..3` continue to work without an app.

## Themes

Themes are app-scoped Elixir data that compile semantic color/style tokens to primitive IR style tuples before native render. `Guppy.App.Theme.default(:dark)` and `Guppy.App.Theme.default(:light)` provide built-in defaults, `Guppy.App.Theme.refine/2` creates explicit overrides from an existing theme, and apps can register `Guppy.App.ThemeFamily` values and activate a theme by id.

Useful helpers:

- `Guppy.active_theme/0` / `Guppy.active_theme/1`
- `Guppy.set_theme/1` / `Guppy.set_theme/2`
- `Guppy.register_theme_family/1` / `Guppy.register_theme_family/2`
- `Guppy.theme_color/1` / `Guppy.theme_color/2`
- `Guppy.theme_style/1` / `Guppy.theme_style/2`
- app-scoped equivalents under `Guppy.App`
- `Guppy.Style.theme_color/2` for semantic references inside theme style definitions
- `theme_style!/1` / `theme_color!/1` inside `use Guppy.Window`

See `docs/theme.md` for the Zed/GPUI audit notes and current Guppy theme boundaries.

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

Preferred `Guppy.Window` modules may handle `"window_focused"`, `"window_blurred"`, `"window_moved"`, and `"window_resized"` in `handle_event/3`; `window_closed` remains lifecycle-driving and stops the window process. `window_close_requested` remains informational for lower-level owners and is not exposed as a veto callback by `Guppy.Window`.

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

Box-spacing, size/aspect ratio, position, display, visibility, overflow visible/clip/hidden/scroll, scroll behavior booleans, debug flags, cursor, border, radius, named/hex/gradient/pattern color including text background, opacity, scrollbar width, named/arbitrary shadow, flex grow/shrink/alignment/self-alignment/basis, core text/font size/line-height/weight/family/fallbacks/features/decoration/strikethrough, line clamp, grid count/span/full-span/line placement, and image-only object-fit/grayscale helpers/classes already use canonical tuple ops or image option tuples: `Guppy.Style.py(1)` and template `class="py-1"` both produce `{:padding, :y, {:rem, 0.25}}`; `Guppy.Style.mx(:auto)` produces `{:margin, :x, :auto}`; `Guppy.Style.gap_x("px")` produces `{:gap, :x, {:px, 1}}`; `Guppy.Style.w("full")` produces `{:width, {:fraction, 1}}`; `Guppy.Style.aspect_ratio(1.5)` produces `{:aspect_ratio, 1.5}`; `Guppy.Style.top(-2)` produces `{:inset, :top, {:rem, -0.5}}`; `class="hidden invisible overflow-visible overflow-x-clip overflow-x-scroll scroll-concurrent scroll-axis-restricted debug debug-below cursor-pointer border-1 rounded-sm bg-[#0f172a] bg-pattern-slash-[red,1,4] opacity-50 scrollbar-w-[12px] text-white text-bg-yellow shadow-md shadow-[red,0,2,4,-1] flex-col basis-1/2 grow-[2] shrink-[0.5] aspect-video items-stretch self-stretch justify-evenly text-xl text-[14px] leading-[18px] font-bold font-[650] font-family-[Monaco] font-fallbacks-[Monaco,Menlo] font-features-[calt=0,kern=1] font-ligatures-none underline decoration-red decoration-wavy line-through strikethrough-red strikethrough-2 line-clamp-2 grid-cols-3 col-start-2 col-span-full"` produces display, visibility, overflow, scroll behavior, debug flags, cursor, border-width, border-radius, color, pattern background, text-background, opacity, scrollbar-width, named/arbitrary shadow, flex grow/shrink/alignment/self-alignment/basis, aspect ratio, text/font-size/line-height/weight/family/fallbacks/features/decoration/strikethrough, line-clamp, and grid tuple ops. On `<image>`, `class="object-cover grayscale"` maps to image `object_fit` and `grayscale` options. Later ops win over earlier ones, and order is preserved through the bridge. In `~GUI` templates, `class` may be a string or a dynamic list of strings; `nil` and `false` list entries are ignored. Raw `style` values must be canonical style lists (for example `style={Guppy.Style.py(1)}` or `style={[Guppy.Style.py(1)]}`); use `class` for class-token strings.

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
