mod bridge_text_input;
mod bridge_view;
mod ir;
mod main_thread_runtime;
mod menu;
mod window_options;

use crate::ir::IrNode;
use crate::menu::MenuSpec;
use crate::window_options::WindowOptionsConfig;
use rustler::{Atom, Encoder, Env, LocalPid, Monitor, Resource, ResourceArc, Term};
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
    button,
    callback,
    change,
    checked,
    click,
    close,
    click_count,
    column_id,
    context_menu,
    control,
    delta_kind,
    delta_x,
    delta_y,
    data_table_cell_click,
    data_table_row_click,
    data_table_sort,
    decode_error,
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
    item_id,
    key,
    key_char,
    key_down,
    key_up,
    left,
    lines,
    list_id,
    menu_action,
    menus_decode_error,
    middle,
    modifiers,
    native_timeout,
    mouse_down,
    mouse_move,
    mouse_up,
    navigate_back,
    navigate_forward,
    nil,
    none,
    options_decode_error,
    pixels,
    platform,
    pong,
    pressed_button,
    right,
    row_id,
    runtime_unavailable,
    rust_core_unavailable,
    scroll_wheel,
    shift,
    shortcut,
    source_id,
    some,
    table_id,
    tree_id,
    tree_select,
    tree_toggle,
    unknown_view_id,
    value,
    control_id,
    window_close_requested,
    window_closed,
    x,
    y,
}

static RUNTIME_RUNNING: AtomicBool = AtomicBool::new(false);
static GUI_STARTED: AtomicBool = AtomicBool::new(false);
static GUI_STATUS: Mutex<i32> = Mutex::new(0);
static GUI_STATUS_COND: Condvar = Condvar::new();
static EVENT_TARGET: Mutex<Option<EventTargetRegistration>> = Mutex::new(None);
static EVENT_TARGET_GENERATION: AtomicU64 = AtomicU64::new(0);
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

fn load(env: Env, _term: Term) -> bool {
    if env.register::<EventTargetMonitor>().is_err() {
        return false;
    }

    main_thread_runtime::init_request_queue();
    RUNTIME_RUNNING.store(true, Ordering::SeqCst);
    let _ = maybe_start_main_thread_runtime();
    true
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
    timeout_ms: u64,
) -> Term<'a> {
    let to_binary_started_at = Instant::now();
    let ir_binary = ir.to_binary();
    record_counter(
        &OPEN_IR_TO_BINARY_COUNT,
        &OPEN_IR_TO_BINARY_NANOS,
        to_binary_started_at.elapsed(),
    );

    let opts_binary = opts.to_binary();

    let options_decode_started_at = Instant::now();
    let options = match WindowOptionsConfig::decode_etf(opts_binary.as_slice()) {
        Ok(options) => options,
        Err(reason) => return error_reason_tuple(env, options_decode_error(), reason),
    };
    record_counter(
        &OPEN_OPTIONS_DECODE_COUNT,
        &OPEN_OPTIONS_DECODE_NANOS,
        options_decode_started_at.elapsed(),
    );

    let ir = match decode_ir_binary(
        ir_binary.as_slice(),
        &OPEN_IR_DECODE_COUNT,
        &OPEN_IR_DECODE_NANOS,
    ) {
        Ok(ir) => ir,
        Err(reason) => return error_reason_tuple(env, decode_error(), reason),
    };

    let result = request_i32(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::OpenWindow {
            deadline,
            view_id,
            ir,
            options,
            reply,
        }
    });

    status_result(env, result, duplicate_view_id())
}

