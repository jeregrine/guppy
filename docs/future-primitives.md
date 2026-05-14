# Future primitive scopes

This document records scoped designs for planned primitives without making them active implementation work. Guppy remains Elixir-owned and full-tree rendered; these scopes are gates for future work when explicitly prioritized.

## Retained controls inside generic `list` rows

Status: design recorded; implementation remains deferred. `list` rows stay static/layout-only until this design is implemented end-to-end.

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

### Implementation shape

1. Add an explicit native `RowControlKey` and a per-list row-control registry under `BridgeView` retained state.
2. Relax list-row validation only for supported row-control kinds, requiring explicit control ids and preserving row-local identity checks.
3. Thread list/row/control identity through static-row rendering so event bridge payloads include structured row-control fields.
4. Start with controls that do not need text-editor entities (`button`, `checkbox`, `radio`) before enabling `text_input`, `textarea`, or overlay-backed controls like `select`.
5. Add Rust tests for key construction, pruning, duplicate row/control validation, and event payloads; add ExUnit tests for IR/template validation and server event routing.

### Non-goals for the first implementation

- No keyed diffing of arbitrary subtrees.
- No native ownership of row values.
- No stateful controls in `uniform_list`; use generic `list` only.
- No nested popover/select overlay support inside virtual rows until anchor lifecycle is tested separately.

## Menu APIs

Status: scoped; no public menu API yet.

### GPUI 0.2.2 surface

The active GPUI dependency exposes application-level menus through `App::set_menus(Vec<Menu>)`, `App::get_menus()`, and `App::set_dock_menu(Vec<MenuItem>)`. A menu item can be a separator, submenu, system submenu (`Services` on macOS), or action. Action items may carry GPUI OS actions for Cut, Copy, Paste, Select All, Undo, and Redo.

### Guppy scope

Menus should be app/runtime state, not IR nodes. They are not part of a window render tree and should not be rebuilt by every window render unless the owner explicitly changes menus.

A first Guppy API should be deliberately narrow:

- `Guppy.set_menus/1` for app menus and `Guppy.set_dock_menu/1` only if a real macOS app needs it.
- Menu specs are Elixir data with `:label`, `:id`, `:callback`, `:shortcut`, `:enabled`, nested `:items`, and `:separator` entries.
- Event delivery routes selected menu actions to the Guppy runtime server, then to the process that registered or owns the menu spec.
- Built-in OS edit actions may be represented explicitly (`:cut`, `:copy`, `:paste`, `:select_all`, `:undo`, `:redo`) but should only be wired when focused native controls can answer them correctly.

### Deferred until proven by app needs

- Context menus or element-local popup menus. Existing div `context_menu` events are only notifications today.
- Per-window dynamic menu ownership and validation callbacks.
- Arbitrary Rust action types from Elixir.
- Cross-platform promises beyond the validated `gpui = 0.2.2` behavior on supported targets.

### Implementation gates

- A concrete example needs a real menu before adding public API.
- Native tests must cover spec decoding, action identity, callback emission, and clearing/replacing menus.
- Manual macOS smoke must verify top-level menu installation and basic OS edit items before docs claim menu support.
