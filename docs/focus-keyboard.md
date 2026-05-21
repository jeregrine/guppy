# Focus and keyboard model

Guppy's focus model keeps Elixir as the owner of semantic UI state while native GPUI focus handles provide local keyboard reachability.

## Focus scopes

- **Window root**: each native root view owns Tab/Shift-Tab traversal across GPUI tab stops and tracks keyboard-vs-mouse focus-visible state.
- **Ordinary IR nodes**: focusable `div`/control nodes can opt into tab stops with `tab_stop`/`tab_index`; callbacks still round-trip to the owning Elixir process.
- **Virtual widgets**: list-like widgets retain stable native focus handles for visible, keyboard-actionable rows/cells/items. Elixir owns selected/expanded/sorted state; native focus is only the current keyboard target.
- **Overlays**: select/popover/context-menu overlays are transient focus scopes. Elixir owns open/close state; native handling provides close/activation keys where supported.

## Roving-focus pattern

Virtual widgets use a narrow roving-focus pattern:

1. Tab enters the widget at its first keyboard-actionable retained item.
2. Arrow keys move native focus between retained visible items where the widget defines a clear spatial order.
3. Enter/Space activate the focused item according to that widget's semantics.
4. Keyboard context-menu invocation uses Shift-F10 or the context-menu key when a context-menu callback exists.
5. Selection, expansion, and sorting remain semantic Elixir state updated from callback events; native focus does not imply selection.

Current widget behavior:

- **data_table**: sortable headers are tab stops; Left/Right moves between sortable headers; Down enters the first row cell in that column; Up from the first row cell returns to the sortable header. Body rows use Up/Down roving focus. Body cells use Left/Right/Up/Down roving focus. Enter/Space activate row/cell/sort callbacks, and keyboard context-menu invocation emits row/cell context-menu events.
- **tree**: visible rows are tab stops when select/toggle/context-menu callbacks exist. Up/Down moves row focus; Enter selects; Space toggles disclosure; Left collapses expanded nodes; Right expands collapsed nodes; keyboard context-menu invocation emits row context-menu events.
- **list**: row-local controls are ordinary retained tab stops. Generic row roving focus is not implemented yet.
- **select/popover/context menus**: select owns menu-like arrow/Home/End/typeahead behavior; popover supports toggle/close keys. Context-menu overlay focus return is app-owned where opened through `Guppy.App` helpers.

## Shortcut priority

Current shortcut dispatch is element-local and bubbles through GPUI event propagation: a focused element with a matching shortcut emits its action and stops propagation before ancestor shortcuts see the key. This child-before-ancestor priority is covered by a GPUI keyboard regression test. `text_input` and `textarea` accept the same explicit `actions`/`shortcuts` IR fields as other shortcut-capable nodes; matching shortcuts emit action events while preserving normal text-editing key bindings for non-matching keys. App command shortcuts are usually installed on a focusable window root. A more explicit cross-scope app-command priority table remains Priority 3 follow-up work.

## Accessibility boundary

Guppy currently exposes semantic ids and event payloads for tables/trees but does not expose typed accessibility roles/states through IR. That audit remains separate Priority 3 work.
