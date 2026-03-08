# BridgeView refactor plan

This plan assumes **no backwards-compatibility constraints**.
If the current `BridgeView` shape gets in the way, replace it outright.

## Goals

- keep full-tree replacement as the only render update model
- make identity/state retention explicit instead of incidental
- split rendering, interactivity wiring, and native event encoding into separate modules
- make adding a new IR node or event a localized change instead of a file-wide edit
- keep native-side retained state pruned every render
- make event and focus behavior mechanically testable

## Immediate target architecture

### 1. Separate runtime state from rendering

Create a dedicated retained-state type, owned by the view:

- `BridgeRetainedState`
  - `scroll_handles`
  - `focus_handles`
  - `focus_subscriptions`
  - `text_inputs`

and a separate per-render collector:

- `RenderPassState`
  - `live_scroll_ids`
  - `live_focus_ids`
  - `live_text_input_ids`
  - `registered_focus_callbacks`

That makes pruning an explicit post-render phase instead of something mixed into traversal.

### 2. Split node rendering by IR kind

Move rendering into dedicated modules:

- `bridge_view/mod.rs`
- `bridge_view/render_pass.rs`
- `bridge_view/render_div.rs`
- `bridge_view/render_text.rs`
- `bridge_view/render_scroll.rs`
- `bridge_view/render_text_input.rs`
- `bridge_view/style.rs`
- `bridge_view/events.rs`
- `bridge_view/identity.rs`

Each render module should accept:

- a small node-specific input struct
- a mutable render pass context
- `window`
- `cx`

No module should know about every event or every style token.

### 3. Split event encoding from event attachment

Right now event attachment closures directly call C shims.
Replace that with an internal event API:

- `NativeEventEmitter::click(...)`
- `NativeEventEmitter::hover(...)`
- `NativeEventEmitter::focus(...)`
- etc.

That allows:

- centralized payload shaping
- centralized throttling/coalescing for high-frequency events later
- easier native event tests

### 4. Normalize identity handling

Make node identity a first-class type:

- `NodeIdentity`
  - explicit id
  - generated fallback id
  - path

Rendering code should stop formatting raw strings ad hoc.
All retained-state lookups should go through the same identity helper.

### 5. Make focus wiring declarative

Introduce a focus config type for interactive nodes:

- whether a focus handle is needed
- whether the node is focusable
- tab-stop policy
- tab index
- focus callback ids
- blur callback ids

Then have one place that:

- allocates/reuses focus handles
- registers focus subscriptions
- prunes dead focus state

### 6. Untangle div rendering

`div` is currently doing too much:

- layout
- style
- focus
- keyboard activation
- shortcut dispatch
- pointer events
- drag/drop
- scroll anchoring
- retained scroll state
- overlay priority

Split it into ordered phases:

1. identity
2. retained-state preparation
3. child rendering
4. base style application
5. focus/scroll attachment
6. interactive behavior attachment
7. state-style refinement
8. deferred/overlay wrapping

## Near-term cleanup tasks

### Phase 1

- move `apply_div_style` and `apply_refinement_style` into `bridge_view/style.rs`
- move native event helpers and modifier conversion into `bridge_view/events.rs`
- move `node_id` and future identity helpers into `bridge_view/identity.rs`
- add unit tests for style application and shortcut matching

### Phase 2

- introduce `BridgeRetainedState`
- introduce `RenderPassState`
- move pruning into an explicit `finish_render_pass()` step
- remove any remaining ad hoc retained-state access from individual node renderers

### Phase 3

- split node renderers into per-kind modules
- replace large match arms with node-dispatch methods
- make button semantics a native IR node on the Rust side instead of lowering into a giant div shape inside the same file

### Phase 4

- introduce optional event coalescing for `mouse_move`, `scroll_wheel`, and `drag_move`
- make coalescing policy explicit per event kind
- add focused regression tests for event ordering and suppression

### Phase 5

- add a small Rust-side test harness for IR decode -> render dispatch decisions
- add tests for retained-state reuse and pruning across rerenders
- add tests for focus callback replacement/removal across rerenders

## Non-goals for the refactor

- preserving the old file structure
- preserving the current internal helper names
- keeping the current `div` renderer monolithic
- adding compatibility shims for old node/state assumptions

## Exit criteria

The refactor is done when:

- `bridge_view.rs` is no longer a giant everything-file
- retained state is pruned by design every render
- adding a new IR node touches a small, obvious set of files
- adding a new native event does not require editing rendering logic all over the place
- focus/scroll/text-input retention rules are explicit and testable
- `cargo clippy --all-targets -- -D warnings` stays clean
