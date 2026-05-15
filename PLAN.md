# Guppy Forward Plan

Operational rules, checks, architecture notes, and maintenance reminders live in `AGENTS.md`. This file tracks prospective work only. Current behavior is documented in `README.md`, `docs/gpui-compliance.md`, examples, and commit history; deferred primitive ideas live in `docs/future-primitives.md`. Do not keep large done-task checklists here.

## Planning rules

- Prefer stabilization, hardening, docs/examples, and compliance maintenance over new surface area.
- Do not add a new primitive or broaden an existing primitive without a concrete app/example need.
- Use TDD for regressions and behavior changes; add measurement before performance changes.
- Keep commits small and update docs/examples/benchmarks in the same change that alters behavior.
- Do not preserve old internal shapes for compatibility; this project is unreleased. DO NOT deprecate.

## Priority 0: native hardening follow-ups from code review

### Row-control identity keys must be collision-safe

Context: row-control lookup/focus identity currently uses delimiter-joined strings while row/control ids are arbitrary binaries. Different valid `(row_id, control_id)` pairs can collide and reuse the wrong focus handle or event context.

- [x] Add a Rust regression covering distinct row/control id pairs that collide under the current delimiter/string formatting.
- [x] Replace row-control lookup state with a typed tuple/struct key instead of delimiter-joined strings.
- [x] Replace retained row-control focus ids with collision-safe encoding or a typed retained-key conversion at the map boundary.
- [x] Decide whether Elixir IR should reject control characters in ids for GPUI/debug-output hygiene; do not rely on such validation for correctness. (Decision: do not add an id-character restriction for correctness; use typed/encoded native keys.)

### Native numeric decode must reject pathological and non-finite values

Context: native f32 decode still formats BigInteger values through decimal strings, and some geometry/table/canvas validators check ranges without first requiring finite values.

- [x] Add native decode regressions for huge BigInteger f32 fields and non-finite float values across canvas geometry, canvas line/interval/radius, popover/animation values, and data-table `{:px, value}` widths.
- [x] Remove BigInteger decimal string formatting from f32 decode; accept only safely bounded numeric conversions or reject oversized integer terms.
- [x] Require `value.is_finite()` for every native f32 input before range checks.
- [x] Mirror any semantic change in Elixir validation/docs if public IR accepts a value that native now rejects. (Elixir validation now rejects numeric values outside the native f32-safe integer/float bounds before native decode.)

### Prefer owned render-closure state before Arc

Context: some renderers create fresh `Arc` values only to move data into a single GPUI `list` render closure. Own those values directly unless sharing or retained native state actually requires reference counting.

- [ ] Replace `Arc<[VisibleTreeItem]>` in tree rendering with a closure-owned `Vec<VisibleTreeItem>` unless GPUI lifetime constraints prove otherwise.
- [ ] Replace row-control render-state `Arc<HashMap<...>>` with a closure-owned `HashMap` unless sharing becomes necessary.
- [ ] Audit similar fresh-per-render `Arc` uses and keep only the ones needed for retained/shared IR ownership.

### Data-table row rendering should avoid avoidable per-cell scans

Context: row rendering currently scans `row.cells` for each column, making rendered rows `O(columns * cells)`.

- [ ] Add a small renderer/helper regression or benchmark fixture for wide rows to lock intended column ordering/lookup behavior.
- [ ] Decode or precompute data-table cells in column order, or build a per-row lookup once when rendering wide rows.
- [ ] Keep missing-cell behavior unchanged and covered.

## Priority 4: harden existing primitives only when a real gap appears

These remain deferred until a concrete example, bug report, or compliance target justifies them.

- [ ] Select/popover/overlay edge cases: nested overlays, richer option-list positioning, focus/close lifecycle, and keyboard behavior.
- [ ] Data-table/tree interactions: keyboard navigation, focus-visible behavior, accessibility semantics, pinned headers/columns, resize/reorder, and stateful cell controls.
- [ ] Text/editor parity: richer text layout, syntax/editor semantics, undo/redo wiring for native text controls, and advanced selection behavior.
- [ ] Generic list row controls: text-editor or overlay-backed controls inside virtual rows after anchor and retained lifecycle are tested separately.
- [ ] Canvas/custom painting: path/line/text/image commands, retained drawing resources, and per-command hit testing only after a real visual need and measurement.
- [ ] Gradient/animation styling: multi-stop/radial/conic/text/border gradients or broader animation primitives only with an example need.
- [ ] Menus: dock menus, element-local/context menus, system Services submenu, or synchronous dynamic enablement only for a real app.
