use crate::*;
use rustler::{Atom, Encoder, Env, Term};
use std::time::Instant;

pub(crate) fn send_window_close_requested_event(view_id: u64) -> i32 {
    send_event(view_id, window_close_requested(), |env| {
        rustler::types::atom::undefined().encode(env)
    })
}

pub(crate) fn send_window_closed_event(view_id: u64) -> i32 {
    send_event(view_id, window_closed(), |env| {
        rustler::types::atom::undefined().encode(env)
    })
}

pub(crate) fn send_menu_action_event(action_id: &str, callback_id: &str) -> i32 {
    let action_id = action_id.to_owned();
    let callback_id = callback_id.to_owned();

    #[cfg(test)]
    {
        record_menu_event_snapshot_for_test(action_id, callback_id);
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(0, menu_action(), move |env| {
        map_from_pairs(env, base_payload(env, &action_id, &callback_id))
    })
}

fn send_event(view_id: u64, event: Atom, payload: impl for<'a> FnOnce(Env<'a>) -> Term<'a>) -> i32 {
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
            (guppy_native_event(), view_id, event, payload(env)).encode(env)
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

fn binary_str(ptr: *const u8, len: usize) -> Option<String> {
    if ptr.is_null() {
        return None;
    }

    // SAFETY: native event shims pass a non-null pointer and byte length for data that remains
    // valid for this call; this function checks for null before constructing the borrowed slice.
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) };
    std::str::from_utf8(bytes).map(str::to_owned).ok()
}

fn id_callback_strings(
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
) -> Option<(String, String)> {
    Some((
        binary_str(node_id_ptr, node_id_len)?,
        binary_str(callback_id_ptr, callback_id_len)?,
    ))
}

fn base_payload<'a>(env: Env<'a>, node_id: &str, callback_id: &str) -> Vec<(Term<'a>, Term<'a>)> {
    base_payload_with_capacity(env, node_id, callback_id, 0)
}

fn base_payload_with_capacity<'a>(
    env: Env<'a>,
    node_id: &str,
    callback_id: &str,
    additional_pairs: usize,
) -> Vec<(Term<'a>, Term<'a>)> {
    let mut pairs = Vec::with_capacity(2 + additional_pairs);
    pairs.push((id().encode(env), node_id.encode(env)));
    pairs.push((callback().encode(env), callback_id.encode(env)));
    pairs
}

#[cfg_attr(test, allow(dead_code))]
fn row_control_payload<'a>(
    env: Env<'a>,
    node_id: &str,
    callback_id: &str,
    list_id_value: &str,
    row_id_value: &str,
    control_id_value: &str,
) -> Vec<(Term<'a>, Term<'a>)> {
    let mut pairs = base_payload_with_capacity(env, node_id, callback_id, 3);
    pairs.extend([
        (list_id().encode(env), list_id_value.encode(env)),
        (row_id().encode(env), row_id_value.encode(env)),
        (control_id().encode(env), control_id_value.encode(env)),
    ]);
    pairs
}

#[cfg_attr(test, allow(dead_code))]
fn data_table_payload<'a>(
    env: Env<'a>,
    node_id: &str,
    callback_id: &str,
    table_id_value: &str,
    row_id_value: Option<&str>,
    column_id_value: Option<&str>,
) -> Vec<(Term<'a>, Term<'a>)> {
    let mut pairs = base_payload_with_capacity(env, node_id, callback_id, 3);
    pairs.push((table_id().encode(env), table_id_value.encode(env)));
    if let Some(row_id_value) = row_id_value {
        pairs.push((row_id().encode(env), row_id_value.encode(env)));
    }
    if let Some(column_id_value) = column_id_value {
        pairs.push((column_id().encode(env), column_id_value.encode(env)));
    }
    pairs
}

