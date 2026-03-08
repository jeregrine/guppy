use super::{
    events::{self, BridgeDragState},
    identity::NodeIdentity,
    render_pass::RenderPass,
    style::{apply_div_style, apply_refinement_style},
};
use crate::bridge_view::BridgeView;
use crate::ir::{DivNode, ShortcutBinding};
use gpui::{
    AnyElement, AppContext, Context, Empty, InteractiveElement, IntoElement, KeyDownEvent,
    KeyUpEvent, MouseButton, MouseDownEvent, MouseMoveEvent, MouseUpEvent, ParentElement,
    ScrollAnchor, ScrollHandle, ScrollWheelEvent, StatefulInteractiveElement, Window, deferred,
    div,
};

struct DisabledEventFilter {
    disabled: bool,
}

impl DisabledEventFilter {
    fn new(disabled: bool) -> Self {
        Self { disabled }
    }

    fn callback<'a>(&self, callback: Option<&'a str>) -> Option<&'a str> {
        if self.disabled { None } else { callback }
    }

    fn shortcuts(&self, shortcuts: &[ShortcutBinding]) -> Vec<ShortcutBinding> {
        if self.disabled {
            Vec::new()
        } else {
            shortcuts.to_vec()
        }
    }

    fn tab_stop(&self, tab_stop: Option<bool>) -> Option<bool> {
        if self.disabled { None } else { tab_stop }
    }

    fn tab_index(&self, tab_index: Option<isize>) -> Option<isize> {
        if self.disabled { None } else { tab_index }
    }

    fn focusable(&self, focusable: bool) -> bool {
        focusable && !self.disabled
    }
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    node: &DivNode,
    parent_scroll_handle: Option<ScrollHandle>,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, node.id.as_deref());
    let node_key = node_id.to_string();
    let disabled = DisabledEventFilter::new(node.disabled);
    let click = disabled.callback(node.click.as_deref());
    let hover = disabled.callback(node.hover.as_deref());
    let focus = disabled.callback(node.focus.as_deref());
    let blur = disabled.callback(node.blur.as_deref());
    let key_down = disabled.callback(node.key_down.as_deref());
    let key_up = disabled.callback(node.key_up.as_deref());
    let context_menu = disabled.callback(node.context_menu.as_deref());
    let drag_start = disabled.callback(node.drag_start.as_deref());
    let drag_move = disabled.callback(node.drag_move.as_deref());
    let drop = disabled.callback(node.drop.as_deref());
    let mouse_down = disabled.callback(node.mouse_down.as_deref());
    let mouse_up = disabled.callback(node.mouse_up.as_deref());
    let mouse_move = disabled.callback(node.mouse_move.as_deref());
    let scroll_wheel = disabled.callback(node.scroll_wheel.as_deref());
    let shortcuts = disabled.shortcuts(&node.shortcuts);
    let focusable = disabled.focusable(node.focusable);
    let tab_stop = disabled.tab_stop(node.tab_stop);
    let tab_index = disabled.tab_index(node.tab_index);
    let keyboard_actionable = click.is_some() || !shortcuts.is_empty();
    let tab_stop = if keyboard_actionable {
        Some(tab_stop.unwrap_or(true))
    } else {
        tab_stop
    };

    let tracked_scroll_handle = if node.track_scroll {
        Some(pass.retain_scroll_handle(&node_key))
    } else {
        None
    };

    let needs_focus_handle = keyboard_actionable
        || focusable
        || tab_stop.is_some()
        || tab_index.is_some()
        || !node.focus_style.is_empty()
        || !node.in_focus_style.is_empty()
        || focus.is_some()
        || blur.is_some()
        || key_down.is_some()
        || key_up.is_some();

    let focus_handle = if needs_focus_handle {
        Some(pass.ensure_focus_handle(&node_key, cx, tab_stop, tab_index))
    } else {
        None
    };

    if let Some(handle) = focus_handle.as_ref() {
        pass.register_focus_callbacks(&node_key, handle, focus, blur, window, cx);
    }

    let child_scroll_handle = tracked_scroll_handle
        .clone()
        .or(parent_scroll_handle.clone());
    let child_elements =
        pass.render_children(path, &node.children, child_scroll_handle, window, cx);

    let styled_div = apply_div_style(
        div()
            .id(node_id.to_shared_string())
            .children(child_elements),
        &node.style,
    );
    let styled_div = if node.occlude {
        styled_div.occlude()
    } else {
        styled_div
    };
    let styled_div = match tracked_scroll_handle.as_ref() {
        Some(handle) => styled_div.track_scroll(handle),
        None => styled_div,
    };

    let styled_div = if node.anchor_scroll {
        match parent_scroll_handle.as_ref() {
            Some(handle) => {
                styled_div.anchor_scroll(Some(ScrollAnchor::for_handle(handle.clone())))
            }
            None => styled_div,
        }
    } else {
        styled_div
    };

    let styled_div = match focus_handle.as_ref() {
        Some(handle) => {
            let styled_div = styled_div.track_focus(handle);
            if keyboard_actionable || focusable {
                styled_div.focusable()
            } else {
                styled_div
            }
        }
        None => styled_div,
    };

    let styled_div = if node.disabled || node.focus_style.is_empty() {
        styled_div
    } else {
        let focus_ops = node.focus_style.clone();
        styled_div.focus(move |style| apply_refinement_style(style, &focus_ops))
    };

    let styled_div = if node.disabled || node.in_focus_style.is_empty() {
        styled_div
    } else {
        let in_focus_ops = node.in_focus_style.clone();
        styled_div.in_focus(move |style| apply_refinement_style(style, &in_focus_ops))
    };

    let styled_div = if node.disabled || node.hover_style.is_empty() {
        styled_div
    } else {
        let hover_ops = node.hover_style.clone();
        styled_div.hover(move |style| apply_refinement_style(style, &hover_ops))
    };

    let styled_div = if node.disabled || node.active_style.is_empty() {
        styled_div
    } else {
        let active_ops = node.active_style.clone();
        styled_div.active(move |style| apply_refinement_style(style, &active_ops))
    };

    let styled_div = match hover {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let hover_node_id = node_key.clone();
            styled_div.on_hover(move |hovered, _, _| {
                events::emit_hover(view_id, &hover_node_id, &callback_id, *hovered);
            })
        }
        None => styled_div,
    };

    let styled_div = match focus_handle.as_ref() {
        Some(handle) => {
            let handle = handle.clone();
            styled_div.on_any_mouse_down(move |_, window, _| {
                handle.focus(window);
            })
        }
        None => styled_div,
    };

    let styled_div = if key_down.is_some() || !shortcuts.is_empty() {
        let key_down_callback_id = key_down.map(str::to_owned);
        let key_down_node_id = node_key.clone();
        let shortcut_bindings = shortcuts.clone();

        styled_div.on_key_down(move |event: &KeyDownEvent, _, cx| {
            if let Some(callback_id) = key_down_callback_id.as_ref() {
                events::emit_key_down(view_id, &key_down_node_id, callback_id, event);
            }

            if let Some(shortcut) = events::matching_shortcut(event, &shortcut_bindings) {
                events::emit_action(view_id, &key_down_node_id, shortcut, event);
                cx.stop_propagation();
            }
        })
    } else {
        styled_div
    };

    let styled_div = match key_up {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let key_up_node_id = node_key.clone();
            styled_div.on_key_up(move |event: &KeyUpEvent, _, _| {
                events::emit_key_up(view_id, &key_up_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match context_menu {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let context_menu_node_id = node_key.clone();
            styled_div.on_mouse_down(MouseButton::Right, move |event: &MouseDownEvent, _, _| {
                events::emit_context_menu(view_id, &context_menu_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match drop {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let drop_node_id = node_key.clone();
            styled_div.on_drop::<BridgeDragState>(move |drag, _, _| {
                events::emit_drop(view_id, &drop_node_id, &callback_id, &drag.source_id);
            })
        }
        None => styled_div,
    };

    let styled_div = match drag_move {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let drag_move_node_id = node_key.clone();
            styled_div.on_drag_move::<BridgeDragState>(move |event, _, cx| {
                let drag = event.drag(cx);
                events::emit_drag_move(
                    view_id,
                    &drag_move_node_id,
                    &callback_id,
                    &drag.source_id,
                    event.event.pressed_button,
                    event.event.position,
                    &event.event.modifiers,
                );
            })
        }
        None => styled_div,
    };

    let styled_div = match drag_start {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let drag_start_node_id = node_key.clone();
            let drag_source_id = node_key.clone();
            styled_div.on_drag(
                BridgeDragState {
                    source_id: drag_source_id,
                },
                move |drag, _, _, cx| {
                    events::emit_drag_start(
                        view_id,
                        &drag_start_node_id,
                        &callback_id,
                        &drag.source_id,
                    );
                    cx.new(|_| Empty)
                },
            )
        }
        None if drag_move.is_some() => {
            let drag_source_id = node_key.clone();
            styled_div.on_drag(
                BridgeDragState {
                    source_id: drag_source_id,
                },
                move |_, _, _, cx| cx.new(|_| Empty),
            )
        }
        None => styled_div,
    };

    let styled_div = match mouse_down {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let mouse_down_node_id = node_key.clone();
            styled_div.on_any_mouse_down(move |event: &MouseDownEvent, _, _| {
                events::emit_mouse_down(view_id, &mouse_down_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match mouse_up {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let mouse_up_node_id = node_key.clone();
            styled_div.capture_any_mouse_up(move |event: &MouseUpEvent, _, _| {
                events::emit_mouse_up(view_id, &mouse_up_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match mouse_move {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let mouse_move_node_id = node_key.clone();
            styled_div.on_mouse_move(move |event: &MouseMoveEvent, _, _| {
                events::emit_mouse_move(view_id, &mouse_move_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match scroll_wheel {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let scroll_node_id = node_key.clone();
            styled_div.on_scroll_wheel(move |event: &ScrollWheelEvent, _, _| {
                events::emit_scroll_wheel(view_id, &scroll_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = if node.disabled && !node.disabled_style.is_empty() {
        apply_div_style(styled_div, &node.disabled_style)
    } else {
        styled_div
    };

    let element = match click {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let click_node_id = node_key.clone();
            styled_div
                .on_click(move |_, _, _| {
                    events::emit_click(view_id, &click_node_id, &callback_id);
                })
                .into_any_element()
        }
        None => styled_div.into_any_element(),
    };

    match node.stack_priority {
        Some(priority) => deferred(element).with_priority(priority).into_any_element(),
        None => element,
    }
}
