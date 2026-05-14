# Future primitive scopes

This document records scoped designs for planned primitives without making them active implementation work. Guppy remains Elixir-owned and full-tree rendered; these scopes are gates for future work when explicitly prioritized.

## Retained controls inside generic `list` rows

Status: first control set implemented. Generic `list` rows support row-local `button`, `checkbox`, and `radio` controls with explicit ids; text-editor and overlay-backed controls remain deferred.

### Goals

- Allow stateful row controls without making native code the source of truth for row data.
- Keep virtualization compatible with full-tree replacement from Elixir.
- Preserve native transient state only when it is keyed by stable identity and can be pruned deterministically.

### Identity model

Use a composite row-control identity:

```text
view_id / list_identity / row_id / control_id
```

- `list_identity` is the existing explicit list `id`, falling back to the generated path identity when no explicit id exists.
- `row_id` is the required `id` on each generic `list` item.
- Stateful row controls must provide an explicit `id`; generated path ids are not stable enough for virtualized row reuse.
- Control ids are row-local for identity, so repeated row templates can use ids like `"done"` under different row ids.
- Native event payloads should include `list_id`, `row_id`, `control_id`, and the existing callback/value fields. The legacy top-level `id` may be the composite id for traceability, but row-aware handlers should use the structured fields.

### Lifecycle model

- Elixir owns semantic values (`checked`, `value`, selected option, disabled state). Native retained state may only hold transient UI state such as focus handles, text cursor/composition state, hover/active state, and GPUI entities required for controls.
- Each render marks the complete set of live row ids and live control ids from the `items` list. Native retained row-control state is pruned when a row disappears or a control id disappears from that row.
- Virtualization may materialize only visible rows, but pruning is based on the full IR item set, not viewport visibility. Offscreen controls can keep bounded retained state if they were previously materialized; controls for removed rows must be dropped on the next render.
- If a focused control is unmounted because its row is removed or the control disappears, native must clear focus state and emit at most the normal blur/change events that GPUI would produce for the control. It must not synthesize semantic value changes.
- Stale queued native requests must continue to obey request deadlines; expired renders must not prune or mutate row-control registries.

### Implemented first pass

- Native `RowControlKey` identity uses `view_id / list_identity / row_id / control_id` and keys retained focus handles for row controls.
- List-row validation admits only `button`, `checkbox`, and `radio` controls, requires explicit control ids, and rejects duplicate row-local control ids.
- Native row-control click/change emissions include structured `list_id`, `row_id`, and `control_id` fields along with the existing callback and value/checked fields.
- Retained row-control focus handles are marked from the full rendered item/control set and pruned on full-tree replacement.
- ExUnit and Rust coverage exists for validation, duplicate ids, key construction, pruning, event payloads, and server routing.
- `examples/list_row_controls.exs` demonstrates the supported first control set, and `bench/guppy_bench.exs` includes row-control list build/validation scenarios.

### Still deferred

- No keyed diffing of arbitrary subtrees.
- No native ownership of row values.
- No stateful controls in `uniform_list`; use generic `list` only.
- No nested popover/select overlay support inside virtual rows until anchor lifecycle is tested separately.

## Menu APIs

Status: first app-menu pass implemented. `Guppy.set_menus/1` installs app/runtime menus for the calling process; dock menus and element-local/context menus remain deferred.

### GPUI 0.2.2 surface

The active GPUI dependency exposes application-level menus through `App::set_menus(Vec<Menu>)`, `App::get_menus()`, and `App::set_dock_menu(Vec<MenuItem>)`. A menu item can be a separator, submenu, system submenu (`Services` on macOS), or action. Action items may carry GPUI OS actions for Cut, Copy, Paste, Select All, Undo, and Redo.

### Guppy scope

Menus should be app/runtime state, not IR nodes. They are not part of a window render tree and should not be rebuilt by every window render unless the owner explicitly changes menus.

The first Guppy API is deliberately narrow:

- `Guppy.set_menus/1` and `Guppy.set_menus/2` replace the app menu bar; `Guppy.set_menus([])` clears it. Dock menus remain deferred until a real macOS app needs them.
- Menu specs are Elixir data with top-level `%{label:, items: [...]}` menus, action items, `:separator` entries, and nested `%{label:, items: [...]}` submenus.
- Callback action items use `%{id:, label:, callback:}` plus optional `:shortcut` and `:enabled`.
- Focused-control OS edit items use `%{id:, label:, os_action: :cut | :copy | :paste | :select_all}`. Undo/redo are decoded for GPUI role completeness but stay disabled until retained text controls implement them.
- Event delivery routes selected callback actions to the Guppy runtime server, then to the process that registered the current menu spec.

