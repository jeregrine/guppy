use super::{events, identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::bridge_view::BridgeView;
use crate::ir::{DivStyle, IrNode, PopoverAnchor, PopoverAnchorFit, PopoverAnchorPositionMode};
use gpui::{
    AnchoredPositionMode, AnyElement, Context, Corner, InteractiveElement, IntoElement,
    KeyDownEvent, ParentElement, SharedString, StatefulInteractiveElement, Styled, Window,
    anchored, deferred, div, point, px, rgb,
};

pub(crate) struct PopoverSpec<'a> {
    pub path: &'a str,
    pub id: Option<&'a str>,
    pub label: &'a str,
    pub open: bool,
    pub style: &'a DivStyle,
    pub popover_style: &'a DivStyle,
    pub anchor: PopoverAnchor,
    pub anchor_position: Option<(f32, f32)>,
    pub anchor_offset: Option<(f32, f32)>,
    pub anchor_position_mode: PopoverAnchorPositionMode,
    pub anchor_fit: PopoverAnchorFit,
    pub snap_margin: f32,
    pub close_on_click_outside: bool,
    pub stack_priority: usize,
    pub disabled: bool,
    pub click: Option<&'a str>,
    pub close: Option<&'a str>,
    pub children: &'a [IrNode],
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    spec: PopoverSpec<'_>,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, spec.path, spec.id);
    let node_key = node_id.to_string();

    let focus_handle = if spec.disabled {
        None
    } else {
        Some(pass.ensure_focus_handle(&node_key, cx, Some(true), None))
    };

    let mut trigger = apply_div_style(
        div()
            .id(node_id.to_shared_string())
            .flex()
            .items_center()
            .justify_center()
            .px_2()
            .py_2()
            .rounded_md()
            .border_1()
            .border_color(rgb(0x94a3b8))
            .bg(if spec.disabled {
                rgb(0x334155)
            } else {
                rgb(0x1d4ed8)
            })
            .text_color(rgb(0xffffff))
            .child(spec.label.to_owned()),
        spec.style,
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

    if !spec.disabled {
        trigger = attach_keyboard_actions(trigger, view_id, &node_key, &spec);
    }

    if !spec.disabled
        && let Some(callback_id) = spec.click
    {
        let click_node_id = node_key.clone();
        let callback_id = callback_id.to_owned();
        trigger = trigger.on_click(move |_, _, _| {
            events::emit_click(view_id, &click_node_id, &callback_id);
        });
    }

    if spec.open {
        let child_elements = pass.render_children(
            &format!("{}.popover", spec.path),
            spec.children,
            None,
            window,
            cx,
        );
        let mut content = apply_div_style(
            div()
                .id(SharedString::from(format!("{node_key}.popover")))
                .flex()
                .flex_col()
                .gap_2()
                .p_3()
                .rounded_md()
                .border_1()
                .shadow_lg()
                .bg(rgb(0xffffff))
                .text_color(rgb(0x111827))
                .children(child_elements),
            spec.popover_style,
        );

        if spec.close_on_click_outside
            && !spec.disabled
            && let Some(callback_id) = spec.close
        {
            let close_node_id = format!("{node_key}.popover");
            let callback_id = callback_id.to_owned();
            content = content.on_mouse_down_out(move |_, _, _| {
                events::emit_close(view_id, &close_node_id, &callback_id);
            });
        }

        trigger = trigger.child(
            deferred(build_anchored_popover(&spec).child(content)).priority(spec.stack_priority),
        );
    }

    trigger.into_any_element()
}

fn build_anchored_popover(spec: &PopoverSpec<'_>) -> gpui::Anchored {
    let anchored = anchored()
        .anchor(to_gpui_corner(spec.anchor))
        .position_mode(to_gpui_position_mode(spec.anchor_position_mode));

    let anchored = match spec.anchor_position {
        Some((x, y)) => anchored.position(point(px(x), px(y))),
        None => anchored,
    };

    let anchored = match spec.anchor_offset {
        Some((x, y)) => anchored.offset(point(px(x), px(y))),
        None => anchored,
    };

    match spec.anchor_fit {
        PopoverAnchorFit::SwitchAnchor => anchored,
        PopoverAnchorFit::SnapToWindow => anchored.snap_to_window(),
        PopoverAnchorFit::SnapToWindowWithMargin => {
            anchored.snap_to_window_with_margin(px(spec.snap_margin))
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum PopoverKeyboardAction {
    Toggle,
    Close,
}

fn attach_keyboard_actions(
    mut trigger: gpui::Stateful<gpui::Div>,
    view_id: u64,
    node_key: &str,
    spec: &PopoverSpec<'_>,
) -> gpui::Stateful<gpui::Div> {
    let click = spec.click.map(str::to_owned);
    let close = spec.close.map(str::to_owned);
    let open = spec.open;
    let key_node_id = node_key.to_owned();

    if click.is_some() || close.is_some() {
        trigger = trigger.on_key_down(move |event: &KeyDownEvent, _, cx| {
            let Some(action) = popover_keyboard_action(event, open) else {
                return;
            };

            let emitted = match action {
                PopoverKeyboardAction::Toggle => {
                    if let Some(callback_id) = click.as_ref() {
                        events::emit_click(view_id, &key_node_id, callback_id);
                        true
                    } else {
                        false
                    }
                }
                PopoverKeyboardAction::Close => {
                    if let Some(callback_id) = close.as_ref() {
                        events::emit_close(view_id, &key_node_id, callback_id);
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

fn popover_keyboard_action(event: &KeyDownEvent, open: bool) -> Option<PopoverKeyboardAction> {
    match event.keystroke.key.as_str() {
        "space" | "enter" => Some(PopoverKeyboardAction::Toggle),
        "escape" if open => Some(PopoverKeyboardAction::Close),
        _ => None,
    }
}

fn to_gpui_corner(anchor: PopoverAnchor) -> Corner {
    match anchor {
        PopoverAnchor::TopLeft => Corner::TopLeft,
        PopoverAnchor::TopRight => Corner::TopRight,
        PopoverAnchor::BottomLeft => Corner::BottomLeft,
        PopoverAnchor::BottomRight => Corner::BottomRight,
    }
}

fn to_gpui_position_mode(mode: PopoverAnchorPositionMode) -> AnchoredPositionMode {
    match mode {
        PopoverAnchorPositionMode::Window => AnchoredPositionMode::Window,
        PopoverAnchorPositionMode::Local => AnchoredPositionMode::Local,
    }
}

#[cfg(test)]
mod tests {
    use super::{PopoverKeyboardAction, PopoverSpec, popover_keyboard_action};
    use crate::ir::{PopoverAnchor, PopoverAnchorFit, PopoverAnchorPositionMode};
    use gpui::{KeyDownEvent, Keystroke};

    #[test]
    fn popover_keyboard_action_matches_toggle_and_escape() {
        assert_eq!(
            popover_keyboard_action(&key_event("space"), false),
            Some(PopoverKeyboardAction::Toggle)
        );
        assert_eq!(
            popover_keyboard_action(&key_event("enter"), true),
            Some(PopoverKeyboardAction::Toggle)
        );
        assert_eq!(
            popover_keyboard_action(&key_event("escape"), true),
            Some(PopoverKeyboardAction::Close)
        );
        assert_eq!(popover_keyboard_action(&key_event("escape"), false), None);
        assert_eq!(popover_keyboard_action(&key_event("down"), true), None);
    }

    #[test]
    fn popover_spec_tracks_open_and_callbacks() {
        let style = Vec::new().into();
        let spec = PopoverSpec {
            path: "root",
            id: Some("menu"),
            label: "Open",
            open: true,
            style: &style,
            popover_style: &style,
            anchor: PopoverAnchor::BottomRight,
            anchor_position: Some((4.0, 8.0)),
            anchor_offset: Some((0.0, 12.0)),
            anchor_position_mode: PopoverAnchorPositionMode::Local,
            anchor_fit: PopoverAnchorFit::SnapToWindowWithMargin,
            snap_margin: 12.0,
            close_on_click_outside: false,
            stack_priority: 2,
            disabled: false,
            click: Some("open_menu"),
            close: Some("close_menu"),
            children: &[],
        };

        assert!(spec.open);
        assert_eq!(spec.anchor, PopoverAnchor::BottomRight);
        assert_eq!(spec.anchor_offset, Some((0.0, 12.0)));
        assert_eq!(spec.anchor_position_mode, PopoverAnchorPositionMode::Local);
        assert_eq!(spec.stack_priority, 2);
        assert!(!spec.close_on_click_outside);
        assert_eq!(spec.click, Some("open_menu"));
        assert_eq!(spec.close, Some("close_menu"));
    }

    fn key_event(key: &str) -> KeyDownEvent {
        KeyDownEvent {
            keystroke: Keystroke::parse(key).unwrap(),
            is_held: false,
        }
    }
}
