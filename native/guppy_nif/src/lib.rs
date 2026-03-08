//! Rust core linked into the final `guppy_nif` native library.
//!
//! The C shim owns `ERL_NIF_INIT` and low-level bootstrap concerns,
//! while this Rust crate grows into the GPUI runtime core.

mod bridge_text_input;
mod bridge_view;
mod ir;
mod main_thread_runtime;

use crate::ir::IrNode;
use std::ffi::{c_char, c_void};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Sender};
use std::sync::{Mutex, OnceLock};
use std::thread::{self, JoinHandle};

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

static RUNTIME: OnceLock<Mutex<RuntimeState>> = OnceLock::new();
static RUNTIME_RUNNING: AtomicBool = AtomicBool::new(false);

#[derive(Default)]
struct RuntimeState {
    sender: Option<Sender<Command>>,
    join_handle: Option<JoinHandle<()>>,
}

enum Command {
    OpenWindow {
        view_id: u64,
        reply: Sender<i32>,
    },
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
    CloseWindow {
        view_id: u64,
        reply: Sender<i32>,
    },
    ViewCount {
        reply: Sender<u64>,
    },
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
    let runtime = runtime_state();
    let mut runtime = runtime.lock().expect("runtime lock poisoned");
    refresh_runtime_state(&mut runtime);

    if runtime.sender.is_some() {
        RUNTIME_RUNNING.store(true, Ordering::SeqCst);
        return 1;
    }

    let (sender, receiver) = mpsc::channel();
    let join_handle = thread::Builder::new()
        .name("guppy-native-runtime".into())
        .spawn(move || runtime_loop(receiver))
        .expect("failed to spawn native runtime thread");

    runtime.sender = Some(sender);
    runtime.join_handle = Some(join_handle);
    RUNTIME_RUNNING.store(true, Ordering::SeqCst);
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_runtime_shutdown() -> i32 {
    let runtime = runtime_state();
    let (sender, join_handle) = {
        let mut runtime = runtime.lock().expect("runtime lock poisoned");
        refresh_runtime_state(&mut runtime);

        let sender = runtime.sender.take();
        let join_handle = runtime.join_handle.take();
        (sender, join_handle)
    };

    let Some(sender) = sender else {
        RUNTIME_RUNNING.store(false, Ordering::SeqCst);
        return 0;
    };

    let _ = sender.send(Command::Shutdown);

    if let Some(join_handle) = join_handle {
        let _ = join_handle.join();
    }

    RUNTIME_RUNNING.store(false, Ordering::SeqCst);
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_runtime_status() -> *const c_char {
    let runtime = runtime_state();
    let mut runtime = runtime.lock().expect("runtime lock poisoned");
    refresh_runtime_state(&mut runtime);

    let bytes = if RUNTIME_RUNNING.load(Ordering::SeqCst) {
        RUNTIME_STATUS_STARTED
    } else if runtime.sender.is_some() || runtime.join_handle.is_some() {
        RUNTIME_STATUS_STOPPED
    } else {
        RUNTIME_STATUS_NOT_STARTED
    };

    bytes.as_ptr().cast()
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_run_main_thread_runtime(arg: *mut c_void) -> *mut c_void {
    let open_bootstrap_window = !arg.is_null();
    main_thread_runtime::run_app(open_bootstrap_window);
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
    request_ir(view_id, ir_ptr, ir_len, |view_id, ir, reply| {
        Command::MountIr { view_id, ir, reply }
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn guppy_rust_update_ir_window(
    view_id: u64,
    ir_ptr: *const u8,
    ir_len: usize,
) -> i32 {
    request_ir(view_id, ir_ptr, ir_len, |view_id, ir, reply| {
        Command::UpdateIr { view_id, ir, reply }
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
    let sender = runtime_sender()?;
    let (reply_tx, reply_rx) = mpsc::channel();
    sender.send(build(reply_tx)).ok()?;
    reply_rx.recv().ok()
}

fn request_u64(build: impl FnOnce(Sender<u64>) -> Command) -> Option<u64> {
    let sender = runtime_sender()?;
    let (reply_tx, reply_rx) = mpsc::channel();
    sender.send(build(reply_tx)).ok()?;
    reply_rx.recv().ok()
}

fn runtime_state() -> &'static Mutex<RuntimeState> {
    RUNTIME.get_or_init(|| Mutex::new(RuntimeState::default()))
}

fn runtime_sender() -> Option<Sender<Command>> {
    let runtime = runtime_state();
    let mut runtime = runtime.lock().expect("runtime lock poisoned");
    refresh_runtime_state(&mut runtime);
    runtime.sender.clone()
}

fn refresh_runtime_state(runtime: &mut RuntimeState) {
    let finished = runtime
        .join_handle
        .as_ref()
        .is_some_and(JoinHandle::is_finished);

    if finished {
        if let Some(join_handle) = runtime.join_handle.take() {
            let _ = join_handle.join();
        }
        runtime.sender = None;
        RUNTIME_RUNNING.store(false, Ordering::SeqCst);
    }
}

fn runtime_loop(receiver: mpsc::Receiver<Command>) {
    while let Ok(command) = receiver.recv() {
        let result = match command {
            Command::OpenWindow { view_id, reply } => main_thread_runtime::enqueue_request(
                main_thread_runtime::MainThreadRequest::OpenWindow { view_id, reply },
            ),
            Command::MountIr { view_id, ir, reply } => main_thread_runtime::enqueue_request(
                main_thread_runtime::MainThreadRequest::MountIr { view_id, ir, reply },
            ),
            Command::UpdateIr { view_id, ir, reply } => main_thread_runtime::enqueue_request(
                main_thread_runtime::MainThreadRequest::UpdateIr { view_id, ir, reply },
            ),
            Command::CloseWindow { view_id, reply } => main_thread_runtime::enqueue_request(
                main_thread_runtime::MainThreadRequest::CloseWindow { view_id, reply },
            ),
            Command::ViewCount { reply } => main_thread_runtime::enqueue_request(
                main_thread_runtime::MainThreadRequest::ViewCount { reply },
            ),
            Command::Shutdown => break,
        };

        if result.is_err() {
            break;
        }
    }

    RUNTIME_RUNNING.store(false, Ordering::SeqCst);
}
