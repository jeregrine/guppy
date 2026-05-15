# Guppy Forward Plan

Operational rules, checks, architecture notes, and maintenance reminders live in `AGENTS.md`. This file tracks prospective work only. Current behavior is documented in `README.md`, `docs/gpui-compliance.md`, examples, and commit history.

## Planning rules

- Prefer stabilization, hardening, docs/examples, and compliance maintenance over new surface area.
- Do not add a new primitive or broaden an existing primitive without a concrete app/example need.
- Use TDD for regressions and behavior changes; add measurement before performance changes.
- Keep commits small and update docs/examples/benchmarks in the same change that alters behavior.
- Do not preserve old internal shapes for compatibility; this project is unreleased. DO NOT deprecate.

## Priority 1: GPUI style-surface compatibility

Concrete gap found while building `examples/markdownview.exs`: GPUI supports generated spacing/style helpers such as `py_1`, but Guppy only exposes a hand-picked subset, so template class tokens like `py-1` fail.

- [ ] Audit GPUI 0.2.2 `Styled` helpers and generated macro surfaces (`style_helpers`, padding/margin/position/overflow/cursor/border/radius/shadow helpers). Possibly bring this or similar into our codebase for simplicity.
- [ ] Add matching Elixir IR style flags/value tuples for supported GPUI style attributes where they fit Guppy's data-only IR model. Possibly make a macro helper.
- [ ] Possibly share data if possible (ie make a csv or json file of source mappings idk reduce duplication and oopsie style errors)
- [ ] Extend the `~GUI` class parser to accept the corresponding Tailwind-ish tokens, including decimal-ish GPUI suffixes like `0p5` via `0.5`/`0p5` class spellings where appropriate.
- [ ] Extend native `StyleOp` decode and renderer mapping to call the corresponding GPUI methods or set equivalent `StyleRefinement` fields.
- [ ] Keep refinement/hover/focus style support correct: layout/scroll/positioning ops should remain element-only unless GPUI supports them safely in refinements.
- [ ] Add tests for representative GPUI-compatible tokens (`py-1`, `px-1`, `p-0.5`, `gap-x-*`, `border-x-*`, `rounded-t-*`, etc.) at component, Elixir IR, and native decode/render-mapping levels.
- [ ] Update `README.md` and `docs/gpui-compliance.md` with the supported style-token surface and any deliberate exclusions.

## Priority 4: harden existing primitives only when a real gap appears

These remain deferred until a concrete example, bug report, or compliance target justifies them.

- [ ] Select/popover/overlay edge cases: nested overlays, richer option-list positioning, focus/close lifecycle, and keyboard behavior.
- [ ] Data-table/tree interactions: keyboard navigation, focus-visible behavior, accessibility semantics, pinned headers/columns, resize/reorder, and stateful cell controls.
- [ ] Text/editor parity: richer text layout, syntax/editor semantics, undo/redo wiring for native text controls, and advanced selection behavior.
- [ ] Generic list row controls: text-editor or overlay-backed controls inside virtual rows after anchor and retained lifecycle are tested separately.
- [ ] Canvas/custom painting: path/line/text/image commands, retained drawing resources, and per-command hit testing only after a real visual need and measurement.
- [ ] Gradient/animation styling: multi-stop/radial/conic/text/border gradients or broader animation primitives only with an example need.
- [ ] Menus: dock menus, element-local/context menus, system Services submenu, or synchronous dynamic enablement only for a real app.
