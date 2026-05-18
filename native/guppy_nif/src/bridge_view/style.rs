use crate::ir::{
    ColorToken, DisplayStyle, DivStyle, LinearGradientStop, MouseCursorStyle, OverflowStyle,
    PositionStyle, StyleAxis, StyleColor, StyleLength, StyleOp, VisibilityStyle,
};
use gpui::{
    DefiniteLength, FontStyle, FontWeight, HighlightStyle, Length, StatefulInteractiveElement,
    StrikethroughStyle, StyleRefinement, Styled, UnderlineStyle, linear_color_stop,
    linear_gradient, px, relative, rems, rgb,
};

pub(crate) fn apply_div_style<E>(mut element: E, style: &DivStyle) -> E
where
    E: Styled + StatefulInteractiveElement,
{
    for op in style.iter() {
        element = match apply_refinement_supported_style_op(element, op) {
            StyleApplication::Applied(element) => element,
            StyleApplication::Unsupported(element) => apply_div_only_style_op(element, op),
        };
    }

    element
}

enum StyleApplication<T> {
    Applied(T),
    Unsupported(T),
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum LengthStyleProperty {
    Width,
    Height,
    Size,
    MinWidth,
    MinHeight,
    MaxWidth,
    MaxHeight,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RefinementStyleSupport {
    Supported,
    Unsupported,
}

fn refinement_style_support(op: &StyleOp) -> RefinementStyleSupport {
    // Refinement styles are used for pseudo-state overlays such as hover/focus. These ops are
    // deliberately element-only because applying them from a refinement can relayout, reposition,
    // resize, or mutate interactive scroll behavior instead of only changing state presentation.
    match op {
        StyleOp::Grid
        | StyleOp::Flex
        | StyleOp::FlexCol
        | StyleOp::FlexRow
        | StyleOp::FlexWrap
        | StyleOp::FlexNowrap
        | StyleOp::FlexNone
        | StyleOp::FlexAuto
        | StyleOp::FlexGrow
        | StyleOp::FlexShrink
        | StyleOp::FlexShrink0
        | StyleOp::Flex1
        | StyleOp::ColSpanFull
        | StyleOp::RowSpanFull
        | StyleOp::SizeFull
        | StyleOp::WFull
        | StyleOp::HFull
        | StyleOp::W32
        | StyleOp::W64
        | StyleOp::W96
        | StyleOp::H32
        | StyleOp::MinW32
        | StyleOp::MinH0
        | StyleOp::MinHFull
        | StyleOp::MaxW64
        | StyleOp::MaxW96
        | StyleOp::MaxWFull
        | StyleOp::MaxH32
        | StyleOp::MaxH96
        | StyleOp::MaxHFull
        | StyleOp::Gap1
        | StyleOp::Gap2
        | StyleOp::Gap4
        | StyleOp::P1
        | StyleOp::P2
        | StyleOp::P4
        | StyleOp::P6
        | StyleOp::P8
        | StyleOp::Px2
        | StyleOp::Py2
        | StyleOp::Pt2
        | StyleOp::Pr2
        | StyleOp::Pb2
        | StyleOp::Pl2
        | StyleOp::M2
        | StyleOp::Mx2
        | StyleOp::My2
        | StyleOp::Mt2
        | StyleOp::Mr2
        | StyleOp::Mb2
        | StyleOp::Ml2
        | StyleOp::Relative
        | StyleOp::Absolute
        | StyleOp::Top0
        | StyleOp::Right0
        | StyleOp::Bottom0
        | StyleOp::Left0
        | StyleOp::Inset0
        | StyleOp::Top1
        | StyleOp::Right1
        | StyleOp::Top2
        | StyleOp::Right2
        | StyleOp::Bottom2
        | StyleOp::Left2
        | StyleOp::OverflowScroll
        | StyleOp::OverflowXScroll
        | StyleOp::OverflowYScroll
        | StyleOp::OverflowHidden
        | StyleOp::OverflowXHidden
        | StyleOp::OverflowYHidden
        | StyleOp::Padding { .. }
        | StyleOp::Margin { .. }
        | StyleOp::Gap { .. }
        | StyleOp::Width(_)
        | StyleOp::Height(_)
        | StyleOp::Size(_)
        | StyleOp::MinWidth(_)
        | StyleOp::MinHeight(_)
        | StyleOp::MaxWidth(_)
        | StyleOp::MaxHeight(_)
        | StyleOp::Position(_)
        | StyleOp::Inset { .. }
        | StyleOp::Display(_)
        | StyleOp::Overflow { .. }
        | StyleOp::GridCols(_)
        | StyleOp::GridRows(_)
        | StyleOp::ColSpan(_)
        | StyleOp::RowSpan(_)
        | StyleOp::ScrollbarWidthPx(_)
        | StyleOp::ScrollbarWidthRem(_) => RefinementStyleSupport::Unsupported,
        StyleOp::TextLeft
        | StyleOp::TextCenter
        | StyleOp::TextRight
        | StyleOp::WhitespaceNormal
        | StyleOp::WhitespaceNowrap
        | StyleOp::Truncate
        | StyleOp::TextEllipsis
        | StyleOp::LineClamp2
        | StyleOp::LineClamp3
        | StyleOp::TextXs
        | StyleOp::TextSm
        | StyleOp::TextBase
        | StyleOp::TextLg
        | StyleOp::TextXl
        | StyleOp::Text2xl
        | StyleOp::Text3xl
        | StyleOp::LeadingNone
        | StyleOp::LeadingTight
        | StyleOp::LeadingSnug
        | StyleOp::LeadingNormal
        | StyleOp::LeadingRelaxed
        | StyleOp::LeadingLoose
        | StyleOp::FontThin
        | StyleOp::FontExtralight
        | StyleOp::FontLight
        | StyleOp::FontNormal
        | StyleOp::FontMedium
        | StyleOp::FontSemibold
        | StyleOp::FontBold
        | StyleOp::FontExtrabold
        | StyleOp::FontBlack
        | StyleOp::Italic
        | StyleOp::NotItalic
        | StyleOp::Underline
        | StyleOp::LineThrough
        | StyleOp::ItemsStart
        | StyleOp::ItemsCenter
        | StyleOp::ItemsEnd
        | StyleOp::JustifyStart
        | StyleOp::JustifyCenter
        | StyleOp::JustifyEnd
        | StyleOp::JustifyBetween
        | StyleOp::JustifyAround
        | StyleOp::CursorPointer
        | StyleOp::RoundedSm
        | StyleOp::RoundedMd
        | StyleOp::RoundedLg
        | StyleOp::RoundedXl
        | StyleOp::Rounded2xl
        | StyleOp::RoundedFull
        | StyleOp::Border1
        | StyleOp::Border2
        | StyleOp::BorderDashed
        | StyleOp::BorderT1
        | StyleOp::BorderR1
        | StyleOp::BorderB1
        | StyleOp::BorderL1
        | StyleOp::ShadowSm
        | StyleOp::ShadowMd
        | StyleOp::ShadowLg
        | StyleOp::Visibility(_)
        | StyleOp::Cursor(_)
        | StyleOp::Bg(_)
        | StyleOp::TextColor(_)
        | StyleOp::BorderColor(_)
        | StyleOp::BgHex(_)
        | StyleOp::TextColorHex(_)
        | StyleOp::BorderColorHex(_)
        | StyleOp::BgLinearGradient { .. }
        | StyleOp::Opacity(_)
        | StyleOp::WPx(_)
        | StyleOp::WRem(_)
        | StyleOp::WFrac(_)
        | StyleOp::HPx(_)
        | StyleOp::HRem(_)
        | StyleOp::HFrac(_) => RefinementStyleSupport::Supported,
    }
}

fn apply_refinement_supported_style_op<T>(style: T, op: &StyleOp) -> StyleApplication<T>
where
    T: Styled,
{
    if refinement_style_support(op) != RefinementStyleSupport::Supported {
        return StyleApplication::Unsupported(style);
    }

    let style = match op {
        StyleOp::TextLeft => style.text_left(),
        StyleOp::TextCenter => style.text_center(),
        StyleOp::TextRight => style.text_right(),
        StyleOp::WhitespaceNormal => style.whitespace_normal(),
        StyleOp::WhitespaceNowrap => style.whitespace_nowrap(),
        StyleOp::Truncate => style.truncate(),
        StyleOp::TextEllipsis => style.text_ellipsis(),
        StyleOp::LineClamp2 => style.line_clamp(2),
        StyleOp::LineClamp3 => style.line_clamp(3),
        StyleOp::TextXs => style.text_xs(),
        StyleOp::TextSm => style.text_sm(),
        StyleOp::TextBase => style.text_base(),
        StyleOp::TextLg => style.text_lg(),
        StyleOp::TextXl => style.text_xl(),
        StyleOp::Text2xl => style.text_2xl(),
        StyleOp::Text3xl => style.text_3xl(),
        StyleOp::LeadingNone => style.line_height(relative(1.0)),
        StyleOp::LeadingTight => style.line_height(relative(1.25)),
        StyleOp::LeadingSnug => style.line_height(relative(1.375)),
        StyleOp::LeadingNormal => style.line_height(relative(1.5)),
        StyleOp::LeadingRelaxed => style.line_height(relative(1.625)),
        StyleOp::LeadingLoose => style.line_height(relative(2.0)),
        StyleOp::FontThin => style.font_weight(FontWeight::THIN),
        StyleOp::FontExtralight => style.font_weight(FontWeight::EXTRA_LIGHT),
        StyleOp::FontLight => style.font_weight(FontWeight::LIGHT),
        StyleOp::FontNormal => style.font_weight(FontWeight::NORMAL),
        StyleOp::FontMedium => style.font_weight(FontWeight::MEDIUM),
        StyleOp::FontSemibold => style.font_weight(FontWeight::SEMIBOLD),
        StyleOp::FontBold => style.font_weight(FontWeight::BOLD),
        StyleOp::FontExtrabold => style.font_weight(FontWeight::EXTRA_BOLD),
        StyleOp::FontBlack => style.font_weight(FontWeight::BLACK),
        StyleOp::Italic => style.italic(),
        StyleOp::NotItalic => style.not_italic(),
        StyleOp::Underline => style.underline(),
        StyleOp::LineThrough => style.line_through(),
        StyleOp::ItemsStart => style.items_start(),
        StyleOp::ItemsCenter => style.items_center(),
        StyleOp::ItemsEnd => style.items_end(),
        StyleOp::JustifyStart => style.justify_start(),
        StyleOp::JustifyCenter => style.justify_center(),
        StyleOp::JustifyEnd => style.justify_end(),
        StyleOp::JustifyBetween => style.justify_between(),
        StyleOp::JustifyAround => style.justify_around(),
        StyleOp::CursorPointer => style.cursor_pointer(),
        StyleOp::RoundedSm => style.rounded_sm(),
        StyleOp::RoundedMd => style.rounded_md(),
        StyleOp::RoundedLg => style.rounded_lg(),
        StyleOp::RoundedXl => style.rounded_xl(),
        StyleOp::Rounded2xl => style.rounded_2xl(),
        StyleOp::RoundedFull => style.rounded_full(),
        StyleOp::Border1 => style.border_1(),
        StyleOp::Border2 => style.border_2(),
        StyleOp::BorderDashed => style.border_dashed(),
        StyleOp::BorderT1 => style.border_t_1(),
        StyleOp::BorderR1 => style.border_r_1(),
        StyleOp::BorderB1 => style.border_b_1(),
        StyleOp::BorderL1 => style.border_l_1(),
        StyleOp::ShadowSm => style.shadow_sm(),
        StyleOp::ShadowMd => style.shadow_md(),
        StyleOp::ShadowLg => style.shadow_lg(),
        StyleOp::Bg(color) => style.bg(color_token_to_color(*color)),
        StyleOp::TextColor(color) => style.text_color(color_token_to_color(*color)),
        StyleOp::BorderColor(color) => style.border_color(color_token_to_color(*color)),
        StyleOp::BgHex(value) => style.bg(hex_color_to_color(*value)),
        StyleOp::TextColorHex(value) => style.text_color(hex_color_to_color(*value)),
        StyleOp::BorderColorHex(value) => style.border_color(hex_color_to_color(*value)),
        StyleOp::BgLinearGradient { angle, from, to } => style.bg(linear_gradient(
            *angle,
            linear_gradient_stop_to_gpui(from),
            linear_gradient_stop_to_gpui(to),
        )),
        StyleOp::Opacity(value) => style.opacity(*value),
        StyleOp::Visibility(visibility) => apply_visibility(style, *visibility),
        StyleOp::Cursor(cursor) => apply_cursor(style, *cursor),
        StyleOp::WPx(value) => style.w(px(*value)),
        StyleOp::WRem(value) => style.w(rems(*value)),
        StyleOp::WFrac(value) => style.w(relative(*value)),
        StyleOp::HPx(value) => style.h(px(*value)),
        StyleOp::HRem(value) => style.h(rems(*value)),
        StyleOp::HFrac(value) => style.h(relative(*value)),
        _ => return StyleApplication::Unsupported(style),
    };

    StyleApplication::Applied(style)
}

fn apply_div_only_style_op<E>(element: E, op: &StyleOp) -> E
where
    E: Styled + StatefulInteractiveElement,
{
    match op {
        StyleOp::Grid => element.grid(),
        StyleOp::Flex => element.flex(),
        StyleOp::FlexCol => element.flex_col(),
        StyleOp::FlexRow => element.flex_row(),
        StyleOp::FlexWrap => element.flex_wrap(),
        StyleOp::FlexNowrap => element.flex_nowrap(),
        StyleOp::FlexNone => element.flex_none(),
        StyleOp::FlexAuto => element.flex_auto(),
        StyleOp::FlexGrow => element.flex_grow(),
        StyleOp::FlexShrink => element.flex_shrink(),
        StyleOp::FlexShrink0 => element.flex_shrink_0(),
        StyleOp::Flex1 => element.flex_1(),
        StyleOp::ColSpanFull => element.col_span_full(),
        StyleOp::RowSpanFull => element.row_span_full(),
        StyleOp::SizeFull => element.size_full(),
        StyleOp::WFull => element.w_full(),
        StyleOp::HFull => element.h_full(),
        StyleOp::W32 => element.w_32(),
        StyleOp::W64 => element.w_64(),
        StyleOp::W96 => element.w_96(),
        StyleOp::H32 => element.h_32(),
        StyleOp::MinW32 => element.min_w_32(),
        StyleOp::MinH0 => element.min_h_0(),
        StyleOp::MinHFull => element.min_h_full(),
        StyleOp::MaxW64 => element.max_w_64(),
        StyleOp::MaxW96 => element.max_w_96(),
        StyleOp::MaxWFull => element.max_w_full(),
        StyleOp::MaxH32 => element.max_h_32(),
        StyleOp::MaxH96 => element.max_h_96(),
        StyleOp::MaxHFull => element.max_h_full(),
        StyleOp::Gap1 => element.gap_1(),
        StyleOp::Gap2 => element.gap_2(),
        StyleOp::Gap4 => element.gap_4(),
        StyleOp::P1 => element.p_1(),
        StyleOp::P2 => element.p_2(),
        StyleOp::P4 => element.p_4(),
        StyleOp::P6 => element.p_6(),
        StyleOp::P8 => element.p_8(),
        StyleOp::Px2 => element.px_2(),
        StyleOp::Py2 => element.py_2(),
        StyleOp::Pt2 => element.pt_2(),
        StyleOp::Pr2 => element.pr_2(),
        StyleOp::Pb2 => element.pb_2(),
        StyleOp::Pl2 => element.pl_2(),
        StyleOp::M2 => element.m_2(),
        StyleOp::Mx2 => element.mx_2(),
        StyleOp::My2 => element.my_2(),
        StyleOp::Mt2 => element.mt_2(),
        StyleOp::Mr2 => element.mr_2(),
        StyleOp::Mb2 => element.mb_2(),
        StyleOp::Ml2 => element.ml_2(),
        StyleOp::Relative => element.relative(),
        StyleOp::Absolute => element.absolute(),
        StyleOp::Top0 => element.top_0(),
        StyleOp::Right0 => element.right_0(),
        StyleOp::Bottom0 => element.bottom_0(),
        StyleOp::Left0 => element.left_0(),
        StyleOp::Inset0 => element.inset_0(),
        StyleOp::Top1 => element.top_1(),
        StyleOp::Right1 => element.right_1(),
        StyleOp::Top2 => element.top_2(),
        StyleOp::Right2 => element.right_2(),
        StyleOp::Bottom2 => element.bottom_2(),
        StyleOp::Left2 => element.left_2(),
        StyleOp::OverflowScroll => element.overflow_scroll(),
        StyleOp::OverflowXScroll => element.overflow_x_scroll(),
        StyleOp::OverflowYScroll => element.overflow_y_scroll(),
        StyleOp::OverflowHidden => element.overflow_hidden(),
        StyleOp::OverflowXHidden => element.overflow_x_hidden(),
        StyleOp::OverflowYHidden => element.overflow_y_hidden(),
        StyleOp::GridCols(value) => element.grid_cols(*value),
        StyleOp::GridRows(value) => element.grid_rows(*value),
        StyleOp::ColSpan(value) => element.col_span(*value),
        StyleOp::RowSpan(value) => element.row_span(*value),
        StyleOp::ScrollbarWidthPx(value) => element.scrollbar_width(px(*value)),
        StyleOp::ScrollbarWidthRem(value) => element.scrollbar_width(rems(*value)),
        StyleOp::Padding { axis, length } => apply_padding(element, *axis, *length),
        StyleOp::Margin { axis, length } => apply_margin(element, *axis, *length),
        StyleOp::Gap { axis, length } => apply_gap(element, *axis, *length),
        StyleOp::Width(length) => apply_length_style(element, LengthStyleProperty::Width, *length),
        StyleOp::Height(length) => {
            apply_length_style(element, LengthStyleProperty::Height, *length)
        }
        StyleOp::Size(length) => apply_length_style(element, LengthStyleProperty::Size, *length),
        StyleOp::MinWidth(length) => {
            apply_length_style(element, LengthStyleProperty::MinWidth, *length)
        }
        StyleOp::MinHeight(length) => {
            apply_length_style(element, LengthStyleProperty::MinHeight, *length)
        }
        StyleOp::MaxWidth(length) => {
            apply_length_style(element, LengthStyleProperty::MaxWidth, *length)
        }
        StyleOp::MaxHeight(length) => {
            apply_length_style(element, LengthStyleProperty::MaxHeight, *length)
        }
        StyleOp::Position(position) => apply_position(element, *position),
        StyleOp::Inset { axis, length } => apply_inset(element, *axis, *length),
        StyleOp::Display(display) => apply_display(element, *display),
        StyleOp::Visibility(visibility) => apply_visibility(element, *visibility),
        StyleOp::Overflow { axis, behavior } => apply_overflow(element, *axis, *behavior),
        StyleOp::Cursor(cursor) => apply_cursor(element, *cursor),
        _ => element,
    }
}

fn apply_padding<E>(element: E, axis: StyleAxis, length: StyleLength) -> E
where
    E: Styled,
{
    let length = style_length_to_definite(length);

    match axis {
        StyleAxis::All => element.p(length),
        StyleAxis::X => element.px(length),
        StyleAxis::Y => element.py(length),
        StyleAxis::Top => element.pt(length),
        StyleAxis::Right => element.pr(length),
        StyleAxis::Bottom => element.pb(length),
        StyleAxis::Left => element.pl(length),
    }
}

fn apply_margin<E>(element: E, axis: StyleAxis, length: StyleLength) -> E
where
    E: Styled,
{
    let length = style_length_to_length(length);

    match axis {
        StyleAxis::All => element.m(length),
        StyleAxis::X => element.mx(length),
        StyleAxis::Y => element.my(length),
        StyleAxis::Top => element.mt(length),
        StyleAxis::Right => element.mr(length),
        StyleAxis::Bottom => element.mb(length),
        StyleAxis::Left => element.ml(length),
    }
}

fn apply_gap<E>(element: E, axis: StyleAxis, length: StyleLength) -> E
where
    E: Styled,
{
    let length = style_length_to_definite(length);

    match axis {
        StyleAxis::All => element.gap(length),
        StyleAxis::X => element.gap_x(length),
        StyleAxis::Y => element.gap_y(length),
        _ => element,
    }
}

fn apply_length_style<E>(element: E, property: LengthStyleProperty, length: StyleLength) -> E
where
    E: Styled,
{
    let length = style_length_to_length(length);

    match property {
        LengthStyleProperty::Width => element.w(length),
        LengthStyleProperty::Height => element.h(length),
        LengthStyleProperty::Size => element.size(length),
        LengthStyleProperty::MinWidth => element.min_w(length),
        LengthStyleProperty::MinHeight => element.min_h(length),
        LengthStyleProperty::MaxWidth => element.max_w(length),
        LengthStyleProperty::MaxHeight => element.max_h(length),
    }
}

fn apply_position<E>(element: E, position: PositionStyle) -> E
where
    E: Styled,
{
    match position {
        PositionStyle::Relative => element.relative(),
        PositionStyle::Absolute => element.absolute(),
    }
}

fn apply_inset<E>(element: E, axis: StyleAxis, length: StyleLength) -> E
where
    E: Styled,
{
    let length = style_length_to_length(length);

    match axis {
        StyleAxis::All => element.inset(length),
        StyleAxis::Top => element.top(length),
        StyleAxis::Right => element.right(length),
        StyleAxis::Bottom => element.bottom(length),
        StyleAxis::Left => element.left(length),
        _ => element,
    }
}

fn apply_display<E>(element: E, display: DisplayStyle) -> E
where
    E: Styled,
{
    match display {
        DisplayStyle::Block => element.block(),
        DisplayStyle::Flex => element.flex(),
        DisplayStyle::Grid => element.grid(),
        DisplayStyle::None => element.hidden(),
    }
}

fn apply_visibility<E>(element: E, visibility: VisibilityStyle) -> E
where
    E: Styled,
{
    match visibility {
        VisibilityStyle::Visible => element.visible(),
        VisibilityStyle::Hidden => element.invisible(),
    }
}

fn apply_overflow<E>(mut element: E, axis: StyleAxis, overflow: OverflowStyle) -> E
where
    E: Styled,
{
    let overflow = match overflow {
        OverflowStyle::Hidden => gpui::Overflow::Hidden,
        OverflowStyle::Scroll => gpui::Overflow::Scroll,
    };

    match axis {
        StyleAxis::All => {
            element.style().overflow.x = Some(overflow);
            element.style().overflow.y = Some(overflow);
        }
        StyleAxis::X => element.style().overflow.x = Some(overflow),
        StyleAxis::Y => element.style().overflow.y = Some(overflow),
        _ => {}
    }

    element
}

fn apply_cursor<E>(element: E, cursor: MouseCursorStyle) -> E
where
    E: Styled,
{
    element.cursor(mouse_cursor_to_gpui(cursor))
}

fn mouse_cursor_to_gpui(cursor: MouseCursorStyle) -> gpui::CursorStyle {
    match cursor {
        MouseCursorStyle::Default => gpui::CursorStyle::Arrow,
        MouseCursorStyle::Pointer => gpui::CursorStyle::PointingHand,
        MouseCursorStyle::Text => gpui::CursorStyle::IBeam,
        MouseCursorStyle::Move => gpui::CursorStyle::ClosedHand,
        MouseCursorStyle::NotAllowed => gpui::CursorStyle::OperationNotAllowed,
        MouseCursorStyle::ContextMenu => gpui::CursorStyle::ContextualMenu,
        MouseCursorStyle::Crosshair => gpui::CursorStyle::Crosshair,
        MouseCursorStyle::VerticalText => gpui::CursorStyle::IBeamCursorForVerticalLayout,
        MouseCursorStyle::Alias => gpui::CursorStyle::DragLink,
        MouseCursorStyle::Copy => gpui::CursorStyle::DragCopy,
        MouseCursorStyle::NoDrop => gpui::CursorStyle::OperationNotAllowed,
        MouseCursorStyle::Grab => gpui::CursorStyle::OpenHand,
        MouseCursorStyle::Grabbing => gpui::CursorStyle::ClosedHand,
        MouseCursorStyle::EwResize => gpui::CursorStyle::ResizeLeftRight,
        MouseCursorStyle::NsResize => gpui::CursorStyle::ResizeUpDown,
        MouseCursorStyle::NeswResize => gpui::CursorStyle::ResizeUpRightDownLeft,
        MouseCursorStyle::NwseResize => gpui::CursorStyle::ResizeUpLeftDownRight,
        MouseCursorStyle::ColResize => gpui::CursorStyle::ResizeColumn,
        MouseCursorStyle::RowResize => gpui::CursorStyle::ResizeRow,
        MouseCursorStyle::NResize => gpui::CursorStyle::ResizeUp,
        MouseCursorStyle::EResize => gpui::CursorStyle::ResizeRight,
        MouseCursorStyle::SResize => gpui::CursorStyle::ResizeDown,
        MouseCursorStyle::WResize => gpui::CursorStyle::ResizeLeft,
        MouseCursorStyle::None => gpui::CursorStyle::None,
    }
}

fn style_length_to_definite(length: StyleLength) -> DefiniteLength {
    match length {
        StyleLength::Px(value) => px(value).into(),
        StyleLength::Rem(value) => rems(value).into(),
        StyleLength::Fraction(value) => relative(value),
        StyleLength::Auto => px(0.0).into(),
    }
}

fn style_length_to_length(length: StyleLength) -> Length {
    match length {
        StyleLength::Px(value) => px(value).into(),
        StyleLength::Rem(value) => rems(value).into(),
        StyleLength::Fraction(value) => relative(value).into(),
        StyleLength::Auto => Length::Auto,
    }
}

pub(crate) fn style_ops_to_highlight_style(ops: &DivStyle) -> HighlightStyle {
    let mut highlight = HighlightStyle::default();

    for op in ops.iter() {
        match op {
            StyleOp::TextColor(color) => highlight.color = Some(color_token_to_color(*color)),
            StyleOp::TextColorHex(value) => highlight.color = Some(hex_color_to_color(*value)),
            StyleOp::Bg(color) => {
                highlight.background_color = Some(color_token_to_color(*color));
            }
            StyleOp::BgHex(value) => highlight.background_color = Some(hex_color_to_color(*value)),
            StyleOp::FontThin => highlight.font_weight = Some(FontWeight::THIN),
            StyleOp::FontExtralight => highlight.font_weight = Some(FontWeight::EXTRA_LIGHT),
            StyleOp::FontLight => highlight.font_weight = Some(FontWeight::LIGHT),
            StyleOp::FontNormal => highlight.font_weight = Some(FontWeight::NORMAL),
            StyleOp::FontMedium => highlight.font_weight = Some(FontWeight::MEDIUM),
            StyleOp::FontSemibold => highlight.font_weight = Some(FontWeight::SEMIBOLD),
            StyleOp::FontBold => highlight.font_weight = Some(FontWeight::BOLD),
            StyleOp::FontExtrabold => highlight.font_weight = Some(FontWeight::EXTRA_BOLD),
            StyleOp::FontBlack => highlight.font_weight = Some(FontWeight::BLACK),
            StyleOp::Italic => highlight.font_style = Some(FontStyle::Italic),
            StyleOp::NotItalic => highlight.font_style = Some(FontStyle::Normal),
            StyleOp::Underline => {
                highlight.underline = Some(UnderlineStyle {
                    thickness: px(1.0),
                    color: None,
                    wavy: false,
                });
            }
            StyleOp::LineThrough => {
                highlight.strikethrough = Some(StrikethroughStyle {
                    thickness: px(1.0),
                    color: None,
                });
            }
            StyleOp::Opacity(value) => highlight.fade_out = Some(1.0 - value.clamp(0.0, 1.0)),
            _ => {}
        }
    }

    highlight
}

pub(crate) fn apply_refinement_style(
    mut style: StyleRefinement,
    ops: &DivStyle,
) -> StyleRefinement {
    for op in ops.iter() {
        style = match apply_refinement_supported_style_op(style, op) {
            StyleApplication::Applied(style) | StyleApplication::Unsupported(style) => style,
        };
    }

    style
}

fn color_token_to_color(color: ColorToken) -> gpui::Hsla {
    match color {
        ColorToken::Red => rgb(0xff0000).into(),
        ColorToken::Green => rgb(0x00ff00).into(),
        ColorToken::Blue => rgb(0x0000ff).into(),
        ColorToken::Yellow => rgb(0xffff00).into(),
        ColorToken::Black => rgb(0x000000).into(),
        ColorToken::White => rgb(0xffffff).into(),
        ColorToken::Gray => rgb(0x505050).into(),
    }
}

pub(crate) fn style_color_to_color(color: &StyleColor) -> gpui::Hsla {
    match color {
        StyleColor::Token(color) => color_token_to_color(*color),
        StyleColor::Hex(value) => hex_color_to_color(*value),
    }
}

fn linear_gradient_stop_to_gpui(stop: &LinearGradientStop) -> gpui::LinearColorStop {
    linear_color_stop(style_color_to_color(&stop.color), stop.percentage)
}

fn hex_color_to_color(value: u32) -> gpui::Hsla {
    rgb(value).into()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ir::{LinearGradientStop, StyleColor};
    use gpui::{Fill, StyleRefinement, linear_color_stop, linear_gradient};

    #[test]
    fn applies_canonical_box_spacing_to_style_refinement() {
        let style = apply_padding(
            StyleRefinement::default(),
            StyleAxis::Y,
            StyleLength::Rem(0.25),
        );

        assert_eq!(style.padding.top, Some(DefiniteLength::from(rems(0.25))));
        assert_eq!(style.padding.bottom, Some(DefiniteLength::from(rems(0.25))));
        assert_eq!(style.padding.left, None);
        assert_eq!(style.padding.right, None);

        let style = apply_margin(StyleRefinement::default(), StyleAxis::X, StyleLength::Auto);
        assert_eq!(style.margin.left, Some(Length::Auto));
        assert_eq!(style.margin.right, Some(Length::Auto));
        assert_eq!(style.margin.top, None);
        assert_eq!(style.margin.bottom, None);

        let style = apply_gap(
            StyleRefinement::default(),
            StyleAxis::All,
            StyleLength::Px(-1.0),
        );
        assert_eq!(style.gap.width, Some(DefiniteLength::from(px(-1.0))));
        assert_eq!(style.gap.height, Some(DefiniteLength::from(px(-1.0))));

        let style = apply_length_style(
            StyleRefinement::default(),
            LengthStyleProperty::Width,
            StyleLength::Fraction(1.0),
        );
        assert_eq!(style.size.width, Some(Length::Definite(relative(1.0))));

        let style = apply_length_style(
            StyleRefinement::default(),
            LengthStyleProperty::Height,
            StyleLength::Auto,
        );
        assert_eq!(style.size.height, Some(Length::Auto));

        let style = apply_position(StyleRefinement::default(), PositionStyle::Absolute);
        assert_eq!(style.position, Some(gpui::Position::Absolute));

        let style = apply_inset(
            StyleRefinement::default(),
            StyleAxis::Top,
            StyleLength::Rem(-0.5),
        );
        assert_eq!(style.inset.top, Some(Length::Definite(rems(-0.5).into())));

        let style = apply_display(StyleRefinement::default(), DisplayStyle::Flex);
        assert_eq!(style.display, Some(gpui::Display::Flex));

        let style = apply_visibility(StyleRefinement::default(), VisibilityStyle::Hidden);
        assert_eq!(style.visibility, Some(gpui::Visibility::Hidden));

        let style = apply_overflow(
            StyleRefinement::default(),
            StyleAxis::X,
            OverflowStyle::Scroll,
        );
        assert_eq!(style.overflow.x, Some(gpui::Overflow::Scroll));

        let style = apply_cursor(StyleRefinement::default(), MouseCursorStyle::NotAllowed);
        assert_eq!(
            style.mouse_cursor,
            Some(gpui::CursorStyle::OperationNotAllowed)
        );
    }

    #[test]
    fn applies_bg_linear_gradient_to_refinement_background() {
        let ops = vec![
            StyleOp::Bg(ColorToken::Gray),
            StyleOp::BgLinearGradient {
                angle: 90.0,
                from: LinearGradientStop {
                    color: StyleColor::Hex(0x0f172a),
                    percentage: 0.0,
                },
                to: LinearGradientStop {
                    color: StyleColor::Hex(0x2563eb),
                    percentage: 1.0,
                },
            },
        ]
        .into();

        let style = apply_refinement_style(StyleRefinement::default(), &ops);

        assert_eq!(
            style.background,
            Some(Fill::from(linear_gradient(
                90.0,
                linear_color_stop(rgb(0x0f172a), 0.0),
                linear_color_stop(rgb(0x2563eb), 1.0),
            )))
        );
    }

    #[test]
    fn refinement_style_ignores_documented_layout_and_interactive_ops() {
        let ops = vec![
            StyleOp::Flex,
            StyleOp::GridCols(3),
            StyleOp::OverflowHidden,
            StyleOp::ScrollbarWidthPx(12.0),
            StyleOp::TextColor(ColorToken::Red),
        ]
        .into();

        let style = apply_refinement_style(StyleRefinement::default(), &ops);

        assert_eq!(style.display, None);
        assert_eq!(style.grid_cols, None);
        assert_eq!(
            style.text.as_ref().and_then(|text| text.color),
            Some(rgb(0xff0000).into())
        );
    }
}
