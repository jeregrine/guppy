# Guppy Forward Plan

Operational rules, checks, architecture notes, and maintenance reminders live in `AGENTS.md`. This file tracks prospective work only. Current behavior is documented in `README.md`, `docs/gpui-compliance.md`, examples, and commit history; deferred primitive ideas live in `docs/future-primitives.md`. Do not keep large done-task checklists here.

## Planning rules

- Prefer stabilization, hardening, docs/examples, and compliance maintenance over new surface area.
- Do not add a new primitive or broaden an existing primitive without a concrete app/example need.
- Use TDD for regressions and behavior changes; add measurement before performance changes.
- Keep commits small and update docs/examples/benchmarks in the same change that alters behavior.
- Do not preserve old internal shapes for compatibility; this project is unreleased. DO NOT deprecate.

## Priority 0: fix code-review regressions

### Template `class` / `style` normalization

Context: `Guppy.Component.class_to_style!/1` supports list-valued class inputs, but `Guppy.Component.merge_styles/2` currently treats any list as already-normalized style ops. Dynamic templates such as `class={["p-2", false, "text-white"]}` can therefore produce raw string style ops and fail IR validation.

- [x] Add an ExUnit regression for dynamic list-valued `class` attributes in `~GUI`, including `nil` / `false` filtering.
- [x] Split class normalization from raw `style` normalization so class strings/lists always go through `class_to_style!/1`, while `style` lists remain raw style ops.
- [x] Keep `style={"p-2 text-white"}` behavior intentional: convert it as class-like input; covered by `Guppy.Component.merge_styles/2` regression.
- [x] Run `mix test test/guppy/component_test.exs` and a full `mix test` after the fix. (`mix test test/guppy/component_test.exs` and full `mix test` passed.)

### Data-table fractional column widths

Context: `DataTableColumnWidth::Fr(value)` is decoded, but native render maps every `{:fr, value}` to `flex_1()`, making `{:fr, 2}` behave the same as `{:fr, 1}`.

- [x] Add a Rust renderer/style-focused regression showing `{:fr, 2}` and `{:fr, 1}` produce distinct flex-grow behavior, or decide that weighted fractions are not supported.
- [x] If weighted fractions are supported, render `DataTableColumnWidth::Fr(value)` with proportional flex grow and a zero/auto basis matching intended semantics.
- [x] If weighted fractions are not supported, simplify the IR/docs to `:auto` plus fixed `{:px, value}` instead of accepting an ignored value. (Not chosen; weighted fractions are supported.)
- [x] Re-run the data-table/tree example smoke after the chosen behavior lands.

### Tree native invariants and rendering follow-through

Context: native decode accepts `selected_id` without proving it exists in the tree, while Elixir validation rejects unknown selected ids. `TreeItem.style` is validated/decoded but dropped during `VisibleTreeItem` flattening, so item-level style never renders.

- [x] Add a native IR decode regression rejecting a `tree.selected_id` that is absent from decoded nodes, including the `%Guppy.IR.Validated{}` bypass path assumption.
- [x] Preserve the decoded tree-id set long enough to validate `selected_id` natively.
- [x] Add a renderer/unit regression for `TreeItem.style` flowing through `flatten_visible_tree_items/1` into row rendering.
- [x] Carry `TreeItem.style` into `VisibleTreeItem` and apply it in row render without overriding ordered `row_style` semantics unexpectedly.
- [x] Audit whether `selected_id` should have any default native visual treatment today; either implement a narrow selected-row style hook or document that selection is semantic-only until a selected-style primitive exists. (Decision: semantic-only; documented in README/compliance docs.)

### Data-table selected-state rendering/documentation

Context: `selected_row_id` and `selected_cell` are validated and decoded, but native table rendering currently does not visibly distinguish selected rows/cells. This may be acceptable as semantic state, but the docs/examples imply selection state is part of the primitive.

- [x] Decide whether first-pass `data_table` selection is semantic-only or should have default/highlight styling. (Decision: semantic-only.)
- [x] If semantic-only, clarify README / compliance docs and keep examples from implying native selection highlighting.
- [x] If visual, add a narrow selected row/cell style path with tests before changing examples. (Not chosen.)

## Priority 1: simplify unsafe/Rustler boundaries

