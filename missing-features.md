# Missing IR Features

This is a working checklist of GPUI capabilities that Guppy.IR does not fully expose yet.

It is not a promise of exact API shape. Some GPUI capabilities may land in Guppy as style tokens, some as first-class IR node kinds, and some as higher-level components.

The goal is to add these incrementally:

1. add one feature at a time
2. update an example to exercise it
3. add or expand tests
4. validate before moving on

## Current implemented subset

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
  - `flex_1`
  - `size_full`
  - `w_full`
  - `h_full`
  - `gap_2`
  - `p_2`
  - `p_4`
  - `p_6`
  - `w_64`
  - `items_center`
  - `justify_center`
  - `cursor_pointer`
  - `rounded_md`
  - `border_1`
  - `overflow_y_scroll`
  - `bg`
  - `text_color`
  - `border_color`

## Priority order

The rough order below is chosen to improve layout correctness first, then text/layout ergonomics, then input richness.

## 1. Core sizing and layout constraints

- [x] `size_full`
- [x] `w_full`
- [x] `h_full`
- [ ] `flex_row`
- [ ] `flex_wrap`
- [ ] `flex_nowrap`
- [ ] `flex_none`
- [ ] `flex_auto`
- [ ] `flex_grow`
- [ ] `flex_shrink`
- [ ] `flex_shrink_0`
- [ ] `items_start`
- [ ] `items_end`
- [ ] `justify_start`
- [ ] `justify_end`
- [ ] `justify_between`
- [ ] `justify_around`
- [ ] width tokens beyond `w_64`
- [ ] height tokens
- [ ] min width tokens
- [ ] min height tokens
- [ ] max width tokens
- [ ] max height tokens
- [ ] explicit pixel/rem/relative width values
- [ ] explicit pixel/rem/relative height values

## 2. Overflow and scrolling

- [ ] `overflow_scroll`
- [ ] `overflow_x_scroll`
- [ ] `overflow_hidden`
- [ ] `overflow_x_hidden`
- [ ] `overflow_y_hidden`
- [ ] `scrollbar_width`
- [ ] tracked scrolling / `track_scroll`
- [ ] scroll anchoring / `anchor_scroll`
- [ ] explicit scroll-container semantics if style tokens are not enough

## 3. Spacing and positioning

- [ ] more gap tokens
- [ ] more padding tokens
- [ ] axis padding (`px_*`, `py_*`)
- [ ] side padding (`pt_*`, `pr_*`, `pb_*`, `pl_*`)
- [ ] margin tokens
- [ ] axis margin (`mx_*`, `my_*`)
- [ ] side margin (`mt_*`, `mr_*`, `mb_*`, `ml_*`)
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
