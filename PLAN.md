# Guppy Forward Plan

Operational rules, checks, and maintenance reminders live in `AGENTS.md`. This file tracks only the forward feature plan.

## Next work

No feature implementation is active. Keep stabilization, bug fixes, verification paths, docs, examples, and compliance tracking ahead of speculative surface area. Start one of the scoped tasks below only when explicitly prioritized by a real use case.

## Scoped task backlog

### 1. Retained controls inside generic `list` rows

Scope: [`docs/future-primitives.md`](docs/future-primitives.md#retained-controls-inside-generic-list-rows). Status: first supported control set complete.

- [x] Confirm the concrete row-control use case and first supported control set (`button`, `checkbox`, and `radio` before text/overlay controls).
- [x] Add native `RowControlKey` identity using `view_id / list_identity / row_id / control_id`.
- [x] Relax list-row validation only for supported stateful controls, requiring explicit control ids.
- [x] Thread structured `list_id`, `row_id`, and `control_id` fields through native event payloads and server routing.
- [x] Retain and prune row-control state from the full rendered item/control set while preserving request-deadline stale-render behavior.
- [x] Add ExUnit and Rust tests for validation, duplicate ids, key construction, pruning, and event payloads.
- [x] Update README, examples, and `docs/gpui-compliance.md` after end-to-end support lands.

### 2. App-level menu APIs

Scope: [`docs/future-primitives.md`](docs/future-primitives.md#menu-apis). Status: first app-menu pass complete.

- [x] Capture a real app menu use case before adding public API (`examples/menu_demo.exs` scratch-note File/Edit/Help menus).
- [x] Design the Elixir menu spec for labels, ids, callbacks, shortcuts, enabled state, separators, and nested items.
- [x] Add narrow public APIs such as `Guppy.set_menus/1` and, only if needed, `Guppy.set_dock_menu/1` (`set_dock_menu` remains deferred).
- [x] Decode specs to GPUI 0.2.2 app menus and OS edit actions where focused controls can support them.
- [x] Route menu action callbacks through `Guppy.Server` to the registering/owning process.
- [x] Add native tests for spec decoding, action identity, callback emission, clearing, and replacement.
- [x] Manually verify macOS menu installation before documenting menu support (`examples/menu_demo.exs` launch smoke plus direct `Guppy.set_menus/1` / clear smoke returned `:ok` on macOS).

### 3. Gradient style primitives

Scope: [`docs/future-primitives.md`](docs/future-primitives.md#gradient-style-primitives). Status: first narrow pass complete.

- [x] Confirm an example or product design needs gradients (`examples/style_gallery.exs` now demonstrates static and dynamic gradient surfaces).
- [x] Finalize the first background-only op shape: `{:bg_linear_gradient, [angle: ..., from: ..., to: ...]}`.
- [x] Add Elixir IR validation for angle, exactly two color stops, supported color formats, and stop percentages.
- [x] Add template/class parsing only for the chosen op shape.
- [x] Add native ETF decode and style mapping to GPUI `linear_gradient`.
- [x] Add ExUnit and Rust style tests, then update examples and compliance docs when used.

### 4. Data-table and tree virtualization

Scope: [`docs/future-primitives.md`](docs/future-primitives.md#data-table-and-tree-virtualization). Status: scoped, not active.

- [ ] Capture a concrete table or tree use case before adding IR.
- [ ] Define dedicated semantic IR instead of hiding table/tree behavior inside current `grid`, `uniform_list`, or `list` primitives.
- [ ] For tables, specify row ids, column ids, cell identity, sizing, selection, sort/filter events, and keyboard navigation.
- [ ] For trees, specify node ids, parent/child relationships, Elixir-owned expansion state, selection/focus, disclosure rendering, and flattened visible-node virtualization.
- [ ] Add stress-test or benchmark coverage before making large-data performance claims.
- [ ] Add independent IR/template/native tests and update docs/examples only after end-to-end support lands.

### 5. Custom painting, canvas, and pattern painting

Scope: [`docs/future-primitives.md`](docs/future-primitives.md#custom-painting-canvas-and-pattern-painting). Status: scoped, not active.

- [ ] Confirm a real drawing need that cannot be expressed with existing nodes, styles, image/icon support, or future gradient primitives.
- [ ] Design a retained, data-only canvas/drawing IR with explicit ids, viewport/style, optional pointer events, and ordered draw commands.
- [ ] Keep Elixir code out of the native paint pass; native retained resources must be keyed by stable canvas id and pruned on full-tree replacement.
- [ ] Decide whether pattern painting belongs as a small background style op or as a canvas command based on the real use case.
- [ ] Add benchmark or stress-test coverage for draw-command volume before optimizing or claiming performance.
- [ ] Add ExUnit command-schema tests and Rust decode/paint/pruning/deadline tests before updating docs/examples.
