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
| `examples/scrollable.rs` | `examples/kanban_todo.exs`, `examples/super_demo.exs`; native scroll tests | partial | GPUI parity for every scroll option not mapped; high-frequency scroll coalescing pending | Rust scroll-axis unit test; manual kanban smoke |
| `examples/input.rs` | `examples/kanban_todo.exs`, `examples/super_demo.exs`; text input retained-state tests | partial | textarea/editor, rich input behavior, full focus semantics | Rust text-input retained-state unit test; manual example smoke |
| `examples/drag_drop.rs` | `examples/kanban_todo.exs` drag callbacks | partial | native drag payload parity, drop target model, event coalescing | manual kanban smoke; no automated native event smoke yet |
| `examples/tab_stop.rs` | text input/button/checkbox `tab_index` and `tab_stop` IR fields | partial | full GPUI tab stop traversal parity not covered | IR validation only; needs native smoke |
| `examples/image/image.rs` | `examples/style_gallery.exs`, `examples/super_demo.exs`, `test/guppy_test.exs` image template checks | partial | complete image loading states and asset pipeline parity | automated IR/template tests; manual gallery smoke |
| `examples/svg/svg.rs` | `examples/style_gallery.exs`, `examples/super_demo.exs` via `icon`/embedded image sources | partial | full SVG rendering controls and sizing parity | automated IR/template checks for icon/image; manual smoke |
| `examples/window_positioning.rs` | window options validation in `Guppy.Server` tests | partial | complete multi-display/window positioning behavior not smoke-tested | automated option validation; needs native smoke |
| `examples/active_state_bug.rs` | style states on button/checkbox/div | partial | exact active state regression not ported | IR validation only |
| `examples/anchor.rs` | none | unsupported | anchor/anchored overlay primitives | none |
| `examples/animation.rs` | none | unsupported | animation primitives | none |
| `examples/data_table.rs` | none | unsupported | grid/data-table/list primitives | none |
| `examples/focus_visible.rs` | focus/blur callbacks | partial | focus-visible styling semantics | IR validation only |
| `examples/gif_viewer.rs` | image node | partial | animated GIF controls/loading states | manual only |
| `examples/gradient.rs` | none | unsupported | gradient style primitives | none |
| `examples/grid_layout.rs` | none | unsupported | grid layout primitives | none |
| `examples/image_gallery.rs` | image node examples | partial | gallery layout primitives and loading states | manual only |
| `examples/image_loading.rs` | image node | partial | async loading/error state parity | manual only |
| `examples/layer_shell.rs` | none | out of scope | platform shell/layer APIs | none |
| `examples/list_example.rs` | none | unsupported | list/uniform-list primitive | none |
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
| `examples/text.rs` | `text` node | partial | rich text runs/layout controls incomplete | IR/template tests |
| `examples/text_layout.rs` | text style tokens | partial | advanced text layout/rich runs | IR/style validation |
| `examples/text_wrapper.rs` | text style tokens | partial | wrapping measurement parity | IR/style validation |
| `examples/tree.rs` | nested `div`/`text` IR | partial | tree-specific interaction/virtualization | template/IR tests |
| `examples/uniform_list.rs` | none | unsupported | virtualized/uniform list primitive | none |
| `examples/window.rs` | window options | partial | full GPUI window API parity | option validation tests |
| `examples/window_shadow.rs` | window decorations/background options | partial | full shadow/window-frame parity | option validation tests |
| `tests/action_macros.rs` | `actions` / `shortcuts` IR fields and native shortcut matching tests | partial | Rust macro parity is out of scope; shortcut behavior still narrow | Rust shortcut unit tests |

## First ports to harden

1. `hello_world`: keep as the basic smoke target.
2. `scrollable`: add automated native smoke around scroll state retention.
3. `input`: expand text-input behavior and focus/change event coverage.
4. `drag_drop`: automate event payload and rerender regression coverage.
5. `tab_stop`: add focus traversal smoke coverage.
6. `image` / `svg`: add asset-loading success/failure smoke coverage.
7. `window_positioning`: add hidden-window native option smoke where CI can run GPUI.

## Refresh process

1. Update `../zed`.
2. Record `git -C ../zed rev-parse --short HEAD` at the top of this file.
3. Run `find ../zed/crates/gpui -maxdepth 3 -type f \( -path '*examples*' -o -path '*tests*' \) | sort`.
4. Add any new examples/tests to the matrix before claiming GPUI compatibility improvements.
