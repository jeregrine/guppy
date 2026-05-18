# Guppy Forward Plan

Operational rules, checks, architecture notes, and maintenance reminders live in `AGENTS.md`. This file tracks prospective work only. Current behavior is documented in `README.md`, `docs/gpui-compliance.md`, examples, and commit history.

## Planning rules

- Prefer stabilization, hardening, docs/examples, and compliance maintenance over new surface area.
- Do not add a new primitive or broaden an existing primitive without a concrete app/example need.
- Use TDD for regressions and behavior changes; add measurement before performance changes.
- Keep commits small and update docs/examples/benchmarks in the same change that alters behavior.
- Do not preserve old internal shapes for compatibility; this project is unreleased. DO NOT deprecate.

## Priority 1: GPUI style-surface parity

Concrete gap found while building `examples/markdownview.exs`: GPUI supports generated spacing/style helpers such as `py_1`, but Guppy only exposes a hand-picked subset, so template class tokens like `py-1` fail. Fix this as a full GPUI 0.2.2 style-surface parity pass, not a staged token patch.

Design decisions:

- Target full data-representable parity with GPUI 0.2.2 `Style`, `Styled`, generated style-helper macro surfaces, and CSS-like node-specific styling helpers. Closure-backed/event/render helpers are not style parity.
- Delete the old atom-style compatibility surface; this project is unreleased. Break examples/tests/docs and update them in the same change.
- Use property-first canonical tuple IR. Examples: `{:padding, :y, {:rem, 0.25}}`, `{:border_width, :x, {:px, 1}}`, `{:font_weight, 700}`, `{:overflow, :x, :scroll}`, `{:object_fit, :cover}`.
- Every canonical tuple op must validate on the Elixir side, decode on the Rust side, and map to GPUI or equivalent `StyleRefinement` fields. Rust should decode canonical tuples, not class strings. Native decode should remain typed and reject malformed style tuples at the boundary when practical, but avoid expensive duplicate validation that would materially hurt hot-path render performance.
- Put the shared style catalog in `data/gpui_style_catalog.json`, include `data` in Hex/source package files for dependency compile-time use, and do not put it in `priv` or require runtime/release inclusion. Treat it as the source of truth for class tokens, helper specs, canonical tuple schemas, node applicability, refinement support, and audit coverage. Use Elixir's built-in `JSON` module; do not add `Jason`.
- Use compile-time macro expansion from the catalog for `Guppy.Style` helpers and parser tables. Do not check in generated code files. Helper naming should include Tailwind-ish convenience helpers (`Guppy.Style.py(1)`, `Guppy.Style.p(0.5)`) plus property-first exact helpers (`Guppy.Style.padding(:y, {:rem, 0.25})`, `Guppy.Style.bg({:hex, "#fff"})`). Rust should use typed categorical decode plus catalog audit tests via `include_str!`/`serde_json`, not generated match arms.
- Parse static `~GUI` class strings at compile time like HEEx wherever practical, including literal XML attribute strings. Dynamic class expressions remain runtime-parsed without an unbounded cache. Keep HEEx-like class-list behavior for dynamic classes: lists are flattened, `nil`/`false` entries are ignored, and non-string entries are rejected.
- Apply the same class/style split to stateful style attributes: `hover_class`, `focus_class`, `focus_visible_class`, `in_focus_class`, `active_class`, and `disabled_class` accept class shorthand; `hover_style`, `focus_style`, `focus_visible_style`, `in_focus_style`, `active_style`, and `disabled_style` accept canonical tuple style lists only.
- Normalize class/helper output to primitive tuple ops so composite helpers such as `truncate` and preset shadows expand before native decode. Expand composites in place and preserve order so later ops can override earlier expanded ops. Keep Tailwind/GPUI visibility/display semantics: `hidden` maps to `{:display, :none}`, `invisible` maps to `{:visibility, :hidden}`, and `visible` maps to `{:visibility, :visible}`.
- Public class DX should prefer Tailwind-ish spellings (`py-1`, `p-0.5`, `rounded-t-md`); accept GPUI-ish aliases such as `0p5` where unambiguous.
- Not every style op needs a class token. Every op must have tuple IR and a `Guppy.Style` helper; classes cover Tailwind-ish/GPUI-ish tokens where sensible.
- Browser/HEEx principle for template attrs vs styles: HTML-ish data attrs stay attrs (`id`, `src`, `value`, `checked`, `disabled`, `placeholder`); CSS-ish presentation moves to style (`object_fit`, `grayscale`, cursor, visibility, etc.). Do not add broad direct XML style attrs such as `padding_y={1}`; high-level template DX should feel familiar to HEEx/LiveView/HTML authors through normal attrs, `class`, and explicit `style={...}` data. Remove image `object_fit`/`grayscale` attrs and replace them with style ops/classes. Template `class` attributes accept class shorthand; template `style` attributes should accept canonical style tuples or direct style-setting expressions, not class strings. Runtime raw string style values should raise a clear error telling callers to use `class` for class tokens.
- Include data specs for GPUI values that are Rust structs/enums: lengths, colors, backgrounds/fills, box shadows, text decorations, font specs, grid placement, cursor, visibility, overflow, etc. Public helpers may accept ergonomic keyword lists for complex values, but must return canonical tuple IR before values enter raw style lists or native decode. Primitive helpers should return one tuple; composite helpers may return lists of tuples, and style merging must flatten helper output.
- Canonical length IR: `{:px, n}`, `{:rem, n}`, `{:fraction, n}`, or `:auto` when GPUI accepts auto. Support arbitrary classes such as `w-[42px]`, `w-[50%]`, `m-[auto]`, `rounded-[6px]`, and negative values wherever GPUI supports them.
- Canonical color IR: named GPUI/current colors (`:black`, `:white`, `:red`, `:green`, `:blue`, `:yellow`, transparent variants, grey/gray lightness+opacity), `{:hex, "#rgb/#rgba/#rrggbb/#rrggbbaa"}`, `{:rgba, r, g, b, a}`, or `{:hsla, h, s, l, a}`. Do not add a Tailwind palette in this pass.
- Background/fill IR should explicitly model solid backgrounds, two-stop linear gradients with optional color space, and slash patterns: e.g. `{:bg, {:solid, color}}`, `{:bg, {:linear_gradient, angle, from_stop, to_stop, color_space}}`, `{:bg, {:pattern_slash, color, width, interval}}`.
- Font IR should expose `font_family`, `font_features`, `font_fallbacks`, `font_weight`, `font_style`, and a complete `font` data spec.
- Shadow classes should cover GPUI presets; arbitrary shadow data is tuple/helper-only.
- Include debug-only GPUI styles (`debug`, `debug_below`) if easy; native release builds may no-op them and docs must mark them debug-only.
- Stateful/refinement styles (`hover_style`, `focus_style`, `focus_visible_style`, `in_focus_style`, `active_style`, `disabled_style`) must reject unsupported layout/position/scroll/sizing/spacing/grid/flex/font-metric ops instead of silently ignoring them. Allow visual-ish ops such as colors/backgrounds, opacity, shadow, radius, border color/style, cursor, and text decoration/color/background.
- Rich-text run styles get highlight-only parity, not full node style parity; reject layout ops on runs.
- Reject node-applicability violations instead of silently ignoring them; for example image-only style ops such as `object_fit`/`grayscale` should fail on `<div>`.