### Implemented first pass

- `examples/menu_demo.exs` captures the initial real use case: a scratch-note window with File/Help callbacks and Edit actions for a focused textarea.
- `Guppy.Server` validates menu specs, tracks the installing process, forwards `:menu_action` payloads as `{:guppy_menu_event, event}`, and clears native menus when the owner exits.
- Native decode maps validated specs to GPUI 0.2.2 `Menu` / `MenuItem` values, preserves custom action identity, installs menu shortcuts, and uses GPUI text-input actions for cut/copy/paste/select-all OS edit items.
- ExUnit coverage checks server validation, owner routing, native dispatch, and owner-exit clearing. Rust coverage checks ETF decode, invalid specs, action identity, GPUI item mapping, current-spec shortcut replacement, and callback emission payloads.
- `bench/guppy_bench.exs` includes menu-spec build and encode/decode proxy scenarios.
- macOS smoke launched `examples/menu_demo.exs` and confirmed direct `Guppy.set_menus/1` / clear calls return `:ok`.

### Deferred until proven by app needs

- Dock menus (`App::set_dock_menu`).
- Context menus or element-local popup menus. Existing div `context_menu` events are only notifications today.
- Per-window dynamic menu validation callbacks or synchronous menu enablement sourced from Elixir.
- Arbitrary Rust action types from Elixir.
- Cross-platform promises beyond the validated `gpui = 0.2.2` behavior on supported targets.

## Gradient style primitives

Status: first narrow pass implemented. Guppy now exposes ordered, two-stop background linear gradients; deferred gradient variants remain future work.

### GPUI 0.2.2 surface

GPUI exposes `linear_gradient(angle, from, to)` as a `Background`, with two `LinearColorStop` values and stop percentages from `0.0` to `1.0`. GPUI also has `pattern_slash`, but pattern painting should stay with the custom-painting scope rather than the first gradient style pass.

### Guppy scope

The first style primitive is background-only and ordered like every other style op, so later background ops override earlier ones.

Implemented shape:

```elixir
{:bg_linear_gradient,
 [angle: 90.0,
  from: {"#0f172a", 0.0},
  to: {"#2563eb", 1.0}]}
```

Validation requires:

- numeric `:angle` in degrees from `0.0..360.0`;
- exactly `:from` and `:to` color stops;
- named Guppy color tokens or `#RRGGBB` strings;
- stop percentages in `0.0..1.0`.

Template classes support the compact static form `bg-linear-gradient-[90,#0f172a:0,#2563eb:1]`.

### Deferred

- Multi-stop, radial, conic, border, and text gradients.
- Semantic theme-token expansion in core IR.
- Gradient animation.
- Pattern/slash backgrounds, which belong with custom painting/pattern scope.

### Implemented coverage

- Elixir IR validation and template/class parsing cover the chosen op shape.
- Native ETF decode and style mapping target GPUI `linear_gradient`.
- ExUnit style validation/template coverage and Rust decode/style mapping tests cover regressions.
- `examples/style_gallery.exs` demonstrates static and dynamic gradient classes, and `bench/guppy_bench.exs` includes gradient class-parse/style-validation scenarios.

## Data-table and tree virtualization

Status: first semantic virtualization pass implemented. `Guppy.IR.data_table/3` and `Guppy.IR.tree/2` are dedicated primitives with native virtual-row rendering and semantic event payloads.

Current primitives are intentionally narrower:

- grid style ops express static GPUI grid layout;
- `uniform_list` handles simple fixed text rows;
- generic `list` handles variable-height static/layout rows.

Full data-table and tree virtualization should not be squeezed into those primitives. They need dedicated semantics so identity, selection, focus, and scrolling remain predictable.

Initial implementation use case: a project-planning surface with a navigable outline/tree on the left and a task table on the right. Elixir owns selected node/row/cell state, sort state, and tree expansion; native emits selection, toggle, and sort requests.

`Guppy.IR.data_table/3` and `Guppy.IR.tree/2` define the dedicated semantic IR shape with validation for column/node/row identity, cell references, selected state, sort state, and callback names. Native decode maps the semantics into GPUI list-backed virtual rows. Native event payloads preserve `table_id`, `row_id`, `column_id`, `tree_id`, and `item_id` so Elixir remains the source of truth.

