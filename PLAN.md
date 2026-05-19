# Guppy Forward Plan

Operational rules, checks, architecture notes, and maintenance reminders live in `AGENTS.md`. This file tracks prospective work only. Current behavior is documented in `README.md`, `docs/gpui-compliance.md`, examples, and commit history.

## Planning rules

- Prefer stabilization, hardening, docs/examples, and compliance maintenance over speculative new surface area.
- Do not add a new primitive or broaden an existing primitive without a concrete app/example need.
- Use TDD for regressions and behavior changes; add measurement before performance changes.
- Keep commits small and update docs/examples/benchmarks in the same change that alters behavior.
- Do not preserve old internal shapes for compatibility; this project is unreleased. DO NOT deprecate.
- Preserve the architectural invariant that Elixir owns app/UI state and renders data IR; native code should stay a typed GPUI bridge.

## Priority 1: Theme support

Add first-class theming now that GPUI style-surface parity is catalog-backed. Keep themes as a semantic layer above primitive style tuples; raw template `style` strings should stay rejected.

Initial direction to design next:

- [ ] Audit Zed's theme architecture and use it as the primary reference, without taking a hard dependency on Zed crates. Key reference files include `../zed/crates/theme/src/theme.rs`, `../zed/crates/theme/src/registry.rs`, `../zed/crates/theme/src/styles/*.rs`, `../zed/crates/theme/src/default_colors.rs`, and `../zed/crates/theme_settings/src/theme_settings.rs`.
- [ ] Audit GPUI 0.2.2 theming/color hooks. Known surface includes `Colors`, `GlobalColors`, `DefaultColors`, `WindowAppearance`, and app globals (`set_global`/`global`/`observe_global`); verify the usable surface before choosing Guppy's layer.
- [ ] Define a Guppy theme shape: metadata (`id`, `name`, `appearance`), semantic color/style tokens, default light/dark themes, and explicit override/refinement support.
- [ ] Decide theme ownership and scope: app-global, process-owned, per-window overrides, or inherited context. Define server restart and owner-exit behavior.
- [ ] Decide where resolution happens. Prefer Elixir-side compile-down into primitive style IR unless GPUI globals provide appearance-aware behavior without violating Elixir source-of-truth semantics.
- [ ] Add APIs and examples after design, likely `Guppy.set_theme/1`, `Guppy.set_theme/2`, `Guppy.register_theme_family/1`, `Guppy.active_theme/0`, `use Guppy.Window` theme helpers, and `~GUI`/`Guppy.Style` helpers for theme references.
- [ ] Add tests for theme validation, registry/lookup, owner cleanup/lifecycle, render resolution, server restart behavior, and docs/examples.

## Priority 2: Native app shell APIs

These are the biggest missing pieces for building real desktop apps. Add them as narrow, typed APIs with process ownership and restart behavior, not as ad hoc NIF calls.

- [ ] App/window command model: command registry, keyboard shortcut registration, routing priority, enable/disable state, and `Guppy.Window` integration.
- [ ] Element-local/context menus: right-click/context menu primitives for rows, trees, canvas items, editors, and general elements; include keyboard invocation and focus return.
- [ ] File dialogs: open file(s), save file, choose directory, filters, default paths/names, cancellation semantics, and owner-window association.
- [ ] Clipboard APIs: read/write text, later images/files if GPUI/platform support is practical; define permission/error behavior.
- [ ] App/window lifecycle events: app activated/deactivated, hidden/unhidden, window focused/blurred, moved/resized if available and useful.
- [ ] Notifications/badges where platform support is practical; keep optional and well-documented.
- [ ] Dock/system menu follow-ups: dock menus, Services submenu, and dynamic menu enablement only after the command model is in place.

## Priority 3: Overlay, popover, and select hardening

Current popover/select support is first-pass. Native apps need reliable overlays before complex menus/forms feel right.

- [ ] Define overlay lifecycle semantics: open/close ownership, escape behavior, click-outside behavior, focus return, and stale-owner cleanup.
- [ ] Harden positioning: anchor bounds, viewport constraints, flipping/offsets, scroll-parent behavior, and window-edge handling.
- [ ] Add keyboard behavior for select/menu-like overlays: arrows, home/end, typeahead if warranted, enter/space, escape, disabled options.
- [ ] Support nested overlays deliberately or reject/document unsupported nesting with tests.
- [ ] Add examples that exercise dropdowns, context menus, nested panels, and form-like select usage.

## Priority 4: Keyboard, focus, accessibility, data table, and tree interactions

Focus and keyboard behavior are now more important than broadening visual primitives.

- [ ] Define focus scopes and roving-focus patterns for list/tree/table/menu-like widgets.
- [ ] Add shortcut bubbling/priority rules that work with app commands, focused controls, and text inputs.
- [ ] Improve data-table/tree keyboard navigation, row/cell/item focus-visible behavior, selection affordances, disclosure behavior, and context-menu integration.
- [ ] Add data-table column resize/reorder and pinned header/column behavior only after navigation/focus semantics are stable.
- [ ] Audit GPUI accessibility/semantics support and expose labels/roles/states where practical through typed IR.

## Priority 5: Packaging and distribution hardening

Before external users rely on Guppy, make source builds and release consumption boring.

- [ ] Keep `scripts/check`, `scripts/clean_install_load_test`, `scripts/package_smoke`, and macOS source-build CI green.
- [ ] Finish the precompiled NIF artifact plan only for targets with CI build/load validation and checksums.
- [ ] Document release-mode native build workflows and expected performance tradeoffs.
- [ ] Brainstorm ways to package this up into a binary we can code-sign. Existing ways all suck we might have to reinvent the wheel here.

## Priority 6: Text/editor parity

Real native apps often need more than plain inputs. Treat this as a focused design effort rather than incremental prop sprawl.

- [ ] Audit GPUI text/editor capabilities available in `gpui = 0.2.2` and decide what belongs in Guppy now versus later.
- [ ] Improve `text_input`/`textarea`: selection APIs, cursor control, scroll control, validation hooks, keyboard shortcut behavior, IME correctness, and native event coverage.
- [ ] Design a richer editor primitive only if a concrete example needs it: rich text editing, syntax highlighting, undo/redo integration, diagnostics, and multi-cursor/selection behavior.
- [ ] Ensure editor-like controls interact correctly with commands, context menus, themes, focus scopes, and clipboard APIs.

## Deferred primitives and polish

Keep these deferred until a concrete app/example need appears.

- [ ] Canvas/custom painting: path/line/text/image commands, retained drawing resources, and per-command hit testing.
- [ ] Closure-backed render slots: image `fallback`/`loading`, tooltip builders, and similar render closures should be explicit data IR child/slot fields with lifecycle/render/event tests.
- [ ] Broader gradients/animations: multi-stop/radial/conic/text/border gradients or general animation primitives.
- [ ] Generic list row controls beyond the current safe subset, especially editor or overlay-backed controls inside virtual rows.
