use super::{
    BridgeView, events, identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style,
};
use crate::ir::{DivStyle, SelectNode, SelectOption};
use gpui::{
    AnyElement, Context, Corner, InteractiveElement, IntoElement, KeyDownEvent, ParentElement,
    SharedString, StatefulInteractiveElement, Styled, Window, anchored, deferred, div, point, px,
    rgb,
};

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    node: &SelectNode,
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

    let mut trigger = apply_div_style(
        div()
            .id(node_id.to_shared_string())
            .flex()
            .flex_row()
            .items_center()
            .justify_between()
            .gap_2()
            .px_2()
            .py_2()
            .rounded_md()
            .border_1()
            .border_color(rgb(0x94a3b8))
            .bg(if node.disabled {
                rgb(0x334155)
            } else {
                rgb(0x0f172a)
            })
            .text_color(if node.disabled {
                rgb(0x94a3b8)
            } else {
                rgb(0xf8fafc)
            })
            .child(selected_label(node))
            .child("⌄"),
        &node.style,
    );

    if let Some(handle) = focus_handle.as_ref() {
        let handle = handle.clone();
        trigger =
            trigger
                .track_focus(&handle)
                .focusable()
                .on_any_mouse_down(move |_, window, _| {
                    handle.focus(window);
                });
    }

    if !node.disabled {
        if let Some(callback_id) = node.click.as_ref() {
            let callback_id = callback_id.clone();
            let click_node_id = node_key.clone();
            trigger = trigger.on_click(move |_, _, _| {
                events::emit_click(view_id, &click_node_id, &callback_id);
            });
        }

        trigger = attach_keyboard_navigation(trigger, view_id, &node_key, node);
    }

    if node.open {
        let list = render_option_list(view_id, &node_key, node);
        trigger = trigger.child(
            deferred(
                anchored()
                    .anchor(Corner::TopLeft)
                    .position_mode(gpui::AnchoredPositionMode::Local)
                    .offset(point(px(0.0), px(32.0)))
                    .snap_to_window_with_margin(px(8.0))
                    .child(list),
            )
            .priority(2),
        );
    }

    trigger.into_any_element()
}

fn selected_label(node: &SelectNode) -> String {
    node.value
        .as_ref()
        .and_then(|value| node.options.iter().find(|option| &option.value == value))
        .map(|option| option.label.clone())
        .unwrap_or_else(|| node.placeholder.clone())
}

fn attach_keyboard_navigation(
    mut trigger: gpui::Stateful<gpui::Div>,
    view_id: u64,
    node_key: &str,
    node: &SelectNode,
) -> gpui::Stateful<gpui::Div> {
    let click = node.click.clone();
    let change = node.change.clone();
    let close = node.close.clone();
    let options = node.options.clone();
    let value = node.value.clone();
    let open = node.open;
    let key_node_id = node_key.to_owned();

    if click.is_some() || change.is_some() || close.is_some() {
        trigger = trigger.on_key_down(move |event: &KeyDownEvent, _, cx| {
            let Some(action) = select_keyboard_action(event, open, &options, value.as_deref())
            else {
                return;
            };

            let emitted = match action {
                SelectKeyboardAction::Toggle => {
                    if let Some(callback_id) = click.as_ref() {
                        events::emit_click(view_id, &key_node_id, callback_id);
                        true
                    } else {
                        false
                    }
                }
                SelectKeyboardAction::Close => {
                    if let Some(callback_id) = close.as_ref() {
                        events::emit_close(view_id, &key_node_id, callback_id);
                        true
                    } else {
                        false
                    }
                }
                SelectKeyboardAction::Change(value) => {
                    if let Some(callback_id) = change.as_ref() {
                        events::emit_change(view_id, &key_node_id, callback_id, &value);
                        true
                    } else {
                        false
                    }
                }
            };

            if emitted {
                cx.stop_propagation();
            }
        });
    }

    trigger
}