Implementation checklist:

- [ ] Audit GPUI 0.2.2 `Style`, `Styled`, generated macro surfaces (`style_helpers`, padding/margin/position/overflow/cursor/border/radius/shadow helpers), `StyleRefinement`, and CSS-like node-specific style traits such as image object-fit/grayscale.
- [ ] Add `data/gpui_style_catalog.json` with canonical tuple schemas, class/helper mappings, GPUI mapping metadata, node applicability, refinement support, and docs labels.
- [ ] Add `Guppy.Style` helpers generated at compile time from the catalog.
- [ ] Replace old atom-style IR validation/types with property-first tuple schemas; remove compatibility shims.
- [ ] Update `Guppy.Component`/`~GUI` static and dynamic class parsing to normalize into canonical tuple ops.
- [ ] Extend native `StyleOp` decode to categorical tuple ops and map all catalogued ops to GPUI methods or equivalent `StyleRefinement` fields.
- [ ] Add catalog audit tests proving Elixir validation/parser/helper coverage and native decode/render mapping coverage for every canonical op.
- [ ] Add representative behavior tests for `py-1`, `px-1`, `p-0.5`, `gap-x-*`, `border-x-*`, `rounded-t-*`, arbitrary lengths/colors/shadows, image `object-fit`/`grayscale` classes, pseudo-state rejection, and rich-text run rejection.
- [ ] Update examples, `README.md`, and `docs/gpui-compliance.md` with the new tuple/class/helper style surface and deliberate non-style exclusions.

## Priority 2: Theme support

