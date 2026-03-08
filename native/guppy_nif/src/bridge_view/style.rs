use crate::ir::{ColorToken, DivStyle, StyleOp};
use gpui::{
    FontWeight, StatefulInteractiveElement, StyleRefinement, Styled, px, relative, rems, rgb,
};

pub(crate) fn apply_div_style<E>(mut element: E, style: &DivStyle) -> E
where
    E: Styled + StatefulInteractiveElement,
{
    for op in style.iter() {
        element = match op {
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
            StyleOp::TextLeft => element.text_left(),
            StyleOp::TextCenter => element.text_center(),
            StyleOp::TextRight => element.text_right(),
            StyleOp::WhitespaceNormal => element.whitespace_normal(),
            StyleOp::WhitespaceNowrap => element.whitespace_nowrap(),
            StyleOp::Truncate => element.truncate(),
            StyleOp::TextEllipsis => element.text_ellipsis(),
            StyleOp::LineClamp2 => element.line_clamp(2),
            StyleOp::LineClamp3 => element.line_clamp(3),
            StyleOp::TextXs => element.text_xs(),
            StyleOp::TextSm => element.text_sm(),
            StyleOp::TextBase => element.text_base(),
            StyleOp::TextLg => element.text_lg(),
            StyleOp::TextXl => element.text_xl(),
            StyleOp::Text2xl => element.text_2xl(),
            StyleOp::Text3xl => element.text_3xl(),
            StyleOp::LeadingNone => element.line_height(relative(1.0)),
            StyleOp::LeadingTight => element.line_height(relative(1.25)),
            StyleOp::LeadingSnug => element.line_height(relative(1.375)),
            StyleOp::LeadingNormal => element.line_height(relative(1.5)),
            StyleOp::LeadingRelaxed => element.line_height(relative(1.625)),
            StyleOp::LeadingLoose => element.line_height(relative(2.0)),
            StyleOp::FontThin => element.font_weight(FontWeight::THIN),
            StyleOp::FontExtralight => element.font_weight(FontWeight::EXTRA_LIGHT),
            StyleOp::FontLight => element.font_weight(FontWeight::LIGHT),
            StyleOp::FontNormal => element.font_weight(FontWeight::NORMAL),
            StyleOp::FontMedium => element.font_weight(FontWeight::MEDIUM),
            StyleOp::FontSemibold => element.font_weight(FontWeight::SEMIBOLD),
            StyleOp::FontBold => element.font_weight(FontWeight::BOLD),
            StyleOp::FontExtrabold => element.font_weight(FontWeight::EXTRA_BOLD),
            StyleOp::FontBlack => element.font_weight(FontWeight::BLACK),
            StyleOp::Italic => element.italic(),
            StyleOp::NotItalic => element.not_italic(),
            StyleOp::Underline => element.underline(),
            StyleOp::LineThrough => element.line_through(),
            StyleOp::ItemsStart => element.items_start(),
            StyleOp::ItemsCenter => element.items_center(),
            StyleOp::ItemsEnd => element.items_end(),
            StyleOp::JustifyStart => element.justify_start(),
            StyleOp::JustifyCenter => element.justify_center(),
            StyleOp::JustifyEnd => element.justify_end(),
            StyleOp::JustifyBetween => element.justify_between(),
            StyleOp::JustifyAround => element.justify_around(),
            StyleOp::CursorPointer => element.cursor_pointer(),
            StyleOp::RoundedSm => element.rounded_sm(),
            StyleOp::RoundedMd => element.rounded_md(),
            StyleOp::RoundedLg => element.rounded_lg(),
            StyleOp::RoundedXl => element.rounded_xl(),
            StyleOp::Rounded2xl => element.rounded_2xl(),
            StyleOp::RoundedFull => element.rounded_full(),
            StyleOp::Border1 => element.border_1(),
            StyleOp::Border2 => element.border_2(),
            StyleOp::BorderDashed => element.border_dashed(),
            StyleOp::BorderT1 => element.border_t_1(),
            StyleOp::BorderR1 => element.border_r_1(),
            StyleOp::BorderB1 => element.border_b_1(),
            StyleOp::BorderL1 => element.border_l_1(),
            StyleOp::ShadowSm => element.shadow_sm(),
            StyleOp::ShadowMd => element.shadow_md(),
            StyleOp::ShadowLg => element.shadow_lg(),
            StyleOp::OverflowScroll => element.overflow_scroll(),
            StyleOp::OverflowXScroll => element.overflow_x_scroll(),
            StyleOp::OverflowYScroll => element.overflow_y_scroll(),
            StyleOp::OverflowHidden => element.overflow_hidden(),
            StyleOp::OverflowXHidden => element.overflow_x_hidden(),
            StyleOp::OverflowYHidden => element.overflow_y_hidden(),
            StyleOp::Bg(color) => element.bg(color_token_to_color(color.to_owned())),
            StyleOp::TextColor(color) => element.text_color(color_token_to_color(color.to_owned())),
            StyleOp::BorderColor(color) => {
                element.border_color(color_token_to_color(color.to_owned()))
            }
            StyleOp::BgHex(value) => element.bg(hex_color_to_color(value)),
            StyleOp::TextColorHex(value) => element.text_color(hex_color_to_color(value)),
            StyleOp::BorderColorHex(value) => element.border_color(hex_color_to_color(value)),
            StyleOp::Opacity(value) => element.opacity(value.to_owned()),
            StyleOp::WPx(value) => element.w(px(value.to_owned())),
            StyleOp::WRem(value) => element.w(rems(value.to_owned())),
            StyleOp::WFrac(value) => element.w(relative(value.to_owned())),
            StyleOp::HPx(value) => element.h(px(value.to_owned())),
            StyleOp::HRem(value) => element.h(rems(value.to_owned())),
            StyleOp::HFrac(value) => element.h(relative(value.to_owned())),
            StyleOp::ScrollbarWidthPx(value) => element.scrollbar_width(px(value.to_owned())),
            StyleOp::ScrollbarWidthRem(value) => element.scrollbar_width(rems(value.to_owned())),
        };
    }

    element
}

