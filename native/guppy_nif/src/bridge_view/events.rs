use crate::ir::ShortcutBinding;
use gpui::{
    KeyDownEvent, KeyUpEvent, Modifiers, MouseButton, MouseDownEvent, MouseMoveEvent, MouseUpEvent,
    Pixels, ScrollDelta, ScrollWheelEvent,
};

#[derive(Clone, Debug)]
pub(crate) struct BridgeDragState {
    pub source_id: String,
}

mod ffi {
    unsafe extern "C" {
        pub(super) fn guppy_c_send_click_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
        ) -> i32;

        pub(super) fn guppy_c_send_hover_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            hovered: i32,
        ) -> i32;

        pub(super) fn guppy_c_send_focus_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
        ) -> i32;

        pub(super) fn guppy_c_send_blur_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
        ) -> i32;

        pub(super) fn guppy_c_send_key_down_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            key_ptr: *const u8,
            key_len: usize,
            key_char_ptr: *const u8,
            key_char_len: usize,
            has_key_char: i32,
            is_held: i32,
            control: i32,
            alt: i32,
            shift: i32,
            platform: i32,
            function: i32,
        ) -> i32;

        pub(super) fn guppy_c_send_key_up_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            key_ptr: *const u8,
            key_len: usize,
            key_char_ptr: *const u8,
            key_char_len: usize,
            has_key_char: i32,
            control: i32,
            alt: i32,
            shift: i32,
            platform: i32,
            function: i32,
        ) -> i32;

        pub(super) fn guppy_c_send_action_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            action_ptr: *const u8,
            action_len: usize,
            shortcut_ptr: *const u8,
            shortcut_len: usize,
            key_ptr: *const u8,
            key_len: usize,
            key_char_ptr: *const u8,
            key_char_len: usize,
            has_key_char: i32,
            control: i32,
            alt: i32,
            shift: i32,
            platform: i32,
            function: i32,
        ) -> i32;

        pub(super) fn guppy_c_send_context_menu_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            x: f64,
            y: f64,
            control: i32,
            alt: i32,
            shift: i32,
            platform: i32,
            function: i32,
        ) -> i32;

        pub(super) fn guppy_c_send_drag_start_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            source_id_ptr: *const u8,
            source_id_len: usize,
        ) -> i32;

        pub(super) fn guppy_c_send_drag_move_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            source_id_ptr: *const u8,
            source_id_len: usize,
            pressed_button_code: i32,
            x: f64,
            y: f64,
            control: i32,
            alt: i32,
            shift: i32,
            platform: i32,
            function: i32,
        ) -> i32;

        pub(super) fn guppy_c_send_drop_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            source_id_ptr: *const u8,
            source_id_len: usize,
        ) -> i32;

        pub(super) fn guppy_c_send_mouse_down_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            button_code: i32,
            x: f64,
            y: f64,
            click_count: u64,
            control: i32,
            alt: i32,
            shift: i32,
            platform: i32,
            function: i32,
            first_mouse: i32,
        ) -> i32;

        pub(super) fn guppy_c_send_mouse_up_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            button_code: i32,
            x: f64,
            y: f64,
            click_count: u64,
            control: i32,
            alt: i32,
            shift: i32,
            platform: i32,
            function: i32,
        ) -> i32;

        pub(super) fn guppy_c_send_mouse_move_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            pressed_button_code: i32,
            x: f64,
            y: f64,
            control: i32,
            alt: i32,
            shift: i32,
            platform: i32,
            function: i32,
        ) -> i32;

        pub(super) fn guppy_c_send_scroll_wheel_event(
            view_id: u64,
            node_id_ptr: *const u8,
            node_id_len: usize,
            callback_id_ptr: *const u8,
            callback_id_len: usize,
            x: f64,
            y: f64,
            delta_kind_code: i32,
            delta_x: f64,
            delta_y: f64,
            control: i32,
            alt: i32,
            shift: i32,
            platform: i32,
            function: i32,
        ) -> i32;
    }
}

pub(crate) fn emit_click(view_id: u64, node_id: &str, callback_id: &str) {
    unsafe {
        let _ = ffi::guppy_c_send_click_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
        );
    }
}

