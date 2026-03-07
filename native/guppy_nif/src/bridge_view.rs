use crate::ir::{ColorToken, DivStyle, IrNode};
use gpui::{
    AnyElement, Context, InteractiveElement, InteractiveText, SharedString, StatefulInteractiveElement, Styled, StyledText,
    Window, div, prelude::*, rgb,
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
    let interactive_text =
        InteractiveText::new(SharedString::from(node_id.clone()), StyledText::new(content.to_owned()));

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
    if style.flex {
        element = element.flex();
    }
    if style.flex_col {
        element = element.flex_col();
    }
    if style.size_full {
        element = element.size_full();
    }
    if style.w_full {
        element = element.w_full();
    }
    if style.h_full {
        element = element.h_full();
    }
    if style.flex_1 {
        element = element.flex_1();
    }
    if style.gap_2 {
        element = element.gap_2();
    }
    if style.p_2 {
        element = element.p_2();
    }
    if style.p_4 {
        element = element.p_4();
    }
    if style.p_6 {
        element = element.p_6();
    }
    if style.w_64 {
        element = element.w_64();
    }
    if style.items_center {
        element = element.items_center();
    }
    if style.justify_center {
        element = element.justify_center();
    }
    if style.cursor_pointer {
        element = element.cursor_pointer();
    }
    if style.rounded_md {
        element = element.rounded_md();
    }
    if style.border_1 {
        element = element.border_1();
    }
    if style.overflow_y_scroll {
        element = element.overflow_y_scroll();
    }
    if let Some(color) = style.bg {
        element = element.bg(color_token_to_color(color));
    }
    if let Some(color) = style.text_color {
        element = element.text_color(color_token_to_color(color));
    }
    if let Some(color) = style.border_color {
        element = element.border_color(color_token_to_color(color));
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