### Replace same-crate C event shims with safe Rust calls

Context: many GPUI render/event modules declare `extern "C"` functions exported by `native_events.rs` in the same crate, pass raw string pointers, then reconstruct Rust strings with `from_raw_parts`. Rustler does not require this: `OwnedEnv::send_and_clear` can stay inside a normal Rust module callable through safe `pub(crate)` functions.

- [x] Move event send entrypoints in `native_events.rs` behind safe Rust functions that accept `&str`, `Option<&str>`, booleans, numeric payloads, and small payload structs where useful.
- [x] Update `bridge_view/events.rs`, `bridge_text_input.rs`, `render_checkbox.rs`, `render_radio.rs`, and `render_uniform_list.rs` to call those safe functions directly instead of local `extern "C"` declarations.
- [x] Remove now-unneeded `#[unsafe(no_mangle)]` exports and raw pointer decode helpers for internal event paths.
- [x] Keep `rustler::OwnedEnv::send_and_clear` for cross-thread BEAM delivery; it remains the right Rustler mechanism for GPUI/native event emission.
- [x] Add focused tests/snapshots proving click, checkbox/radio change, text input change, row-control, data-table/tree, menu, and window lifecycle events still encode the same payloads.

### Keep and document unavoidable unsafe narrowly

Context: macOS GPUI bootstrap still needs OTP main-thread stealing, and GPUI `DisplayId` is opaque.

- [x] Keep the `erl_drv_steal_main_thread` unsafe block narrow and documented; Rustler does not provide an equivalent safe abstraction for this OTP/macOS bootstrap path.
- [x] Replace `std::mem::transmute::<u32, DisplayId>` with a lookup through `cx.displays()` / `u32::from(display.id())`, returning a real GPUI `DisplayId` when present.
- [x] Add tests for valid, missing, and out-of-range display ids at the decode/mapping boundary where practical.
- [x] Run `rg "unsafe" native/guppy_nif/src` after the refactor and add/update `SAFETY:` comments only for remaining unavoidable unsafe blocks.

## Priority 2: verification gates for the current surface

- [x] Run `mix compile --force` after the review-fix batch.
- [x] Run `mix test` after the review-fix batch.
- [x] Run `scripts/check` before declaring the stabilization pass green.
- [x] Smoke the changed examples: `examples/data_table_tree.exs`, `examples/list_row_controls.exs`, `examples/canvas_pattern.exs`, and `examples/menu_demo.exs`.
- [x] If native hot paths change meaningfully, refresh the relevant `docs/performance.md` benchmark/stress snapshot instead of assuming cleanup helped. (No meaningful native hot-path performance claim changed; no benchmark snapshot refreshed.)

## Priority 3: docs and compliance cleanup after fixes

- [x] Recheck `README.md` claims for template class inputs, data-table/tree selection semantics, canvas commands, menus, and event payloads after the fixes above.
- [x] Recheck `docs/gpui-compliance.md` against actual `gpui = 0.2.2` APIs used in the current native code.
- [x] Keep `docs/future-primitives.md` focused on scoped/deferred ideas; move any current-behavior details that users need into README/compliance docs.
- [x] Update examples only when behavior changes, not just to paper over implementation gaps.

## Priority 4: harden existing primitives only when a real gap appears

These remain deferred until a concrete example, bug report, or compliance target justifies them.

- [ ] Select/popover/overlay edge cases: nested overlays, richer option-list positioning, focus/close lifecycle, and keyboard behavior.
- [ ] Data-table/tree interactions: keyboard navigation, focus-visible behavior, accessibility semantics, pinned headers/columns, resize/reorder, and stateful cell controls.
- [ ] Text/editor parity: richer text layout, syntax/editor semantics, undo/redo wiring for native text controls, and advanced selection behavior.
- [ ] Generic list row controls: text-editor or overlay-backed controls inside virtual rows after anchor and retained lifecycle are tested separately.
- [ ] Canvas/custom painting: path/line/text/image commands, retained drawing resources, and per-command hit testing only after a real visual need and measurement.
- [ ] Gradient/animation styling: multi-stop/radial/conic/text/border gradients or broader animation primitives only with an example need.
- [ ] Menus: dock menus, element-local/context menus, system Services submenu, or synchronous dynamic enablement only for a real app.
