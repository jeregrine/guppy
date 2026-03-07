use crate::ir::{ColorToken, DivStyle, IrNode, StyleOp};
use gpui::{
    AnyElement, Context, InteractiveElement, InteractiveText, SharedString,
    StatefulInteractiveElement, Styled, StyledText, Window, div, prelude::*, rgb,
};

unsafe extern "C" {
    fn guppy_c_send_click_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
    ) -> i32;
}

pub struct BridgeView {
    pub view_id: u64,
    pub ir: IrNode,
}

impl Render for BridgeView {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .size_full()
            .p_6()
            .bg(rgb(0x202020))
            .text_color(rgb(0xffffff))
            .child(render_ir(self.view_id, "root", &self.ir))
    }
}

fn render_ir(view_id: u64, path: &str, ir: &IrNode) -> AnyElement {
    match ir {
        IrNode::Text { id, content, click } => {
            render_text(view_id, path, id.as_deref(), content, click.as_deref())
        }
        IrNode::Div {
            id,
            style,
            children,
            click,
        } => render_div(view_id, path, id.as_deref(), style, children, click.as_deref()),
    }
}

fn render_text(
    view_id: u64,
    path: &str,
    id: Option<&str>,
    content: &str,
    click: Option<&str>,
) -> AnyElement {
    let node_id = node_id(view_id, path, id);
    let interactive_text = InteractiveText::new(
        SharedString::from(node_id.clone()),
        StyledText::new(content.to_owned()),
    );

    match click {
        Some(callback_id) if !content.is_empty() => {
            let callback_id = callback_id.to_owned();
            let click_node_id = node_id.clone();

            interactive_text
                .on_click(vec![0..content.len()], move |_, _, _| unsafe {
                    let _ = guppy_c_send_click_event(
                        view_id,
                        click_node_id.as_ptr(),
                        click_node_id.len(),
                        callback_id.as_ptr(),
                        callback_id.len(),
                    );
                })
                .into_any_element()
        }
        _ => interactive_text.into_any_element(),
    }
}

fn render_div(
    view_id: u64,
    path: &str,
    id: Option<&str>,
    style: &DivStyle,
    children: &[IrNode],
    click: Option<&str>,
) -> AnyElement {
    let child_elements = children
        .iter()
        .enumerate()
        .map(|(index, child)| render_ir(view_id, &format!("{path}.{index}"), child))
        .collect::<Vec<_>>();

    let node_id = node_id(view_id, path, id);
    let styled_div = apply_div_style(
        div()
            .id(SharedString::from(node_id.clone()))
            .children(child_elements),
        style,
    );

    match click {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let click_node_id = node_id.clone();

            styled_div
                .active(|style| style.opacity(0.85))
                .on_click(move |_, _, _| unsafe {
                    let _ = guppy_c_send_click_event(
                        view_id,
                        click_node_id.as_ptr(),
                        click_node_id.len(),
                        callback_id.as_ptr(),
                        callback_id.len(),
                    );
                })
                .into_any_element()
        }
        None => styled_div.into_any_element(),
    }
}

fn apply_div_style<E>(mut element: E, style: &DivStyle) -> E
where
    E: Styled + InteractiveElement + StatefulInteractiveElement,
{
    for op in style {
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
            StyleOp::MaxH32 => element.max_h_32(),
            StyleOp::MaxH96 => element.max_h_96(),
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
            StyleOp::ItemsStart => element.items_start(),
            StyleOp::ItemsCenter => element.items_center(),
            StyleOp::ItemsEnd => element.items_end(),
            StyleOp::JustifyStart => element.justify_start(),
            StyleOp::JustifyCenter => element.justify_center(),
            StyleOp::JustifyEnd => element.justify_end(),
            StyleOp::JustifyBetween => element.justify_between(),
            StyleOp::JustifyAround => element.justify_around(),
            StyleOp::CursorPointer => element.cursor_pointer(),
            StyleOp::RoundedMd => element.rounded_md(),
            StyleOp::Border1 => element.border_1(),
            StyleOp::OverflowScroll => element.overflow_scroll(),
            StyleOp::OverflowXScroll => element.overflow_x_scroll(),
            StyleOp::OverflowYScroll => element.overflow_y_scroll(),
            StyleOp::OverflowHidden => element.overflow_hidden(),
            StyleOp::OverflowXHidden => element.overflow_x_hidden(),
            StyleOp::OverflowYHidden => element.overflow_y_hidden(),
            StyleOp::Bg(color) => element.bg(color_token_to_color(*color)),
            StyleOp::TextColor(color) => element.text_color(color_token_to_color(*color)),
            StyleOp::BorderColor(color) => element.border_color(color_token_to_color(*color)),
        };
    }

    element
}

fn node_id(view_id: u64, path: &str, id: Option<&str>) -> String {
    match id {
        Some(id) => id.to_owned(),
        None => format!("guppy-{view_id}-{path}"),
    }
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
