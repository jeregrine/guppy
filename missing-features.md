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
  - `max_h_32`
  - `max_h_96`
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
  - `w_64`
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
- [ ] min height tokens
- [ ] max width tokens
- [x] max height tokens
- [ ] explicit pixel/rem/relative width values
- [ ] explicit pixel/rem/relative height values

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
- [ ] `relative`
- [ ] `absolute`
- [ ] top/right/bottom/left inset tokens
- [ ] z-index / stacking controls

## 4. Text styling

- [ ] text alignment (`text_left`, `text_center`, `text_right`)
- [ ] whitespace control (`whitespace_normal`, `whitespace_nowrap`)
- [ ] truncation (`truncate`, `text_ellipsis`)
- [ ] line clamp
- [ ] font size tokens
- [ ] font weight tokens
- [ ] font style / italic
- [ ] line height tokens
- [ ] letter spacing
- [ ] underline
- [ ] strikethrough
- [ ] richer text runs/highlights

## 5. Visual styling

- [ ] more border width tokens
- [ ] side-specific borders
- [ ] border style tokens
- [ ] more radius tokens
- [ ] opacity
- [ ] box shadow / shadow tokens
- [ ] richer color space / arbitrary colors
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
