mod bridge_text_input;
mod bridge_view;
mod ir;
mod main_thread_runtime;
mod window_options;

use crate::ir::IrNode;
use crate::window_options::WindowOptionsConfig;
use rustler::{Atom, Encoder, Env, Error, LocalPid, NifResult, Term};
use std::ffi::{CString, c_char, c_void};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{self, Sender};
use std::sync::{Condvar, Mutex};
use std::time::{Duration, Instant};

#[cfg(target_os = "macos")]
type ErlNifTid = *mut c_void;

#[cfg(target_os = "macos")]
unsafe extern "C" {
    fn erl_drv_steal_main_thread(
        name: *mut c_char,
        dtid: *mut ErlNifTid,
        func: extern "C" fn(*mut c_void) -> *mut c_void,
        arg: *mut c_void,
        opts: *mut c_void,
    ) -> i32;
}

rustler::atoms! {
    action,
    alt,
    blur,
    callback,
    change,
    checked,
    click,
    click_count,
    context_menu,
    control,
    delta_kind,
    delta_x,
    delta_y,
    drag_move,
    drag_start,
    drop,
    duplicate_view_id,
    first_mouse,
    focus,
    function,
    guppy_native_event,
    hover,
    hovered,
    id,
    is_held,
    key,
    key_char,
    key_down,
    key_up,
    left,
    lines,
    middle,
    modifiers,
    mouse_down,
    mouse_move,
    mouse_up,
    navigate_back,
    navigate_forward,
    nil,
    pixels,
    platform,
    pong,
    pressed_button,
    right,
    runtime_unavailable,
    rust_core_unavailable,
    scroll_wheel,
    shift,
    shortcut,
    source_id,
    unknown_view_id,
    value,
    window_closed,
    x,
    y,
}

static RUNTIME_RUNNING: AtomicBool = AtomicBool::new(false);
static GUI_STARTED: AtomicBool = AtomicBool::new(false);
static GUI_STATUS: Mutex<i32> = Mutex::new(0);
static GUI_STATUS_COND: Condvar = Condvar::new();
static EVENT_TARGET: Mutex<Option<LocalPid>> = Mutex::new(None);
static OPEN_IR_TO_BINARY_COUNT: AtomicU64 = AtomicU64::new(0);
static OPEN_IR_TO_BINARY_NANOS: AtomicU64 = AtomicU64::new(0);
static OPEN_IR_DECODE_COUNT: AtomicU64 = AtomicU64::new(0);
static OPEN_IR_DECODE_NANOS: AtomicU64 = AtomicU64::new(0);
static OPEN_OPTIONS_DECODE_COUNT: AtomicU64 = AtomicU64::new(0);
static OPEN_OPTIONS_DECODE_NANOS: AtomicU64 = AtomicU64::new(0);
static RENDER_IR_TO_BINARY_COUNT: AtomicU64 = AtomicU64::new(0);
static RENDER_IR_TO_BINARY_NANOS: AtomicU64 = AtomicU64::new(0);
static RENDER_IR_DECODE_COUNT: AtomicU64 = AtomicU64::new(0);
static RENDER_IR_DECODE_NANOS: AtomicU64 = AtomicU64::new(0);
static NATIVE_EVENT_SEND_COUNT: AtomicU64 = AtomicU64::new(0);
static NATIVE_EVENT_SEND_NANOS: AtomicU64 = AtomicU64::new(0);
static NATIVE_EVENT_SEND_FAILURE_COUNT: AtomicU64 = AtomicU64::new(0);

#[cfg(target_os = "macos")]
static GUI_THREAD: Mutex<Option<usize>> = Mutex::new(None);

fn load(_env: Env, _term: Term) -> bool {
    main_thread_runtime::init_request_queue();
    RUNTIME_RUNNING.store(true, Ordering::SeqCst);
    maybe_start_main_thread_runtime()
}

#[rustler::nif]
fn native_ping() -> Atom {
    pong()
}

