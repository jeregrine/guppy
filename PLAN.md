# Guppy Hardening Plan

This is the active forward-looking plan. Completed baseline, Rustler migration, benchmark setup, GPUI matrix, and README surface-contract work have been removed from the required-work list.

## Current standard

Guppy should be treated as a serious Elixir/GPUI bridge, not a demo. Keep the bar at:

- TDD-driven development
- small commits with clear descriptions of what was done and why
- one clear Rustler NIF boundary
- no bespoke C shim
- native tests green
- measurable performance
- explicit GPUI compatibility tracking
- examples that double as regression coverage

## Current state

Guppy now has:

- Elixir-owned UI state
- tree IR render output
- Rustler-owned NIF exports and BEAM interop
- no `native/guppy_nif/c_src/` implementation
- GPUI native rendering through Rust
- native events routed back through Rustler to BEAM owners
- retained native state for focus, scroll, and text input
- a local full-suite check command: `scripts/check`
- Benchee benchmarks: `bench/guppy_bench.exs`
- performance notes: `docs/performance.md`
- GPUI compatibility matrix: `docs/gpui-compliance.md`
- supported-surface contract in `README.md`

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

For performance-sensitive changes, run:

```sh
mix run bench/guppy_bench.exs
mix run bench/guppy_bench.exs --native
```

## Phase 1: performance hardening

Benchmarks exist. Use them before optimizing.

Current known benchmark coverage:

- `~G` template render cost for 10/100/1_000 nodes
- IR validation cost
- ETF encode/decode proxy cost
- `Guppy.render/2` hidden-window native request latency
- runtime telemetry for direct NIF call latency, native request latency, native event routing, and `Guppy.Window` rerender latency
- native-side performance counters for Rust boundary IR/options encode-decode timing
- event-to-rerender proxy latency
- `Guppy.Window` routed event-to-rerender latency and repeated routed-event pressure through native-shaped server event delivery
- high-frequency event payload pressure: mouse move, drag move, scroll wheel
- kanban scenario: initial render, add card, move card, edit card, scroll interaction
- debug and release native benchmark snapshots documented in `docs/performance.md`
- prevalidated IR wrapper for trusted/static trees to skip repeated Elixir validation

Remaining performance work:

1. Add a GPUI-generated end-to-end event-to-rerender benchmark using actual native event delivery.
2. Coalesce high-frequency native events where measurement shows pressure:
   - mouse move
   - drag move
   - scroll wheel
3. Batch or debounce `Guppy.Window` rerenders where measurement shows repeated render pressure.

## Phase 2: GPUI compliance hardening

The matrix exists at `docs/gpui-compliance.md`. Keep it current against `../zed/crates/gpui` before claiming compatibility improvements.

Initial examples to harden first:

- `hello_world`
- `scrollable`
- `input`
- `drag_drop`
- `tab_stop`
- `image` / `svg`
- `window_positioning`

For each port or compatibility improvement, track:

- source path and upstream commit/reference
- Guppy port path
- status: supported / partial / unsupported / intentionally out of scope
- missing primitives
- automated smoke coverage if possible
- manual verification notes if not automatable yet

Known likely gaps:

- uniform list / virtualized list
- popover / anchored overlays
- editor / textarea
- custom painting / canvas
- animation
- menus
- advanced text layout and rich text runs
- grid/data-table parity

## Phase 3: supported primitive expansion

Do not add more widgets casually. Every new primitive needs:

- Elixir IR validation
- Rust decode
- render implementation
- event behavior if interactive
- retained-state behavior if applicable
- unit/integration tests
- example or compliance-port coverage
- matrix update in `docs/gpui-compliance.md`

Priority order:

1. textarea/editor
2. radio/select primitives
3. list / uniform-list primitive
4. tooltip/popover primitives

## Phase 4: runtime hardening

After performance/compliance work has sharper evidence:

- consider keyed subtree diffing if benchmarks demand it
- strengthen supervision/restart behavior for native runtime failures
- improve native event lifecycle coverage, especially close-request and owner cleanup cases
- expand cross-platform strategy beyond macOS

## Phase 5: distribution and precompiled artifacts

Add `rustler_precompiled` only after the Rustler boundary and native behavior are stable enough to package.

Exit criteria:

- local source builds still work
- precompiled loading works on supported targets
- release process documents how native artifacts are produced
- CI builds and validates artifacts before publishing

## Non-goals for now

- adding more widgets before performance/compliance hardening
- reintroducing a C shim
- claiming full GPUI compatibility without matrix evidence
- optimizing based on anecdotes instead of benchmarks
- adding `rustler_precompiled` before the native boundary is stable
