# Guppy Forward Plan

Operational rules, checks, architecture notes, and maintenance reminders live in `AGENTS.md`. This file tracks prospective work only. Current behavior is documented in `README.md`, `docs/gpui-compliance.md`, examples, and commit history.

## Planning rules

- Prefer stabilization, hardening, docs/examples, and compliance maintenance over speculative new surface area.
- Do not add a new primitive or broaden an existing primitive without a concrete app/example need.
- Use TDD for regressions and behavior changes; add measurement before performance changes.
- Keep commits small and update docs/examples/benchmarks in the same change that alters behavior.
- Do not preserve old internal shapes for compatibility; this project is unreleased. DO NOT deprecate.
- Preserve the architectural invariant that Elixir owns app/UI state and renders data IR; native code should stay a typed GPUI bridge.

## Priority 1: Runtime stability findings (2026-06-09 code review)

`Guppy.Server` is a single GenServer that blocks inside `native_request/4` for the full duration of every native call. Fix the blocking model before broadening anything else.

- [x] Make `Guppy.Server` non-blocking for slow native requests, file dialogs first: validate ownership/options in `handle_call`, run the NIF call in a spawned task, and reply via `GenServer.reply/2` from a continuation. Today a 30s file dialog stalls all event routing, renders, closes, and clipboard calls for every window. (The native-side `runModal` main-thread freeze is a documented GPUI 0.2.2 limit and stays.)
- [x] Narrow the blanket `catch _kind, _reason -> {:error, :runtime_unavailable}` in `Guppy.Server.native_request/4`; it currently reports real bugs (e.g. `FunctionClauseError` in the native module) as runtime unavailability.
- [x] Add backoff or a retry cap to the `Guppy.Window` reopen loop (`lib/guppy/window.ex` reopen retry); on persistent failure it retries every 50ms forever against a struggling runtime.
- [x] Make `native_gui_status` honest on non-macOS: `maybe_start_main_thread_runtime` stores `GUI_STARTED = true` without ever calling `run_app()`, so status reports `"started"` while every request times out. Report not-started/unsupported instead.
- [x] Document (or reconcile) the open-window timeout race: if `native_open_window` succeeds natively but the reply lands after the caller timeout, Elixir drops the view id and the native window is live but ownerless. Reconciled: timed-out opens enqueue a best-effort close behind the stale open in the FIFO main-thread queue.

## Priority 2: Measured hot-path cleanups (2026-06-09 code review)

Each of these is measurable with the existing counters/benchmarks; verify before/after per the planning rules.

- [x] Drop the per-request `Task.async` wrapper in `Guppy.Server.native_request/4` in favor of inline `try/catch`; the task adds no concurrency (it is yielded immediately) and copies the full IR term to a fresh process on every render.
- [ ] Cache NIF load status in `Guppy.Native.Nif` after first success instead of calling `native_ping` through `apply` + rescue on every dispatch (`with_loaded/1`).
- [ ] Remove the `bytes.to_vec()` copy on the IR decode worker handoff in `native/guppy_nif/src/lib.rs` if a borrow/ownership transfer is practical.

## Priority 3: Native de-slopification pass, concrete first steps (2026-06-09 code review)

- [ ] Merge `render_checkbox.rs` and `render_radio.rs` (~90% line-for-line clones: focus handling, six style-state blocks, `enabled_change_callback`, toggle-key helpers, tests) into a shared choice-control renderer parameterized by indicator + emit function; sweep `bridge_view/` for the same pattern in other renderers.
- [ ] Move the hardcoded control palette (`0x2563eb`, `0x94a3b8`, `0x0f172a`, etc. in checkbox/radio indicators and labels) to style-op-driven values with these as defaults; today Elixir cannot fully theme native controls, which violates "higher-level theming stays in Elixir".
- [ ] Use the existing `normalize_native_reply/1` in the four `Guppy.Server` call sites that re-pattern-match `:ok` / `{:ok, _payload}` arms inline.
- [ ] Consider one schema-driven helper for the option-map validators (window options, dialogs, menus) in `Guppy.Server`; keep node IR validation explicit.

## Priority 3.5: Examples and docs sync (2026-06-09 examples review)

- [ ] Fix `examples/counter.exs`: it `receive`s a `:DOWN` message but never calls `Process.monitor(pid)`, so the script hangs forever after the window closes. Also add the `Application.ensure_all_started(:guppy)` line for consistency.
- [ ] Sync the README example list: `counter.exs`, `click_counter.exs`, `text_clicks.exs`, `style_gallery.exs`, and `markdownview.exs` are not referenced (and `style_gallery` is in the AGENTS.md run list). Consider promoting the fixed `counter.exs` as the README's minimal quickstart, or fold it into `click_counter.exs`.
- [ ] Optional: add a debug-level log on the `Guppy.Window` unmatched-callback no-op path so app authors notice typo'd callback names.

## Priority 4: Packaging and distribution hardening

Before external users rely on Guppy, make source builds and release consumption boring.

- [ ] Keep `scripts/check`, `scripts/clean_install_load_test`, `scripts/package_smoke`, and macOS source-build CI green.
- [ ] Finish the precompiled NIF artifact plan only for targets with CI build/load validation and checksums.
- [ ] Document release-mode native build workflows and expected performance tradeoffs.
- [ ] Brainstorm ways to package this up into a binary we can code-sign. Existing ways all suck we might have to reinvent the wheel here.

## Priority 5: Text/editor parity

Real native apps often need more than plain inputs. Treat this as a focused design effort rather than incremental prop sprawl.

- [ ] Audit GPUI text/editor capabilities available in `gpui = 0.2.2` and decide what belongs in Guppy now versus later.
- [ ] Improve `text_input`/`textarea`: selection APIs, cursor control, scroll control, validation hooks, IME correctness, and native event coverage. Explicit `actions`/`shortcuts` now work on text inputs/textareas; deeper editor parity remains.
- [ ] Ensure editor-like controls interact correctly with commands, context menus, themes, focus scopes, and clipboard APIs.

## Deferred primitives and polish

Keep these deferred until a concrete app/example need appears.

- [ ] Canvas/custom painting: path/line/text/image commands, retained drawing resources, and per-command hit testing.
- [ ] Closure-backed render slots: image `fallback`/`loading`, tooltip builders, and similar render closures should be explicit data IR child/slot fields with lifecycle/render/event tests.
- [ ] Broader gradients/animations: multi-stop/radial/conic/text/border gradients or general animation primitives.
- [ ] Generic list row controls beyond the current safe subset, especially editor or overlay-backed controls inside virtual rows.