#[rustler::nif]
fn native_set_event_target<'a>(env: Env<'a>, pid: LocalPid) -> Term<'a> {
    let generation = EVENT_TARGET_GENERATION.fetch_add(1, Ordering::SeqCst) + 1;
    let resource = ResourceArc::new(EventTargetMonitor { generation });
    let Some(monitor) = env.monitor(&resource, &pid) else {
        return error_tuple(env, runtime_unavailable());
    };

    let Ok(mut target) = EVENT_TARGET.lock() else {
        return error_tuple(env, runtime_unavailable());
    };

    *target = Some(EventTargetRegistration {
        pid,
        generation,
        _resource: resource,
        _monitor: Some(monitor),
    });

    rustler::types::atom::ok().encode(env)
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_set_menus<'a>(env: Env<'a>, menus: Term<'a>, timeout_ms: u64) -> Term<'a> {
    let menus_binary = menus.to_binary();
    let menus = match MenuSpec::decode_etf(menus_binary.as_slice()) {
        Ok(menus) => menus,
        Err(reason) => return error_reason_tuple(env, menus_decode_error(), reason),
    };

    let result = request_i32(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::SetMenus {
            deadline,
            menus,
            reply,
        }
    });

    status_result(env, result, runtime_unavailable())
}

#[rustler::nif]
fn native_event_target_status<'a>(env: Env<'a>) -> Term<'a> {
    let Ok(target) = EVENT_TARGET.lock() else {
        return error_tuple(env, runtime_unavailable());
    };

    match target.as_ref() {
        Some(target) => (some(), target.generation).encode(env),
        None => none().encode(env),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_render<'a>(env: Env<'a>, view_id: u64, ir: Term<'a>, timeout_ms: u64) -> Term<'a> {
    let to_binary_started_at = Instant::now();
    let ir_binary = ir.to_binary();
    record_counter(
        &RENDER_IR_TO_BINARY_COUNT,
        &RENDER_IR_TO_BINARY_NANOS,
        to_binary_started_at.elapsed(),
    );

    let ir = match decode_ir_binary(
        ir_binary.as_slice(),
        &RENDER_IR_DECODE_COUNT,
        &RENDER_IR_DECODE_NANOS,
    ) {
        Ok(ir) => ir,
        Err(reason) => return error_reason_tuple(env, decode_error(), reason),
    };

    let result = request_i32(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::SetIr {
            deadline,
            view_id,
            ir,
            reply,
        }
    });

    status_result(env, result, unknown_view_id())
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_close_window<'a>(env: Env<'a>, view_id: u64, timeout_ms: u64) -> Term<'a> {
    let result = request_i32(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::CloseWindow {
            deadline,
            view_id,
            reply,
        }
    });

    status_result(env, result, unknown_view_id())
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_close_all<'a>(env: Env<'a>, timeout_ms: u64) -> Term<'a> {
    let result = request_i32(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::CloseAll { deadline, reply }
    });

    status_result(env, result, runtime_unavailable())
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_view_count<'a>(env: Env<'a>, timeout_ms: u64) -> Term<'a> {
    match request_u64(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::ViewCount { deadline, reply }
    }) {
        NativeRequestResult::Reply(count) => count.encode(env),
        NativeRequestResult::Timeout => error_tuple(env, native_timeout()),
        NativeRequestResult::Unavailable => error_tuple(env, runtime_unavailable()),
    }
}

fn decode_ir_binary(bytes: &[u8], count: &AtomicU64, nanos: &AtomicU64) -> Result<IrNode, String> {
    let started_at = Instant::now();
    let decoded = IrNode::decode_etf(bytes);
    record_counter(count, nanos, started_at.elapsed());
    decoded
}

fn status_result<'a>(
    env: Env<'a>,
    result: NativeRequestResult<i32>,
    zero_reason: Atom,
) -> Term<'a> {
    match result {
        NativeRequestResult::Reply(1) => rustler::types::atom::ok().encode(env),
        NativeRequestResult::Reply(0) => error_tuple(env, zero_reason),
        NativeRequestResult::Reply(_) => error_tuple(env, runtime_unavailable()),
        NativeRequestResult::Timeout => error_tuple(env, native_timeout()),
        NativeRequestResult::Unavailable => error_tuple(env, runtime_unavailable()),
    }
}