#[rustler::nif]
fn native_build_info() -> &'static str {
    "guppy_nif_rust_core"
}

#[rustler::nif]
fn native_runtime_status() -> &'static str {
    if RUNTIME_RUNNING.load(Ordering::SeqCst) {
        "started"
    } else {
        "not_started"
    }
}

#[rustler::nif]
fn native_gui_status() -> &'static str {
    if GUI_STARTED.load(Ordering::SeqCst) {
        "started"
    } else {
        "failed"
    }
}

#[rustler::nif]
fn native_performance_counters<'a>(env: Env<'a>) -> Term<'a> {
    let pairs = vec![
        counter_pair(env, "open_ir_to_binary_count", &OPEN_IR_TO_BINARY_COUNT),
        counter_pair(
            env,
            "open_ir_to_binary_native_time_ns",
            &OPEN_IR_TO_BINARY_NANOS,
        ),
        counter_pair(env, "open_ir_decode_count", &OPEN_IR_DECODE_COUNT),
        counter_pair(env, "open_ir_decode_native_time_ns", &OPEN_IR_DECODE_NANOS),
        counter_pair(env, "open_options_decode_count", &OPEN_OPTIONS_DECODE_COUNT),
        counter_pair(
            env,
            "open_options_decode_native_time_ns",
            &OPEN_OPTIONS_DECODE_NANOS,
        ),
        counter_pair(env, "render_ir_to_binary_count", &RENDER_IR_TO_BINARY_COUNT),
        counter_pair(
            env,
            "render_ir_to_binary_native_time_ns",
            &RENDER_IR_TO_BINARY_NANOS,
        ),
        counter_pair(env, "render_ir_decode_count", &RENDER_IR_DECODE_COUNT),
        counter_pair(
            env,
            "render_ir_decode_native_time_ns",
            &RENDER_IR_DECODE_NANOS,
        ),
        counter_pair(env, "native_event_send_count", &NATIVE_EVENT_SEND_COUNT),
        counter_pair(
            env,
            "native_event_send_native_time_ns",
            &NATIVE_EVENT_SEND_NANOS,
        ),
        counter_pair(
            env,
            "native_event_send_failure_count",
            &NATIVE_EVENT_SEND_FAILURE_COUNT,
        ),
    ];

    map_from_pairs(env, pairs)
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_open_window<'a>(
    env: Env<'a>,
    view_id: u64,
    ir: Term<'a>,
    opts: Term<'a>,
) -> NifResult<Term<'a>> {
    let to_binary_started_at = Instant::now();
    let ir_binary = ir.to_binary();
    record_counter(
        &OPEN_IR_TO_BINARY_COUNT,
        &OPEN_IR_TO_BINARY_NANOS,
        to_binary_started_at.elapsed(),
    );

    let opts_binary = opts.to_binary();

    let options_decode_started_at = Instant::now();
    let options =
        WindowOptionsConfig::decode_etf(opts_binary.as_slice()).map_err(|_| Error::BadArg)?;
    record_counter(
        &OPEN_OPTIONS_DECODE_COUNT,
        &OPEN_OPTIONS_DECODE_NANOS,
        options_decode_started_at.elapsed(),
    );

    let ir_decode_started_at = Instant::now();
    let ir = IrNode::decode_etf(ir_binary.as_slice()).map_err(|_| Error::BadArg)?;
    record_counter(
        &OPEN_IR_DECODE_COUNT,
        &OPEN_IR_DECODE_NANOS,
        ir_decode_started_at.elapsed(),
    );

    let result = request_i32(|reply| main_thread_runtime::MainThreadRequest::OpenWindow {
        view_id,
        ir,
        options,
        reply,
    })
    .unwrap_or(-1);

    Ok(status_result(env, result, duplicate_view_id()))
}

