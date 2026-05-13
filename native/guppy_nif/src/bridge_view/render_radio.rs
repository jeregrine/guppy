use super::{
    BridgeView,
    identity::NodeIdentity,
    render_pass::RenderPass,
    style::{apply_div_style, apply_refinement_style},
};
use crate::ir::RadioNode;
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, KeyDownEvent, ParentElement,
    StatefulInteractiveElement, Styled, Window, div, px, rgb,
};

unsafe extern "C" {
    fn guppy_c_send_change_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
        value_ptr: *const u8,
        value_len: usize,
    ) -> i32;
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    node: &RadioNode,
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

    let indicator = radio_indicator(node.checked, node.disabled);
    let label = radio_label(node);

    let mut radio = apply_div_style(
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
        radio = radio
            .track_focus(&handle)
            .focusable()
            .on_any_mouse_down(move |_, window, _| {
                handle.focus(window);
            });
    }

    if !node.disabled && !node.hover_style.is_empty() {
        let hover_ops = node.hover_style.clone();
        radio = radio.hover(move |style| apply_refinement_style(style, &hover_ops));
    }

    if !node.disabled && !node.focus_style.is_empty() {
        let focus_ops = node.focus_style.clone();
        radio = radio.focus(move |style| apply_refinement_style(style, &focus_ops));
    }

    if !node.disabled && !node.in_focus_style.is_empty() {
        let in_focus_ops = node.in_focus_style.clone();
        radio = radio.in_focus(move |style| apply_refinement_style(style, &in_focus_ops));
    }

    if !node.disabled && !node.active_style.is_empty() {
        let active_ops = node.active_style.clone();
        radio = radio.active(move |style| apply_refinement_style(style, &active_ops));
    }

    if node.disabled && !node.disabled_style.is_empty() {
        radio = apply_div_style(radio, &node.disabled_style);
    }

    if let Some(callback_id) = enabled_change_callback(node.disabled, node.change.as_ref()) {
        let click_callback_id = callback_id.clone();
        let click_node_id = node_key.clone();
        let click_value = node.value.clone();

        radio = radio.on_click(move |_, _, _| {
            emit_radio_change(view_id, &click_node_id, &click_callback_id, &click_value);
        });

        let key_callback_id = callback_id.clone();
        let key_node_id = node_key.clone();
        let key_value = node.value.clone();
        radio = radio.on_key_down(move |event: &KeyDownEvent, _, cx| {
            if is_radio_toggle_key(event) {
                emit_radio_change(view_id, &key_node_id, &key_callback_id, &key_value);
                cx.stop_propagation();
            }
        });
    }

    radio.into_any_element()
}

fn enabled_change_callback(disabled: bool, callback: Option<&String>) -> Option<&String> {
    if disabled { None } else { callback }
}

fn radio_indicator(checked: bool, disabled: bool) -> AnyElement {
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

fn radio_label(node: &RadioNode) -> AnyElement {
    let text_color = if node.disabled { 0x94a3b8 } else { 0xe2e8f0 };

    div()
        .text_color(rgb(text_color))
        .child(node.label.clone())
        .into_any_element()
}

fn emit_radio_change(view_id: u64, node_id: &str, callback_id: &str, value: &str) {
    unsafe {
        let _ = guppy_c_send_change_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            value.as_ptr(),
            value.len(),
        );
    }
}

fn is_radio_toggle_key(event: &KeyDownEvent) -> bool {
    matches!(event.keystroke.key.as_str(), "space" | "enter")
}

#[cfg(test)]
mod tests {
    use super::{enabled_change_callback, is_radio_toggle_key};
    use gpui::{KeyDownEvent, Keystroke};

    #[test]
    fn disabled_radio_does_not_attach_change_handlers() {
        let callback = "priority_changed".to_string();

        assert_eq!(
            enabled_change_callback(false, Some(&callback)),
            Some(&callback)
        );
        assert_eq!(enabled_change_callback(true, Some(&callback)), None);
        assert_eq!(enabled_change_callback(false, None), None);
    }

    #[test]
    fn radio_toggle_keys_match_space_and_enter() {
        assert!(is_radio_toggle_key(&KeyDownEvent {
            keystroke: Keystroke::parse("space").unwrap(),
            is_held: false,
        }));
        assert!(is_radio_toggle_key(&KeyDownEvent {
            keystroke: Keystroke::parse("enter").unwrap(),
            is_held: false,
        }));
        assert!(!is_radio_toggle_key(&KeyDownEvent {
            keystroke: Keystroke::parse("tab").unwrap(),
            is_held: false,
        }));
    }
}