fn render_option_list(view_id: u64, node_key: &str, node: &SelectNode) -> AnyElement {
    let mut list = apply_div_style(
        div()
            .id(SharedString::from(format!("{node_key}.list")))
            .flex()
            .flex_col()
            .min_w(px(180.0))
            .p_1()
            .rounded_md()
            .border_1()
            .border_color(rgb(0x94a3b8))
            .shadow_lg()
            .bg(rgb(0xffffff))
            .text_color(rgb(0x0f172a)),
        &node.list_style,
    );

    if !node.disabled
        && let Some(callback_id) = node.close.as_ref()
    {
        let close_node_id = format!("{node_key}.list");
        let callback_id = callback_id.clone();
        list = list.on_mouse_down_out(move |_, _, _| {
            events::emit_close(view_id, &close_node_id, &callback_id);
        });
    }

    list.children(node.options.iter().map(|option| {
        render_option(
            view_id,
            node_key,
            option,
            &node.option_style,
            node.change.as_deref(),
        )
    }))
    .into_any_element()
}

fn render_option(
    view_id: u64,
    node_key: &str,
    option: &SelectOption,
    option_style: &DivStyle,
    change: Option<&str>,
) -> AnyElement {
    let option_key = format!("{node_key}.{}", option.value);
    let mut row = apply_div_style(
        div()
            .id(SharedString::from(option_key.clone()))
            .w_full()
            .px_2()
            .py_2()
            .rounded_sm()
            .text_color(if option.disabled {
                rgb(0x94a3b8)
            } else {
                rgb(0x0f172a)
            })
            .child(option.label.clone()),
        option_style,
    );

    if !option.disabled
        && let Some(callback_id) = change
    {
        let callback_id = callback_id.to_owned();
        let event_node_id = node_key.to_owned();
        let value = option.value.clone();
        row = row.on_click(move |_, _, _| {
            events::emit_change(view_id, &event_node_id, &callback_id, &value);
        });
    }

    row.into_any_element()
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum SelectKeyboardAction {
    Toggle,
    Close,
    Change(String),
}

#[derive(Clone, Copy)]
enum SelectNavigationDirection {
    Previous,
    Next,
}

fn is_select_toggle_key(event: &KeyDownEvent) -> bool {
    matches!(event.keystroke.key.as_str(), "space" | "enter")
}

fn select_navigation_direction(event: &KeyDownEvent) -> Option<SelectNavigationDirection> {
    match event.keystroke.key.as_str() {
        "up" => Some(SelectNavigationDirection::Previous),
        "down" => Some(SelectNavigationDirection::Next),
        _ => None,
    }
}

fn select_keyboard_action(
    event: &KeyDownEvent,
    open: bool,
    options: &[SelectOption],
    value: Option<&str>,
) -> Option<SelectKeyboardAction> {
    if is_select_toggle_key(event) {
        return Some(SelectKeyboardAction::Toggle);
    }

    match event.keystroke.key.as_str() {
        "escape" if open => Some(SelectKeyboardAction::Close),
        "home" => first_enabled_option(options)
            .map(|option| SelectKeyboardAction::Change(option.value.clone())),
        "end" => last_enabled_option(options)
            .map(|option| SelectKeyboardAction::Change(option.value.clone())),
        _ => select_navigation_direction(event)
            .and_then(|direction| adjacent_enabled_option(options, value, direction))
            .or_else(|| typeahead_enabled_option(options, value, &event.keystroke.key))
            .map(|option| SelectKeyboardAction::Change(option.value.clone())),
    }
}

fn first_enabled_option(options: &[SelectOption]) -> Option<&SelectOption> {
    options.iter().find(|option| !option.disabled)
}

fn last_enabled_option(options: &[SelectOption]) -> Option<&SelectOption> {
    options.iter().rev().find(|option| !option.disabled)
}

fn typeahead_enabled_option<'a>(
    options: &'a [SelectOption],
    value: Option<&str>,
    key: &str,
) -> Option<&'a SelectOption> {
    if key.chars().count() != 1 {
        return None;
    }

    let key = key.to_lowercase();
    let enabled = options
        .iter()
        .filter(|option| !option.disabled)
        .collect::<Vec<_>>();

    if enabled.is_empty() {
        return None;
    }

    let current = value
        .and_then(|value| enabled.iter().position(|option| option.value == value))
        .unwrap_or(enabled.len() - 1);

    (1..=enabled.len())
        .map(|offset| enabled[(current + offset) % enabled.len()])
        .find(|option| option.label.to_lowercase().starts_with(&key))
}

