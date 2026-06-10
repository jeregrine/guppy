# Changelog

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