#[rustler::nif]
fn native_set_event_target(pid: LocalPid) -> Atom {
    let mut target = EVENT_TARGET.lock().expect("event target lock poisoned");
    *target = Some(pid);
    rustler::types::atom::ok()
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_render<'a>(env: Env<'a>, view_id: u64, ir: Term<'a>) -> NifResult<Term<'a>> {
    let to_binary_started_at = Instant::now();
    let ir_binary = ir.to_binary();
    record_counter(
        &RENDER_IR_TO_BINARY_COUNT,
        &RENDER_IR_TO_BINARY_NANOS,
        to_binary_started_at.elapsed(),
    );

    let ir_decode_started_at = Instant::now();
    let ir = IrNode::decode_etf(ir_binary.as_slice()).map_err(|_| Error::BadArg)?;
    record_counter(
        &RENDER_IR_DECODE_COUNT,
        &RENDER_IR_DECODE_NANOS,
        ir_decode_started_at.elapsed(),
    );

    let result =
        request_i32(|reply| main_thread_runtime::MainThreadRequest::SetIr { view_id, ir, reply })
            .unwrap_or(-1);

    Ok(status_result(env, result, unknown_view_id()))
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_close_window<'a>(env: Env<'a>, view_id: u64) -> Term<'a> {
    let result =
        request_i32(|reply| main_thread_runtime::MainThreadRequest::CloseWindow { view_id, reply })
            .unwrap_or(-1);

    status_result(env, result, unknown_view_id())
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_view_count<'a>(env: Env<'a>) -> Term<'a> {
    match request_u64(|reply| main_thread_runtime::MainThreadRequest::ViewCount { reply }) {
        Some(count) => count.encode(env),
        None => error_tuple(env, runtime_unavailable()),
    }
}

fn status_result<'a>(env: Env<'a>, result: i32, zero_reason: Atom) -> Term<'a> {
    match result {
        1 => rustler::types::atom::ok().encode(env),
        0 => error_tuple(env, zero_reason),
        _ => error_tuple(env, runtime_unavailable()),
    }
}

fn error_tuple<'a>(env: Env<'a>, reason: Atom) -> Term<'a> {
    (rustler::types::atom::error(), reason).encode(env)
}

fn request_i32(
    build: impl FnOnce(Sender<i32>) -> main_thread_runtime::MainThreadRequest,
) -> Option<i32> {
    let (reply_tx, reply_rx) = mpsc::channel();
    main_thread_runtime::enqueue_request(build(reply_tx)).ok()?;
    reply_rx.recv().ok()
}

fn request_u64(
    build: impl FnOnce(Sender<u64>) -> main_thread_runtime::MainThreadRequest,
) -> Option<u64> {
    let (reply_tx, reply_rx) = mpsc::channel();
    main_thread_runtime::enqueue_request(build(reply_tx)).ok()?;
    reply_rx.recv().ok()
}

fn maybe_start_main_thread_runtime() -> bool {
    if GUI_STARTED.load(Ordering::SeqCst) {
        return true;
    }

    #[cfg(target_os = "macos")]
    {
        {
            let mut status = GUI_STATUS.lock().expect("gui status lock poisoned");
            *status = 0;
        }

        let mut thread_id: ErlNifTid = std::ptr::null_mut();
        let name = CString::new("guppy_gpui").expect("static thread name has no nul");
        let result = unsafe {
            erl_drv_steal_main_thread(
                name.as_ptr().cast_mut(),
                &mut thread_id,
                run_main_thread_runtime,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
            )
        };

        if result != 0 {
            return false;
        }

        {
            let mut slot = GUI_THREAD.lock().expect("gui thread lock poisoned");
            *slot = Some(thread_id as usize);
        }

        let mut status = GUI_STATUS.lock().expect("gui status lock poisoned");
        while *status == 0 {
            status = GUI_STATUS_COND
                .wait(status)
                .expect("gui status condvar poisoned");
        }

        let started = *status == 1;
        GUI_STARTED.store(started, Ordering::SeqCst);
        started
    }

    #[cfg(not(target_os = "macos"))]
    {
        GUI_STARTED.store(true, Ordering::SeqCst);
        true
    }
}

