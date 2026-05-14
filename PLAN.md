# Guppy Forward Plan

Operational rules, checks, architecture notes, and maintenance reminders live in `AGENTS.md`. This file tracks prospective work only. Completed primitive scopes are documented in `docs/future-primitives.md`, `docs/gpui-compliance.md`, examples, and commit history; do not keep large done-task checklists here.

## Planning rules

- Prefer stabilization, hardening, docs/examples, and compliance maintenance over new surface area.
- Do not add a new primitive or broaden an existing primitive without a concrete app/example need.
- Use TDD for regressions and behavior changes; add measurement before performance changes.
- Keep commits small and update docs/examples/benchmarks in the same change that alters behavior.
- Do not preserve old internal shapes for compatibility; this project is unreleased.

## Priority 1: release/stability hardening

Goal: keep the current feature surface boring, repeatable, and shippable.

- Keep `scripts/check`, `mix compile --force`, and macOS source-build paths green.
- Run and fix `scripts/clean_install_load_test`, `scripts/package_smoke`, and `mix hex.build --unpack --output /tmp/guppy-hex-unpack` before any release/distribution claim.
- Smoke the main examples after behavior changes: `hello_world`, `super_demo`, `kanban_todo`, `style_gallery`, `list_row_controls`, `menu_demo`, `data_table_tree`, and `canvas_pattern`.
- Keep `README.md`, `AGENTS.md`, `docs/gpui-compliance.md`, `docs/distribution.md`, and `docs/performance.md` current when behavior or support claims change.
- Add small regression tests for bugs found by real examples before refactoring around them.

## Priority 2: native cleanup / de-slopification pass

Goal: reduce accidental complexity from the recent primitive push without changing public behavior.

- Establish a before snapshot with `scripts/check`, `mix run bench/guppy_bench.exs`, `MIX_ENV=prod mix run examples/stress_test.exs`, and `Guppy.native_performance_counters/0` where relevant.
- Audit exceptionally large files and split them only where logical boundaries are clear and behavior stays easy to trace. Likely candidates: native IR decode/types/tests (`native/guppy_nif/src/ir.rs`), NIF entrypoints/event encoding (`native/guppy_nif/src/lib.rs`), Elixir IR helpers/validation (`lib/guppy/ir.ex`), template parsing/compilation (`lib/guppy/component/compiler.ex`), and oversized native/test modules.
- Audit `native/guppy_nif/src/ir.rs` for duplicated decode/validation helpers, op-specific field checks, avoidable string conversions, and places that can share stricter helper functions; consider splitting by IR type families only if it reduces coupling.
- Audit `native/guppy_nif/src/bridge_view/` for needless clones/allocations in render paths, especially command vectors, style lists, callback ids, node identities, semantic event payloads, and row/canvas/list state handoff.
- Consolidate duplicated color/style conversion paths across gradients, canvas, and regular style ops without weakening validation.
- Prefer `Arc<[T]>`, borrowed helpers, or smaller owned structs where measurement or review shows repeated full-tree replacement cost; do not cargo-cult lifetime complexity.
- Add focused Rust/ExUnit regression tests before each cleanup when behavior could change, and update benchmarks if the measured hot path changes.

## Priority 3: documentation, examples, and compliance polish

Goal: make the current API understandable and keep support claims honest.

- Trim duplicated or stale prose between `README.md`, `docs/future-primitives.md`, `docs/gpui-compliance.md`, and examples.
- Keep `docs/gpui-compliance.md` aligned with the actual `gpui = 0.2.2` surface, not newer local upstream APIs.
- Make example launch behavior and timeout expectations obvious for automated/manual smoke runs.
- Keep `docs/performance.md` updated with stress-test interpretation, native counter notes, and benchmark snapshots after meaningful changes.

## Priority 4: harden existing primitives only when a real gap appears

These are likely next gaps, ordered by expected product value. Start one only with a concrete example, bug report, or compliance target.

1. **Select/popover/overlay edge cases**: nested overlays, richer option-list positioning, focus/close lifecycle, and keyboard behavior.
2. **Data-table/tree interactions**: keyboard navigation, focus-visible behavior, accessibility semantics, pinned headers/columns, resize/reorder, and stateful cell controls.
3. **Text/editor parity**: richer text layout, syntax/editor semantics, undo/redo wiring for native text controls, and advanced selection behavior.
4. **Generic list row controls**: text-editor or overlay-backed controls inside virtual rows after anchor and retained lifecycle are tested separately.
5. **Canvas/custom painting**: path/line/text/image commands, retained drawing resources, and per-command hit testing only after a real visual need and measurement.
6. **Gradient/animation styling**: multi-stop/radial/conic/text/border gradients or broader animation primitives only with an example need.
7. **Menus**: dock menus, element-local/context menus, system Services submenu, or synchronous dynamic enablement only for a real app.

## Priority 5: distribution/precompiled artifacts

Goal: ship only validated artifacts.

- Keep source builds as the default until CI has release artifacts and checksums.
- Do not expand `RustlerPrecompiled` targets beyond validated build/load coverage.
- Before public release claims, run the full distribution suite from `AGENTS.md` and update `docs/distribution.md` with exact results and limitations.
