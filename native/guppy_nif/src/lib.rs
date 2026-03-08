//! Rust core linked into the final `guppy_nif` native library.
//!
//! The C shim owns `ERL_NIF_INIT` and low-level bootstrap concerns,
//! while this Rust crate grows into the GPUI runtime core.

mod bridge_text_input;
mod bridge_view;
mod ir;
mod main_thread_runtime;
mod window_options;

use crate::ir::IrNode;
use crate::window_options::WindowOptionsConfig;
use std::ffi::{c_char, c_void};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Sender};

unsafe extern "C" {
    fn guppy_c_nif_link_anchor();
    fn nif_init();
}

#[used]
static KEEP_NIF_INIT: unsafe extern "C" fn() = nif_init;

static BUILD_INFO: &[u8] = b"guppy_nif_rust_core\0";
static RUNTIME_STATUS_NOT_STARTED: &[u8] = b"not_started\0";
static RUNTIME_STATUS_STARTED: &[u8] = b"started\0";

static RUNTIME_RUNNING: AtomicBool = AtomicBool::new(false);

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_ping_value() -> i32 {
    unsafe { guppy_c_nif_link_anchor() };
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_build_info() -> *const c_char {
    BUILD_INFO.as_ptr().cast()
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_runtime_start() -> i32 {
    main_thread_runtime::init_request_queue();
    RUNTIME_RUNNING.store(true, Ordering::SeqCst);
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_runtime_shutdown() -> i32 {
    RUNTIME_RUNNING.store(false, Ordering::SeqCst);
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_runtime_status() -> *const c_char {
    let bytes = if RUNTIME_RUNNING.load(Ordering::SeqCst) {
        RUNTIME_STATUS_STARTED
    } else {
        RUNTIME_STATUS_NOT_STARTED
    };

    bytes.as_ptr().cast()
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_run_main_thread_runtime(_arg: *mut c_void) -> *mut c_void {
    main_thread_runtime::run_app();
    std::ptr::null_mut()
}

#[unsafe(no_mangle)]
/// # Safety
///
/// `ir_ptr`/`ir_len` and `opts_ptr`/`opts_len` must describe valid byte slices
/// for the duration of this call.
pub unsafe extern "C" fn guppy_rust_open_window(
    view_id: u64,
    ir_ptr: *const u8,
    ir_len: usize,
    opts_ptr: *const u8,
    opts_len: usize,
) -> i32 {
    let Some(opts_bytes) = (unsafe { slice_from_raw_parts(opts_ptr, opts_len) }) else {
        return -1;
    };

    let Ok(options) = WindowOptionsConfig::decode_etf(opts_bytes) else {
        return -2;
    };

    request_ir(view_id, ir_ptr, ir_len, |view_id, ir, reply| {
        main_thread_runtime::MainThreadRequest::OpenWindow {
            view_id,
            ir,
            options,
            reply,
        }
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_render_ir_window(
    view_id: u64,
    ir_ptr: *const u8,
    ir_len: usize,
) -> i32 {
    request_ir(view_id, ir_ptr, ir_len, |view_id, ir, reply| {
        main_thread_runtime::MainThreadRequest::SetIr { view_id, ir, reply }
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_close_window(view_id: u64) -> i32 {
    request_i32(|reply| main_thread_runtime::MainThreadRequest::CloseWindow { view_id, reply })
        .unwrap_or(-1)
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_view_count() -> u64 {
    request_u64(|reply| main_thread_runtime::MainThreadRequest::ViewCount { reply })
        .unwrap_or(u64::MAX)
}

fn request_ir(
    view_id: u64,
    ir_ptr: *const u8,
    ir_len: usize,
    build: impl FnOnce(u64, IrNode, Sender<i32>) -> main_thread_runtime::MainThreadRequest,
) -> i32 {
    let Some(bytes) = (unsafe { slice_from_raw_parts(ir_ptr, ir_len) }) else {
        return -1;
    };

    let Ok(ir) = IrNode::decode_etf(bytes) else {
        return -2;
    };

    request_i32(|reply| build(view_id, ir, reply)).unwrap_or(-1)
}

unsafe fn slice_from_raw_parts<'a>(ptr: *const u8, len: usize) -> Option<&'a [u8]> {
    (unsafe { ptr.as_ref() }).map(|_| unsafe { std::slice::from_raw_parts(ptr, len) })
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