fn adjacent_enabled_option<'a>(
    options: &'a [SelectOption],
    value: Option<&str>,
    direction: SelectNavigationDirection,
) -> Option<&'a SelectOption> {
    let enabled_count = options.iter().filter(|option| !option.disabled).count();

    if enabled_count == 0 {
        return None;
    }

    let current = value
        .and_then(|value| {
            options
                .iter()
                .filter(|option| !option.disabled)
                .position(|option| option.value == value)
        })
        .unwrap_or(0);

    let next = match direction {
        SelectNavigationDirection::Previous => current.saturating_sub(1),
        SelectNavigationDirection::Next => (current + 1).min(enabled_count - 1),
    };

    options.iter().filter(|option| !option.disabled).nth(next)
}

#[cfg(test)]
mod tests {
    use super::{
        SelectKeyboardAction, SelectNavigationDirection, adjacent_enabled_option,
        is_select_toggle_key, select_keyboard_action, select_navigation_direction,
    };
    use crate::ir::SelectOption;
    use gpui::{KeyDownEvent, Keystroke};

    #[test]
    fn select_keyboard_helpers_match_toggle_and_arrow_keys() {
        assert!(is_select_toggle_key(&key_event("space")));
        assert!(is_select_toggle_key(&key_event("enter")));
        assert!(matches!(
            select_navigation_direction(&key_event("up")),
            Some(SelectNavigationDirection::Previous)
        ));
        assert!(matches!(
            select_navigation_direction(&key_event("down")),
            Some(SelectNavigationDirection::Next)
        ));
        assert!(select_navigation_direction(&key_event("tab")).is_none());
    }

    #[test]
    fn adjacent_enabled_option_skips_disabled_options() {
        let options = vec![
            option("todo", "Todo", false),
            option("blocked", "Blocked", true),
            option("done", "Done", false),
        ];

        assert_eq!(
            adjacent_enabled_option(&options, Some("todo"), SelectNavigationDirection::Next)
                .map(|option| option.value.as_str()),
            Some("done")
        );
        assert_eq!(
            adjacent_enabled_option(&options, Some("done"), SelectNavigationDirection::Previous)
                .map(|option| option.value.as_str()),
            Some("todo")
        );
        assert_eq!(
            adjacent_enabled_option(&options, Some("missing"), SelectNavigationDirection::Next)
                .map(|option| option.value.as_str()),
            Some("done")
        );
    }

    #[test]
    fn select_keyboard_action_supports_escape_home_end_and_typeahead() {
        let options = vec![
            option("alpha", "Alpha", false),
            option("archived", "Archived", false),
            option("blocked", "Blocked", true),
            option("done", "Done", false),
        ];

        assert_eq!(
            select_keyboard_action(&key_event("escape"), true, &options, Some("alpha")),
            Some(SelectKeyboardAction::Close)
        );
        assert_eq!(
            select_keyboard_action(&key_event("home"), true, &options, Some("done")),
            Some(SelectKeyboardAction::Change("alpha".into()))
        );
        assert_eq!(
            select_keyboard_action(&key_event("end"), true, &options, Some("alpha")),
            Some(SelectKeyboardAction::Change("done".into()))
        );
        assert_eq!(
            select_keyboard_action(&key_event("a"), true, &options, Some("alpha")),
            Some(SelectKeyboardAction::Change("archived".into()))
        );
        assert_eq!(
            select_keyboard_action(&key_event("b"), true, &options, Some("alpha")),
            None
        );
        assert_eq!(
            select_keyboard_action(&key_event("escape"), false, &options, Some("alpha")),
            None
        );
    }

    fn key_event(key: &str) -> KeyDownEvent {
        KeyDownEvent {
            keystroke: Keystroke::parse(key).unwrap(),
            is_held: false,
        }
    }

    fn option(value: &str, label: &str, disabled: bool) -> SelectOption {
        SelectOption {
            value: value.into(),
            label: label.into(),
            disabled,
        }
    }
}
