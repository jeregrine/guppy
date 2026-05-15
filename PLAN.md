# Guppy Forward Plan

Operational rules, checks, architecture notes, and maintenance reminders live in `AGENTS.md`. This file tracks prospective work only. Current behavior is documented in `README.md`, `docs/gpui-compliance.md`, examples, and commit history; deferred primitive ideas live in `docs/future-primitives.md`. Do not keep large done-task checklists here.

## Planning rules

- Prefer stabilization, hardening, docs/examples, and compliance maintenance over new surface area.
- Do not add a new primitive or broaden an existing primitive without a concrete app/example need.
- Use TDD for regressions and behavior changes; add measurement before performance changes.
- Keep commits small and update docs/examples/benchmarks in the same change that alters behavior.
- Do not preserve old internal shapes for compatibility; this project is unreleased. DO NOT deprecate.

## Priority 1: native code-review cleanup follow-ups

### Keep timeout/failure semantics mutation-safe

Context: native/main-thread requests are timeout-aware, but enqueue/scheduling edge cases still need hardening.

- [ ] Ensure a request that is sent to the native queue but fails drain scheduling cannot mutate state later after the caller receives `runtime_unavailable`/`native_timeout`.
- [ ] Make native duplicate `view_id` opens return the existing `duplicate_view_id` error instead of overwriting the tracked window handle.
- [ ] Make `RequestDeadline::after/1` robust for very large `timeout_ms` values by using checked/saturating `Instant` arithmetic instead of panic-prone addition.

### Tighten text-input edge cases and panic surfaces

Context: retained text input is intentionally first-pass editor behavior, but correctness bugs and production panics should be removed before expanding editor parity.

- [ ] Fix IME `replace_and_mark_text_in_range` selection conversion for non-ASCII text before the replacement range; selected ranges are UTF-16-relative to marked text and must not be converted against the whole buffer before offsetting.
- [ ] Replace the production `line.layout.paint(...).unwrap()` in text-input painting with non-panicking error handling unless GPUI guarantees infallibility.

### Reduce remaining hot-path render allocations

Context: the previous data-table cleanup removed per-cell scans, but rendered rows still build per-row lookup state.

- [ ] Avoid allocating a `HashMap` for every visible data-table row render; decode or precompute cells in column order while preserving missing-cell behavior.

### Consolidate duplicated native decode/style code

Context: native decode/render helpers have grown across primitives and should be de-slopped before adding more surface area.

- [ ] Consolidate duplicate ETF map/list/string/field helper patterns across `ir.rs`, `menu.rs`, and `window_options.rs` without weakening context-specific error messages or validation.
- [ ] Reduce duplication between `apply_div_style` and `apply_refinement_style`; keep ordered style-op semantics and document which ops are deliberately unsupported by refinement styling.

### Split root render dispatch once renderer APIs settle

Context: `RenderPass::render_node` is a large central dispatch that now knows every renderer's spec shape.

- [ ] Refactor `RenderPass::render_node` toward smaller per-kind dispatch helpers or renderer-owned spec builders without changing behavior.

## Priority 4: harden existing primitives only when a real gap appears

These remain deferred until a concrete example, bug report, or compliance target justifies them.

- [ ] Select/popover/overlay edge cases: nested overlays, richer option-list positioning, focus/close lifecycle, and keyboard behavior.
- [ ] Data-table/tree interactions: keyboard navigation, focus-visible behavior, accessibility semantics, pinned headers/columns, resize/reorder, and stateful cell controls.
- [ ] Text/editor parity: richer text layout, syntax/editor semantics, undo/redo wiring for native text controls, and advanced selection behavior.
- [ ] Generic list row controls: text-editor or overlay-backed controls inside virtual rows after anchor and retained lifecycle are tested separately.
- [ ] Canvas/custom painting: path/line/text/image commands, retained drawing resources, and per-command hit testing only after a real visual need and measurement.
- [ ] Gradient/animation styling: multi-stop/radial/conic/text/border gradients or broader animation primitives only with an example need.
- [ ] Menus: dock menus, element-local/context menus, system Services submenu, or synchronous dynamic enablement only for a real app.
