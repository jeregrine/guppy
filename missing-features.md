# Missing IR Features

This is the working checklist for Guppy.IR gaps.

It is not a promise of final API shape. Some items may land as style tokens, some as node fields, some as new node kinds, and some as higher-level components.

The goal is to keep one checklist, check items off as they land, and continue from the highest-value remaining gaps.

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
- [x] `scrollbar_width`
- [x] tracked scrolling / `track_scroll`
- [x] scroll anchoring / `anchor_scroll`
- [x] explicit scroll-container semantics if style tokens are not enough

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
- [x] z-index / stacking controls

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

- [x] hover styles
- [x] hover enter/leave events
- [x] mouse down
- [x] mouse up
- [x] mouse move
- [x] scroll wheel events
- [x] keyboard key down
- [x] keyboard key up
- [x] focus/blur events
- [x] right click / context menu event
- [x] drag start
- [x] drag move
- [x] drop
- [x] disabled state semantics
- [x] active/focus state styling expressed in IR

## 7. Focus and keyboard participation

- [x] `focusable`
- [x] focus ring / focus styling hooks
- [x] tab-order participation
- [x] keyboard activation semantics
- [x] action dispatch / shortcuts

## 8. Additional node kinds and higher-level primitives

- [x] image node
- [ ] icon node
- [x] spacer node
- [x] explicit scroll node
- [x] button node
- [x] text input node
- [ ] textarea/editor node
- [ ] checkbox node
- [ ] radio/select primitives
- [ ] list / uniform list primitive
- [ ] tooltip / popover primitives