#[cfg(target_os = "macos")]
extern "C" fn run_main_thread_runtime(_arg: *mut c_void) -> *mut c_void {
    main_thread_runtime::run_app();
    std::ptr::null_mut()
}

pub(crate) fn notify_gui_started(status: i32) {
    let mut gui_status = GUI_STATUS.lock().expect("gui status lock poisoned");
    *gui_status = status;
    GUI_STATUS_COND.notify_all();
}

pub(crate) fn send_window_closed_event(view_id: u64) -> i32 {
    send_event(view_id, window_closed(), |env| {
        rustler::types::atom::undefined().encode(env)
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
            let target = EVENT_TARGET.lock().expect("event target lock poisoned");
            *target
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

    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) };
    std::str::from_utf8(bytes).map(str::to_owned).ok()
}

fn base_payload<'a>(env: Env<'a>, node_id: &str, callback_id: &str) -> Vec<(Term<'a>, Term<'a>)> {
    vec![
        (id().encode(env), node_id.encode(env)),
        (callback().encode(env), callback_id.encode(env)),
    ]
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
        vec![
            (control().encode(env), (control_value != 0).encode(env)),
            (alt().encode(env), (alt_value != 0).encode(env)),
            (shift().encode(env), (shift_value != 0).encode(env)),
            (platform().encode(env), (platform_value != 0).encode(env)),
            (function().encode(env), (function_value != 0).encode(env)),
        ],
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

fn map_from_pairs<'a>(env: Env<'a>, pairs: Vec<(Term<'a>, Term<'a>)>) -> Term<'a> {
    let (keys, values): (Vec<_>, Vec<_>) = pairs.into_iter().unzip();
    Term::map_from_term_arrays(env, &keys, &values).expect("event payload map construction failed")
}

fn counter_pair<'a>(env: Env<'a>, key: &'static str, counter: &AtomicU64) -> (Term<'a>, Term<'a>) {
    (key.encode(env), counter.load(Ordering::Relaxed).encode(env))
}

fn record_counter(count: &AtomicU64, nanos: &AtomicU64, duration: Duration) {
    count.fetch_add(1, Ordering::Relaxed);
    nanos.fetch_add(duration_to_u64_nanos(duration), Ordering::Relaxed);
}

fn record_event_send(started_at: Instant, sent: bool) {
    record_counter(
        &NATIVE_EVENT_SEND_COUNT,
        &NATIVE_EVENT_SEND_NANOS,
        started_at.elapsed(),
    );

    if !sent {
        NATIVE_EVENT_SEND_FAILURE_COUNT.fetch_add(1, Ordering::Relaxed);
    }
}

fn duration_to_u64_nanos(duration: Duration) -> u64 {
    duration.as_nanos().min(u128::from(u64::MAX)) as u64
}

#[cfg(test)]
pub(crate) fn native_event_send_snapshot_for_test() -> (u64, u64) {
    (
        NATIVE_EVENT_SEND_COUNT.load(Ordering::Relaxed),
        NATIVE_EVENT_SEND_FAILURE_COUNT.load(Ordering::Relaxed),
    )
}

