use crate::{
    ir::ShortcutBinding,
    native_events::{
        self, ActionEventPayload, ContextMenuEventPayload, DragMoveEventPayload, EventModifiers,
        KeyEventPayload, MouseDownEventPayload, MouseMoveEventPayload, MouseUpEventPayload,
        ScrollWheelEventPayload,
    },
};
use gpui::{
    KeyDownEvent, KeyUpEvent, Modifiers, MouseButton, MouseDownEvent, MouseMoveEvent, MouseUpEvent,
    Pixels, ScrollDelta, ScrollWheelEvent,
};

#[derive(Clone, Debug)]
pub(crate) struct BridgeDragState {
    pub source_id: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct RowControlEventContext {
    pub node_id: String,
    pub list_id: String,
    pub row_id: String,
    pub control_id: String,
}

pub(crate) fn emit_click(view_id: u64, node_id: &str, callback_id: &str) {
    let _ = native_events::send_click_event(view_id, node_id, callback_id);
}

pub(crate) fn emit_row_control_click(
    view_id: u64,
    context: &RowControlEventContext,
    callback_id: &str,
) {
    let _ = native_events::send_row_control_click_event(
        view_id,
        &context.node_id,
        callback_id,
        &context.list_id,
        &context.row_id,
        &context.control_id,
    );
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn emit_data_table_event(
    view_id: u64,
    event_code: i32,
    node_id: &str,
    callback_id: &str,
    table_id: &str,
    row_id: Option<&str>,
    column_id: Option<&str>,
) {
    let _ = native_events::send_data_table_event(
        view_id,
        event_code,
        node_id,
        callback_id,
        table_id,
        row_id,
        column_id,
    );
}

pub(crate) fn emit_tree_event(
    view_id: u64,
    event_code: i32,
    node_id: &str,
    callback_id: &str,
    tree_id: &str,
    item_id: &str,
) {
    let _ =
        native_events::send_tree_event(view_id, event_code, node_id, callback_id, tree_id, item_id);
}

pub(crate) fn emit_row_control_change(
    view_id: u64,
    context: &RowControlEventContext,
    callback_id: &str,
    value: &str,
) {
    let _ = native_events::send_row_control_change_event(
        view_id,
        &context.node_id,
        callback_id,
        &context.list_id,
        &context.row_id,
        &context.control_id,
        value,
    );
}

pub(crate) fn emit_row_control_checkbox_change(
    view_id: u64,
    context: &RowControlEventContext,
    callback_id: &str,
    checked: bool,
) {
    let _ = native_events::send_row_control_checkbox_change_event(
        view_id,
        &context.node_id,
        callback_id,
        &context.list_id,
        &context.row_id,
        &context.control_id,
        checked,
    );
}

pub(crate) fn emit_close(view_id: u64, node_id: &str, callback_id: &str) {
    let _ = native_events::send_close_event(view_id, node_id, callback_id);
}

pub(crate) fn emit_hover(view_id: u64, node_id: &str, callback_id: &str, hovered: bool) {
    let _ = native_events::send_hover_event(view_id, node_id, callback_id, hovered);
}

pub(crate) fn emit_focus(view_id: u64, node_id: &str, callback_id: &str) {
    let _ = native_events::send_focus_event(view_id, node_id, callback_id);
}

pub(crate) fn emit_blur(view_id: u64, node_id: &str, callback_id: &str) {
    let _ = native_events::send_blur_event(view_id, node_id, callback_id);
}

pub(crate) fn emit_change(view_id: u64, node_id: &str, callback_id: &str, value: &str) {
    let _ = native_events::send_change_event(view_id, node_id, callback_id, value);
}

pub(crate) fn emit_key_down(view_id: u64, node_id: &str, callback_id: &str, event: &KeyDownEvent) {
    let _ = native_events::send_key_down_event(
        view_id,
        node_id,
        callback_id,
        KeyEventPayload {
            key: event.keystroke.key.as_str(),
            key_char: key_char(event.keystroke.key_char.as_ref()),
            is_held: event.is_held,
            modifiers: modifier_flags(&event.keystroke.modifiers),
        },
    );
}

pub(crate) fn emit_key_up(view_id: u64, node_id: &str, callback_id: &str, event: &KeyUpEvent) {
    let _ = native_events::send_key_up_event(
        view_id,
        node_id,
        callback_id,
        KeyEventPayload {
            key: event.keystroke.key.as_str(),
            key_char: key_char(event.keystroke.key_char.as_ref()),
            is_held: false,
            modifiers: modifier_flags(&event.keystroke.modifiers),
        },
    );
}

pub(crate) fn emit_action(
    view_id: u64,
    node_id: &str,
    shortcut: &ShortcutBinding,
    event: &KeyDownEvent,
) {
    let _ = native_events::send_action_event(
        view_id,
        node_id,
        &shortcut.callback,
        ActionEventPayload {
            action: &shortcut.action,
            shortcut: &shortcut.shortcut,
            key: event.keystroke.key.as_str(),
            key_char: key_char(event.keystroke.key_char.as_ref()),
            modifiers: modifier_flags(&event.keystroke.modifiers),
        },
    );
}

pub(crate) fn emit_context_menu(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    event: &MouseDownEvent,
) {
    let _ = native_events::send_context_menu_event(
        view_id,
        node_id,
        callback_id,
        ContextMenuEventPayload {
            x: pixel_to_f64(event.position.x),
            y: pixel_to_f64(event.position.y),
            modifiers: modifier_flags(&event.modifiers),
        },
    );
}

pub(crate) fn emit_drag_start(view_id: u64, node_id: &str, callback_id: &str, source_id: &str) {
    let _ = native_events::send_drag_start_event(view_id, node_id, callback_id, source_id);
}

pub(crate) fn emit_drag_move(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    source_id: &str,
    pressed_button: Option<MouseButton>,
    position: gpui::Point<Pixels>,
    modifiers: &Modifiers,
) {
    let _ = native_events::send_drag_move_event(
        view_id,
        node_id,
        callback_id,
        DragMoveEventPayload {
            source_id,
            pressed_button_code: optional_mouse_button_code(pressed_button),
            x: pixel_to_f64(position.x),
            y: pixel_to_f64(position.y),
            modifiers: modifier_flags(modifiers),
        },
    );
}

pub(crate) fn emit_drop(view_id: u64, node_id: &str, callback_id: &str, source_id: &str) {
    let _ = native_events::send_drop_event(view_id, node_id, callback_id, source_id);
}

pub(crate) fn emit_mouse_down(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    event: &MouseDownEvent,
) {
    let _ = native_events::send_mouse_down_event(
        view_id,
        node_id,
        callback_id,
        MouseDownEventPayload {
            button_code: mouse_button_code(event.button),
            x: pixel_to_f64(event.position.x),
            y: pixel_to_f64(event.position.y),
            click_count: event.click_count as u64,
            modifiers: modifier_flags(&event.modifiers),
            first_mouse: event.first_mouse,
        },
    );
}

pub(crate) fn emit_mouse_up(view_id: u64, node_id: &str, callback_id: &str, event: &MouseUpEvent) {
    let _ = native_events::send_mouse_up_event(
        view_id,
        node_id,
        callback_id,
        MouseUpEventPayload {
            button_code: mouse_button_code(event.button),
            x: pixel_to_f64(event.position.x),
            y: pixel_to_f64(event.position.y),
            click_count: event.click_count as u64,
            modifiers: modifier_flags(&event.modifiers),
        },
    );
}

pub(crate) fn emit_mouse_move(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    event: &MouseMoveEvent,
) {
    let _ = native_events::send_mouse_move_event(
        view_id,
        node_id,
        callback_id,
        MouseMoveEventPayload {
            pressed_button_code: optional_mouse_button_code(event.pressed_button),
            x: pixel_to_f64(event.position.x),
            y: pixel_to_f64(event.position.y),
            modifiers: modifier_flags(&event.modifiers),
        },
    );
}

pub(crate) fn emit_scroll_wheel(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    event: &ScrollWheelEvent,
) {
    let (delta_kind_code, delta_x, delta_y) = scroll_delta_parts(event.delta);

    let _ = native_events::send_scroll_wheel_event(
        view_id,
        node_id,
        callback_id,
        ScrollWheelEventPayload {
            x: pixel_to_f64(event.position.x),
            y: pixel_to_f64(event.position.y),
            delta_kind_code,
            delta_x,
            delta_y,
            modifiers: modifier_flags(&event.modifiers),
        },
    );
}

pub(crate) fn matching_shortcut<'a>(
    event: &KeyDownEvent,
    shortcuts: &'a [ShortcutBinding],
) -> Option<&'a ShortcutBinding> {
    if event.is_held {
        return None;
    }

