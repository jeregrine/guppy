use super::{
    BridgeView,
    identity::NodeIdentity,
    render_pass::RenderPass,
    style::{apply_div_style, apply_refinement_style},
};
use crate::ir::DivStyle;
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, KeyDownEvent, ParentElement,
    StatefulInteractiveElement, Styled, Window, div, rgb,
};

// Default choice-control palette, shared by checkbox and radio. The wrapper
// receives the default text color before user style ops run, so `text_color`
// ops on the node theme the label (and checkbox glyph background contrast
// stays an indicator-local concern).
pub(crate) const CHOICE_BORDER: u32 = 0x94a3b8;
pub(crate) const CHOICE_BORDER_DISABLED: u32 = 0x5b6472;
pub(crate) const CHOICE_FILL_CHECKED: u32 = 0x2563eb;
pub(crate) const CHOICE_FILL_CHECKED_DISABLED: u32 = 0x475569;
pub(crate) const CHOICE_FILL_UNCHECKED: u32 = 0x0f172a;
pub(crate) const CHOICE_GLYPH: u32 = 0xffffff;
pub(crate) const CHOICE_GLYPH_DISABLED: u32 = 0xcbd5e1;
pub(crate) const CHOICE_TEXT: u32 = 0xe2e8f0;
pub(crate) const CHOICE_TEXT_DISABLED: u32 = 0x94a3b8;

pub(crate) fn indicator_border_color(disabled: bool) -> u32 {
    if disabled {
        CHOICE_BORDER_DISABLED
    } else {
        CHOICE_BORDER
    }
}

pub(crate) fn indicator_fill_color(checked: bool, disabled: bool) -> u32 {
    match (checked, disabled) {
        (true, true) => CHOICE_FILL_CHECKED_DISABLED,
        (true, false) => CHOICE_FILL_CHECKED,
        (false, _) => CHOICE_FILL_UNCHECKED,
    }
}

pub(crate) fn glyph_color(disabled: bool) -> u32 {
    if disabled {
        CHOICE_GLYPH_DISABLED
    } else {
        CHOICE_GLYPH
    }
}

pub(crate) fn default_text_color(disabled: bool) -> u32 {
    if disabled {
        CHOICE_TEXT_DISABLED
    } else {
        CHOICE_TEXT
    }
}

/// Label element that inherits the wrapper text color, so `text_color` style
/// ops on the node theme it from Elixir.
pub(crate) fn choice_label(label: &str) -> AnyElement {
    div().child(label.to_owned()).into_any_element()
}

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
            .text_color(rgb(default_text_color(spec.disabled)))
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
    use super::{
        CHOICE_BORDER, CHOICE_BORDER_DISABLED, CHOICE_FILL_CHECKED, CHOICE_FILL_CHECKED_DISABLED,
        CHOICE_FILL_UNCHECKED, CHOICE_TEXT, CHOICE_TEXT_DISABLED, default_text_color,
        enabled_change_callback, indicator_border_color, indicator_fill_color,
        is_choice_toggle_key,
    };
    use gpui::{KeyDownEvent, Keystroke};

    #[test]
    fn palette_helpers_map_disabled_states() {
        assert_eq!(indicator_border_color(false), CHOICE_BORDER);
        assert_eq!(indicator_border_color(true), CHOICE_BORDER_DISABLED);
        assert_eq!(indicator_fill_color(true, false), CHOICE_FILL_CHECKED);
        assert_eq!(
            indicator_fill_color(true, true),
            CHOICE_FILL_CHECKED_DISABLED
        );
        assert_eq!(indicator_fill_color(false, false), CHOICE_FILL_UNCHECKED);
        assert_eq!(indicator_fill_color(false, true), CHOICE_FILL_UNCHECKED);
        assert_eq!(default_text_color(false), CHOICE_TEXT);
        assert_eq!(default_text_color(true), CHOICE_TEXT_DISABLED);
    }

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
