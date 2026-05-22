# Theme support

Guppy themes are app-scoped Elixir data. They intentionally compile semantic tokens to primitive IR style tuples before native render so Elixir remains the source of truth and the Rust/GPUI bridge stays a typed renderer rather than a theme runtime.

## Reference audit

Zed's theme system is the primary reference:

- `../zed/crates/theme/src/theme.rs` defines `ThemeFamily`, `Theme`, `Appearance`, `GlobalTheme`, and active-theme access.
- `../zed/crates/theme/src/registry.rs` keeps registered theme families in a global registry and looks themes up by display name.
- `../zed/crates/theme/src/styles/colors.rs` defines a large semantic color surface (`background`, `surface_background`, `text`, `border`, editor/status colors, etc.).
- `../zed/crates/theme/src/default_colors.rs` fills missing theme colors from light/dark defaults.
- `../zed/crates/theme_settings/src/theme_settings.rs` and `settings.rs` connect settings, theme selection, overrides, and `observe_global` reloads.
- `../zed/crates/theme_settings/src/schema.rs` shows serialized theme-family/theme content and style overrides.

Relevant GPUI 0.2.2 hooks:

- `../zed/crates/gpui/src/colors.rs` exposes `Colors`, `GlobalColors`, and `DefaultColors` for GPUI's base component colors.
- `../zed/crates/gpui/src/app.rs` supports `set_global`, `default_global`, and `observe_global` for app-global data.
- `../zed/crates/gpui/src/platform.rs` exposes `WindowAppearance` light/dark/vibrant variants.

Guppy does not currently install GPUI globals for themes. That would make native retained state partly responsible for theme resolution. The current layer stays app-scoped and Elixir-side.

## Current Guppy shape

`Guppy.App.Theme` contains:

- `id`
- `name`
- `appearance` (`:light`, `:dark`, or `:system`)
- `colors` — semantic color tokens keyed by strings/atoms, with named Guppy colors or hex strings as values
- `styles` — semantic style tokens resolved to canonical IR style tuples
- `metadata`

Theme style definitions can mix Guppy class strings, canonical style tuples, and explicit theme color references (`Guppy.Style.theme_color/2` or `Guppy.App.Theme.color_ref/2`):

```elixir
%{
  id: "demo-dark",
  name: "Demo Dark",
  appearance: :dark,
  colors: %{surface: "#0f172a", text: :white},
  styles: %{
    card: [
      "p-4 rounded-lg",
      Guppy.Style.theme_color(:bg, :surface),
      Guppy.Style.theme_color(:text_color, :text)
    ]
  }
}
```

Validated themes store normalized string keys and resolved primitive style lists. Built-in defaults are available with `Guppy.App.Theme.default(:dark)` and `Guppy.App.Theme.default(:light)`. Use `Guppy.App.Theme.refine/2` to create explicit refinements/overrides from an existing theme while preserving unspecified tokens.

`Guppy.App.ThemeFamily` groups related themes by stable theme id. Apps can register families with `Guppy.App.register_theme_family/2` and activate a registered theme by id with `Guppy.App.set_theme/2`.

## App/window helpers

Use `Guppy.active_theme/0..1` to inspect the current theme and `Guppy.App` for app-scoped theme mutation/lookup:

```elixir
Guppy.active_theme()
Guppy.active_theme(app)
Guppy.App.set_theme(app, theme_or_registered_theme_id)
Guppy.App.theme_color(:surface)
Guppy.App.theme_color(app, :surface)
Guppy.App.theme_style(:card)
Guppy.App.theme_style(app, :card)
Guppy.App.register_theme_family(app, family)
Guppy.App.theme_families(app)
```

`use Guppy.Window` imports current-app helpers through `Guppy.Component`:

```elixir
def render(window) do
  card_style = theme_style!(:card)

  ~GUI"""
  <div id="card" style={card_style}>
    <text>Themed card</text>
  </div>
  """
end
```

`examples/multi_window_app.exs` demonstrates app-owned theme metadata, theme style resolution, stylesheet refs, commands, menus, keymaps, a command palette, and multi-window supervision.

## Boundaries

- Raw template `style` strings remain rejected; use `class` strings or resolved theme styles.
- Theme resolution is Elixir-side and produces existing primitive style tuples.
- Native `GlobalColors`/`DefaultColors` hooks are audited but not used for Guppy theme resolution yet.
- Standalone non-app theme conveniences remain deferred until a concrete standalone example needs them.