### Data-table scope

The first table primitive includes:

- table id, row ids, column ids, and cell identity;
- `:auto`, `{:px, value}`, and `{:fr, value}` column sizing;
- selected row/cell state owned by Elixir;
- sort requests as events, not native-owned data transforms;
- virtualized rows backed by GPUI `ListState`;
- static cell children (`text`, `spacer`, and nested static `div`) only.

### Tree scope

The first tree primitive includes:

- node ids and parent/child relationships;
- expanded/collapsed state owned by Elixir;
- indentation/disclosure rendering;
- selected node state;
- select/toggle event callbacks;
- virtualization over the flattened visible node sequence.

### Implemented coverage

- `examples/data_table_tree.exs` demonstrates a project tree and task table with Elixir-owned expansion, selection, and sorting.
- `bench/guppy_bench.exs` includes data-table/tree build and validation scenarios before any large-data performance claims.
- ExUnit covers IR validation, template compilation, server routing for semantic payloads, and invalid table/tree shapes.
- Rust coverage includes native ETF decode, invalid table child rejection, visible-tree flattening, GPUI list-state retention, and semantic event payload snapshots.

### Deferred

- Reusing generic `list` row controls as a hidden table/tree implementation without a public semantic model.
- Native sorting/filtering/tree expansion ownership.
- Stateful controls or text editors inside data-table cells.
- Keyboard navigation and focus-visible behavior across cells/tree rows.
- Pinned headers/columns, horizontal viewport synchronization, column drag-resize/reorder, spreadsheet editing, and accessibility semantics until a concrete app needs them.

## Custom painting, canvas, and pattern painting

Status: first bounded canvas pass implemented. `Guppy.IR.canvas/2` exposes data-only rect, rounded-rect, and slash-pattern rect commands with coarse canvas click events; arbitrary custom elements, paint callbacks, paths, text, image drawing, and per-command hit testing remain deferred.

GPUI exposes low-level painting through custom elements, window paint APIs such as `paint_path`, `PaintQuad` fills, and background helpers such as `pattern_slash`. Guppy does not expose those raw APIs directly to Elixir. The first primitive is deliberately bounded around native-owned painting from validated draw data.

### Implemented first pass

The real use case is `examples/canvas_pattern.exs`: a release-health card with a slash-pattern capacity band. That visual cannot be expressed by current `div`, `text`, `image`, `icon`, grid/list primitives, or the two-stop gradient style op without introducing pattern painting.

`Guppy.IR.canvas/2` produces a node with:

- explicit optional `id`, wrapper `style`/viewport sizing, and optional coarse `events: %{click: callback}`;
- ordered draw commands: `:rect`, `:rounded_rect`, and `:pattern_rect`;
- named color tokens or strict `#RRGGBB` colors using the same validated color set as gradients;
- unit slash-pattern `line_width` and `interval` values for `:pattern_rect`;
- no arbitrary Elixir code executed from the native paint pass;
- native rendering through GPUI `canvas`, `PaintQuad` fills, and `pattern_slash` backgrounds.

Canvas currently has no retained native resources beyond the stable node identity used for event routing. If later commands introduce retained images, paths, shaders, or text layouts, those resources must be keyed by stable canvas id and pruned on full-tree replacement.

Pattern painting is implemented as a canvas command (`:pattern_rect`) rather than a global background style op because the concrete use case needs a bounded drawn region inside a custom card, not a general semantic background token.

### Implemented coverage

- ExUnit validates command schemas, op-specific fields, colors, dimensions, pattern parameters, template compilation, and click callback shape.
- Rust tests cover native ETF decode, op-specific rejection, GPUI render/click smoke, the current stateless retained-resource behavior, and expired queued render requests carrying canvas IR.
- `bench/guppy_bench.exs` includes canvas build, validation, and encode/decode proxy scenarios for 100 draw commands before any performance claims.
- `examples/canvas_pattern.exs`, README, and `docs/gpui-compliance.md` document the supported first pass.

### Deferred

- Arbitrary custom GPUI elements authored from Elixir.
- Per-frame Elixir paint callbacks.
- Rich vector/SVG authoring beyond current `icon`/`image` support.
- Line/path/text/image canvas commands and retained resources for those commands.
- Canvas hit-testing beyond coarse element pointer events.
- General pattern background style ops, until a real style-level use case needs them.