pub(crate) fn apply_refinement_style(
    mut style: StyleRefinement,
    ops: &DivStyle,
) -> StyleRefinement {
    for op in ops.iter() {
        style = match op {
            StyleOp::Flex
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
            | StyleOp::OverflowYHidden => style,
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
            StyleOp::Bg(color) => style.bg(color_token_to_color(color.to_owned())),
            StyleOp::TextColor(color) => style.text_color(color_token_to_color(color.to_owned())),
            StyleOp::BorderColor(color) => {
                style.border_color(color_token_to_color(color.to_owned()))
            }
            StyleOp::BgHex(value) => style.bg(hex_color_to_color(value)),
            StyleOp::TextColorHex(value) => style.text_color(hex_color_to_color(value)),
            StyleOp::BorderColorHex(value) => style.border_color(hex_color_to_color(value)),
            StyleOp::Opacity(value) => style.opacity(value.to_owned()),
            StyleOp::WPx(value) => style.w(px(value.to_owned())),
            StyleOp::WRem(value) => style.w(rems(value.to_owned())),
            StyleOp::WFrac(value) => style.w(relative(value.to_owned())),
            StyleOp::HPx(value) => style.h(px(value.to_owned())),
            StyleOp::HRem(value) => style.h(rems(value.to_owned())),
            StyleOp::HFrac(value) => style.h(relative(value.to_owned())),
            StyleOp::ScrollbarWidthPx(_) => style,
            StyleOp::ScrollbarWidthRem(_) => style,
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

fn hex_color_to_color(value: &str) -> gpui::Hsla {
    let normalized = value.trim_start_matches('#');
    let parsed = u32::from_str_radix(normalized, 16).unwrap_or(0xff00ff);
    rgb(parsed).into()
}
