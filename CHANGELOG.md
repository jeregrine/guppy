# Changelog

## v0.2.0 (2026-06-10)

Bug fixes, developer-experience, and performance pass from a full code review.

Breaking:

- Invalid window/file-dialog options now return field-tagged errors such as
  `{:error, {:invalid_window_options, :window_bounds}}` instead of the bare
  `{:error, :invalid_window_options}` / `{:error, :invalid_file_dialog_options}`
  atoms; update any code matching on those shapes.
- Static `class="..."` strings in `~GUI` templates are validated at compile
  time, so templates with invalid class tokens that previously compiled (and
  crashed at render time) now fail to compile.
- The unused `cast/2` and `connected?/1` callbacks were removed from the
  `Guppy.Native` behaviour.

Fixed:

- `Guppy.App` `handle_command/3` returning `{:stop, reason, state}` corrupted
  the coordinator state instead of stopping it; all command dispatch paths now
  honor stop tuples.
- `Guppy.Server` no longer crashes on unexpected or malformed messages; they
  are dropped with a warning (and telemetry for malformed native events).
- Concurrent `Guppy.App.open_window/3` calls for the same window id could
  start a second untracked window and deadlock the second caller against the
  window supervisor; duplicate ids are now rejected while an open is pending,
  and window starters are monitored so a crashed start fails fast with
  `{:error, {:window_start_failed, reason}}` instead of timing out.
- File dialog options now accept maps as well as keyword lists, matching
  window options.

Developer experience:

- `~GUI` template parse failures (mismatched tags, raw `&`, unclosed quotes)
  now raise readable `CompileError`s with template line/column instead of
  escaping as raw xmerl exits.
- Static `class="..."` strings are parsed and validated at template compile
  time: invalid tokens are compile errors instead of render-time crashes, and
  the parsed style list is embedded in the compiled template.
- Unsupported color-like class tokens explain the supported named palette and
  the `bg-[#hex]` escape hatch.
- Invalid window/file-dialog options report the offending field, e.g.
  `{:error, {:invalid_window_options, :window_bounds}}` (previously a bare
  `:invalid_window_options`).
- Unmatched `handle_event/3` clauses for user-wired callbacks and dispatches
  of unknown app commands now log warnings; lifecycle events stay at debug.

Performance:

- Full-tree IR validation moved from the central server into the calling
  window process (`Guppy.IR.Validated` is now used internally), so validation
  parallelizes per window.
- Dynamic class-token parses are memoized in an ETS cache; static class
  strings cost nothing at render time.

Removed:

- Dead no-timeout NIF stubs (`native_render/2` and friends) and the unused
  `cast/2` / `connected?/1` callbacks on `Guppy.Native`.

## v0.1.1 (2026-06-10)

Hardening release from a post-0.1.0 code review.

- IR validation now rejects empty node ids, empty event callback ids, and
  empty action names/bindings. Explicit ids key retained native state, so two
  nodes with `id: ""` previously shared focus/scroll/input state silently;
  native decode rejects empty ids as a backstop.
- Holding enter/space no longer spams discrete activation events: checkbox
  and radio changes, select and popover open/close, tree select/disclosure,
  and data-table sort/row/cell activation all ignore held key repeat. Held
  arrow navigation and held column-resize stepping still repeat.
- The uniform-list, list, tree, and data-table renderers now share one
  roving-focus/navigation/activation implementation, removing the duplicated
  keyboard plumbing that allowed per-renderer behavior drift.
- Documentation sync: `docs/distribution.md` no longer contradicts the
  published precompiled artifact state.

## v0.1.0 (2026-06-09)

Initial alpha release.

- Native GPUI windows driven by Elixir processes: full-tree IR rendering,
  retained native state keyed by stable node identity, and native events
  routed back to owning BEAM processes.
- `use Guppy.Window` LiveView-style window processes with assigns, `~GUI`
  templates, function components, and prop declarations.
- `use Guppy.App` multi-window apps with themes, stylesheets, commands,
  keymaps, menus, and a built-in command palette.
- Node kinds: text/rich text, div, scroll, virtualized uniform/generic lists,
  data table, tree, canvas, popover, select, button, checkbox, radio, text
  input, textarea, image, icon, and spacer.
- App shell APIs: app and Dock menus, app badges, file dialogs, and clipboard
  text.
- Telemetry events for native calls, request dispatch, event routing, and
  window rerenders, plus native performance counters.
- macOS (Apple Silicon) only. Precompiled NIF artifact for
  `aarch64-apple-darwin`; source builds require a Rust toolchain.
