use super::{
    BridgeView,
    identity::NodeIdentity,
    render_pass::RenderPass,
    style::{apply_div_style, apply_refinement_style},
};
use crate::ir::CheckboxNode;
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, KeyDownEvent, ParentElement,
    StatefulInteractiveElement, Styled, Window, div, px, rgb,
};

unsafe extern "C" {
    fn guppy_c_send_checkbox_change_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
        checked: i32,
    ) -> i32;
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    node: &CheckboxNode,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, node.id.as_deref());
    let node_key = node_id.to_string();

    let focus_handle = if node.disabled {
        None
    } else {
        Some(pass.ensure_focus_handle(&node_key, cx, Some(true), node.tab_index))
    };

    if let Some(handle) = focus_handle.as_ref() {
        pass.register_focus_callbacks(
            &node_key,
            handle,
            node.focus.as_deref(),
            node.blur.as_deref(),
            window,
            cx,
        );
    }

    let indicator = checkbox_indicator(node.checked, node.disabled);
    let label = checkbox_label(node);

    let mut checkbox = apply_div_style(
        div()
            .id(node_id.to_shared_string())
            .flex()
            .flex_row()
            .items_center()
            .gap_2()
            .child(indicator)
            .child(label),
        &node.style,
    );

    if let Some(handle) = focus_handle.as_ref() {
        let handle = handle.clone();
        checkbox =
            checkbox
                .track_focus(&handle)
                .focusable()
                .on_any_mouse_down(move |_, window, _| {
                    handle.focus(window);
                });
    }

    if !node.disabled && !node.hover_style.is_empty() {
        let hover_ops = node.hover_style.clone();
        checkbox = checkbox.hover(move |style| apply_refinement_style(style, &hover_ops));
    }

    if !node.disabled && !node.focus_style.is_empty() {
        let focus_ops = node.focus_style.clone();
        checkbox = checkbox.focus(move |style| apply_refinement_style(style, &focus_ops));
    }

    if !node.disabled && !node.in_focus_style.is_empty() {
        let in_focus_ops = node.in_focus_style.clone();
        checkbox = checkbox.in_focus(move |style| apply_refinement_style(style, &in_focus_ops));
    }

    if !node.disabled && !node.active_style.is_empty() {
        let active_ops = node.active_style.clone();
        checkbox = checkbox.active(move |style| apply_refinement_style(style, &active_ops));
    }

    if node.disabled && !node.disabled_style.is_empty() {
        checkbox = apply_div_style(checkbox, &node.disabled_style);
    }

    if let Some(callback_id) = node.change.as_ref() {
        let click_callback_id = callback_id.clone();
        let click_node_id = node_key.clone();
        let next_checked = !node.checked;

        checkbox = checkbox.on_click(move |_, _, _| {
            emit_checkbox_change(view_id, &click_node_id, &click_callback_id, next_checked);
        });

        let key_callback_id = callback_id.clone();
        let key_node_id = node_key.clone();
        checkbox = checkbox.on_key_down(move |event: &KeyDownEvent, _, cx| {
            if is_checkbox_toggle_key(event) {
                emit_checkbox_change(view_id, &key_node_id, &key_callback_id, next_checked);
                cx.stop_propagation();
            }
        });
    }

    checkbox.into_any_element()
}

fn checkbox_indicator(checked: bool, disabled: bool) -> AnyElement {
    let border = if disabled { 0x5b6472 } else { 0x94a3b8 };
    let fill = if checked {
        if disabled { 0x475569 } else { 0x2563eb }
    } else {
        0x0f172a
    };
    let text = if disabled { 0xcbd5e1 } else { 0xffffff };

    div()
        .w(px(16.0))
        .h(px(16.0))
        .flex()
        .items_center()
        .justify_center()
        .border_1()
        .rounded_sm()
        .border_color(rgb(border))
        .bg(rgb(fill))
        .text_color(rgb(text))
        .child(if checked { "✓" } else { "" })
        .into_any_element()
}

fn checkbox_label(node: &CheckboxNode) -> AnyElement {
    let text_color = if node.disabled { 0x94a3b8 } else { 0xe2e8f0 };

    div()
        .text_color(rgb(text_color))
        .child(node.label.clone())
        .into_any_element()
}

fn emit_checkbox_change(view_id: u64, node_id: &str, callback_id: &str, checked: bool) {
    unsafe {
        let _ = guppy_c_send_checkbox_change_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            if checked { 1 } else { 0 },
        );
    }
}

fn is_checkbox_toggle_key(event: &KeyDownEvent) -> bool {
    matches!(event.keystroke.key.as_str(), "space" | "enter")
}
