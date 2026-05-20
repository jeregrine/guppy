use crate::*;
use rustler::{Atom, Encoder, Env, Term};
use std::time::Instant;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub(crate) struct EventModifiers {
    pub control: bool,
    pub alt: bool,
    pub shift: bool,
    pub platform: bool,
    pub function: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct KeyEventPayload<'a> {
    pub key: &'a str,
    pub key_char: Option<&'a str>,
    pub is_held: bool,
    pub modifiers: EventModifiers,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct ActionEventPayload<'a> {
    pub action: &'a str,
    pub shortcut: &'a str,
    pub key: &'a str,
    pub key_char: Option<&'a str>,
    pub modifiers: EventModifiers,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct ContextMenuEventPayload {
    pub x: f64,
    pub y: f64,
    pub modifiers: EventModifiers,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct DragMoveEventPayload<'a> {
    pub source_id: &'a str,
    pub pressed_button_code: i32,
    pub x: f64,
    pub y: f64,
    pub modifiers: EventModifiers,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct MouseDownEventPayload {
    pub button_code: i32,
    pub x: f64,
    pub y: f64,
    pub click_count: u64,
    pub modifiers: EventModifiers,
    pub first_mouse: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct MouseUpEventPayload {
    pub button_code: i32,
    pub x: f64,
    pub y: f64,
    pub click_count: u64,
    pub modifiers: EventModifiers,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct MouseMoveEventPayload {
    pub pressed_button_code: i32,
    pub x: f64,
    pub y: f64,
    pub modifiers: EventModifiers,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct ScrollWheelEventPayload {
    pub x: f64,
    pub y: f64,
    pub delta_kind_code: i32,
    pub delta_x: f64,
    pub delta_y: f64,
    pub modifiers: EventModifiers,
}

pub(crate) fn send_window_close_requested_event(view_id: u64) -> i32 {
    #[cfg(test)]
    record_basic_event_snapshot_for_test("window_close_requested", view_id, None, None, None, None);

    send_event(view_id, window_close_requested, |env| {
        rustler::types::atom::undefined().encode(env)
    })
}

pub(crate) fn send_window_closed_event(view_id: u64) -> i32 {
    #[cfg(test)]
    record_basic_event_snapshot_for_test("window_closed", view_id, None, None, None, None);

    send_event(view_id, window_closed, |env| {
        rustler::types::atom::undefined().encode(env)
    })
}

pub(crate) fn send_menu_action_event(action_id: &str, callback_id: &str) -> i32 {
    #[cfg(test)]
    {
        record_menu_event_snapshot_for_test(action_id.to_owned(), callback_id.to_owned());
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(0, menu_action, move |env| {
        base_payload_map(env, action_id, callback_id)
    })
}

pub(crate) fn send_click_event(view_id: u64, node_id: &str, callback_id: &str) -> i32 {
    #[cfg(test)]
    record_basic_event_snapshot_for_test(
        "click",
        view_id,
        Some(node_id.to_owned()),
        Some(callback_id.to_owned()),
        None,
        None,
    );

    send_id_callback_event(view_id, click, node_id, callback_id)
}

pub(crate) fn send_close_event(view_id: u64, node_id: &str, callback_id: &str) -> i32 {
    #[cfg(test)]
    record_basic_event_snapshot_for_test(
        "close",
        view_id,
        Some(node_id.to_owned()),
        Some(callback_id.to_owned()),
        None,
        None,
    );

    send_id_callback_event(view_id, close, node_id, callback_id)
}

pub(crate) fn send_focus_event(view_id: u64, node_id: &str, callback_id: &str) -> i32 {
    #[cfg(test)]
    record_basic_event_snapshot_for_test(
        "focus",
        view_id,
        Some(node_id.to_owned()),
        Some(callback_id.to_owned()),
        None,
        None,
    );

    send_id_callback_event(view_id, focus, node_id, callback_id)
}

pub(crate) fn send_blur_event(view_id: u64, node_id: &str, callback_id: &str) -> i32 {
    #[cfg(test)]
    record_basic_event_snapshot_for_test(
        "blur",
        view_id,
        Some(node_id.to_owned()),
        Some(callback_id.to_owned()),
        None,
        None,
    );

    send_id_callback_event(view_id, blur, node_id, callback_id)
}

pub(crate) fn send_hover_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    hovered_value: bool,
) -> i32 {
    send_event(view_id, hover, move |env| {
        base_payload_with_one_map(
            env,
            node_id,
            callback_id,
            (hovered().encode(env), hovered_value.encode(env)),
        )
    })
}

pub(crate) fn send_change_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    value_string: &str,
) -> i32 {
    #[cfg(test)]
    record_basic_event_snapshot_for_test(
        "change",
        view_id,
        Some(node_id.to_owned()),
        Some(callback_id.to_owned()),
        Some(value_string.to_owned()),
        None,
    );

    send_event(view_id, change, move |env| {
        base_payload_with_one_map(
            env,
            node_id,
            callback_id,
            (value().encode(env), value_string.encode(env)),
        )
    })
}

pub(crate) fn send_checkbox_change_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    checked_value: bool,
) -> i32 {
    #[cfg(test)]
    record_basic_event_snapshot_for_test(
        "change",
        view_id,
        Some(node_id.to_owned()),
        Some(callback_id.to_owned()),
        None,
        Some(checked_value),
    );

    send_event(view_id, change, move |env| {
        base_payload_with_one_map(
            env,
            node_id,
            callback_id,
            (checked().encode(env), checked_value.encode(env)),
        )
    })
}

pub(crate) fn send_row_control_click_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    list_id_value: &str,
    row_id_value: &str,
    control_id_value: &str,
) -> i32 {
    #[cfg(test)]
    {
        record_row_control_event_snapshot_for_test(
            "click",
            view_id,
            node_id.to_owned(),
            callback_id.to_owned(),
            list_id_value.to_owned(),
            row_id_value.to_owned(),
            control_id_value.to_owned(),
            None,
            None,
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(view_id, click, move |env| {
        row_control_payload_map(
            env,
            node_id,
            callback_id,
            list_id_value,
            row_id_value,
            control_id_value,
        )
    })
}

pub(crate) fn send_row_control_change_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    list_id_value: &str,
    row_id_value: &str,
    control_id_value: &str,
    value_string: &str,
) -> i32 {
    #[cfg(test)]
    {
        record_row_control_event_snapshot_for_test(
            "change",
            view_id,
            node_id.to_owned(),
            callback_id.to_owned(),
            list_id_value.to_owned(),
            row_id_value.to_owned(),
            control_id_value.to_owned(),
            Some(value_string.to_owned()),
            None,
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(view_id, change, move |env| {
        row_control_payload_with_one_map(
            env,
            node_id,
            callback_id,
            list_id_value,
            row_id_value,
            control_id_value,
            (value().encode(env), value_string.encode(env)),
        )
    })
}

pub(crate) fn send_row_control_checkbox_change_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    list_id_value: &str,
    row_id_value: &str,
    control_id_value: &str,
    checked_value: bool,
) -> i32 {
    #[cfg(test)]
    {
        record_row_control_event_snapshot_for_test(
            "change",
            view_id,
            node_id.to_owned(),
            callback_id.to_owned(),
            list_id_value.to_owned(),
            row_id_value.to_owned(),
            control_id_value.to_owned(),
            None,
            Some(checked_value),
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(view_id, change, move |env| {
        row_control_payload_with_one_map(
            env,
            node_id,
            callback_id,
            list_id_value,
            row_id_value,
            control_id_value,
            (checked().encode(env), checked_value.encode(env)),
        )
    })
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn send_data_table_event(
    view_id: u64,
    event_code: i32,
    node_id: &str,
    callback_id: &str,
    table_id_value: &str,
    row_id_value: Option<&str>,
    column_id_value: Option<&str>,
) -> i32 {
    let Some(event_name) = data_table_event_name(event_code) else {
        return 0;
    };

    #[cfg(test)]
    {
        record_semantic_event_snapshot_for_test(
            event_name,
            view_id,
            node_id.to_owned(),
            callback_id.to_owned(),
            Some(table_id_value.to_owned()),
            row_id_value.map(str::to_owned),
            column_id_value.map(str::to_owned),
            None,
            None,
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    {
        let _ = event_name;
        send_event(
            view_id,
            || data_table_event_atom(event_code),
            move |env| {
                data_table_payload_map(
                    env,
                    node_id,
                    callback_id,
                    table_id_value,
                    row_id_value,
                    column_id_value,
                )
            },
        )
    }
}

pub(crate) fn send_tree_context_menu_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    tree_id_value: &str,
    item_id_value: &str,
    payload: ContextMenuEventPayload,
) -> i32 {
    #[cfg(test)]
    {
        let _ = payload;

        record_semantic_event_snapshot_for_test(
            "context_menu",
            view_id,
            node_id.to_owned(),
            callback_id.to_owned(),
            None,
            None,
            None,
            Some(tree_id_value.to_owned()),
            Some(item_id_value.to_owned()),
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(view_id, context_menu, move |env| {
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (tree_id().encode(env), tree_id_value.encode(env)),
                (item_id().encode(env), item_id_value.encode(env)),
                (x().encode(env), payload.x.encode(env)),
                (y().encode(env), payload.y.encode(env)),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

pub(crate) fn send_tree_event(
    view_id: u64,
    event_code: i32,
    node_id: &str,
    callback_id: &str,
    tree_id_value: &str,
    item_id_value: &str,
) -> i32 {
    let Some(event_name) = tree_event_name(event_code) else {
        return 0;
    };

    #[cfg(test)]
    {
        record_semantic_event_snapshot_for_test(
            event_name,
            view_id,
            node_id.to_owned(),
            callback_id.to_owned(),
            None,
            None,
            None,
            Some(tree_id_value.to_owned()),
            Some(item_id_value.to_owned()),
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    {
        let _ = event_name;
        send_event(
            view_id,
            || tree_event_atom(event_code),
            move |env| tree_payload_map(env, node_id, callback_id, tree_id_value, item_id_value),
        )
    }
}

pub(crate) fn send_key_down_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    payload: KeyEventPayload<'_>,
) -> i32 {
    send_event(view_id, key_down, move |env| {
        let key_char_term = optional_str_term(env, payload.key_char);
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (key().encode(env), payload.key.encode(env)),
                (key_char().encode(env), key_char_term),
                (is_held().encode(env), payload.is_held.encode(env)),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

pub(crate) fn send_key_up_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    payload: KeyEventPayload<'_>,
) -> i32 {
    send_event(view_id, key_up, move |env| {
        let key_char_term = optional_str_term(env, payload.key_char);
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (key().encode(env), payload.key.encode(env)),
                (key_char().encode(env), key_char_term),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

pub(crate) fn send_action_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    payload: ActionEventPayload<'_>,
) -> i32 {
    send_event(view_id, action, move |env| {
        let key_char_term = optional_str_term(env, payload.key_char);
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (action().encode(env), payload.action.encode(env)),
                (shortcut().encode(env), payload.shortcut.encode(env)),
                (key().encode(env), payload.key.encode(env)),
                (key_char().encode(env), key_char_term),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

pub(crate) fn send_context_menu_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    payload: ContextMenuEventPayload,
) -> i32 {
    #[cfg(test)]
    record_basic_event_snapshot_for_test(
        "context_menu",
        view_id,
        Some(node_id.to_owned()),
        Some(callback_id.to_owned()),
        None,
        None,
    );

    send_event(view_id, context_menu, move |env| {
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (x().encode(env), payload.x.encode(env)),
                (y().encode(env), payload.y.encode(env)),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

pub(crate) fn send_drag_start_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    source: &str,
) -> i32 {
    source_event(view_id, drag_start, node_id, callback_id, source)
}

pub(crate) fn send_drop_event(view_id: u64, node_id: &str, callback_id: &str, source: &str) -> i32 {
    source_event(view_id, drop, node_id, callback_id, source)
}

pub(crate) fn send_drag_move_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    payload: DragMoveEventPayload<'_>,
) -> i32 {
    send_event(view_id, drag_move, move |env| {
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (source_id().encode(env), payload.source_id.encode(env)),
                (
                    pressed_button().encode(env),
                    mouse_button_atom(payload.pressed_button_code).encode(env),
                ),
                (x().encode(env), payload.x.encode(env)),
                (y().encode(env), payload.y.encode(env)),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

pub(crate) fn send_mouse_down_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    payload: MouseDownEventPayload,
) -> i32 {
    send_event(view_id, mouse_down, move |env| {
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (
                    button().encode(env),
                    mouse_button_atom(payload.button_code).encode(env),
                ),
                (x().encode(env), payload.x.encode(env)),
                (y().encode(env), payload.y.encode(env)),
                (click_count().encode(env), payload.click_count.encode(env)),
                (first_mouse().encode(env), payload.first_mouse.encode(env)),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

pub(crate) fn send_mouse_up_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    payload: MouseUpEventPayload,
) -> i32 {
    send_event(view_id, mouse_up, move |env| {
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (
                    button().encode(env),
                    mouse_button_atom(payload.button_code).encode(env),
                ),
                (x().encode(env), payload.x.encode(env)),
                (y().encode(env), payload.y.encode(env)),
                (click_count().encode(env), payload.click_count.encode(env)),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

pub(crate) fn send_mouse_move_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    payload: MouseMoveEventPayload,
) -> i32 {
    send_event(view_id, mouse_move, move |env| {
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (
                    pressed_button().encode(env),
                    mouse_button_atom(payload.pressed_button_code).encode(env),
                ),
                (x().encode(env), payload.x.encode(env)),
                (y().encode(env), payload.y.encode(env)),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

pub(crate) fn send_scroll_wheel_event(
    view_id: u64,
    node_id: &str,
    callback_id: &str,
    payload: ScrollWheelEventPayload,
) -> i32 {
    send_event(view_id, scroll_wheel, move |env| {
        map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (x().encode(env), payload.x.encode(env)),
                (y().encode(env), payload.y.encode(env)),
                (
                    delta_kind().encode(env),
                    if payload.delta_kind_code == 1 {
                        pixels()
                    } else {
                        lines()
                    }
                    .encode(env),
                ),
                (delta_x().encode(env), payload.delta_x.encode(env)),
                (delta_y().encode(env), payload.delta_y.encode(env)),
                modifiers_pair(env, payload.modifiers),
            ],
        )
    })
}

fn send_event(
    view_id: u64,
    event: impl FnOnce() -> Atom,
    payload: impl for<'a> FnOnce(Env<'a>) -> Term<'a>,
) -> i32 {
    let started_at = Instant::now();

    #[cfg(test)]
    {
        let _ = (view_id, event, payload);
        record_event_send(started_at, false);
        0
    }

    #[cfg(not(test))]
    {
        let target = {
            let Ok(target) = EVENT_TARGET.lock() else {
                record_event_send(started_at, false);
                return 0;
            };

            target.as_ref().map(|target| target.pid)
        };

        let Some(target) = target else {
            record_event_send(started_at, false);
            return 0;
        };

        let mut msg_env = rustler::OwnedEnv::new();
        match msg_env.send_and_clear(&target, |env| {
            (guppy_native_event(), view_id, event(), payload(env)).encode(env)
        }) {
            Ok(()) => {
                record_event_send(started_at, true);
                1
            }
            Err(_) => {
                record_event_send(started_at, false);
                0
            }
        }
    }
}

fn optional_str_term<'a>(env: Env<'a>, value: Option<&str>) -> Term<'a> {
    value.map_or_else(|| nil().encode(env), |value| value.encode(env))
}

#[cfg_attr(test, allow(dead_code))]
fn base_payload_map<'a>(env: Env<'a>, node_id: &str, callback_id: &str) -> Term<'a> {
    map_from_pairs(
        env,
        [
            (id().encode(env), node_id.encode(env)),
            (callback().encode(env), callback_id.encode(env)),
        ],
    )
}

#[cfg_attr(test, allow(dead_code))]
fn base_payload_with_one_map<'a>(
    env: Env<'a>,
    node_id: &str,
    callback_id: &str,
    extra: (Term<'a>, Term<'a>),
) -> Term<'a> {
    map_from_pairs(
        env,
        [
            (id().encode(env), node_id.encode(env)),
            (callback().encode(env), callback_id.encode(env)),
            extra,
        ],
    )
}

#[cfg_attr(test, allow(dead_code))]
fn row_control_payload_map<'a>(
    env: Env<'a>,
    node_id: &str,
    callback_id: &str,
    list_id_value: &str,
    row_id_value: &str,
    control_id_value: &str,
) -> Term<'a> {
    map_from_pairs(
        env,
        [
            (id().encode(env), node_id.encode(env)),
            (callback().encode(env), callback_id.encode(env)),
            (list_id().encode(env), list_id_value.encode(env)),
            (row_id().encode(env), row_id_value.encode(env)),
            (control_id().encode(env), control_id_value.encode(env)),
        ],
    )
}

#[cfg_attr(test, allow(dead_code))]
fn row_control_payload_with_one_map<'a>(
    env: Env<'a>,
    node_id: &str,
    callback_id: &str,
    list_id_value: &str,
    row_id_value: &str,
    control_id_value: &str,
    extra: (Term<'a>, Term<'a>),
) -> Term<'a> {
    map_from_pairs(
        env,
        [
            (id().encode(env), node_id.encode(env)),
            (callback().encode(env), callback_id.encode(env)),
            (list_id().encode(env), list_id_value.encode(env)),
            (row_id().encode(env), row_id_value.encode(env)),
            (control_id().encode(env), control_id_value.encode(env)),
            extra,
        ],
    )
}

#[cfg_attr(test, allow(dead_code))]
fn data_table_payload_map<'a>(
    env: Env<'a>,
    node_id: &str,
    callback_id: &str,
    table_id_value: &str,
    row_id_value: Option<&str>,
    column_id_value: Option<&str>,
) -> Term<'a> {
    match (row_id_value, column_id_value) {
        (Some(row_id_value), Some(column_id_value)) => map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (table_id().encode(env), table_id_value.encode(env)),
                (row_id().encode(env), row_id_value.encode(env)),
                (column_id().encode(env), column_id_value.encode(env)),
            ],
        ),
        (Some(row_id_value), None) => map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (table_id().encode(env), table_id_value.encode(env)),
                (row_id().encode(env), row_id_value.encode(env)),
            ],
        ),
        (None, Some(column_id_value)) => map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (table_id().encode(env), table_id_value.encode(env)),
                (column_id().encode(env), column_id_value.encode(env)),
            ],
        ),
        (None, None) => map_from_pairs(
            env,
            [
                (id().encode(env), node_id.encode(env)),
                (callback().encode(env), callback_id.encode(env)),
                (table_id().encode(env), table_id_value.encode(env)),
            ],
        ),
    }
}

#[cfg_attr(test, allow(dead_code))]
fn tree_payload_map<'a>(
    env: Env<'a>,
    node_id: &str,
    callback_id: &str,
    tree_id_value: &str,
    item_id_value: &str,
) -> Term<'a> {
    map_from_pairs(
        env,
        [
            (id().encode(env), node_id.encode(env)),
            (callback().encode(env), callback_id.encode(env)),
            (tree_id().encode(env), tree_id_value.encode(env)),
            (item_id().encode(env), item_id_value.encode(env)),
        ],
    )
}

fn modifiers_payload<'a>(env: Env<'a>, modifiers_value: EventModifiers) -> Term<'a> {
    map_from_pairs(
        env,
        [
            (control().encode(env), modifiers_value.control.encode(env)),
            (alt().encode(env), modifiers_value.alt.encode(env)),
            (shift().encode(env), modifiers_value.shift.encode(env)),
            (platform().encode(env), modifiers_value.platform.encode(env)),
            (function().encode(env), modifiers_value.function.encode(env)),
        ],
    )
}

fn modifiers_pair<'a>(env: Env<'a>, modifiers_value: EventModifiers) -> (Term<'a>, Term<'a>) {
    (
        modifiers().encode(env),
        modifiers_payload(env, modifiers_value),
    )
}

fn mouse_button_atom(code: i32) -> Atom {
    match code {
        1 => left(),
        2 => right(),
        3 => middle(),
        4 => navigate_back(),
        5 => navigate_forward(),
        _ => nil(),
    }
}

fn send_id_callback_event(
    view_id: u64,
    event: impl FnOnce() -> Atom,
    node_id: &str,
    callback_id: &str,
) -> i32 {
    send_event(view_id, event, move |env| {
        base_payload_map(env, node_id, callback_id)
    })
}

fn source_event(
    view_id: u64,
    event: impl FnOnce() -> Atom,
    node_id: &str,
    callback_id: &str,
    source: &str,
) -> i32 {
    send_event(view_id, event, move |env| {
        base_payload_with_one_map(
            env,
            node_id,
            callback_id,
            (source_id().encode(env), source.encode(env)),
        )
    })
}

fn data_table_event_name(code: i32) -> Option<&'static str> {
    match code {
        1 => Some("data_table_row_click"),
        2 => Some("data_table_cell_click"),
        3 => Some("data_table_sort"),
        _ => None,
    }
}

#[cfg(not(test))]
fn data_table_event_atom(code: i32) -> Atom {
    match code {
        1 => data_table_row_click(),
        2 => data_table_cell_click(),
        3 => data_table_sort(),
        _ => nil(),
    }
}

fn tree_event_name(code: i32) -> Option<&'static str> {
    match code {
        1 => Some("tree_select"),
        2 => Some("tree_toggle"),
        _ => None,
    }
}

#[cfg(not(test))]
fn tree_event_atom(code: i32) -> Atom {
    match code {
        1 => tree_select(),
        2 => tree_toggle(),
        _ => nil(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn basic_event_snapshots_cover_click_change_and_window_lifecycle_payloads() {
        let _ = send_click_event(7, "button", "clicked");
        let click = crate::take_basic_event_snapshot_for_test().unwrap();
        assert_eq!(click.event, "click");
        assert_eq!(click.view_id, 7);
        assert_eq!(click.node_id.as_deref(), Some("button"));
        assert_eq!(click.callback_id.as_deref(), Some("clicked"));
        assert_eq!(click.value, None);
        assert_eq!(click.checked, None);

        let _ = send_checkbox_change_event(8, "done", "toggle_done", true);
        let checkbox = crate::take_basic_event_snapshot_for_test().unwrap();
        assert_eq!(checkbox.event, "change");
        assert_eq!(checkbox.view_id, 8);
        assert_eq!(checkbox.node_id.as_deref(), Some("done"));
        assert_eq!(checkbox.callback_id.as_deref(), Some("toggle_done"));
        assert_eq!(checkbox.checked, Some(true));

        let _ = send_change_event(9, "name", "name_changed", "Jason");
        let change = crate::take_basic_event_snapshot_for_test().unwrap();
        assert_eq!(change.event, "change");
        assert_eq!(change.view_id, 9);
        assert_eq!(change.node_id.as_deref(), Some("name"));
        assert_eq!(change.callback_id.as_deref(), Some("name_changed"));
        assert_eq!(change.value.as_deref(), Some("Jason"));
        assert_eq!(change.checked, None);

        let _ = send_window_close_requested_event(10);
        let requested = crate::take_basic_event_snapshot_for_test().unwrap();
        assert_eq!(requested.event, "window_close_requested");
        assert_eq!(requested.view_id, 10);
        assert_eq!(requested.node_id, None);
        assert_eq!(requested.callback_id, None);

        let _ = send_window_closed_event(11);
        let closed = crate::take_basic_event_snapshot_for_test().unwrap();
        assert_eq!(closed.event, "window_closed");
        assert_eq!(closed.view_id, 11);
        assert_eq!(closed.node_id, None);
        assert_eq!(closed.callback_id, None);
    }
}