fn error_tuple<'a>(env: Env<'a>, reason: Atom) -> Term<'a> {
    (rustler::types::atom::error(), reason).encode(env)
}

fn error_reason_tuple<'a>(env: Env<'a>, kind: Atom, reason: String) -> Term<'a> {
    (rustler::types::atom::error(), (kind, reason)).encode(env)
}

struct EventTargetRegistration {
    pid: LocalPid,
    generation: u64,
    _resource: ResourceArc<EventTargetMonitor>,
    _monitor: Option<Monitor>,
}

struct EventTargetMonitor {
    generation: u64,
}

impl Resource for EventTargetMonitor {
    const IMPLEMENTS_DOWN: bool = true;

    fn down<'a>(&'a self, _env: Env<'a>, pid: LocalPid, _monitor: Monitor) {
        let Ok(mut target) = EVENT_TARGET.lock() else {
            return;
        };

        if matches!(target.as_ref(), Some(current) if current.generation == self.generation && current.pid == pid)
        {
            *target = None;
            let _ = main_thread_runtime::enqueue_request(
                main_thread_runtime::MainThreadRequest::CloseAllNoReply,
            );
        }
    }
}

enum NativeRequestResult<T> {
    Reply(T),
    Timeout,
    Unavailable,
}

fn request_i32(
    timeout_ms: u64,
    build: impl FnOnce(
        Sender<i32>,
        main_thread_runtime::RequestDeadline,
    ) -> main_thread_runtime::MainThreadRequest,
) -> NativeRequestResult<i32> {
    request_with_timeout(timeout_ms, build)
}

fn request_u64(
    timeout_ms: u64,
    build: impl FnOnce(
        Sender<u64>,
        main_thread_runtime::RequestDeadline,
    ) -> main_thread_runtime::MainThreadRequest,
) -> NativeRequestResult<u64> {
    request_with_timeout(timeout_ms, build)
}

fn request_with_timeout<T>(
    timeout_ms: u64,
    build: impl FnOnce(
        Sender<T>,
        main_thread_runtime::RequestDeadline,
    ) -> main_thread_runtime::MainThreadRequest,
) -> NativeRequestResult<T> {
    let (reply_tx, reply_rx) = mpsc::channel();
    let timeout = Duration::from_millis(timeout_ms);
    let deadline = main_thread_runtime::RequestDeadline::after(timeout);

    if main_thread_runtime::enqueue_request(build(reply_tx, deadline)).is_err() {
        return NativeRequestResult::Unavailable;
    }

    match reply_rx.recv_timeout(timeout) {
        Ok(value) => NativeRequestResult::Reply(value),
        Err(mpsc::RecvTimeoutError::Timeout) => NativeRequestResult::Timeout,
        Err(mpsc::RecvTimeoutError::Disconnected) => NativeRequestResult::Unavailable,
    }
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
        // SAFETY: OTP exposes erl_drv_steal_main_thread for NIF/bootstrap code. The thread name
        // is a live CString for the duration of the call, dtid points to valid stack storage, and
        // the callback has the required extern "C" ABI.
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
        vec![
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

fn map_from_pairs<'a>(env: Env<'a>, pairs: Vec<(Term<'a>, Term<'a>)>) -> Term<'a> {
    match Term::map_from_pairs(env, &pairs) {
        Ok(term) => term,
        Err(_) => rustler::types::atom::undefined().encode(env),
    }
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
mod native_event_test_support;

#[cfg(test)]
use native_event_test_support::{
    record_menu_event_snapshot_for_test, record_row_control_event_snapshot_for_test,
    record_semantic_event_snapshot_for_test,
};

#[cfg(test)]
pub(crate) use native_event_test_support::{
    native_event_send_snapshot_for_test, take_menu_event_snapshot_for_test,
    take_row_control_event_snapshot_for_test, take_semantic_event_snapshot_for_test,
};

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

rustler::init!("Elixir.Guppy.Native.Nif", load = load);
