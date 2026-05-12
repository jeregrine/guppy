# Guppy Forward Plan

This is the active forward-looking plan. Completed baseline architecture, Rustler migration, benchmark/performance hardening, GPUI compliance matrix setup, initial GPUI example hardening, and README surface-contract work are historical context only and are no longer planned work.

## Current standard

Guppy should be treated as a serious Elixir/GPUI bridge, not a demo. Keep the bar at:

- TDD-driven development
- small, reviewable changes
- one clear Rustler NIF boundary
- no bespoke C shim
- native tests green
- measurable performance decisions
- explicit GPUI compatibility tracking
- examples that double as regression coverage

## Required checks

Before and after meaningful changes, keep this green:

```sh
scripts/check
```

That covers:

```sh
mix test
mix format --check-formatted
cd native/guppy_nif && cargo test
cd native/guppy_nif && cargo clippy --all-targets -- -D warnings
cd native/guppy_nif && cargo fmt --check
```

For native/runtime changes, also run:

```sh
mix guppy.native.build
mix run examples/hello_world.exs
```

For performance-sensitive changes, run benchmarks or probes from `docs/performance.md` before optimizing.

## Active phase: primitive expansion

The next useful work is adding missing high-value primitives that are already visible in the GPUI compliance matrix. Do not add widgets casually: each primitive must be implemented end-to-end and backed by tests, docs, examples, and matrix updates.

### Primitive definition of done

Every new primitive needs:

- Elixir IR helper and validation in `lib/guppy/ir.ex`
- template/compiler support in `Guppy.Component` / `~G` when author-facing
- Rust ETF decode in `native/guppy_nif/src/ir.rs`
- native render implementation under `native/guppy_nif/src/bridge_view/`
- native event behavior if interactive
- retained-state behavior if stateful
- ExUnit coverage for IR/template/server behavior
- Rust coverage for decode/render/event behavior
- example or compliance-port coverage
- `README.md` supported-surface update
- `docs/gpui-compliance.md` matrix update

### Completed in primitive expansion: textarea

Guppy now has a practical multiline `textarea` primitive without claiming full Zed editor parity.

Delivered scope:

- `Guppy.IR.textarea/2`
- `textarea` template tag
- value, placeholder, disabled, style, tab index, and change events
- retained native state keyed by stable node identity through the shared text input implementation
- example coverage in `examples/super_demo.exs`
- `README.md` supported-surface update
- `docs/gpui-compliance.md` matrix update for input/text-related gaps

Still out of scope:

- rich text runs
- syntax highlighting
- collaborative/editor entity semantics
- full Zed editor parity

### Completed in primitive expansion: radio

Guppy now has a minimal radio option primitive for Elixir-owned form state.

Delivered scope:

- `Guppy.IR.radio/4`
- `radio` template tag
- label, value, checked, disabled, style, tab index, and change/focus/blur events
- keyboard activation through Enter/Space
- example coverage in `examples/super_demo.exs`
- `README.md` supported-surface update
- `docs/gpui-compliance.md` matrix update for form-control gaps

Still out of scope:

- a retained native radio-group owner; Elixir remains the group state owner
- select/dropdown controls

### Deferred in primitive expansion: select/dropdown

GPUI 0.2.2 does not expose a simple select/dropdown primitive in the examples or public element surface comparable to text input or checkbox. A native-quality select needs anchored overlay/popover behavior first; implementing a fake always-expanded select would add API surface without matching the intended interaction model.

Deferred scope:

- select/dropdown primitive
- option list overlay positioning
- outside-click close lifecycle
- keyboard navigation within the opened option list

Revisit after tooltip/popover/anchored-overlay support exists.

### Completed in primitive expansion: uniform text list

Guppy now has a focused `uniform_list` primitive for large lists of text rows with stable item ids. It wraps GPUI's `uniform_list` for lazy visible-range rendering while keeping Elixir as the owner of item data and selection state.

Delivered scope:

- `Guppy.IR.uniform_list/2`
- `uniform_list` template tag
- stable item ids and labels
- list-level style and item-row style
- item click routing back to the owning Elixir process using stable item identity
- GPUI `uniform_list` native render path
- example coverage in `examples/super_demo.exs`
- `README.md` supported-surface update
- `docs/gpui-compliance.md` matrix update for list/uniform-list gaps

