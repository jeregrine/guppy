use super::{
    BridgeView,
    identity::NodeIdentity,
    render_pass::RenderPass,
    style::{apply_div_style, apply_refinement_style},
};
use crate::ir::DivStyle;
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, KeyDownEvent, ParentElement,
    StatefulInteractiveElement, Styled, Window, div,
};

/// Shared shape of the checkbox/radio choice controls: everything except the
/// indicator element, the label element, and the change event payload.
pub(crate) struct ChoiceSpec<'a> {
    pub id: Option<&'a str>,
    pub disabled: bool,
    pub tab_index: Option<isize>,
    pub focus: Option<&'a str>,
    pub blur: Option<&'a str>,
    pub change: Option<&'a str>,
    pub style: &'a DivStyle,
    pub hover_style: &'a DivStyle,
    pub focus_style: &'a DivStyle,
    pub focus_visible_style: &'a DivStyle,
    pub in_focus_style: &'a DivStyle,
    pub active_style: &'a DivStyle,
    pub disabled_style: &'a DivStyle,
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn render<F>(
    pass: &mut RenderPass<'_>,
    path: &str,
    spec: ChoiceSpec<'_>,
    indicator: AnyElement,
    label: AnyElement,
    emit_change: F,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement
where
    F: Fn(u64, &str, &str) + Clone + 'static,
{
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, spec.id);
    let node_key = node_id.to_string();

    let focus_handle = if spec.disabled {
        None
    } else {
        Some(pass.ensure_focus_handle(&node_key, cx, Some(true), spec.tab_index))
    };

    if let Some(handle) = focus_handle.as_ref() {
        pass.register_focus_callbacks(&node_key, handle, spec.focus, spec.blur, window, cx);
    }

    let mut control = apply_div_style(
        div()
            .id(node_id.to_shared_string())
            .flex()
            .flex_row()
            .items_center()
            .gap_2()
            .child(indicator)
            .child(label),
        spec.style,
    );

    if let Some(handle) = focus_handle.as_ref() {
        let handle = handle.clone();
        control =
            control
                .track_focus(&handle)
                .focusable()
                .on_any_mouse_down(move |_, window, _| {
                    handle.focus(window);
                });
    }

    if !spec.disabled && !spec.hover_style.is_empty() {
        let hover_ops = spec.hover_style.clone();
        control = control.hover(move |style| apply_refinement_style(style, &hover_ops));
    }

    if !spec.disabled
        && !spec.focus_visible_style.is_empty()
        && pass.focus_visible()
        && focus_handle
            .as_ref()
            .is_some_and(|handle| handle.is_focused(window))
    {
        control = apply_div_style(control, spec.focus_visible_style);
    }

    if !spec.disabled && !spec.focus_style.is_empty() {
        let focus_ops = spec.focus_style.clone();
        control = control.focus(move |style| apply_refinement_style(style, &focus_ops));
    }

    if !spec.disabled && !spec.in_focus_style.is_empty() {
        let in_focus_ops = spec.in_focus_style.clone();
        control = control.in_focus(move |style| apply_refinement_style(style, &in_focus_ops));
    }

    if !spec.disabled && !spec.active_style.is_empty() {
        let active_ops = spec.active_style.clone();
        control = control.active(move |style| apply_refinement_style(style, &active_ops));
    }

    if spec.disabled && !spec.disabled_style.is_empty() {
        control = apply_div_style(control, spec.disabled_style);
    }

    if let Some(callback_id) = enabled_change_callback(spec.disabled, spec.change) {
        let click_emit = emit_change.clone();
        let click_callback_id = callback_id.to_owned();
        let click_node_id = node_key.clone();

        control = control.on_click(move |_, _, _| {
            click_emit(view_id, &click_node_id, &click_callback_id);
        });

        let key_emit = emit_change;
        let key_callback_id = callback_id.to_owned();
        let key_node_id = node_key.clone();
        control = control.on_key_down(move |event: &KeyDownEvent, _, cx| {
            if is_choice_toggle_key(event) {
                key_emit(view_id, &key_node_id, &key_callback_id);
                cx.stop_propagation();
            }
        });
    }

    control.into_any_element()
}

pub(crate) fn enabled_change_callback(disabled: bool, callback: Option<&str>) -> Option<&str> {
    if disabled { None } else { callback }
}

pub(crate) fn is_choice_toggle_key(event: &KeyDownEvent) -> bool {
    matches!(event.keystroke.key.as_str(), "space" | "enter")
}

#[cfg(test)]
mod tests {
    use super::{enabled_change_callback, is_choice_toggle_key};
    use gpui::{KeyDownEvent, Keystroke};

    #[test]
    fn disabled_choice_controls_do_not_attach_change_handlers() {
        assert_eq!(
            enabled_change_callback(false, Some("toggle")),
            Some("toggle")
        );
        assert_eq!(enabled_change_callback(true, Some("toggle")), None);
        assert_eq!(enabled_change_callback(false, None), None);
    }

    #[test]
    fn choice_toggle_keys_match_space_and_enter() {
        assert!(is_choice_toggle_key(&KeyDownEvent {
            keystroke: Keystroke::parse("space").unwrap(),
            is_held: false,
        }));
        assert!(is_choice_toggle_key(&KeyDownEvent {
            keystroke: Keystroke::parse("enter").unwrap(),
            is_held: false,
        }));
        assert!(!is_choice_toggle_key(&KeyDownEvent {
            keystroke: Keystroke::parse("tab").unwrap(),
            is_held: false,
        }));
    }
}
