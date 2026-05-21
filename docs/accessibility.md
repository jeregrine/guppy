# Accessibility and semantics audit

Guppy currently exposes semantic UI state to Elixir, but it does not expose native accessibility roles/states through IR yet.

## GPUI 0.2.2 audit

The active dependency is `gpui = 0.2.2`. A source audit of the crate showed no public element-level accessibility role, label, relationship, or state API for ordinary GPUI elements. The only relevant public surface found was focus management and ordinary text/window behavior; newer local GPUI/Zed sources include a window-level accessibility document hook, but that API is not present in the crates.io `gpui-0.2.2` dependency used by Guppy.

Because of that, Guppy should not add inert IR fields such as `role`, `aria_label`, or `checked_state` that native rendering cannot truthfully map into platform accessibility APIs. Unknown IR keys should continue to be rejected.

## Current semantic coverage

Existing typed IR still carries useful app semantics:

- stable node ids for event routing and retained native focus
- text/rich-text content and control labels
- checkbox/radio/select values and checked/selected state
- text input/textarea values, focus/blur/change/context-menu callbacks, and explicit shortcut actions
- data-table column ids/labels, row ids, selected row/cell state, sort state, and semantic row/cell event payloads
- tree item ids/labels, selected id, expanded state, and semantic row event payloads
- list/uniform-list item ids and keyboard-actionable click/context-menu callbacks

Elixir remains the source of truth for selection, expansion, sorting, and enabled/disabled state. Native focus is keyboard reachability, not semantic selection.

## Follow-up policy

Add typed accessibility IR only when the active GPUI dependency exposes a real native mapping for at least one platform, and cover it with native tests or an example-level smoke. Until then, prefer semantic event payloads, stable ids, labels, explicit focus behavior, and documented limitations over placeholder accessibility fields.
