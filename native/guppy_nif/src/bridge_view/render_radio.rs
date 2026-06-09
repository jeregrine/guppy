use super::{BridgeView, render_choice, render_pass::RenderPass};
use crate::{ir::RadioNode, native_events};
use gpui::{
    AnyElement, Context, IntoElement, KeyDownEvent, ParentElement, Styled, Window, div, px, rgb,
};

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    node: &RadioNode,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let value = node.value.clone();

    render_choice::render(
        pass,
        path,
        render_choice::ChoiceSpec {
            id: node.id.as_deref(),
            disabled: node.disabled,
            tab_index: node.tab_index,
            focus: node.focus.as_deref(),
            blur: node.blur.as_deref(),
            change: node.change.as_deref(),
            style: &node.style,
            hover_style: &node.hover_style,
            focus_style: &node.focus_style,
            focus_visible_style: &node.focus_visible_style,
            in_focus_style: &node.in_focus_style,
            active_style: &node.active_style,
            disabled_style: &node.disabled_style,
        },
        radio_indicator(node.checked, node.disabled),
        radio_label(node),
        move |view_id, node_id, callback_id| {
            let _ = native_events::send_change_event(view_id, node_id, callback_id, &value);
        },
        window,
        cx,
    )
}

pub(crate) fn radio_indicator(checked: bool, disabled: bool) -> AnyElement {
    let border = if disabled { 0x5b6472 } else { 0x94a3b8 };
    let fill = if checked {
        if disabled { 0x475569 } else { 0x2563eb }
    } else {
        0x0f172a
    };

    div()
        .w(px(16.0))
        .h(px(16.0))
        .flex()
        .items_center()
        .justify_center()
        .border_1()
        .rounded_full()
        .border_color(rgb(border))
        .child(div().w(px(8.0)).h(px(8.0)).rounded_full().bg(rgb(fill)))
        .into_any_element()
}

pub(crate) fn radio_label(node: &RadioNode) -> AnyElement {
    let text_color = if node.disabled { 0x94a3b8 } else { 0xe2e8f0 };

    div()
        .text_color(rgb(text_color))
        .child(node.label.clone())
        .into_any_element()
}

pub(crate) fn is_radio_toggle_key(event: &KeyDownEvent) -> bool {
    render_choice::is_choice_toggle_key(event)
}