#[cfg_attr(test, allow(dead_code))]
fn tree_payload<'a>(
    env: Env<'a>,
    node_id: &str,
    callback_id: &str,
    tree_id_value: &str,
    item_id_value: &str,
) -> Vec<(Term<'a>, Term<'a>)> {
    let mut pairs = base_payload_with_capacity(env, node_id, callback_id, 2);
    pairs.extend([
        (tree_id().encode(env), tree_id_value.encode(env)),
        (item_id().encode(env), item_id_value.encode(env)),
    ]);
    pairs
}

fn modifiers_payload<'a>(
    env: Env<'a>,
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> Term<'a> {
    map_from_pairs(
        env,
        [
            (control().encode(env), (control_value != 0).encode(env)),
            (alt().encode(env), (alt_value != 0).encode(env)),
            (shift().encode(env), (shift_value != 0).encode(env)),
            (platform().encode(env), (platform_value != 0).encode(env)),
            (function().encode(env), (function_value != 0).encode(env)),
        ],
    )
}

fn modifiers_pair<'a>(
    env: Env<'a>,
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> (Term<'a>, Term<'a>) {
    (
        modifiers().encode(env),
        modifiers_payload(
            env,
            control_value,
            alt_value,
            shift_value,
            platform_value,
            function_value,
        ),
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

fn send_id_callback_event(view_id: u64, event: Atom, node_id: String, callback_id: String) -> i32 {
    send_event(view_id, event, move |env| {
        map_from_pairs(env, base_payload(env, &node_id, &callback_id))
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_click_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };

    #[cfg(test)]
    {
        let _ = (view_id, node_id, callback_id);
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_id_callback_event(view_id, click(), node_id, callback_id)
}

#[allow(clippy::too_many_arguments)]
fn row_control_strings(
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    list_id_ptr: *const u8,
    list_id_len: usize,
    row_id_ptr: *const u8,
    row_id_len: usize,
    control_id_ptr: *const u8,
    control_id_len: usize,
) -> Option<(String, String, String, String, String)> {
    Some((
        binary_str(node_id_ptr, node_id_len)?,
        binary_str(callback_id_ptr, callback_id_len)?,
        binary_str(list_id_ptr, list_id_len)?,
        binary_str(row_id_ptr, row_id_len)?,
        binary_str(control_id_ptr, control_id_len)?,
    ))
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_row_control_click_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    list_id_ptr: *const u8,
    list_id_len: usize,
    row_id_ptr: *const u8,
    row_id_len: usize,
    control_id_ptr: *const u8,
    control_id_len: usize,
) -> i32 {
    let Some((node_id, callback_id, list_id_value, row_id_value, control_id_value)) =
        row_control_strings(
            node_id_ptr,
            node_id_len,
            callback_id_ptr,
            callback_id_len,
            list_id_ptr,
            list_id_len,
            row_id_ptr,
            row_id_len,
            control_id_ptr,
            control_id_len,
        )
    else {
        return 0;
    };

    #[cfg(test)]
    {
        record_row_control_event_snapshot_for_test(
            "click",
            view_id,
            node_id,
            callback_id,
            list_id_value,
            row_id_value,
            control_id_value,
            None,
            None,
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(view_id, click(), move |env| {
        map_from_pairs(
            env,
            row_control_payload(
                env,
                &node_id,
                &callback_id,
                &list_id_value,
                &row_id_value,
                &control_id_value,
            ),
        )
    })
}

#[allow(clippy::too_many_arguments)]
#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_data_table_event(
    view_id: u64,
    event_code: i32,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    table_id_ptr: *const u8,
    table_id_len: usize,
    row_id_ptr: *const u8,
    row_id_len: usize,
    column_id_ptr: *const u8,
    column_id_len: usize,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    let Some(table_id_value) = binary_str(table_id_ptr, table_id_len) else {
        return 0;
    };
    let Some(row_id_value) = binary_str(row_id_ptr, row_id_len) else {
        return 0;
    };
    let Some(column_id_value) = binary_str(column_id_ptr, column_id_len) else {
        return 0;
    };
    let Some(event_name) = data_table_event_name(event_code) else {
        return 0;
    };
    #[cfg(not(test))]
    let _ = event_name;

    let row_id_option = if row_id_value.is_empty() {
        None
    } else {
        Some(row_id_value.as_str())
    };
    let column_id_option = if column_id_value.is_empty() {
        None
    } else {
        Some(column_id_value.as_str())
    };

    #[cfg(test)]
    {
        record_semantic_event_snapshot_for_test(
            event_name,
            view_id,
            node_id,
            callback_id,
            Some(table_id_value),
            row_id_option.map(str::to_owned),
            column_id_option.map(str::to_owned),
            None,
            None,
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(view_id, data_table_event_atom(event_code), move |env| {
        map_from_pairs(
            env,
            data_table_payload(
                env,
                &node_id,
                &callback_id,
                &table_id_value,
                row_id_option,
                column_id_option,
            ),
        )
    })
}

#[allow(clippy::too_many_arguments)]
#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_tree_event(
    view_id: u64,
    event_code: i32,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    tree_id_ptr: *const u8,
    tree_id_len: usize,
    item_id_ptr: *const u8,
    item_id_len: usize,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    let Some(tree_id_value) = binary_str(tree_id_ptr, tree_id_len) else {
        return 0;
    };
    let Some(item_id_value) = binary_str(item_id_ptr, item_id_len) else {
        return 0;
    };
    let Some(event_name) = tree_event_name(event_code) else {
        return 0;
    };
    #[cfg(not(test))]
    let _ = event_name;

    #[cfg(test)]
    {
        record_semantic_event_snapshot_for_test(
            event_name,
            view_id,
            node_id,
            callback_id,
            None,
            None,
            None,
            Some(tree_id_value),
            Some(item_id_value),
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(view_id, tree_event_atom(event_code), move |env| {
        map_from_pairs(
            env,
            tree_payload(env, &node_id, &callback_id, &tree_id_value, &item_id_value),
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

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_close_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_id_callback_event(view_id, close(), node_id, callback_id)
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_hover_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    hovered_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_event(view_id, hover(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 1);
        pairs.push((hovered().encode(env), (hovered_value != 0).encode(env)));
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_focus_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_id_callback_event(view_id, focus(), node_id, callback_id)
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_blur_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_id_callback_event(view_id, blur(), node_id, callback_id)
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_change_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    value_ptr: *const u8,
    value_len: usize,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    let Some(value_string) = binary_str(value_ptr, value_len) else {
        return 0;
    };
    send_event(view_id, change(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 1);
        pairs.push((value().encode(env), value_string.encode(env)));
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_checkbox_change_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    checked_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_event(view_id, change(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 1);
        pairs.push((checked().encode(env), (checked_value != 0).encode(env)));
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_row_control_change_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    list_id_ptr: *const u8,
    list_id_len: usize,
    row_id_ptr: *const u8,
    row_id_len: usize,
    control_id_ptr: *const u8,
    control_id_len: usize,
    value_ptr: *const u8,
    value_len: usize,
) -> i32 {
    let Some((node_id, callback_id, list_id_value, row_id_value, control_id_value)) =
        row_control_strings(
            node_id_ptr,
            node_id_len,
            callback_id_ptr,
            callback_id_len,
            list_id_ptr,
            list_id_len,
            row_id_ptr,
            row_id_len,
            control_id_ptr,
            control_id_len,
        )
    else {
        return 0;
    };
    let Some(value_string) = binary_str(value_ptr, value_len) else {
        return 0;
    };

    #[cfg(test)]
    {
        record_row_control_event_snapshot_for_test(
            "change",
            view_id,
            node_id,
            callback_id,
            list_id_value,
            row_id_value,
            control_id_value,
            Some(value_string),
            None,
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(view_id, change(), move |env| {
        let mut pairs = row_control_payload(
            env,
            &node_id,
            &callback_id,
            &list_id_value,
            &row_id_value,
            &control_id_value,
        );
        pairs.push((value().encode(env), value_string.encode(env)));
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_row_control_checkbox_change_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    list_id_ptr: *const u8,
    list_id_len: usize,
    row_id_ptr: *const u8,
    row_id_len: usize,
    control_id_ptr: *const u8,
    control_id_len: usize,
    checked_value: i32,
) -> i32 {
    let Some((node_id, callback_id, list_id_value, row_id_value, control_id_value)) =
        row_control_strings(
            node_id_ptr,
            node_id_len,
            callback_id_ptr,
            callback_id_len,
            list_id_ptr,
            list_id_len,
            row_id_ptr,
            row_id_len,
            control_id_ptr,
            control_id_len,
        )
    else {
        return 0;
    };

    #[cfg(test)]
    {
        record_row_control_event_snapshot_for_test(
            "change",
            view_id,
            node_id,
            callback_id,
            list_id_value,
            row_id_value,
            control_id_value,
            None,
            Some(checked_value != 0),
        );
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_event(view_id, change(), move |env| {
        let mut pairs = row_control_payload(
            env,
            &node_id,
            &callback_id,
            &list_id_value,
            &row_id_value,
            &control_id_value,
        );
        pairs.push((checked().encode(env), (checked_value != 0).encode(env)));
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_key_down_event(
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
    is_held_value: i32,
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    let Some(key_string) = binary_str(key_ptr, key_len) else {
        return 0;
    };
    let key_char_string = (has_key_char != 0)
        .then(|| binary_str(key_char_ptr, key_char_len))
        .flatten();
    send_event(view_id, key_down(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 4);
        let key_char_term = key_char_string
            .as_ref()
            .map_or_else(|| nil().encode(env), |value| value.encode(env));
        pairs.extend([
            (key().encode(env), key_string.encode(env)),
            (key_char().encode(env), key_char_term),
            (is_held().encode(env), (is_held_value != 0).encode(env)),
            modifiers_pair(
                env,
                control_value,
                alt_value,
                shift_value,
                platform_value,
                function_value,
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_key_up_event(
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
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    let Some(key_string) = binary_str(key_ptr, key_len) else {
        return 0;
    };
    let key_char_string = (has_key_char != 0)
        .then(|| binary_str(key_char_ptr, key_char_len))
        .flatten();
    send_event(view_id, key_up(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 3);
        let key_char_term = key_char_string
            .as_ref()
            .map_or_else(|| nil().encode(env), |value| value.encode(env));
        pairs.extend([
            (key().encode(env), key_string.encode(env)),
            (key_char().encode(env), key_char_term),
            modifiers_pair(
                env,
                control_value,
                alt_value,
                shift_value,
                platform_value,
                function_value,
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_action_event(
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
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    let Some(action_string) = binary_str(action_ptr, action_len) else {
        return 0;
    };
    let Some(shortcut_string) = binary_str(shortcut_ptr, shortcut_len) else {
        return 0;
    };
    let Some(key_string) = binary_str(key_ptr, key_len) else {
        return 0;
    };
    let key_char_string = (has_key_char != 0)
        .then(|| binary_str(key_char_ptr, key_char_len))
        .flatten();
    send_event(view_id, action(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 5);
        let key_char_term = key_char_string
            .as_ref()
            .map_or_else(|| nil().encode(env), |value| value.encode(env));
        pairs.extend([
            (action().encode(env), action_string.encode(env)),
            (shortcut().encode(env), shortcut_string.encode(env)),
            (key().encode(env), key_string.encode(env)),
            (key_char().encode(env), key_char_term),
            modifiers_pair(
                env,
                control_value,
                alt_value,
                shift_value,
                platform_value,
                function_value,
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_context_menu_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    event_x: f64,
    event_y: f64,
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_event(view_id, context_menu(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 3);
        pairs.extend([
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
            modifiers_pair(
                env,
                control_value,
                alt_value,
                shift_value,
                platform_value,
                function_value,
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}

fn source_event(
    view_id: u64,
    event: Atom,
    node_id: String,
    callback_id: String,
    source: String,
) -> i32 {
    send_event(view_id, event, move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 1);
        pairs.push((source_id().encode(env), source.encode(env)));
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_drag_start_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    source_id_ptr: *const u8,
    source_id_len: usize,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    let Some(source) = binary_str(source_id_ptr, source_id_len) else {
        return 0;
    };
    source_event(view_id, drag_start(), node_id, callback_id, source)
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_drop_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    source_id_ptr: *const u8,
    source_id_len: usize,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    let Some(source) = binary_str(source_id_ptr, source_id_len) else {
        return 0;
    };
    source_event(view_id, drop(), node_id, callback_id, source)
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_drag_move_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    source_id_ptr: *const u8,
    source_id_len: usize,
    pressed_button_code: i32,
    event_x: f64,
    event_y: f64,
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    let Some(source) = binary_str(source_id_ptr, source_id_len) else {
        return 0;
    };
    send_event(view_id, drag_move(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 5);
        pairs.extend([
            (source_id().encode(env), source.encode(env)),
            (
                pressed_button().encode(env),
                mouse_button_atom(pressed_button_code).encode(env),
            ),
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
            modifiers_pair(
                env,
                control_value,
                alt_value,
                shift_value,
                platform_value,
                function_value,
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_mouse_down_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    button_code: i32,
    event_x: f64,
    event_y: f64,
    click_count_value: u64,
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
    first_mouse_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_event(view_id, mouse_down(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 6);
        pairs.extend([
            (
                button().encode(env),
                mouse_button_atom(button_code).encode(env),
            ),
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
            (click_count().encode(env), click_count_value.encode(env)),
            (
                first_mouse().encode(env),
                (first_mouse_value != 0).encode(env),
            ),
            modifiers_pair(
                env,
                control_value,
                alt_value,
                shift_value,
                platform_value,
                function_value,
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_mouse_up_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    button_code: i32,
    event_x: f64,
    event_y: f64,
    click_count_value: u64,
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_event(view_id, mouse_up(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 5);
        pairs.extend([
            (
                button().encode(env),
                mouse_button_atom(button_code).encode(env),
            ),
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
            (click_count().encode(env), click_count_value.encode(env)),
            modifiers_pair(
                env,
                control_value,
                alt_value,
                shift_value,
                platform_value,
                function_value,
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_mouse_move_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    pressed_button_code: i32,
    event_x: f64,
    event_y: f64,
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_event(view_id, mouse_move(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 4);
        pairs.extend([
            (
                pressed_button().encode(env),
                mouse_button_atom(pressed_button_code).encode(env),
            ),
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
            modifiers_pair(
                env,
                control_value,
                alt_value,
                shift_value,
                platform_value,
                function_value,
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_scroll_wheel_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
    event_x: f64,
    event_y: f64,
    delta_kind_code: i32,
    delta_x_value: f64,
    delta_y_value: f64,
    control_value: i32,
    alt_value: i32,
    shift_value: i32,
    platform_value: i32,
    function_value: i32,
) -> i32 {
    let Some((node_id, callback_id)) =
        id_callback_strings(node_id_ptr, node_id_len, callback_id_ptr, callback_id_len)
    else {
        return 0;
    };
    send_event(view_id, scroll_wheel(), move |env| {
        let mut pairs = base_payload_with_capacity(env, &node_id, &callback_id, 6);
        pairs.extend([
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
            (
                delta_kind().encode(env),
                if delta_kind_code == 1 {
                    pixels()
                } else {
                    lines()
                }
                .encode(env),
            ),
            (delta_x().encode(env), delta_x_value.encode(env)),
            (delta_y().encode(env), delta_y_value.encode(env)),
            modifiers_pair(
                env,
                control_value,
                alt_value,
                shift_value,
                platform_value,
                function_value,
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}
