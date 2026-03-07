# Missing IR Features

This is a working checklist of GPUI capabilities that Guppy.IR does not fully expose yet.

It is not a promise of exact API shape. Some GPUI capabilities may land in Guppy as style tokens, some as first-class IR node kinds, and some as higher-level components.

The goal is to add these incrementally:

1. add one feature at a time
2. update an example to exercise it
3. add or expand tests
4. validate before moving on

## Current implemented subset

Guppy.IR currently supports an ordered style-op list, not a style map. Later ops are applied after earlier ops.

Guppy.IR currently supports:

- nodes:
  - `:div`
  - `:text`
- ids:
  - `id`
- events:
  - `click`
- style tokens:
  - `flex`
  - `flex_col`
  - `flex_row`
  - `flex_wrap`
  - `flex_nowrap`
  - `flex_none`
  - `flex_auto`
  - `flex_grow`
  - `flex_shrink`
  - `flex_shrink_0`
  - `flex_1`
  - `size_full`
  - `w_full`
  - `h_full`
  - `w_32`
  - `w_64`
  - `w_96`
  - `h_32`
  - `min_w_32`
  - `min_h_full`
  - `max_w_64`
  - `max_w_96`
  - `max_w_full`
  - `max_h_32`
  - `max_h_96`
  - `max_h_full`
  - `gap_1`
  - `gap_2`
  - `gap_4`
  - `p_1`
  - `p_2`
  - `p_4`
  - `p_6`
  - `p_8`
  - `px_2`
  - `py_2`
  - `pt_2`
  - `pr_2`
  - `pb_2`
  - `pl_2`
  - `m_2`
  - `mx_2`
  - `my_2`
  - `mt_2`
  - `mr_2`
  - `mb_2`
  - `ml_2`
  - `relative`
  - `absolute`
  - `top_0`
  - `right_0`
  - `bottom_0`
  - `left_0`
  - `inset_0`
  - `top_1`
  - `right_1`
  - `top_2`
  - `right_2`
  - `bottom_2`
  - `left_2`
  - `text_left`
  - `text_center`
  - `text_right`
  - `whitespace_normal`
  - `whitespace_nowrap`
  - `truncate`
  - `text_ellipsis`
  - `line_clamp_2`
  - `line_clamp_3`
  - `text_xs`
  - `text_sm`
  - `text_base`
  - `text_lg`
  - `text_xl`
  - `text_2xl`
  - `text_3xl`
  - `leading_none`
  - `leading_tight`
  - `leading_snug`
  - `leading_normal`
  - `leading_relaxed`
  - `leading_loose`
  - `font_thin`
  - `font_extralight`
  - `font_light`
  - `font_normal`
  - `font_medium`
  - `font_semibold`
  - `font_bold`
  - `font_extrabold`
  - `font_black`
  - `italic`
  - `not_italic`
  - `underline`
  - `line_through`
  - `rounded_sm`
  - `rounded_lg`
  - `rounded_xl`
  - `rounded_2xl`
  - `rounded_full`
  - `border_2`
  - `border_dashed`
  - `border_t_1`
  - `border_r_1`
  - `border_b_1`
  - `border_l_1`
  - `shadow_sm`
  - `shadow_md`
  - `shadow_lg`
  - `items_start`
  - `items_center`
  - `items_end`
  - `justify_start`
  - `justify_center`
  - `justify_end`
  - `justify_between`
  - `justify_around`
  - `cursor_pointer`
  - `rounded_md`
  - `border_1`
  - `overflow_scroll`
  - `overflow_x_scroll`
  - `overflow_y_scroll`
  - `overflow_hidden`
  - `overflow_x_hidden`
  - `overflow_y_hidden`
  - `{:bg, color}`
  - `{:text_color, color}`
  - `{:border_color, color}`
  - `{:bg_hex, "#RRGGBB"}`
  - `{:text_color_hex, "#RRGGBB"}`
  - `{:border_color_hex, "#RRGGBB"}`
  - `{:opacity, number}`
  - `{:w_px, number}`
  - `{:w_rem, number}`
  - `{:w_frac, number}`
  - `{:h_px, number}`
  - `{:h_rem, number}`
  - `{:h_frac, number}`