Still out of scope:

- arbitrary per-item child IR renderers
- variable-height `list`/`ListState` parity
- data-table/grid parity
- row selection ownership beyond normal Elixir event handling

### Completed in primitive expansion: tooltip

Guppy now supports simple tooltip text on `div` nodes via GPUI's native tooltip mechanism.

Delivered scope:

- `tooltip` option on `Guppy.IR.div/2`
- `tooltip` template attribute on `<div>`
- native GPUI tooltip rendering for non-disabled divs
- example coverage in `examples/super_demo.exs`
- `README.md` supported-surface update
- `docs/gpui-compliance.md` matrix update for tooltip/popover gaps

Still out of scope:

- arbitrary tooltip child IR
- hoverable tooltip content
- anchored popovers / overlay close lifecycle

### Completed in primitive expansion: popover

Guppy now has a minimal Elixir-owned popover primitive backed by GPUI deferred anchored layers.

Delivered scope:

- `Guppy.IR.popover/4`
- `popover` template tag
- trigger label, open flag, children, trigger click callback, and outside-click close callback
- GPUI `deferred(anchored(...))` native render path
- example coverage in `examples/super_demo.exs`
- `README.md` supported-surface update
- `docs/gpui-compliance.md` matrix update for popover/anchor gaps

Still out of scope:

- nested popover parity
- retained/native overlay owner state; Elixir owns open/closed state
- full select/dropdown built on top of popover

### Completed in primitive expansion: compliance sweep

The compliance matrix now has rows for every GPUI example/test source at `../zed/crates/gpui` reference `78c889c21d`, and the remaining unsupported/partial rows are either backed by focused smoke coverage, explicitly deferred, or marked out of scope for the current Elixir-owned IR architecture.

Deferred primitive areas:

- animation lifecycle primitives
- gradient style primitives
- grid layout primitives
- custom painting/canvas and pattern painting
- menu APIs
- richer text/rich editor parity
- full data-table/tree virtualization parity
- full select/dropdown parity on top of richer popover behavior

### Completed in runtime hardening: native request containment and lifecycle telemetry

Runtime hardening is complete enough to unblock distribution planning.

Delivered scope:

- owner process cleanup routes native close-window requests through the same server-mediated native request path as explicit close calls, preserving `[:guppy, :native, :request]` telemetry
- owner cleanup has automated coverage
- known and unknown native close events have event-route telemetry coverage
- native window close attempts emit `window_close_requested` before `window_closed`, so owners can observe close intent before server cleanup
- server-mediated native requests contain native wrapper crashes/exits and report `{:error, :runtime_unavailable}` instead of crashing `Guppy.Server`

Current runtime decisions:

- a full native runtime restart/reinitialization strategy is deferred; hard NIF/runtime failures are not safely restartable inside the same BEAM process today
- keyed subtree diffing remains deferred until benchmarks show full-tree replacement is the bottleneck
- cross-platform behavior beyond macOS remains a distribution/support strategy item, not a blocker for the current local source build

## Ongoing maintenance while expanding primitives

Keep these current as part of feature work:

- `docs/gpui-compliance.md`: source reference, status, gaps, and verification notes
- `README.md`: supported public API and node surface
- `examples/super_demo.exs`: broad manual smoke coverage
- `docs/performance.md`: only when new measurements affect decisions

Performance guidance remains: do not add default scroll debounce, high-frequency event coalescing, or `Guppy.Window` rerender batching without measurements proving the need.

## Active next phase: distribution hardening

Distribution hardening is the next major phase.

Started scope:

- source-build targets and current macOS-first assumptions are documented in `docs/distribution.md`
- precompiled artifact gates and the initial target matrix are documented in `docs/distribution.md`

Remaining scope:

- add `rustler_precompiled` only after source builds remain green and artifact naming/loading is clear
- CI artifact validation for supported targets
- release-process documentation for native artifact production
- preserve local source builds as the fallback path

## Non-goals for now

- reintroducing a C shim
- claiming full GPUI compatibility without matrix evidence
- optimizing based on anecdotes instead of benchmarks
- semantic theme tokens in core IR
- packaging/precompiled artifacts before primitive behavior settles