pub(crate) fn emit_hover(view_id: u64, node_id: &str, callback_id: &str, hovered: bool) {
    unsafe {
        let _ = ffi::guppy_c_send_hover_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            if hovered { 1 } else { 0 },
        );
    }
}

pub(crate) fn emit_focus(view_id: u64, node_id: &str, callback_id: &str) {
    unsafe {
        let _ = ffi::guppy_c_send_focus_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
        );
    }
}

pub(crate) fn emit_blur(view_id: u64, node_id: &str, callback_id: &str) {
    unsafe {
        let _ = ffi::guppy_c_send_blur_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
        );
    }
}

pub(crate) fn emit_key_down(view_id: u64, node_id: &str, callback_id: &str, event: &KeyDownEvent) {
    let key = event.keystroke.key.as_bytes();
    let (key_char_ptr, key_char_len, has_key_char) =
        key_char_parts(event.keystroke.key_char.as_ref());
    let (control, alt, shift, platform, function) = modifier_flags(&event.keystroke.modifiers);

    unsafe {
        let _ = ffi::guppy_c_send_key_down_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            key.as_ptr(),
            key.len(),
            key_char_ptr,
            key_char_len,
            has_key_char,
            if event.is_held { 1 } else { 0 },
            control,
            alt,
            shift,
            platform,
            function,
        );
    }
}

pub(crate) fn emit_key_up(view_id: u64, node_id: &str, callback_id: &str, event: &KeyUpEvent) {
    let key = event.keystroke.key.as_bytes();
    let (key_char_ptr, key_char_len, has_key_char) =
        key_char_parts(event.keystroke.key_char.as_ref());
    let (control, alt, shift, platform, function) = modifier_flags(&event.keystroke.modifiers);

    unsafe {
        let _ = ffi::guppy_c_send_key_up_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            key.as_ptr(),
            key.len(),
            key_char_ptr,
            key_char_len,
            has_key_char,
            control,
            alt,
            shift,
            platform,
            function,
        );
    }
}

pub(crate) fn emit_action(
    view_id: u64,
    node_id: &str,
    shortcut: &ShortcutBinding,
    event: &KeyDownEvent,
) {
    let key = event.keystroke.key.as_bytes();
    let (key_char_ptr, key_char_len, has_key_char) =
        key_char_parts(event.keystroke.key_char.as_ref());
    let (control, alt, shift, platform, function) = modifier_flags(&event.keystroke.modifiers);

    unsafe {
        let _ = ffi::guppy_c_send_action_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            shortcut.callback.as_ptr(),
            shortcut.callback.len(),
            shortcut.action.as_ptr(),
            shortcut.action.len(),
            shortcut.shortcut.as_ptr(),
            shortcut.shortcut.len(),
            key.as_ptr(),
            key.len(),
            key_char_ptr,
            key_char_len,
            has_key_char,
            control,
            alt,
            shift,
            platform,
            function,
        );
    }
}

pub(crate) fn emit_context_menu(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    event: &MouseDownEvent,
) {
    let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);

    unsafe {
        let _ = ffi::guppy_c_send_context_menu_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            pixel_to_f64(event.position.x),
            pixel_to_f64(event.position.y),
            control,
            alt,
            shift,
            platform,
            function,
        );
    }
}

pub(crate) fn emit_drag_start(view_id: u64, node_id: &str, callback_id: &str, source_id: &str) {
    unsafe {
        let _ = ffi::guppy_c_send_drag_start_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            source_id.as_ptr(),
            source_id.len(),
        );
    }
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
    let (control, alt, shift, platform, function) = modifier_flags(modifiers);

    unsafe {
        let _ = ffi::guppy_c_send_drag_move_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            source_id.as_ptr(),
            source_id.len(),
            optional_mouse_button_code(pressed_button),
            pixel_to_f64(position.x),
            pixel_to_f64(position.y),
            control,
            alt,
            shift,
            platform,
            function,
        );
    }
}

pub(crate) fn emit_drop(view_id: u64, node_id: &str, callback_id: &str, source_id: &str) {
    unsafe {
        let _ = ffi::guppy_c_send_drop_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            source_id.as_ptr(),
            source_id.len(),
        );
    }
}