## Priority order

The rough order below is chosen to improve layout correctness first, then text/layout ergonomics, then input richness.

## 1. Core sizing and layout constraints

- [x] `size_full`
- [x] `w_full`
- [x] `h_full`
- [x] `flex_row`
- [x] `flex_wrap`
- [x] `flex_nowrap`
- [x] `flex_none`
- [x] `flex_auto`
- [x] `flex_grow`
- [x] `flex_shrink`
- [x] `flex_shrink_0`
- [x] `items_start`
- [x] `items_end`
- [x] `justify_start`
- [x] `justify_end`
- [x] `justify_between`
- [x] `justify_around`
- [x] width tokens beyond `w_64`
- [x] height tokens
- [x] min width tokens
- [x] min height tokens
- [x] max width tokens
- [x] max height tokens
- [x] explicit pixel/rem/relative width values
- [x] explicit pixel/rem/relative height values

## 2. Overflow and scrolling

- [x] `overflow_scroll`
- [x] `overflow_x_scroll`
- [x] `overflow_hidden`
- [x] `overflow_x_hidden`
- [x] `overflow_y_hidden`
- [ ] `scrollbar_width`
- [ ] tracked scrolling / `track_scroll`
- [ ] scroll anchoring / `anchor_scroll`
- [ ] explicit scroll-container semantics if style tokens are not enough

## 3. Spacing and positioning

- [x] more gap tokens
- [x] more padding tokens
- [x] axis padding (`px_*`, `py_*`)
- [x] side padding (`pt_*`, `pr_*`, `pb_*`, `pl_*`)
- [x] margin tokens
- [x] axis margin (`mx_*`, `my_*`)
- [x] side margin (`mt_*`, `mr_*`, `mb_*`, `ml_*`)
- [x] `relative`
- [x] `absolute`
- [x] top/right/bottom/left inset tokens
- [ ] z-index / stacking controls

## 4. Text styling

- [x] text alignment (`text_left`, `text_center`, `text_right`)
- [x] whitespace control (`whitespace_normal`, `whitespace_nowrap`)
- [x] truncation (`truncate`, `text_ellipsis`)
- [x] line clamp
- [x] font size tokens
- [x] font weight tokens
- [x] font style / italic
- [x] line height tokens
- [ ] letter spacing
- [x] underline
- [x] strikethrough
- [ ] richer text runs/highlights

## 5. Visual styling

- [x] more border width tokens
- [x] side-specific borders
- [x] border style tokens
- [x] more radius tokens
- [x] opacity
- [x] box shadow / shadow tokens
- [x] richer color space / arbitrary colors
- [ ] theme/token-based colors beyond the current atoms

## 6. Interaction and events

- [ ] hover styles
- [ ] hover enter/leave events
- [ ] mouse down
- [ ] mouse up
- [ ] mouse move
- [ ] scroll wheel events
- [ ] keyboard key down
- [ ] keyboard key up
- [ ] focus/blur events
- [ ] right click / context menu event
- [ ] drag start
- [ ] drag move
- [ ] drop
- [ ] disabled state semantics
- [ ] active/focus state styling expressed in IR

## 7. Focus and keyboard participation

- [ ] `focusable`
- [ ] focus ring / focus styling hooks
- [ ] tab-order participation
- [ ] keyboard activation semantics
- [ ] action dispatch / shortcuts

## 8. Additional node kinds and higher-level primitives

- [ ] image node
- [ ] icon node
- [ ] spacer node
- [ ] explicit scroll node
- [ ] button node
- [ ] text input node
- [ ] textarea/editor node
- [ ] checkbox node
- [ ] radio/select primitives
- [ ] list / uniform list primitive
- [ ] tooltip / popover primitives

## Notes

- `size_full` was added first because the current super demo likely needs stronger layout constraints before scrolling will work correctly.
- If scrolling remains broken after the basic sizing/overflow tokens land, the next likely step is explicit tracked scroll support or a dedicated scroll-container node.
