mod bridge_text_input;
mod bridge_view;
mod etf_decode;
mod ir;
mod ir_allowed;
mod main_thread_runtime;
mod menu;
mod native_events;
mod window_options;

use crate::ir::IrNode;
use crate::menu::{MenuItemSpec, MenuSpec};
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
// SAFETY: This declaration binds OTP's main-thread bootstrap hook. The only call site is the
// narrow, documented unsafe block in maybe_start_main_thread_runtime.
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
    app_activated,
    app_deactivated,
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
    dock_menu_action,
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
    window_blurred,
    window_close_requested,
    window_closed,
    window_focused,
    window_moved,
    window_resized,
    width,
    height,
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

#[rustler::nif(schedule = "DirtyIo")]
fn native_set_dock_menu<'a>(env: Env<'a>, items: Term<'a>, timeout_ms: u64) -> Term<'a> {
    let items_binary = items.to_binary();
    let items = match MenuItemSpec::decode_list_etf(items_binary.as_slice()) {
        Ok(items) => items,
        Err(reason) => return error_reason_tuple(env, menus_decode_error(), reason),
    };

    let result = request_i32(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::SetDockMenu {
            deadline,
            items,
            reply,
        }
    });

    status_result(env, result, runtime_unavailable())
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_set_app_badge<'a>(env: Env<'a>, label: Option<String>, timeout_ms: u64) -> Term<'a> {
    let result = request_i32(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::SetAppBadge {
            deadline,
            label,
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
#[allow(clippy::too_many_arguments)]
fn native_open_file_dialog<'a>(
    env: Env<'a>,
    files: bool,
    directories: bool,
    multiple: bool,
    prompt: Option<String>,
    directory: Option<String>,
    filters: Vec<String>,
    owner_view_id: Option<u64>,
    timeout_ms: u64,
) -> Term<'a> {
    let result = request_with_timeout(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::OpenFileDialog {
            deadline,
            files,
            directories,
            multiple,
            prompt,
            directory,
            filters,
            owner_view_id,
            reply,
        }
    });

    match result {
        NativeRequestResult::Reply(Ok(Some(paths))) => paths.encode(env),
        NativeRequestResult::Reply(Ok(None)) => nil().encode(env),
        NativeRequestResult::Reply(Err(())) => error_tuple(env, runtime_unavailable()),
        NativeRequestResult::Timeout => error_tuple(env, native_timeout()),
        NativeRequestResult::Unavailable => error_tuple(env, runtime_unavailable()),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_save_file_dialog<'a>(
    env: Env<'a>,
    directory: Option<String>,
    default_name: Option<String>,
    filters: Vec<String>,
    owner_view_id: Option<u64>,
    timeout_ms: u64,
) -> Term<'a> {
    let result = request_with_timeout(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::SaveFileDialog {
            deadline,
            directory,
            default_name,
            filters,
            owner_view_id,
            reply,
        }
    });

    match result {
        NativeRequestResult::Reply(Ok(Some(path))) => path.encode(env),
        NativeRequestResult::Reply(Ok(None)) => nil().encode(env),
        NativeRequestResult::Reply(Err(())) => error_tuple(env, runtime_unavailable()),
        NativeRequestResult::Timeout => error_tuple(env, native_timeout()),
        NativeRequestResult::Unavailable => error_tuple(env, runtime_unavailable()),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_read_clipboard_text<'a>(env: Env<'a>, timeout_ms: u64) -> Term<'a> {
    let result = request_with_timeout(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::ReadClipboardText { deadline, reply }
    });

    match result {
        NativeRequestResult::Reply(Ok(Some(text))) => text.encode(env),
        NativeRequestResult::Reply(Ok(None)) => nil().encode(env),
        NativeRequestResult::Reply(Err(())) => error_tuple(env, runtime_unavailable()),
        NativeRequestResult::Timeout => error_tuple(env, native_timeout()),
        NativeRequestResult::Unavailable => error_tuple(env, runtime_unavailable()),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn native_write_clipboard_text<'a>(env: Env<'a>, text: String, timeout_ms: u64) -> Term<'a> {
    let result = request_i32(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::WriteClipboardText {
            deadline,
            text,
            reply,
        }
    });

    status_result(env, result, runtime_unavailable())
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
fn native_focus_window<'a>(env: Env<'a>, view_id: u64, timeout_ms: u64) -> Term<'a> {
    let result = request_i32(timeout_ms, |reply, deadline| {
        main_thread_runtime::MainThreadRequest::FocusWindow {
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
        // SAFETY: OTP exposes erl_drv_steal_main_thread for NIF/bootstrap code, and Rustler does
        // not provide an equivalent safe abstraction for this macOS main-thread handoff. Keep this
        // block narrow: the thread name is a live CString for the duration of the call, dtid points
        // to valid stack storage, and the callback has the required extern "C" ABI.
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

pub(crate) use native_events::{
    send_dock_menu_action_event, send_menu_action_event, send_window_close_requested_event,
    send_window_closed_event,
};

fn map_from_pairs<'a>(env: Env<'a>, pairs: impl AsRef<[(Term<'a>, Term<'a>)]>) -> Term<'a> {
    match Term::map_from_pairs(env, pairs.as_ref()) {
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
    record_basic_event_snapshot_for_test, record_menu_event_snapshot_for_test,
    record_row_control_event_snapshot_for_test, record_semantic_event_snapshot_for_test,
};

#[cfg(test)]
pub(crate) use native_event_test_support::{
    native_event_send_snapshot_for_test, take_basic_event_snapshot_matching_for_test,
    take_menu_event_snapshot_for_test, take_row_control_event_snapshot_for_test,
    take_semantic_event_snapshot_for_test,
};

rustler::init!("Elixir.Guppy.Native.Nif", load = load);
