# GPUI Compliance Matrix

Source of truth: `../zed/crates/gpui` at upstream reference `78c889c21d`.

Statuses:

- `supported`: Guppy has a comparable primitive and an example or automated coverage.
- `partial`: Guppy can express the core scenario but is missing GPUI details.
- `unsupported`: Guppy does not yet expose the needed primitive.
- `out of scope`: Not planned for the current Elixir-owned IR subset.

| GPUI source | Guppy port/coverage | Status | Missing primitives / gaps | Verification |
| --- | --- | --- | --- | --- |
| `examples/hello_world.rs` | `examples/hello_world.exs`, `test/guppy_test.exs` template checks | supported | none known for static text/window open | automated IR/template tests; manual example smoke |
| `examples/scrollable.rs` | `examples/kanban_todo.exs`, `examples/super_demo.exs`; native scroll tests | partial | GPUI parity for every scroll option not mapped; no default high-frequency coalescing planned from current measurements | Rust scroll-axis unit test; GPUI render smoke retains explicit scroll handles; manual kanban smoke |
| `examples/input.rs` | `examples/kanban_todo.exs`, `examples/super_demo.exs`; text input, textarea, and radio form-control tests | partial | rich editor behavior, select/dropdown primitive deferred pending popover/anchored overlays, and full focus semantics | Rust retained-state/radio unit tests; ExUnit IR/template/native hidden-window coverage; manual example smoke |
| `examples/drag_drop.rs` | `examples/kanban_todo.exs`, `examples/super_demo.exs` drag/drop callbacks | partial | native drag payload parity and drop target model are narrower than GPUI; no default event coalescing planned from current measurements | Elixir server routing tests cover drag_start/drag_move/drop payloads; manual kanban smoke |
| `examples/tab_stop.rs` | text input/button/checkbox/div `tab_index` and `tab_stop` IR fields | partial | full GPUI tab traversal ordering parity not covered | IR validation; GPUI render smoke retains focus handle for tab-stop div |
| `examples/image/image.rs` | `examples/style_gallery.exs`, `examples/super_demo.exs`, `test/guppy_test.exs` image template checks | partial | complete async image loading states and asset pipeline parity | automated IR/template tests; Rust image source/object-fit mapping tests; manual gallery smoke |
| `examples/svg/svg.rs` | `examples/style_gallery.exs`, `examples/super_demo.exs` via `icon`/embedded image sources | partial | full SVG rendering controls and sizing parity | automated IR/template checks for icon/image; Rust embedded image-source mapping test; manual smoke |
| `examples/window_positioning.rs` | window options validation in `Guppy.Server` tests; hidden native window smoke | partial | complete multi-display/window positioning behavior not covered in CI | automated option validation; hidden-window native smoke with bounds/min-size/kind/decorations/background |
| `examples/active_state_bug.rs` | style states on button/checkbox/div | partial | exact active state regression not ported | IR validation only |
| `examples/anchor.rs` | none | unsupported | anchor/anchored overlay primitives | none |
| `examples/animation.rs` | none | unsupported | animation primitives | none |
| `examples/data_table.rs` | `uniform_list` text-row primitive covers only simple repeated rows | partial | grid/data-table layout, columns, cells, and virtualization semantics beyond simple rows | IR/template/native smoke for `uniform_list`; no data-table port |
| `examples/focus_visible.rs` | focus/blur callbacks | partial | focus-visible styling semantics | IR validation only |
| `examples/gif_viewer.rs` | image node | partial | animated GIF controls/loading states | manual only |
| `examples/gradient.rs` | none | unsupported | gradient style primitives | none |
| `examples/grid_layout.rs` | none | unsupported | grid layout primitives | none |
| `examples/image_gallery.rs` | image node examples | partial | gallery layout primitives and loading states | manual only |
| `examples/image_loading.rs` | image node | partial | async loading/error state parity | manual only |
| `examples/layer_shell.rs` | none | out of scope | platform shell/layer APIs | none |
| `examples/list_example.rs` | `Guppy.IR.uniform_list/2`, `<uniform_list />`, `examples/super_demo.exs` | partial | variable-height `list`/`ListState` behavior and custom scrollbar parity | ExUnit IR/template/native hidden-window coverage; manual super_demo smoke |
| `examples/mouse_pressure.rs` | mouse event callbacks | partial | pressure payload and native event parity | none |
| `examples/move_entity_between_windows.rs` | none | unsupported | multi-window entity migration semantics | none |
| `examples/on_window_close_quit.rs` | `Guppy.close_window/2` | partial | close-request event lifecycle parity | tests cover close API, not native close-request event |
| `examples/opacity.rs` | style token `{:opacity, value}` | partial | exact visual parity not smoke-tested | IR/style validation |
| `examples/ownership_post.rs` | `Guppy.Server` owner tracking | partial | direct GPUI entity ownership scenario not ported | server tests |
| `examples/painting.rs` | none | unsupported | custom painting/canvas | none |
| `examples/paths_bench.rs` | none | out of scope | GPUI internal path benchmark | none |
| `examples/pattern.rs` | none | unsupported | pattern painting | none |
| `examples/popover.rs` | none | unsupported | popover/anchored overlay primitives | none |
| `examples/set_menus.rs` | none | unsupported | menu APIs | none |
| `examples/shadow.rs` | style tokens `shadow_sm/md/lg` | partial | complete shadow controls/visual parity | IR/style validation |
| `examples/testing.rs` | ExUnit/Rust tests | partial | GPUI test API parity not exposed | existing test suites |
| `examples/text.rs` | `text` node; practical multiline input via `textarea` | partial | rich text runs/layout controls and full editor parity incomplete | IR/template tests; textarea example/manual smoke |
| `examples/text_layout.rs` | text style tokens | partial | advanced text layout/rich runs | IR/style validation |
| `examples/text_wrapper.rs` | text style tokens | partial | wrapping measurement parity | IR/style validation |
| `examples/tree.rs` | nested `div`/`text` IR; simple repeated text rows via `uniform_list` | partial | tree-specific interaction/virtualization and arbitrary row renderers | template/IR tests |
| `examples/uniform_list.rs` | `Guppy.IR.uniform_list/2`, `<uniform_list />`, `examples/super_demo.exs` | partial | only text-row items are supported; arbitrary per-row IR renderers not exposed | ExUnit IR/template/native hidden-window coverage; manual super_demo smoke |
| `examples/window.rs` | window options | partial | full GPUI window API parity | option validation tests |
| `examples/window_shadow.rs` | window decorations/background options | partial | full shadow/window-frame parity | option validation tests |
| `tests/action_macros.rs` | `actions` / `shortcuts` IR fields and native shortcut matching tests | partial | Rust macro parity is out of scope; shortcut behavior still narrow | Rust shortcut unit tests |

## First ports to harden

1. `hello_world`: keep as the basic smoke target.
2. `scrollable`: automated native smoke covers explicit scroll handle retention; broader GPUI scroll-option parity remains tracked as partial.
3. `input`: retained text-input/textarea behavior, radio IR/template/render coverage, and server-routed change/focus coverage are automated; rich editor and select/dropdown parity remain out of scope.
4. `drag_drop`: server-routed drag/drop payload regression coverage is automated; native GPUI drag simulation remains manual.
5. `tab_stop`: native render smoke covers tab-stop focus-handle retention; full traversal ordering remains partial.
6. `image` / `svg`: source/object-fit mapping and template coverage are automated; async loading success/failure remains manual/partial.
7. `window_positioning`: hidden-window native option smoke covers the supported option path; multi-display behavior remains manual/partial.

## Refresh process

1. Update `../zed`.
2. Record `git -C ../zed rev-parse --short HEAD` at the top of this file.
3. Run `find ../zed/crates/gpui -maxdepth 3 -type f \( -path '*examples*' -o -path '*tests*' \) | sort`.
4. Add any new examples/tests to the matrix before claiming GPUI compatibility improvements.