    shortcuts
        .iter()
        .find(|shortcut| event.keystroke.should_match(&shortcut.parsed))
}

fn modifier_flags(modifiers: &Modifiers) -> EventModifiers {
    EventModifiers {
        control: modifiers.control,
        alt: modifiers.alt,
        shift: modifiers.shift,
        platform: modifiers.platform,
        function: modifiers.function,
    }
}

fn key_char(key_char: Option<&String>) -> Option<&str> {
    key_char.map(String::as_str)
}

fn pixel_to_f64(value: Pixels) -> f64 {
    f64::from(value)
}

fn mouse_button_code(button: MouseButton) -> i32 {
    match button {
        MouseButton::Left => 1,
        MouseButton::Right => 2,
        MouseButton::Middle => 3,
        MouseButton::Navigate(gpui::NavigationDirection::Back) => 4,
        MouseButton::Navigate(gpui::NavigationDirection::Forward) => 5,
    }
}

fn optional_mouse_button_code(button: Option<MouseButton>) -> i32 {
    button.map(mouse_button_code).unwrap_or(0)
}

fn scroll_delta_parts(delta: ScrollDelta) -> (i32, f64, f64) {
    match delta {
        ScrollDelta::Pixels(delta) => (1, pixel_to_f64(delta.x), pixel_to_f64(delta.y)),
        ScrollDelta::Lines(delta) => (2, f64::from(delta.x), f64::from(delta.y)),
    }
}

#[cfg(test)]
#[path = "events_tests.rs"]
mod tests;