pub(crate) fn emit_mouse_down(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    event: &MouseDownEvent,
) {
    let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);

    unsafe {
        let _ = ffi::guppy_c_send_mouse_down_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            mouse_button_code(event.button),
            pixel_to_f64(event.position.x),
            pixel_to_f64(event.position.y),
            event.click_count as u64,
            control,
            alt,
            shift,
            platform,
            function,
            if event.first_mouse { 1 } else { 0 },
        );
    }
}

pub(crate) fn emit_mouse_up(view_id: u64, node_id: &str, callback_id: &str, event: &MouseUpEvent) {
    let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);

    unsafe {
        let _ = ffi::guppy_c_send_mouse_up_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            mouse_button_code(event.button),
            pixel_to_f64(event.position.x),
            pixel_to_f64(event.position.y),
            event.click_count as u64,
            control,
            alt,
            shift,
            platform,
            function,
        );
    }
}

pub(crate) fn emit_mouse_move(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    event: &MouseMoveEvent,
) {
    let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);

    unsafe {
        let _ = ffi::guppy_c_send_mouse_move_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            optional_mouse_button_code(event.pressed_button),
            pixel_to_f64(event.position.x),
            pixel_to_f64(event.position.y),
            control,
            alt,
            shift,
            platform,
            function,
        );
    }
}

pub(crate) fn emit_scroll_wheel(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    event: &ScrollWheelEvent,
) {
    let (delta_kind_code, delta_x, delta_y) = scroll_delta_parts(event.delta);
    let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);

    unsafe {
        let _ = ffi::guppy_c_send_scroll_wheel_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
            pixel_to_f64(event.position.x),
            pixel_to_f64(event.position.y),
            delta_kind_code,
            delta_x,
            delta_y,
            control,
            alt,
            shift,
            platform,
            function,
        );
    }
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

fn modifier_flags(modifiers: &Modifiers) -> (i32, i32, i32, i32, i32) {
    (
        if modifiers.control { 1 } else { 0 },
        if modifiers.alt { 1 } else { 0 },
        if modifiers.shift { 1 } else { 0 },
        if modifiers.platform { 1 } else { 0 },
        if modifiers.function { 1 } else { 0 },
    )
}

fn key_char_parts(key_char: Option<&String>) -> (*const u8, usize, i32) {
    match key_char {
        Some(key_char) => (key_char.as_ptr(), key_char.len(), 1),
        None => (std::ptr::null(), 0, 0),
    }
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
mod tests {
    use super::matching_shortcut;
    use crate::ir::ShortcutBinding;
    use gpui::{KeyDownEvent, KeybindingKeystroke, Keystroke};

    fn shortcut(shortcut: &str, action: &str, callback: &str) -> ShortcutBinding {
        let parsed = Keystroke::parse(shortcut).expect("valid shortcut");
        ShortcutBinding {
            shortcut: shortcut.to_owned(),
            action: action.to_owned(),
            callback: callback.to_owned(),
            parsed: KeybindingKeystroke::from_keystroke(parsed),
        }
    }

    #[test]
    fn matching_shortcut_ignores_held_keys() {
        let shortcuts = vec![shortcut("ctrl-j", "primary", "primary_action")];
        let event = KeyDownEvent {
            keystroke: Keystroke::parse("ctrl-j").expect("valid keystroke"),
            is_held: true,
        };

        assert!(matching_shortcut(&event, &shortcuts).is_none());
    }

    #[test]
    fn matching_shortcut_returns_matching_binding() {
        let shortcuts = vec![
            shortcut("ctrl-k", "secondary", "secondary_action"),
            shortcut("ctrl-j", "primary", "primary_action"),
        ];
        let event = KeyDownEvent {
            keystroke: Keystroke::parse("ctrl-j").expect("valid keystroke"),
            is_held: false,
        };

        let matched = matching_shortcut(&event, &shortcuts).expect("shortcut should match");
        assert_eq!(matched.action, "primary");
        assert_eq!(matched.callback, "primary_action");
    }
}
