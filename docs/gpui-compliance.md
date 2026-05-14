# GPUI Compliance Matrix

Source of truth: `../zed/crates/gpui` at upstream reference `78c889c21d`.

Statuses:

- `supported`: Guppy has a comparable primitive and an example or automated coverage.
- `partial`: Guppy can express the core scenario but is missing GPUI details.
- `unsupported`: Guppy does not yet expose the needed primitive.
- `out of scope`: Not planned for the current Elixir-owned IR subset.

## Missing or deferred primitive areas

These are the main primitive gaps visible from the current GPUI matrix. They are not active work unless explicitly prioritized.

- **Select/dropdown**: initial Elixir-owned select/dropdown support exists with anchored option lists, close events, keyboard toggling, arrow-key value changes, and change roundtrips; richer native option-list positioning and full menu semantics remain partial.
- **Rich editor / rich text**: rich text runs/highlights are exposed through `Guppy.IR.rich_text/2`; advanced layout, syntax/editor semantics, and full editor parity remain missing.
- **Generic list / variable-height list**: `list` adds GPUI `ListState`-backed variable-height rows with static/layout row children (`text`, `spacer`, and nested static `div`) plus explicit row-local `button`, `checkbox`, and `radio` controls. Text-editor/overlay controls inside virtual rows and custom scrollbar parity remain partial. Retained row-control identity/lifecycle notes live in [`docs/future-primitives.md`](future-primitives.md#retained-controls-inside-generic-list-rows).
- **Data table / tree**: dedicated `data_table` and `tree` primitives now cover first-pass semantic identity, Elixir-owned selection/sort/expansion state, virtualized rows, and structured events. Advanced keyboard/focus, editing, pinned columns, and stateful cell controls remain deferred in [`docs/future-primitives.md`](future-primitives.md#data-table-and-tree-virtualization).
- **Full popover / anchored overlay controls**: popovers now expose anchor corner, optional anchor position/offset, fit mode, close-on-outside-click, and deferred-layer priority; deeper nested-overlay edge cases and richer lifecycle semantics remain partial.
- **Animation primitives**: div-like opacity animation supports stable native animation ids, duration, repeat, and from/to opacity; broader transform/keyframe animation remains partial.
- **Gradient style primitives**: two-stop background linear gradients are exposed as ordered style ops and template classes; multi-stop, radial, conic, border, text-gradient, pattern, and animation variants remain deferred.
- **Grid layout**: current grid style ops cover GPUI's basic grid, row/column counts, and row/column spans; advanced table semantics are not exposed.
- **Custom painting / canvas / pattern painting**: would require a new retained drawing primitive. Scope and deferral are recorded in [`docs/future-primitives.md`](future-primitives.md#custom-painting-canvas-and-pattern-painting).
- **Menu APIs**: app-level `Guppy.set_menus/1` is supported as runtime state, not IR. Callback actions route to the installing process, and cut/copy/paste/select-all OS edit menu items target focused native text inputs. Dock menus, element-local/context menus, and synchronous Elixir validation callbacks remain deferred in [`docs/future-primitives.md`](future-primitives.md#menu-apis).
- **Mouse pressure payloads**: basic mouse events are routed, but pressure-specific data is not exposed.

Intentionally narrow parity areas:

- `window_close_requested` is an informational event, not a synchronous close-veto protocol
- async image loading/error-state APIs
- complete SVG/image asset pipeline controls
- full GPUI window API parity
- exact focus-visible styling edge-case parity
- full native drag/drop payload and drop-target parity
- GPUI test API parity

| GPUI source | Guppy port/coverage | Status | Missing primitives / gaps | Verification |
| --- | --- | --- | --- | --- |
| `examples/hello_world.rs` | `examples/hello_world.exs`, `test/guppy_test.exs` template checks | supported | none known for static text/window open | automated IR/template tests; manual example smoke |
| `examples/scrollable.rs` | `examples/kanban_todo.exs`, `examples/super_demo.exs`; native scroll tests | partial | GPUI parity for every scroll option not mapped; no default high-frequency coalescing planned from current measurements | Rust scroll-axis unit test; GPUI render smoke retains explicit scroll handles; manual kanban smoke |
| `examples/input.rs` | `examples/kanban_todo.exs`, `examples/super_demo.exs`; text input, textarea, radio, and select form-control tests | partial | rich editor behavior, richer select menu semantics, and exact focus-visible edge-case parity | Rust retained-state/text-input focus/radio/select/focus-visible unit tests; ExUnit IR/template/native hidden-window coverage; manual example smoke |
| `examples/drag_drop.rs` | `examples/kanban_todo.exs`, `examples/super_demo.exs` drag/drop callbacks | partial | native drag payload parity and drop target model are narrower than GPUI; no default event coalescing planned from current measurements | Elixir server routing tests cover drag_start/drag_move/drop payloads; manual kanban smoke |
| `examples/tab_stop.rs` | text input/button/checkbox/div `tab_index` and `tab_stop` IR fields; root Tab/Shift-Tab focus traversal bindings | partial | GPUI tab grouping and edge-case parity remain narrow | IR validation; Rust GPUI render smoke retains focus handles and simulates Tab ordering |
| `examples/image/image.rs` | `examples/style_gallery.exs`, `examples/super_demo.exs`, `test/guppy_test.exs` image template checks | partial | complete async image loading states and asset pipeline parity | automated IR/template tests; Rust image source/object-fit mapping tests; manual gallery smoke |
| `examples/svg/svg.rs` | `examples/style_gallery.exs`, `examples/super_demo.exs` via `icon`/embedded image sources | partial | full SVG rendering controls and sizing parity | automated IR/template checks for icon/image; Rust embedded image-source mapping test; manual smoke |
| `examples/window_positioning.rs` | window options validation in `Guppy.Server` tests; hidden native window smoke | partial | complete multi-display/window positioning behavior not covered in CI | automated option validation; hidden-window native smoke with bounds/min-size/kind/decorations/background |
| `examples/active_state_bug.rs` | style states on button/checkbox/div | partial | exact active state regression not ported | IR validation only |
| `examples/anchor.rs` | `Guppy.IR.popover/4`, `<popover>`, `examples/super_demo.exs` | partial | corner anchors, optional position/offset, local/window position mode, and snap-fit controls are exposed; center/edge anchors and hover-driven anchor demo parity remain missing | ExUnit IR/template/native hidden-window coverage; manual super_demo smoke |
| `examples/animation.rs` | div-like opacity `animation` option; `examples/super_demo.exs` | partial | transform/SVG rotation, chained keyframes, easing choices, and completion callbacks are not exposed | IR/template/native hidden-window coverage; Rust opacity interpolation test; manual super_demo smoke |
| `examples/data_table.rs` | `Guppy.IR.data_table/3`, `<data_table />`, `examples/data_table_tree.exs` | partial | first pass covers semantic columns/rows/cells, column sizing, selected row/cell, sort events, and virtualized rows; keyboard navigation, editing, pinned columns, and stateful cell controls remain deferred | ExUnit IR/template/server-routing tests; Rust native decode/render/event tests; benchmark build/validation scenarios; manual data_table_tree smoke |
| `examples/focus_visible.rs` | `focus_visible_style` on div-like controls; Tab/Shift-Tab focus-visible state tracking | partial | exact GPUI input-modality edge cases remain narrow | IR/template/native hidden-window coverage; Rust simulated Tab/mouse focus-visible state coverage |
| `examples/gif_viewer.rs` | image node | partial | animated GIF controls/loading states | manual only |
| `examples/gradient.rs` | `examples/style_gallery.exs`; `{:bg_linear_gradient, [angle: ..., from: ..., to: ...]}` and `bg-linear-gradient-[angle,color:stop,color:stop]` style support | partial | first pass is background-only with exactly two stops; no multi-stop, radial, conic, border, text-gradient, or gradient animation support | ExUnit IR/template/class validation; Rust ETF decode and style mapping tests; manual style_gallery smoke |
| `examples/grid_layout.rs` | grid style ops (`:grid`, `grid_cols`, `grid_rows`, `col_span`, `row_span`, full-span flags); `examples/super_demo.exs` | partial | start/end line placement and exact visual parity remain narrow | IR/component/native hidden-window coverage; manual super_demo smoke |
| `examples/image_gallery.rs` | image node examples | partial | gallery layout primitives and loading states | manual only |
| `examples/image_loading.rs` | image node | partial | async loading/error state parity | manual only |
| `examples/layer_shell.rs` | none | out of scope | platform shell/layer APIs | none |
| `examples/list_example.rs` | `Guppy.IR.list/2`, `<list />`, `Guppy.IR.uniform_list/2`, `<uniform_list />`, `examples/super_demo.exs`, `examples/list_row_controls.exs` | partial | variable-height GPUI `ListState` rows support static/layout `text`/`spacer`/nested static `div` row IR plus explicit row-local `button`/`checkbox`/`radio`; text-editor/overlay row controls and custom scrollbar parity remain incomplete | ExUnit IR/template/native hidden-window coverage; Rust list-state/render helper, row-control key/pruning/event tests; manual super_demo and list_row_controls smoke |
| `examples/mouse_pressure.rs` | mouse event callbacks | partial | pressure payload is not exposed; basic mouse down/up/move payloads are routed | server routing tests cover pointer events; pressure explicitly deferred |
| `examples/move_entity_between_windows.rs` | none | out of scope | direct GPUI entity migration conflicts with Elixir-owned IR/window ownership model | explicitly out of scope for current architecture |
| `examples/on_window_close_quit.rs` | `Guppy.close_window/2`; native `window_close_requested` and `window_closed` events | partial | close-request is intentionally informational today; no synchronous Elixir veto protocol | README documents semantics; server route tests cover close-request and closed lifecycle events |
| `examples/opacity.rs` | style token `{:opacity, value}` | partial | exact visual parity not smoke-tested | IR/style validation |
| `examples/ownership_post.rs` | `Guppy.Server` owner tracking | partial | direct GPUI entity ownership scenario not ported | server tests |
| `examples/painting.rs` | none | unsupported | custom painting/canvas scope is recorded in `docs/future-primitives.md`; would require a retained drawing primitive | no implementation; future draw-command validation/native paint tests required before support claims |
| `examples/paths_bench.rs` | none | out of scope | GPUI internal path benchmark | none |
| `examples/pattern.rs` | none | unsupported | pattern painting is scoped with custom painting/canvas work in `docs/future-primitives.md` | no implementation; future style/canvas tests required before support claims |
| `examples/popover.rs` | `Guppy.IR.popover/4`, `<popover>`, `examples/super_demo.exs` | partial | close-on-outside-click and deferred priority are exposed; deeper nested popover parity and advanced deferred-layer lifecycle controls remain incomplete | ExUnit IR/template/native hidden-window coverage; manual super_demo smoke |
| `examples/set_menus.rs` | `Guppy.set_menus/1`, `examples/menu_demo.exs` | partial | app-level menu bar replacement is supported; dock menus, system services submenu, element-local/context menus, per-window validation callbacks, and undo/redo edit actions remain deferred | ExUnit server validation/routing/owner-clear tests; Rust menu decode/action identity/GPUI mapping/shortcut/callback tests; manual menu_demo smoke |
| `examples/shadow.rs` | style tokens `shadow_sm/md/lg` | partial | complete shadow controls/visual parity | IR/style validation |
| `examples/testing.rs` | ExUnit/Rust tests | partial | GPUI test API parity not exposed | existing test suites |
| `examples/text.rs` | `text` node with style-token support; `Guppy.IR.rich_text/2` / `<rich_text />` runs; practical multiline input via `textarea` | partial | advanced text layout controls and full editor parity incomplete | IR/template/native hidden-window coverage; Rust rich text highlight range tests; textarea example/manual smoke |
| `examples/text_layout.rs` | text style tokens and rich text runs | partial | advanced layout measurement/wrapping parity | IR/style validation and native text/rich-run decode/render coverage |
| `examples/text_wrapper.rs` | text style tokens | partial | wrapping measurement parity | IR/style validation and native text style decode/render coverage |
| `examples/tree.rs` | `Guppy.IR.tree/2`, `<tree />`, `examples/data_table_tree.exs` | partial | first pass covers semantic node ids, Elixir-owned expansion/selection, disclosure rows, flattened visible-node virtualization, and select/toggle events; keyboard/focus/accessibility parity remains deferred | ExUnit IR/template/server-routing tests; Rust native decode/flatten/render/event tests; benchmark build/validation scenarios; manual data_table_tree smoke |
| `examples/uniform_list.rs` | `Guppy.IR.uniform_list/2`, `<uniform_list />`, `Guppy.IR.list/2`, `<list />`, `examples/super_demo.exs`, `examples/list_row_controls.exs` | partial | `uniform_list` remains text-row focused; `list` covers variable-height static/layout row IR plus explicit button/checkbox/radio row controls | ExUnit IR/template/native hidden-window coverage; Rust list-state/render helper and row-control tests; manual super_demo/list_row_controls smoke |
| `examples/window.rs` | window options | partial | full GPUI window API parity | option validation tests |
| `examples/window_shadow.rs` | window decorations/background options | partial | full shadow/window-frame parity | option validation tests |
| `tests/action_macros.rs` | `actions` / `shortcuts` IR fields and native shortcut matching tests | partial | Rust macro parity is out of scope; shortcut behavior still narrow | Rust shortcut unit tests |

## First ports to harden

1. `hello_world`: keep as the basic smoke target.
2. `scrollable`: automated native smoke covers explicit scroll handle retention; broader GPUI scroll-option parity remains tracked as partial.
3. `input`: retained text-input/textarea behavior, text-input focus/blur registration, radio IR/template/render coverage, server-routed change/focus coverage, rich text runs, and disabled checkbox/radio callback suppression are automated; rich editor and richer select/dropdown parity remain out of scope.
4. `drag_drop`: server-routed drag/drop payload regression coverage is automated; native GPUI drag simulation remains manual.
5. `tab_stop` / `focus_visible`: native render smoke covers tab-stop focus-handle retention, simulated Tab ordering, and focus-visible state reset on mouse input; full grouping/input-modality edge-case parity remains partial.
6. `image` / `svg`: source/object-fit mapping and template coverage are automated; async loading success/failure remains manual/partial.
7. `window_positioning`: hidden-window native option smoke covers the supported option path; multi-display behavior remains manual/partial.

## Refresh process

1. Update `../zed`.
2. Record `git -C ../zed rev-parse --short HEAD` at the top of this file.
3. Run `find ../zed/crates/gpui -maxdepth 3 -type f \( -path '*examples*' -o -path '*tests*' \) | sort`.
4. Add any new examples/tests to the matrix before claiming GPUI compatibility improvements.
