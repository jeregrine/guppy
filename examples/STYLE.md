# Example visual language

Guppy examples should look like small native macOS apps, not web dashboards or
feature-tour slides. `examples/support/ui.exs` (`Examples.UI`) carries the
shared palette and class helpers; consume those instead of pasting hex values.

`super_demo.exs` and `style_gallery.exs` are deliberate styling showcases and
are exempt. `hello_world.exs` stays self-contained (no support requires) so the
bring-up smoke test has zero moving parts.

## Palette

One light neutral ramp plus a single accent. Nothing else.

| Role           | Value     | Notes                              |
| -------------- | --------- | ---------------------------------- |
| Window         | `#f5f5f7` | Window/root background             |
| Surface        | `#ffffff` | Lists, inputs, button faces        |
| Hover          | `#ececf0` | Hover fill for surface controls    |
| Border         | `#d2d2d7` | Hairlines and control borders      |
| Text           | `#1d1d1f` | Primary text                       |
| Secondary text | `#6e6e73` | Captions, status lines             |
| Accent         | `#007aff` | Primary buttons, selection, links  |
| Accent hover   | `#0070e8` | Hover fill for accent controls     |

## Type scale

- `text-lg font-semibold` — window/section title (one per window, optional)
- `text-sm` — body and control labels
- `text-xs text-[#6e6e73]` — captions and status lines
- Large numerals in tiny demos may use `text-3xl font-semibold`

Sentence case for labels. No `font-black`.

## Spacing and grouping

- Window padding `p-5` (class form) or `:p_4` (style-op lists support fewer
  steps); `gap-4` between groups, `gap-2` within a group
- Group with whitespace first; use a hairline border or a surface panel only
  when content needs real separation (a list, an input cluster)
- No card-in-card nesting, no `rounded-xl` chrome, no shadows on static
  content; `rounded-md` is the default corner radius

## Controls

- Button: `px-3 py-1 rounded-md border-1 border-[#d2d2d7] bg-[#ffffff] text-sm`
  with `hover_class="bg-[#ececf0]"`
- Primary button: accent face, white text, same metrics
- One primary action per window at most

## Things that read as AI slop — do not add

- Hero panel with a title and subtitle restating the file name
- A "what this example shows" info panel with colored dot bullets
- The same dark slate dashboard palette on every screen
- Shadows, borders, and rounded-xl on everything by default
- Startup `IO.puts` diagnostics dumps (`hello_world.exs` is the one exception;
  it exists to print bring-up status)
