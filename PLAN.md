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

### Priority 1: tooltip/popover primitives

Goal: unlock anchored overlay scenarios after core form/list work.

Initial scope:

- tooltip primitive if lightweight
- popover/anchored overlay primitive only if GPUI 0.2.2 APIs support it cleanly
- focus/close lifecycle behavior
- examples and matrix updates for `examples/popover.rs` and `examples/anchor.rs`

## Ongoing maintenance while expanding primitives

Keep these current as part of feature work:

- `docs/gpui-compliance.md`: source reference, status, gaps, and verification notes
- `README.md`: supported public API and node surface
- `examples/super_demo.exs`: broad manual smoke coverage
- `docs/performance.md`: only when new measurements affect decisions

Performance guidance remains: do not add default scroll debounce, high-frequency event coalescing, or `Guppy.Window` rerender batching without measurements proving the need.

## Later work

Runtime and distribution hardening come after the primitive surface is more useful:

- close-request and owner-cleanup lifecycle hardening
- stronger native runtime failure/restart behavior
- keyed subtree diffing only if benchmarks demand it
- cross-platform strategy beyond macOS
- `rustler_precompiled` packaging once native behavior is stable enough

## Non-goals for now

- reintroducing a C shim
- claiming full GPUI compatibility without matrix evidence
- optimizing based on anecdotes instead of benchmarks
- semantic theme tokens in core IR
- packaging/precompiled artifacts before primitive behavior settles
