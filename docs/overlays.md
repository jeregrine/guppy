# Overlay, popover, and select semantics

Guppy keeps overlay state Elixir-owned. Native code renders the current IR and emits events; it does not retain open/closed truth beyond GPUI focus/layout state.

## Ownership and lifecycle

- `popover` and `select` `open` flags are owned by the process that renders the containing window.
- Trigger clicks/keyboard toggles emit the configured `click` callback; the owner updates `open` and rerenders.
- Close requests emit the configured `close` callback:
  - `select` emits close on Escape while open and on mouse down outside the list.
  - `popover` emits close on Escape while open and, when `close_on_click_outside: true`, on mouse down outside the popover content.
- Selecting a `select` option emits `change` with the selected value. The owner decides whether that also closes the select.
- Focus return is explicit for popup-window overlays such as `Guppy.App.open_context_menu/3`; by default app context menus return focus to the source app window, or to `return_focus_to: window_id` when provided.
- Inline IR overlays (`popover`/`select`) are pruned with their owning window IR. If the owning window process exits, `Guppy.Server` closes the native window and native retained state is pruned with the view.

## Keyboard behavior

- `popover` triggers are focusable and treat Enter/Space as toggle requests.
- Open `popover` triggers treat Escape as a close request.
- `select` triggers are focusable and support:
  - Enter/Space: toggle request via `click`
  - Up/Down: previous/next enabled option via `change`
  - Home/End: first/last enabled option via `change`
  - single-character typeahead: next enabled option whose label starts with that character, wrapping after the current value
  - Escape while open: close request via `close`
- Disabled `select` options are skipped by keyboard navigation/typeahead and do not emit click changes.

## Positioning

`popover` exposes GPUI anchored positioning through typed IR fields:

- `anchor`: `:top_left | :top_right | :bottom_left | :bottom_right`
- `anchor_position`: explicit `{x, y}` point, when needed
- `anchor_position_mode`: `:window | :local`
- `anchor_offset`: `{x, y}` offset from the anchor point
- `anchor_fit`: `:switch_anchor | :snap_to_window | :snap_to_window_with_margin`
- `snap_margin`: non-negative logical pixels for margin-based window-edge snapping
- `stack_priority`: deferred-layer priority

`select` exposes the same practical window-edge controls for its list overlay: `anchor`, `anchor_offset`, `anchor_fit`, and `snap_margin`. It always positions locally relative to the trigger. Defaults keep prior behavior: `anchor: :top_left`, `anchor_offset: {0, 32}`, `anchor_fit: :snap_to_window_with_margin`, and `snap_margin: 8`.

Scroll-parent behavior is intentionally bounded to GPUI's anchored local/window coordinate modes. If a dropdown must ignore a scrolling parent, render a popup-window overlay from Elixir instead of nesting another native overlay.

## Nested overlays

Nested native overlays are deliberately unsupported today. `popover` children may contain nested ordinary panels/layout, but validation and native decode reject nested `popover` or `select` nodes anywhere inside popover content. This avoids ambiguous focus return, Escape routing, and z-order ownership until a complete overlay stack model is designed.

Use popup windows (`Guppy.App.open_context_menu/3` or an app-owned transient window) for multi-level menu flows that need separate ownership and focus return.
