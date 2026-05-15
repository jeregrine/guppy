# Future primitive scopes

This document records deferred primitive ideas only. Current supported behavior belongs in `README.md`, `docs/gpui-compliance.md`, examples, tests, and code.

Guppy remains Elixir-owned and full-tree rendered. Any future primitive must preserve stable identity for retained native state, deadline-aware native requests, ordered style ops, and Elixir as the source of semantic truth.

## Generic list row controls

Deferred until a concrete example needs them:

- text-editor or textarea controls inside virtualized rows;
- select/popover/overlay-backed controls inside virtualized rows;
- arbitrary keyed subtrees or native-owned row values;
- custom scrollbar parity beyond the current list wrappers.

Future retained controls should continue using row-local control identity under the list id and row id, and pruning must be based on the full rendered item/control set rather than viewport visibility alone.

## Data-table and tree interactions

Deferred until a real app needs them:

- default selected row/cell/item highlight primitives beyond semantic `selected_*` state and explicit Elixir-supplied styles;
- keyboard navigation, focus-visible behavior, and accessibility semantics;
- pinned headers/columns and horizontal viewport synchronization;
- column resize/reorder, spreadsheet-style editing, and stateful cell controls;
- native sorting/filtering/tree expansion ownership.

## Select, popover, and overlay lifecycle

Deferred until a real overlay-heavy example needs them:

- nested overlay edge cases and richer deferred-layer lifecycle controls;
- richer option-list positioning and collision behavior;
- focus/close lifecycle parity with more GPUI overlay scenarios;
- keyboard behavior beyond the current first-pass select/popover handling.

## Menus

Deferred until a concrete app needs them:

- dock menus (`App::set_dock_menu`);
- element-local/context menu primitives beyond current context-menu events;
- Services submenu exposure and richer OS menu roles;
- per-window dynamic enablement or synchronous Elixir validation callbacks;
- undo/redo wiring for retained text controls.

## Gradients, animation, and style expansion

Deferred until there is an example need:

- multi-stop, radial, conic, border, and text gradients;
- semantic theme-token expansion in core IR;
- transform/keyframe animations, easing choices, and completion callbacks;
- style-level pattern/slash backgrounds.

## Canvas and custom painting

Deferred until a real visual need and measurement justify them:

- arbitrary custom GPUI elements authored from Elixir;
- per-frame Elixir paint callbacks;
- line/path/text/image canvas commands;
- retained drawing resources such as images, paths, shaders, or text layouts;
- per-command hit testing beyond coarse canvas events.
