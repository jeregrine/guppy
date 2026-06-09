use super::{BridgeView, render_choice, render_pass::RenderPass};
use crate::{ir::CheckboxNode, native_events};
use gpui::{AnyElement, Context, IntoElement, ParentElement, Styled, Window, div, px, rgb};

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    node: &CheckboxNode,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let next_checked = !node.checked;

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
        checkbox_indicator(node.checked, node.disabled),
        render_choice::choice_label(&node.label),
        move |view_id, node_id, callback_id| {
            let _ = native_events::send_checkbox_change_event(
                view_id,
                node_id,
                callback_id,
                next_checked,
            );
        },
        window,
        cx,
    )
}

pub(crate) fn checkbox_indicator(checked: bool, disabled: bool) -> AnyElement {
    div()
        .w(px(16.0))
        .h(px(16.0))
        .flex()
        .items_center()
        .justify_center()
        .border_1()
        .rounded_sm()
        .border_color(rgb(render_choice::indicator_border_color(disabled)))
        .bg(rgb(render_choice::indicator_fill_color(checked, disabled)))
        .text_color(rgb(render_choice::glyph_color(disabled)))
        .child(if checked { "✓" } else { "" })
        .into_any_element()
}