Add first-class theming immediately after the style-surface parity pass. Model it after Zed's theme system as much as is appropriate for Guppy's Elixir-owned architecture. This is separate from accepting raw `style` strings: template `style` should remain canonical tuple/direct style data, while themes provide semantic tokens that compile or resolve into lower-level style IR.

Initial direction to grill/design next:

- [ ] Audit Zed's theme architecture and use it as the primary reference, without taking a hard dependency on Zed crates. Key reference files include `../zed/crates/theme/src/theme.rs`, `../zed/crates/theme/src/registry.rs`, `../zed/crates/theme/src/styles/*.rs`, `../zed/crates/theme/src/default_colors.rs`, and `../zed/crates/theme_settings/src/theme_settings.rs`.
- [ ] Mirror the useful Zed concepts: `ThemeFamily`, `ThemeRegistry`, active/global theme, `Appearance` (`:light`/`:dark`), `SystemAppearance`, `ThemeStyles`, theme overrides/refinements, and named semantic color fields.
- [ ] Start from a Zed-like theme shape: metadata (`id`, `name`, `appearance`), styles (`window_background_appearance`, `system`, `colors`, `status`, `accents`, maybe `players`, later `syntax`), and default light/dark fallback themes. Zed's `ThemeColors` taxonomy (`background`, `surface_background`, `element_background`, `element_hover`, `text`, `text_muted`, `border`, `panel_background`, `editor_background`, terminal/status colors, etc.) should inform Guppy's initial semantic token names.
- [ ] Audit GPUI 0.2.2 theming/color hooks. Known surface includes `Colors`, `GlobalColors`, `DefaultColors`, `WindowAppearance`, and app globals (`set_global`/`global`/`observe_global`); verify whether GPUI has more theme-specific API before designing Guppy's layer.
- [ ] Decide theme ownership and scope: app-global, process-owned, per-window overrides, or inherited context. Preserve Elixir as the source of truth and define restart/server-loss behavior.
- [ ] Define semantic theme token IR and helper API, likely distinct from primitive style tuples: e.g. `{:theme_color, :surface_background}`, `{:theme_color, :text}`, or higher-level Elixir helpers that compile down to `{:bg, ...}` / `{:text_color, ...}` before native render when possible.
- [ ] Decide whether theme resolution happens entirely in Elixir before full-tree render, partially in native through GPUI globals, or both. Prefer Elixir-side compile-down unless GPUI globals provide useful appearance-aware behavior without violating source-of-truth semantics.
- [ ] Support light/dark/window-appearance variants, explicit app-defined themes, and Zed-like refinements/overrides; document how OS appearance interacts with user-selected themes.
- [ ] Add APIs and examples after design: likely `Guppy.set_theme/1`, `Guppy.set_theme/2`, `Guppy.register_theme_family/1`, `Guppy.active_theme/0`, `use Guppy.Window` theme access helpers, and `~GUI`/`Guppy.Style` helpers for theme references.
- [ ] Add tests for theme validation, registry/lookup, owner cleanup/lifecycle if process-owned, render resolution, server restart behavior, native/global updates if used, and docs/examples.

## Priority 4: harden existing primitives only when a real gap appears

These remain deferred until a concrete example, bug report, or compliance target justifies them.

- [ ] Select/popover/overlay edge cases: nested overlays, richer option-list positioning, focus/close lifecycle, and keyboard behavior.
- [ ] Data-table/tree interactions: keyboard navigation, focus-visible behavior, accessibility semantics, pinned headers/columns, resize/reorder, and stateful cell controls.
- [ ] Text/editor parity: richer text layout, syntax/editor semantics, undo/redo wiring for native text controls, and advanced selection behavior.
- [ ] Generic list row controls: text-editor or overlay-backed controls inside virtual rows after anchor and retained lifecycle are tested separately.
- [ ] Canvas/custom painting: path/line/text/image commands, retained drawing resources, and per-command hit testing only after a real visual need and measurement.
- [ ] Closure-backed render slots: GPUI helpers such as image `with_fallback`/`with_loading`, tooltip/hoverable-tooltip builders, and similar render closures are not style parity. Model them as explicit data IR child/slot fields (for example `fallback`, `loading`, and `tooltip` IR), keep Elixir as the source of truth for slot trees, map event closures to Guppy events where applicable, and add lifecycle/render/event tests before enabling them.
- [ ] Gradient/animation styling: multi-stop/radial/conic/text/border gradients or broader animation primitives only with an example need.
- [ ] Menus: dock menus, element-local/context menus, system Services submenu, or synchronous dynamic enablement only for a real app.