fn send_id_callback_event(view_id: u64, event: Atom, node_id: &str, callback_id: &str) -> i32 {
    let node_id = node_id.to_owned();
    let callback_id = callback_id.to_owned();
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };

    #[cfg(test)]
    {
        let _ = (view_id, node_id, callback_id);
        record_event_send(Instant::now(), false);
        0
    }

    #[cfg(not(test))]
    send_id_callback_event(view_id, click(), &node_id, &callback_id)
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    send_event(view_id, hover(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    send_id_callback_event(view_id, focus(), &node_id, &callback_id)
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_c_send_blur_event(
    view_id: u64,
    node_id_ptr: *const u8,
    node_id_len: usize,
    callback_id_ptr: *const u8,
    callback_id_len: usize,
) -> i32 {
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    send_id_callback_event(view_id, blur(), &node_id, &callback_id)
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    let Some(value_string) = binary_str(value_ptr, value_len) else {
        return 0;
    };
    send_event(view_id, change(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    send_event(view_id, change(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    let Some(key_string) = binary_str(key_ptr, key_len) else {
        return 0;
    };
    let key_char_string = (has_key_char != 0)
        .then(|| binary_str(key_char_ptr, key_char_len))
        .flatten();
    send_event(view_id, key_down(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
        let key_char_term = key_char_string
            .as_ref()
            .map_or_else(|| nil().encode(env), |value| value.encode(env));
        pairs.extend([
            (key().encode(env), key_string.encode(env)),
            (key_char().encode(env), key_char_term),
            (is_held().encode(env), (is_held_value != 0).encode(env)),
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    let Some(key_string) = binary_str(key_ptr, key_len) else {
        return 0;
    };
    let key_char_string = (has_key_char != 0)
        .then(|| binary_str(key_char_ptr, key_char_len))
        .flatten();
    send_event(view_id, key_up(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
        let key_char_term = key_char_string
            .as_ref()
            .map_or_else(|| nil().encode(env), |value| value.encode(env));
        pairs.extend([
            (key().encode(env), key_string.encode(env)),
            (key_char().encode(env), key_char_term),
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
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
        let mut pairs = base_payload(env, &node_id, &callback_id);
        let key_char_term = key_char_string
            .as_ref()
            .map_or_else(|| nil().encode(env), |value| value.encode(env));
        pairs.extend([
            (action().encode(env), action_string.encode(env)),
            (shortcut().encode(env), shortcut_string.encode(env)),
            (key().encode(env), key_string.encode(env)),
            (key_char().encode(env), key_char_term),
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    send_event(view_id, context_menu(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
        pairs.extend([
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
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
        let mut pairs = base_payload(env, &node_id, &callback_id);
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    let Some(source) = binary_str(source_id_ptr, source_id_len) else {
        return 0;
    };
    send_event(view_id, drag_move(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
        pairs.extend([
            (source_id().encode(env), source.encode(env)),
            (
                pressed_button().encode(env),
                mouse_button_atom(pressed_button_code).encode(env),
            ),
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    send_event(view_id, mouse_down(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
        pairs.extend([
            (
                rustler::Atom::from_str(env, "button").unwrap().encode(env),
                mouse_button_atom(button_code).encode(env),
            ),
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
            (click_count().encode(env), click_count_value.encode(env)),
            (
                first_mouse().encode(env),
                (first_mouse_value != 0).encode(env),
            ),
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    send_event(view_id, mouse_up(), move |env| {
        let button_atom = rustler::Atom::from_str(env, "button").unwrap();
        let mut pairs = base_payload(env, &node_id, &callback_id);
        pairs.extend([
            (
                button_atom.encode(env),
                mouse_button_atom(button_code).encode(env),
            ),
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
            (click_count().encode(env), click_count_value.encode(env)),
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    send_event(view_id, mouse_move(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
        pairs.extend([
            (
                pressed_button().encode(env),
                mouse_button_atom(pressed_button_code).encode(env),
            ),
            (x().encode(env), event_x.encode(env)),
            (y().encode(env), event_y.encode(env)),
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
    let Some(node_id) = binary_str(node_id_ptr, node_id_len) else {
        return 0;
    };
    let Some(callback_id) = binary_str(callback_id_ptr, callback_id_len) else {
        return 0;
    };
    send_event(view_id, scroll_wheel(), move |env| {
        let mut pairs = base_payload(env, &node_id, &callback_id);
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
            ),
        ]);
        map_from_pairs(env, pairs)
    })
}

rustler::init!("Elixir.Guppy.Native.Nif", load = load);
