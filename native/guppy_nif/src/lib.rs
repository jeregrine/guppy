//! Rust core linked into the final `guppy_nif` native library.
//!
//! The C shim owns `ERL_NIF_INIT` and low-level bootstrap concerns,
//! while this Rust crate grows into the GPUI runtime core.

mod bridge_view;
mod hello_window;
mod ir;

use crate::ir::IrNode;
use std::ffi::{c_char, c_void};
use std::sync::OnceLock;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Sender};
use std::thread;

unsafe extern "C" {
    fn guppy_c_nif_link_anchor();
    fn nif_init();
}

#[used]
static KEEP_NIF_INIT: unsafe extern "C" fn() = nif_init;

static BUILD_INFO: &[u8] = b"guppy_nif_rust_core\0";
static RUNTIME_STATUS_NOT_STARTED: &[u8] = b"not_started\0";
static RUNTIME_STATUS_STARTED: &[u8] = b"started\0";
static RUNTIME_STATUS_STOPPED: &[u8] = b"stopped\0";

static RUNTIME: OnceLock<RuntimeHandle> = OnceLock::new();
static RUNTIME_RUNNING: AtomicBool = AtomicBool::new(false);

struct RuntimeHandle {
    sender: Sender<Command>,
}

enum Command {
    OpenWindow { view_id: u64, reply: Sender<i32> },
    MountIr {
        view_id: u64,
        ir: IrNode,
        reply: Sender<i32>,
    },
    UpdateIr {
        view_id: u64,
        ir: IrNode,
        reply: Sender<i32>,
    },
    CloseWindow { view_id: u64, reply: Sender<i32> },
    ViewCount { reply: Sender<u64> },
    Shutdown,
}

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
    if RUNTIME.get().is_some() {
        RUNTIME_RUNNING.store(true, Ordering::SeqCst);
        return 1;
    }

    let (sender, receiver) = mpsc::channel();

    let handle = RuntimeHandle { sender };

    match RUNTIME.set(handle) {
        Ok(()) => {
            thread::Builder::new()
                .name("guppy-native-runtime".into())
                .spawn(move || runtime_loop(receiver))
                .expect("failed to spawn native runtime thread");

            RUNTIME_RUNNING.store(true, Ordering::SeqCst);
            1
        }
        Err(_handle) => {
            RUNTIME_RUNNING.store(true, Ordering::SeqCst);
            1
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_runtime_shutdown() -> i32 {
    if let Some(runtime) = RUNTIME.get() {
        let _ = runtime.sender.send(Command::Shutdown);
        RUNTIME_RUNNING.store(false, Ordering::SeqCst);
        1
    } else {
        0
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_runtime_status() -> *const c_char {
    let bytes = if RUNTIME_RUNNING.load(Ordering::SeqCst) {
        RUNTIME_STATUS_STARTED
    } else if RUNTIME.get().is_some() {
        RUNTIME_STATUS_STOPPED
    } else {
        RUNTIME_STATUS_NOT_STARTED
    };

    bytes.as_ptr().cast()
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_run_hello_window_main_thread(arg: *mut c_void) -> *mut c_void {
    let open_boot_window = !arg.is_null();
    hello_window::run_app(open_boot_window);
    std::ptr::null_mut()
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_open_window(view_id: u64) -> i32 {
    request_i32(|reply| Command::OpenWindow { view_id, reply }).unwrap_or(-1)
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_mount_ir_window(
    view_id: u64,
    ir_ptr: *const u8,
    ir_len: usize,
) -> i32 {
    request_ir(view_id, ir_ptr, ir_len, |view_id, ir, reply| Command::MountIr {
        view_id,
        ir,
        reply,
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_update_ir_window(
    view_id: u64,
    ir_ptr: *const u8,
    ir_len: usize,
) -> i32 {
    request_ir(view_id, ir_ptr, ir_len, |view_id, ir, reply| Command::UpdateIr {
        view_id,
        ir,
        reply,
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_close_window(view_id: u64) -> i32 {
    request_i32(|reply| Command::CloseWindow { view_id, reply }).unwrap_or(-1)
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_view_count() -> u64 {
    request_u64(|reply| Command::ViewCount { reply }).unwrap_or(u64::MAX)
}

fn request_ir(
    view_id: u64,
    ir_ptr: *const u8,
    ir_len: usize,
    build: impl FnOnce(u64, IrNode, Sender<i32>) -> Command,
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

fn request_i32(build: impl FnOnce(Sender<i32>) -> Command) -> Option<i32> {
    let runtime = RUNTIME.get()?;
    let (reply_tx, reply_rx) = mpsc::channel();
    runtime.sender.send(build(reply_tx)).ok()?;
    reply_rx.recv().ok()
}

fn request_u64(build: impl FnOnce(Sender<u64>) -> Command) -> Option<u64> {
    let runtime = RUNTIME.get()?;
    let (reply_tx, reply_rx) = mpsc::channel();
    runtime.sender.send(build(reply_tx)).ok()?;
    reply_rx.recv().ok()
}

fn runtime_loop(receiver: mpsc::Receiver<Command>) {
    while let Ok(command) = receiver.recv() {
        let result = match command {
            Command::OpenWindow { view_id, reply } => {
                hello_window::enqueue_request(hello_window::MainThreadRequest::OpenWindow {
                    view_id,
                    reply,
                })
            }
            Command::MountIr { view_id, ir, reply } => {
                hello_window::enqueue_request(hello_window::MainThreadRequest::MountIr {
                    view_id,
                    ir,
                    reply,
                })
            }
            Command::UpdateIr { view_id, ir, reply } => {
                hello_window::enqueue_request(hello_window::MainThreadRequest::UpdateIr {
                    view_id,
                    ir,
                    reply,
                })
            }
            Command::CloseWindow { view_id, reply } => {
                hello_window::enqueue_request(hello_window::MainThreadRequest::CloseWindow {
                    view_id,
                    reply,
                })
            }
            Command::ViewCount { reply } => {
                hello_window::enqueue_request(hello_window::MainThreadRequest::ViewCount { reply })
            }
            Command::Shutdown => break,
        };

        if result.is_err() {
            break;
        }
    }

    RUNTIME_RUNNING.store(false, Ordering::SeqCst);
}
