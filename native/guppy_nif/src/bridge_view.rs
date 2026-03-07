use crate::ir::{ColorToken, DivStyle, IrNode, ShortcutBinding, StyleOp};
use gpui::{
    AnyElement, Context, Empty, FocusHandle, FontWeight, InteractiveElement, InteractiveText,
    KeyDownEvent, KeyUpEvent, MouseButton, MouseDownEvent, MouseMoveEvent, MouseUpEvent,
    ScrollAnchor, ScrollDelta, ScrollHandle, ScrollWheelEvent, SharedString,
    StatefulInteractiveElement, StyleRefinement, Styled, StyledText, Subscription, Window,
    deferred, div, prelude::*, px, relative, rems, rgb,
};
use std::collections::{HashMap, HashSet};

unsafe extern "C" {
    fn guppy_c_send_click_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
    ) -> i32;

    fn guppy_c_send_hover_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
        hovered: i32,
    ) -> i32;

    fn guppy_c_send_focus_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
    ) -> i32;

    fn guppy_c_send_blur_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
    ) -> i32;

    fn guppy_c_send_key_down_event(
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

    fn guppy_c_send_key_up_event(
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

    fn guppy_c_send_action_event(
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

    fn guppy_c_send_context_menu_event(
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

    fn guppy_c_send_drag_start_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
        source_id_ptr: *const u8,
        source_id_len: usize,
    ) -> i32;

    fn guppy_c_send_drag_move_event(
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

    fn guppy_c_send_drop_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
        source_id_ptr: *const u8,
        source_id_len: usize,
    ) -> i32;

    fn guppy_c_send_mouse_down_event(
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

    fn guppy_c_send_mouse_up_event(
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

    fn guppy_c_send_mouse_move_event(
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

    fn guppy_c_send_scroll_wheel_event(
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

pub struct BridgeView {
    pub view_id: u64,
    pub ir: IrNode,
    pub scroll_handles: HashMap<String, ScrollHandle>,
    pub focus_handles: HashMap<String, FocusHandle>,
    pub focus_registered: HashSet<String>,
    pub focus_subscriptions: Vec<Subscription>,
}

#[derive(Clone, Debug)]
struct BridgeDragState {
    source_id: String,
}

impl Render for BridgeView {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .size_full()
            .p_6()
            .bg(rgb(0x202020))
            .text_color(rgb(0xffffff))
            .child(render_ir(
                self.view_id,
                "root",
                &self.ir,
                &mut self.scroll_handles,
                &mut self.focus_handles,
                &mut self.focus_registered,
                &mut self.focus_subscriptions,
                None,
                window,
                cx,
            ))
    }
}

fn render_ir(
    view_id: u64,
    path: &str,
    ir: &IrNode,
    scroll_handles: &mut HashMap<String, ScrollHandle>,
    focus_handles: &mut HashMap<String, FocusHandle>,
    focus_registered: &mut HashSet<String>,
    focus_subscriptions: &mut Vec<Subscription>,
    parent_scroll_handle: Option<ScrollHandle>,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    match ir {
        IrNode::Text { id, content, click } => {
            render_text(view_id, path, id.as_deref(), content, click.as_deref())
        }
        IrNode::Div {
            id,
            style,
            hover_style,
            focus_style,
            in_focus_style,
            active_style,
            disabled_style,
            disabled,
            stack_priority,
            occlude,
            focusable,
            tab_stop,
            tab_index,
            track_scroll,
            anchor_scroll,
            shortcuts,
            children,
            click,
            hover,
            focus,
            blur,
            key_down,
            key_up,
            context_menu,
            drag_start,
            drag_move,
            drop,
            mouse_down,
            mouse_up,
            mouse_move,
            scroll_wheel,
        } => render_div(
            view_id,
            path,
            id.as_deref(),
            style,
            hover_style,
            focus_style,
            in_focus_style,
            active_style,
            disabled_style,
            *disabled,
            *stack_priority,
            *occlude,
            *focusable,
            *tab_stop,
            *tab_index,
            *track_scroll,
            *anchor_scroll,
            shortcuts,
            children,
            click.as_deref(),
            hover.as_deref(),
            focus.as_deref(),
            blur.as_deref(),
            key_down.as_deref(),
            key_up.as_deref(),
            context_menu.as_deref(),
            drag_start.as_deref(),
            drag_move.as_deref(),
            drop.as_deref(),
            mouse_down.as_deref(),
            mouse_up.as_deref(),
            mouse_move.as_deref(),
            scroll_wheel.as_deref(),
            scroll_handles,
            focus_handles,
            focus_registered,
            focus_subscriptions,
            parent_scroll_handle,
            window,
            cx,
        ),
    }
}

fn render_text(
    view_id: u64,
    path: &str,
    id: Option<&str>,
    content: &str,
    click: Option<&str>,
) -> AnyElement {
    let node_id = node_id(view_id, path, id);
    let interactive_text = InteractiveText::new(
        SharedString::from(node_id.clone()),
        StyledText::new(content.to_owned()),
    );

    match click {
        Some(callback_id) if !content.is_empty() => {
            let callback_id = callback_id.to_owned();
            let click_node_id = node_id.clone();

            interactive_text
                .on_click(vec![0..content.len()], move |_, _, _| unsafe {
                    let _ = guppy_c_send_click_event(
                        view_id,
                        click_node_id.as_ptr(),
                        click_node_id.len(),
                        callback_id.as_ptr(),
                        callback_id.len(),
                    );
                })
                .into_any_element()
        }
        _ => interactive_text.into_any_element(),
    }
}

fn render_div(
    view_id: u64,
    path: &str,
    id: Option<&str>,
    style: &DivStyle,
    hover_style: &DivStyle,
    focus_style: &DivStyle,
    in_focus_style: &DivStyle,
    active_style: &DivStyle,
    disabled_style: &DivStyle,
    disabled: bool,
    stack_priority: Option<usize>,
    occlude: bool,
    focusable: bool,
    tab_stop: Option<bool>,
    tab_index: Option<isize>,
    track_scroll: bool,
    anchor_scroll: bool,
    shortcuts: &[ShortcutBinding],
    children: &[IrNode],
    click: Option<&str>,
    hover: Option<&str>,
    focus: Option<&str>,
    blur: Option<&str>,
    key_down: Option<&str>,
    key_up: Option<&str>,
    context_menu: Option<&str>,
    drag_start: Option<&str>,
    drag_move: Option<&str>,
    drop: Option<&str>,
    mouse_down: Option<&str>,
    mouse_up: Option<&str>,
    mouse_move: Option<&str>,
    scroll_wheel: Option<&str>,
    scroll_handles: &mut HashMap<String, ScrollHandle>,
    focus_handles: &mut HashMap<String, FocusHandle>,
    focus_registered: &mut HashSet<String>,
    focus_subscriptions: &mut Vec<Subscription>,
    parent_scroll_handle: Option<ScrollHandle>,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
 ) -> AnyElement {
    let node_id = node_id(view_id, path, id);
    let click = if disabled { None } else { click };
    let hover = if disabled { None } else { hover };
    let focus = if disabled { None } else { focus };
    let blur = if disabled { None } else { blur };
    let key_down = if disabled { None } else { key_down };
    let key_up = if disabled { None } else { key_up };
    let context_menu = if disabled { None } else { context_menu };
    let drag_start = if disabled { None } else { drag_start };
    let drag_move = if disabled { None } else { drag_move };
    let drop = if disabled { None } else { drop };
    let mouse_down = if disabled { None } else { mouse_down };
    let mouse_up = if disabled { None } else { mouse_up };
    let mouse_move = if disabled { None } else { mouse_move };
    let scroll_wheel = if disabled { None } else { scroll_wheel };
    let shortcuts = if disabled { Vec::new() } else { shortcuts.to_vec() };
    let focusable = focusable && !disabled;
    let tab_stop = if disabled { None } else { tab_stop };
    let tab_index = if disabled { None } else { tab_index };
    let keyboard_actionable = click.is_some() || !shortcuts.is_empty();
    let tab_stop = if keyboard_actionable {
        Some(tab_stop.unwrap_or(true))
    } else {
        tab_stop
    };

    let tracked_scroll_handle = if track_scroll {
        Some(
            scroll_handles
                .entry(node_id.clone())
                .or_insert_with(ScrollHandle::new)
                .clone(),
        )
    } else {
        None
    };

    let needs_focus_handle =
        keyboard_actionable
            || focusable
            || tab_stop.is_some()
            || tab_index.is_some()
            || !focus_style.is_empty()
            || !in_focus_style.is_empty()
            || focus.is_some()
            || blur.is_some()
            || key_down.is_some()
            || key_up.is_some();

    let focus_handle = if needs_focus_handle {
        Some(ensure_focus_handle(node_id.as_str(), focus_handles, cx, tab_stop, tab_index))
    } else {
        None
    };

    if let Some(handle) = focus_handle.as_ref() {
        register_focus_callbacks(
            view_id,
            node_id.as_str(),
            handle,
            focus,
            blur,
            focus_registered,
            focus_subscriptions,
            window,
            cx,
        );
    }

    let child_scroll_handle = tracked_scroll_handle.clone().or(parent_scroll_handle.clone());

    let child_elements = children
        .iter()
        .enumerate()
        .map(|(index, child)| {
            render_ir(
                view_id,
                &format!("{path}.{index}"),
                child,
                scroll_handles,
                focus_handles,
                focus_registered,
                focus_subscriptions,
                child_scroll_handle.clone(),
                window,
                cx,
            )
        })
        .collect::<Vec<_>>();

    let styled_div = apply_div_style(
        div()
            .id(SharedString::from(node_id.clone()))
            .children(child_elements),
        style,
    );

    let styled_div = if occlude { styled_div.occlude() } else { styled_div };

    let styled_div = match tracked_scroll_handle.as_ref() {
        Some(handle) => styled_div.track_scroll(handle),
        None => styled_div,
    };

    let styled_div = if anchor_scroll {
        match parent_scroll_handle.as_ref() {
            Some(handle) => styled_div.anchor_scroll(Some(ScrollAnchor::for_handle(handle.clone()))),
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

    let styled_div = if disabled || focus_style.is_empty() {
        styled_div
    } else {
        let focus_ops = focus_style.clone();
        styled_div.focus(move |style| apply_refinement_style(style, &focus_ops))
    };

    let styled_div = if disabled || in_focus_style.is_empty() {
        styled_div
    } else {
        let in_focus_ops = in_focus_style.clone();
        styled_div.in_focus(move |style| apply_refinement_style(style, &in_focus_ops))
    };

    let styled_div = if disabled || hover_style.is_empty() {
        styled_div
    } else {
        let hover_ops = hover_style.clone();
        styled_div.hover(move |style| apply_refinement_style(style, &hover_ops))
    };

    let styled_div = if disabled || active_style.is_empty() {
        styled_div
    } else {
        let active_ops = active_style.clone();
        styled_div.active(move |style| apply_refinement_style(style, &active_ops))
    };

    let styled_div = match hover {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let hover_node_id = node_id.clone();

            styled_div.on_hover(move |hovered, _, _| unsafe {
                let _ = guppy_c_send_hover_event(
                    view_id,
                    hover_node_id.as_ptr(),
                    hover_node_id.len(),
                    callback_id.as_ptr(),
                    callback_id.len(),
                    if *hovered { 1 } else { 0 },
                );
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
        let key_down_node_id = node_id.clone();
        let shortcut_bindings = shortcuts.to_vec();

        styled_div.on_key_down(move |event: &KeyDownEvent, _, cx| {
            let key = event.keystroke.key.as_bytes();
            let (key_char_ptr, key_char_len, has_key_char) = key_char_parts(event.keystroke.key_char.as_ref());
            let (control, alt, shift, platform, function) = modifier_flags(&event.keystroke.modifiers);

            if let Some(callback_id) = key_down_callback_id.as_ref() {
                unsafe {
                    let _ = guppy_c_send_key_down_event(
                        view_id,
                        key_down_node_id.as_ptr(),
                        key_down_node_id.len(),
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

            if let Some(shortcut) = matching_shortcut(event, &shortcut_bindings) {
                unsafe {
                    let _ = guppy_c_send_action_event(
                        view_id,
                        key_down_node_id.as_ptr(),
                        key_down_node_id.len(),
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

                cx.stop_propagation();
            }
        })
    } else {
        styled_div
    };

    let styled_div = match key_up {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let key_up_node_id = node_id.clone();

            styled_div.on_key_up(move |event: &KeyUpEvent, _, _| unsafe {
                let key = event.keystroke.key.as_bytes();
                let (key_char_ptr, key_char_len, has_key_char) = match event.keystroke.key_char.as_ref() {
                    Some(key_char) => (key_char.as_ptr(), key_char.len(), 1),
                    None => (std::ptr::null(), 0, 0),
                };
                let (control, alt, shift, platform, function) = modifier_flags(&event.keystroke.modifiers);
                let _ = guppy_c_send_key_up_event(
                    view_id,
                    key_up_node_id.as_ptr(),
                    key_up_node_id.len(),
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
            })
        }
        None => styled_div,
    };

    let styled_div = match context_menu {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let context_menu_node_id = node_id.clone();

            styled_div.on_mouse_down(MouseButton::Right, move |event: &MouseDownEvent, _, _| unsafe {
                let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);
                let _ = guppy_c_send_context_menu_event(
                    view_id,
                    context_menu_node_id.as_ptr(),
                    context_menu_node_id.len(),
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
            })
        }
        None => styled_div,
    };

    let styled_div = match drop {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let drop_node_id = node_id.clone();

            styled_div.on_drop::<BridgeDragState>(move |drag, _, _| unsafe {
                let _ = guppy_c_send_drop_event(
                    view_id,
                    drop_node_id.as_ptr(),
                    drop_node_id.len(),
                    callback_id.as_ptr(),
                    callback_id.len(),
                    drag.source_id.as_ptr(),
                    drag.source_id.len(),
                );
            })
        }
        None => styled_div,
    };

    let styled_div = match drag_move {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let drag_move_node_id = node_id.clone();

            styled_div.on_drag_move::<BridgeDragState>(move |event, _, cx| unsafe {
                let drag = event.drag(cx);
                let (control, alt, shift, platform, function) = modifier_flags(&event.event.modifiers);
                let _ = guppy_c_send_drag_move_event(
                    view_id,
                    drag_move_node_id.as_ptr(),
                    drag_move_node_id.len(),
                    callback_id.as_ptr(),
                    callback_id.len(),
                    drag.source_id.as_ptr(),
                    drag.source_id.len(),
                    optional_mouse_button_code(event.event.pressed_button),
                    pixel_to_f64(event.event.position.x),
                    pixel_to_f64(event.event.position.y),
                    control,
                    alt,
                    shift,
                    platform,
                    function,
                );
            })
        }
        None => styled_div,
    };

    let styled_div = match drag_start {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let drag_start_node_id = node_id.clone();
            let drag_source_id = node_id.clone();

            styled_div.on_drag(
                BridgeDragState {
                    source_id: drag_source_id,
                },
                move |drag, _, _, cx| {
                    unsafe {
                        let _ = guppy_c_send_drag_start_event(
                            view_id,
                            drag_start_node_id.as_ptr(),
                            drag_start_node_id.len(),
                            callback_id.as_ptr(),
                            callback_id.len(),
                            drag.source_id.as_ptr(),
                            drag.source_id.len(),
                        );
                    }

                    cx.new(|_| Empty)
                },
            )
        }
        None if drag_move.is_some() => {
            let drag_source_id = node_id.clone();

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
            let mouse_down_node_id = node_id.clone();

            styled_div.on_any_mouse_down(move |event: &MouseDownEvent, _, _| unsafe {
                let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);
                let _ = guppy_c_send_mouse_down_event(
                    view_id,
                    mouse_down_node_id.as_ptr(),
                    mouse_down_node_id.len(),
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
            })
        }
        None => styled_div,
    };

    let styled_div = match mouse_up {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let mouse_up_node_id = node_id.clone();

            styled_div.capture_any_mouse_up(move |event: &MouseUpEvent, _, _| unsafe {
                let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);
                let _ = guppy_c_send_mouse_up_event(
                    view_id,
                    mouse_up_node_id.as_ptr(),
                    mouse_up_node_id.len(),
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
            })
        }
        None => styled_div,
    };

    let styled_div = match mouse_move {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let mouse_move_node_id = node_id.clone();

            styled_div.on_mouse_move(move |event: &MouseMoveEvent, _, _| unsafe {
                let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);
                let _ = guppy_c_send_mouse_move_event(
                    view_id,
                    mouse_move_node_id.as_ptr(),
                    mouse_move_node_id.len(),
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
            })
        }
        None => styled_div,
    };

    let styled_div = match scroll_wheel {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let scroll_node_id = node_id.clone();

            styled_div.on_scroll_wheel(move |event: &ScrollWheelEvent, _, _| unsafe {
                let (delta_kind_code, delta_x, delta_y) = scroll_delta_parts(event.delta);
                let (control, alt, shift, platform, function) = modifier_flags(&event.modifiers);
                let _ = guppy_c_send_scroll_wheel_event(
                    view_id,
                    scroll_node_id.as_ptr(),
                    scroll_node_id.len(),
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
            })
        }
        None => styled_div,
    };

    let styled_div = if disabled && !disabled_style.is_empty() {
        apply_div_style(styled_div, disabled_style)
    } else {
        styled_div
    };

    let element = match click {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let click_node_id = node_id.clone();

            styled_div
                .on_click(move |_, _, _| unsafe {
                    let _ = guppy_c_send_click_event(
                        view_id,
                        click_node_id.as_ptr(),
                        click_node_id.len(),
                        callback_id.as_ptr(),
                        callback_id.len(),
                    );
                })
                .into_any_element()
        }
        None => styled_div.into_any_element(),
    };

    match stack_priority {
        Some(priority) => deferred(element).with_priority(priority).into_any_element(),
        None => element,
    }
}

fn apply_div_style<E>(mut element: E, style: &DivStyle) -> E
where
    E: Styled + StatefulInteractiveElement,
{
    for op in style {
        element = match op {
            StyleOp::Flex => element.flex(),
            StyleOp::FlexCol => element.flex_col(),
            StyleOp::FlexRow => element.flex_row(),
            StyleOp::FlexWrap => element.flex_wrap(),
            StyleOp::FlexNowrap => element.flex_nowrap(),
            StyleOp::FlexNone => element.flex_none(),
            StyleOp::FlexAuto => element.flex_auto(),
            StyleOp::FlexGrow => element.flex_grow(),
            StyleOp::FlexShrink => element.flex_shrink(),
            StyleOp::FlexShrink0 => element.flex_shrink_0(),
            StyleOp::Flex1 => element.flex_1(),
            StyleOp::SizeFull => element.size_full(),
            StyleOp::WFull => element.w_full(),
            StyleOp::HFull => element.h_full(),
            StyleOp::W32 => element.w_32(),
            StyleOp::W64 => element.w_64(),
            StyleOp::W96 => element.w_96(),
            StyleOp::H32 => element.h_32(),
            StyleOp::MinW32 => element.min_w_32(),
            StyleOp::MinH0 => element.min_h_0(),
            StyleOp::MinHFull => element.min_h_full(),
            StyleOp::MaxW64 => element.max_w_64(),
            StyleOp::MaxW96 => element.max_w_96(),
            StyleOp::MaxWFull => element.max_w_full(),
            StyleOp::MaxH32 => element.max_h_32(),
            StyleOp::MaxH96 => element.max_h_96(),
            StyleOp::MaxHFull => element.max_h_full(),
            StyleOp::Gap1 => element.gap_1(),
            StyleOp::Gap2 => element.gap_2(),
            StyleOp::Gap4 => element.gap_4(),
            StyleOp::P1 => element.p_1(),
            StyleOp::P2 => element.p_2(),
            StyleOp::P4 => element.p_4(),
            StyleOp::P6 => element.p_6(),
            StyleOp::P8 => element.p_8(),
            StyleOp::Px2 => element.px_2(),
            StyleOp::Py2 => element.py_2(),
            StyleOp::Pt2 => element.pt_2(),
            StyleOp::Pr2 => element.pr_2(),
            StyleOp::Pb2 => element.pb_2(),
            StyleOp::Pl2 => element.pl_2(),
            StyleOp::M2 => element.m_2(),
            StyleOp::Mx2 => element.mx_2(),
            StyleOp::My2 => element.my_2(),
            StyleOp::Mt2 => element.mt_2(),
            StyleOp::Mr2 => element.mr_2(),
            StyleOp::Mb2 => element.mb_2(),
            StyleOp::Ml2 => element.ml_2(),
            StyleOp::Relative => element.relative(),
            StyleOp::Absolute => element.absolute(),
            StyleOp::Top0 => element.top_0(),
            StyleOp::Right0 => element.right_0(),
            StyleOp::Bottom0 => element.bottom_0(),
            StyleOp::Left0 => element.left_0(),
            StyleOp::Inset0 => element.inset_0(),
            StyleOp::Top1 => element.top_1(),
            StyleOp::Right1 => element.right_1(),
            StyleOp::Top2 => element.top_2(),
            StyleOp::Right2 => element.right_2(),
            StyleOp::Bottom2 => element.bottom_2(),
            StyleOp::Left2 => element.left_2(),
            StyleOp::TextLeft => element.text_left(),
            StyleOp::TextCenter => element.text_center(),
            StyleOp::TextRight => element.text_right(),
            StyleOp::WhitespaceNormal => element.whitespace_normal(),
            StyleOp::WhitespaceNowrap => element.whitespace_nowrap(),
            StyleOp::Truncate => element.truncate(),
            StyleOp::TextEllipsis => element.text_ellipsis(),
            StyleOp::LineClamp2 => element.line_clamp(2),
            StyleOp::LineClamp3 => element.line_clamp(3),
            StyleOp::TextXs => element.text_xs(),
            StyleOp::TextSm => element.text_sm(),
            StyleOp::TextBase => element.text_base(),
            StyleOp::TextLg => element.text_lg(),
            StyleOp::TextXl => element.text_xl(),
            StyleOp::Text2xl => element.text_2xl(),
            StyleOp::Text3xl => element.text_3xl(),
            StyleOp::LeadingNone => element.line_height(relative(1.0)),
            StyleOp::LeadingTight => element.line_height(relative(1.25)),
            StyleOp::LeadingSnug => element.line_height(relative(1.375)),
            StyleOp::LeadingNormal => element.line_height(relative(1.5)),
            StyleOp::LeadingRelaxed => element.line_height(relative(1.625)),
            StyleOp::LeadingLoose => element.line_height(relative(2.0)),
            StyleOp::FontThin => element.font_weight(FontWeight::THIN),
            StyleOp::FontExtralight => element.font_weight(FontWeight::EXTRA_LIGHT),
            StyleOp::FontLight => element.font_weight(FontWeight::LIGHT),
            StyleOp::FontNormal => element.font_weight(FontWeight::NORMAL),
            StyleOp::FontMedium => element.font_weight(FontWeight::MEDIUM),
            StyleOp::FontSemibold => element.font_weight(FontWeight::SEMIBOLD),
            StyleOp::FontBold => element.font_weight(FontWeight::BOLD),
            StyleOp::FontExtrabold => element.font_weight(FontWeight::EXTRA_BOLD),
            StyleOp::FontBlack => element.font_weight(FontWeight::BLACK),
            StyleOp::Italic => element.italic(),
            StyleOp::NotItalic => element.not_italic(),
            StyleOp::Underline => element.underline(),
            StyleOp::LineThrough => element.line_through(),
            StyleOp::ItemsStart => element.items_start(),
            StyleOp::ItemsCenter => element.items_center(),
            StyleOp::ItemsEnd => element.items_end(),
            StyleOp::JustifyStart => element.justify_start(),
            StyleOp::JustifyCenter => element.justify_center(),
            StyleOp::JustifyEnd => element.justify_end(),
            StyleOp::JustifyBetween => element.justify_between(),
            StyleOp::JustifyAround => element.justify_around(),
            StyleOp::CursorPointer => element.cursor_pointer(),
            StyleOp::RoundedSm => element.rounded_sm(),
            StyleOp::RoundedMd => element.rounded_md(),
            StyleOp::RoundedLg => element.rounded_lg(),
            StyleOp::RoundedXl => element.rounded_xl(),
            StyleOp::Rounded2xl => element.rounded_2xl(),
            StyleOp::RoundedFull => element.rounded_full(),
            StyleOp::Border1 => element.border_1(),
            StyleOp::Border2 => element.border_2(),
            StyleOp::BorderDashed => element.border_dashed(),
            StyleOp::BorderT1 => element.border_t_1(),
            StyleOp::BorderR1 => element.border_r_1(),
            StyleOp::BorderB1 => element.border_b_1(),
            StyleOp::BorderL1 => element.border_l_1(),
            StyleOp::ShadowSm => element.shadow_sm(),
            StyleOp::ShadowMd => element.shadow_md(),
            StyleOp::ShadowLg => element.shadow_lg(),
            StyleOp::OverflowScroll => element.overflow_scroll(),
            StyleOp::OverflowXScroll => element.overflow_x_scroll(),
            StyleOp::OverflowYScroll => element.overflow_y_scroll(),
            StyleOp::OverflowHidden => element.overflow_hidden(),
            StyleOp::OverflowXHidden => element.overflow_x_hidden(),
            StyleOp::OverflowYHidden => element.overflow_y_hidden(),
            StyleOp::Bg(color) => element.bg(color_token_to_color(*color)),
            StyleOp::TextColor(color) => element.text_color(color_token_to_color(*color)),
            StyleOp::BorderColor(color) => element.border_color(color_token_to_color(*color)),
            StyleOp::BgHex(value) => element.bg(hex_color_to_color(value)),
            StyleOp::TextColorHex(value) => element.text_color(hex_color_to_color(value)),
            StyleOp::BorderColorHex(value) => element.border_color(hex_color_to_color(value)),
            StyleOp::Opacity(value) => element.opacity(*value),
            StyleOp::WPx(value) => element.w(px(*value)),
            StyleOp::WRem(value) => element.w(rems(*value)),
            StyleOp::WFrac(value) => element.w(relative(*value)),
            StyleOp::HPx(value) => element.h(px(*value)),
            StyleOp::HRem(value) => element.h(rems(*value)),
            StyleOp::HFrac(value) => element.h(relative(*value)),
            StyleOp::ScrollbarWidthPx(value) => element.scrollbar_width(px(*value)),
            StyleOp::ScrollbarWidthRem(value) => element.scrollbar_width(rems(*value)),
        };
    }

    element
}

fn apply_refinement_style(mut style: StyleRefinement, ops: &DivStyle) -> StyleRefinement {
    for op in ops {
        style = match op {
            StyleOp::Flex
            | StyleOp::FlexCol
            | StyleOp::FlexRow
            | StyleOp::FlexWrap
            | StyleOp::FlexNowrap
            | StyleOp::FlexNone
            | StyleOp::FlexAuto
            | StyleOp::FlexGrow
            | StyleOp::FlexShrink
            | StyleOp::FlexShrink0
            | StyleOp::Flex1
            | StyleOp::SizeFull
            | StyleOp::WFull
            | StyleOp::HFull
            | StyleOp::W32
            | StyleOp::W64
            | StyleOp::W96
            | StyleOp::H32
            | StyleOp::MinW32
            | StyleOp::MinH0
            | StyleOp::MinHFull
            | StyleOp::MaxW64
            | StyleOp::MaxW96
            | StyleOp::MaxWFull
            | StyleOp::MaxH32
            | StyleOp::MaxH96
            | StyleOp::MaxHFull
            | StyleOp::Gap1
            | StyleOp::Gap2
            | StyleOp::Gap4
            | StyleOp::P1
            | StyleOp::P2
            | StyleOp::P4
            | StyleOp::P6
            | StyleOp::P8
            | StyleOp::Px2
            | StyleOp::Py2
            | StyleOp::Pt2
            | StyleOp::Pr2
            | StyleOp::Pb2
            | StyleOp::Pl2
            | StyleOp::M2
            | StyleOp::Mx2
            | StyleOp::My2
            | StyleOp::Mt2
            | StyleOp::Mr2
            | StyleOp::Mb2
            | StyleOp::Ml2
            | StyleOp::Relative
            | StyleOp::Absolute
            | StyleOp::Top0
            | StyleOp::Right0
            | StyleOp::Bottom0
            | StyleOp::Left0
            | StyleOp::Inset0
            | StyleOp::Top1
            | StyleOp::Right1
            | StyleOp::Top2
            | StyleOp::Right2
            | StyleOp::Bottom2
            | StyleOp::Left2
            | StyleOp::OverflowScroll
            | StyleOp::OverflowXScroll
            | StyleOp::OverflowYScroll
            | StyleOp::OverflowHidden
            | StyleOp::OverflowXHidden
            | StyleOp::OverflowYHidden => style,
            StyleOp::TextLeft => style.text_left(),
            StyleOp::TextCenter => style.text_center(),
            StyleOp::TextRight => style.text_right(),
            StyleOp::WhitespaceNormal => style.whitespace_normal(),
            StyleOp::WhitespaceNowrap => style.whitespace_nowrap(),
            StyleOp::Truncate => style.truncate(),
            StyleOp::TextEllipsis => style.text_ellipsis(),
            StyleOp::LineClamp2 => style.line_clamp(2),
            StyleOp::LineClamp3 => style.line_clamp(3),
            StyleOp::TextXs => style.text_xs(),
            StyleOp::TextSm => style.text_sm(),
            StyleOp::TextBase => style.text_base(),
            StyleOp::TextLg => style.text_lg(),
            StyleOp::TextXl => style.text_xl(),
            StyleOp::Text2xl => style.text_2xl(),
            StyleOp::Text3xl => style.text_3xl(),
            StyleOp::LeadingNone => style.line_height(relative(1.0)),
            StyleOp::LeadingTight => style.line_height(relative(1.25)),
            StyleOp::LeadingSnug => style.line_height(relative(1.375)),
            StyleOp::LeadingNormal => style.line_height(relative(1.5)),
            StyleOp::LeadingRelaxed => style.line_height(relative(1.625)),
            StyleOp::LeadingLoose => style.line_height(relative(2.0)),
            StyleOp::FontThin => style.font_weight(FontWeight::THIN),
            StyleOp::FontExtralight => style.font_weight(FontWeight::EXTRA_LIGHT),
            StyleOp::FontLight => style.font_weight(FontWeight::LIGHT),
            StyleOp::FontNormal => style.font_weight(FontWeight::NORMAL),
            StyleOp::FontMedium => style.font_weight(FontWeight::MEDIUM),
            StyleOp::FontSemibold => style.font_weight(FontWeight::SEMIBOLD),
            StyleOp::FontBold => style.font_weight(FontWeight::BOLD),
            StyleOp::FontExtrabold => style.font_weight(FontWeight::EXTRA_BOLD),
            StyleOp::FontBlack => style.font_weight(FontWeight::BLACK),
            StyleOp::Italic => style.italic(),
            StyleOp::NotItalic => style.not_italic(),
            StyleOp::Underline => style.underline(),
            StyleOp::LineThrough => style.line_through(),
            StyleOp::ItemsStart => style.items_start(),
            StyleOp::ItemsCenter => style.items_center(),
            StyleOp::ItemsEnd => style.items_end(),
            StyleOp::JustifyStart => style.justify_start(),
            StyleOp::JustifyCenter => style.justify_center(),
            StyleOp::JustifyEnd => style.justify_end(),
            StyleOp::JustifyBetween => style.justify_between(),
            StyleOp::JustifyAround => style.justify_around(),
            StyleOp::CursorPointer => style.cursor_pointer(),
            StyleOp::RoundedSm => style.rounded_sm(),
            StyleOp::RoundedMd => style.rounded_md(),
            StyleOp::RoundedLg => style.rounded_lg(),
            StyleOp::RoundedXl => style.rounded_xl(),
            StyleOp::Rounded2xl => style.rounded_2xl(),
            StyleOp::RoundedFull => style.rounded_full(),
            StyleOp::Border1 => style.border_1(),
            StyleOp::Border2 => style.border_2(),
            StyleOp::BorderDashed => style.border_dashed(),
            StyleOp::BorderT1 => style.border_t_1(),
            StyleOp::BorderR1 => style.border_r_1(),
            StyleOp::BorderB1 => style.border_b_1(),
            StyleOp::BorderL1 => style.border_l_1(),
            StyleOp::ShadowSm => style.shadow_sm(),
            StyleOp::ShadowMd => style.shadow_md(),
            StyleOp::ShadowLg => style.shadow_lg(),
            StyleOp::Bg(color) => style.bg(color_token_to_color(*color)),
            StyleOp::TextColor(color) => style.text_color(color_token_to_color(*color)),
            StyleOp::BorderColor(color) => style.border_color(color_token_to_color(*color)),
            StyleOp::BgHex(value) => style.bg(hex_color_to_color(value)),
            StyleOp::TextColorHex(value) => style.text_color(hex_color_to_color(value)),
            StyleOp::BorderColorHex(value) => style.border_color(hex_color_to_color(value)),
            StyleOp::Opacity(value) => style.opacity(*value),
            StyleOp::WPx(value) => style.w(px(*value)),
            StyleOp::WRem(value) => style.w(rems(*value)),
            StyleOp::WFrac(value) => style.w(relative(*value)),
            StyleOp::HPx(value) => style.h(px(*value)),
            StyleOp::HRem(value) => style.h(rems(*value)),
            StyleOp::HFrac(value) => style.h(relative(*value)),
            StyleOp::ScrollbarWidthPx(_) => style,
            StyleOp::ScrollbarWidthRem(_) => style,
        };
    }

    style
}

fn ensure_focus_handle(
    node_id: &str,
    focus_handles: &mut HashMap<String, FocusHandle>,
    cx: &mut Context<BridgeView>,
    tab_stop: Option<bool>,
    tab_index: Option<isize>,
) -> FocusHandle {
    let handle = focus_handles
        .entry(node_id.to_owned())
        .or_insert_with(|| cx.focus_handle())
        .clone();

    let handle = match tab_stop {
        Some(tab_stop) => handle.tab_stop(tab_stop),
        None => handle,
    };

    match tab_index {
        Some(tab_index) => handle.tab_index(tab_index),
        None => handle,
    }
}

fn register_focus_callbacks(
    view_id: u64,
    node_id: &str,
    focus_handle: &FocusHandle,
    focus: Option<&str>,
    blur: Option<&str>,
    focus_registered: &mut HashSet<String>,
    focus_subscriptions: &mut Vec<Subscription>,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) {
    let Some(_) = focus.or(blur) else {
        return;
    };

    if focus_registered.contains(node_id) {
        return;
    }

    if let Some(callback_id) = focus {
        let focus_node_id = node_id.to_owned();
        let callback_id = callback_id.to_owned();
        let subscription = cx.on_focus(focus_handle, window, move |_, _, _| unsafe {
            let _ = guppy_c_send_focus_event(
                view_id,
                focus_node_id.as_ptr(),
                focus_node_id.len(),
                callback_id.as_ptr(),
                callback_id.len(),
            );
        });
        focus_subscriptions.push(subscription);
    }

    if let Some(callback_id) = blur {
        let blur_node_id = node_id.to_owned();
        let callback_id = callback_id.to_owned();
        let subscription = cx.on_blur(focus_handle, window, move |_, _, _| unsafe {
            let _ = guppy_c_send_blur_event(
                view_id,
                blur_node_id.as_ptr(),
                blur_node_id.len(),
                callback_id.as_ptr(),
                callback_id.len(),
            );
        });
        focus_subscriptions.push(subscription);
    }

    focus_registered.insert(node_id.to_owned());
}

fn modifier_flags(modifiers: &gpui::Modifiers) -> (i32, i32, i32, i32, i32) {
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

fn matching_shortcut<'a>(
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

fn pixel_to_f64(value: gpui::Pixels) -> f64 {
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

fn node_id(view_id: u64, path: &str, id: Option<&str>) -> String {
    match id {
        Some(id) => id.to_owned(),
        None => format!("guppy-{view_id}-{path}"),
    }
}

fn color_token_to_color(color: ColorToken) -> gpui::Hsla {
    match color {
        ColorToken::Red => rgb(0xff0000).into(),
        ColorToken::Green => rgb(0x00ff00).into(),
        ColorToken::Blue => rgb(0x0000ff).into(),
        ColorToken::Yellow => rgb(0xffff00).into(),
        ColorToken::Black => rgb(0x000000).into(),
        ColorToken::White => rgb(0xffffff).into(),
        ColorToken::Gray => rgb(0x505050).into(),
    }
}

fn hex_color_to_color(value: &str) -> gpui::Hsla {
    let normalized = value.trim_start_matches('#');
    let parsed = u32::from_str_radix(normalized, 16).unwrap_or(0xff00ff);
    rgb(parsed).into()
}
