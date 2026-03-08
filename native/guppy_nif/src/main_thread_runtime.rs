use crate::bridge_text_input;
use crate::bridge_view::BridgeView;
use crate::ir::{DivNode, DivStyle, IrNode};
use async_task::spawn;
use gpui::{
    App, AppContext, Application, AsyncApp, Bounds, PlatformDispatcher, WindowBounds,
    WindowOptions, px, size,
};
use std::cell::RefCell;
use std::collections::HashMap;
use std::sync::Arc;
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Mutex, OnceLock};

unsafe extern "C" {
    fn guppy_c_gui_started(status: i32);
    fn guppy_c_send_window_closed_event(view_id: u64) -> i32;
}

thread_local! {
    static APP: RefCell<Option<AsyncApp>> = const { RefCell::new(None) };
    static WINDOWS: RefCell<HashMap<u64, gpui::WindowHandle<BridgeView>>> = RefCell::new(HashMap::new());
}

static REQUEST_TX: OnceLock<Sender<MainThreadRequest>> = OnceLock::new();
static REQUEST_RX: OnceLock<Mutex<Receiver<MainThreadRequest>>> = OnceLock::new();
static MAIN_THREAD_DISPATCHER: OnceLock<Mutex<Option<Arc<dyn PlatformDispatcher>>>> =
    OnceLock::new();

pub(crate) enum MainThreadRequest {
    OpenWindow {
        view_id: u64,
        reply: Sender<i32>,
    },
    SetIr {
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
}

pub fn run_app() {
    init_request_queue();

    Application::new().run(move |cx: &mut App| {
        APP.with(|app| {
            *app.borrow_mut() = Some(cx.to_async());
        });

        bridge_text_input::bind_keys(cx);
        register_main_thread_dispatcher(cx);

        unsafe { guppy_c_gui_started(1) };
    });
}

pub(crate) fn enqueue_request(request: MainThreadRequest) -> Result<(), ()> {
    let sender = REQUEST_TX.get().ok_or(())?;
    sender.send(request).map_err(|_| ())?;
    schedule_request_drain()
}

pub fn open_window(view_id: u64, ir: IrNode) -> i32 {
    APP.with(|app| {
        let app = app.borrow().as_ref().cloned();

        let Some(mut app) = app else {
            return -1;
        };

        let result = app.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(Bounds::from_corners(
                    gpui::point(px(80.0), px(80.0)),
                    gpui::point(px(1280.0), px(920.0)),
                ))),
                is_resizable: true,
                window_min_size: Some(size(px(960.0), px(720.0))),
                ..Default::default()
            },
            move |_, cx| {
                cx.new(|_| BridgeView {
                    view_id,
                    ir,
                    retained: Default::default(),
                })
            },
        );

        match result {
            Ok(handle) => {
                let _ = app.update(|cx| {
                    cx.activate(true);
                });

                let _ = handle.update(&mut app, |_, window, cx| {
                    window.activate_window();
                    window.on_window_should_close(cx, move |_window, _cx| {
                        WINDOWS.with(|windows| {
                            windows.borrow_mut().remove(&view_id);
                        });

                        unsafe {
                            let _ = guppy_c_send_window_closed_event(view_id);
                        }
                        true
                    });
                });

                WINDOWS.with(|windows| {
                    windows.borrow_mut().insert(view_id, handle);
                });
                1
            }
            Err(_) => -1,
        }
    })
}

pub fn close_window(view_id: u64) -> i32 {
    let handle = WINDOWS.with(|windows| windows.borrow_mut().remove(&view_id));

    let Some(handle) = handle else {
        return 0;
    };

    APP.with(|app| {
        let app = app.borrow().as_ref().cloned();

        let Some(mut app) = app else {
            return -1;
        };

        match handle.update(&mut app, |_, window, _| window.remove_window()) {
            Ok(_) => 1,
            Err(_) => -1,
        }
    })
}

pub fn update_ir(view_id: u64, ir: IrNode) -> i32 {
    let handle = WINDOWS.with(|windows| windows.borrow().get(&view_id).cloned());

    let Some(handle) = handle else {
        return 0;
    };

    APP.with(|app| {
        let app = app.borrow().as_ref().cloned();

        let Some(mut app) = app else {
            return -1;
        };

        match handle.update(&mut app, |view, _window, cx| {
            view.ir = ir;
            cx.notify();
        }) {
            Ok(_) => 1,
            Err(_) => -1,
        }
    })
}

pub fn view_count() -> u64 {
    WINDOWS.with(|windows| windows.borrow().len() as u64)
}

fn init_request_queue() {
    if REQUEST_TX.get().is_none() {
        let (tx, rx) = mpsc::channel();
        let _ = REQUEST_TX.set(tx);
        let _ = REQUEST_RX.set(Mutex::new(rx));
    }

    let _ = MAIN_THREAD_DISPATCHER.set(Mutex::new(None));
}

fn register_main_thread_dispatcher(cx: &mut App) {
    let dispatcher = cx.foreground_executor().dispatcher.clone();
    let slot = MAIN_THREAD_DISPATCHER
        .get()
        .expect("main-thread dispatcher slot not initialized");
    let mut slot = slot.lock().expect("dispatcher lock poisoned");
    *slot = Some(dispatcher);
}

fn schedule_request_drain() -> Result<(), ()> {
    let dispatcher = {
        let slot = MAIN_THREAD_DISPATCHER.get().ok_or(())?;
        let slot = slot.lock().map_err(|_| ())?;
        slot.clone().ok_or(())?
    };

    let (runnable, task) = spawn(async move { drain_requests() }, move |runnable| {
        dispatcher.dispatch_on_main_thread(runnable);
    });

    runnable.schedule();
    task.detach();
    Ok(())
}

fn drain_requests() {
    while let Some(request) = try_next_request() {
        handle_request(request);
    }
}

fn try_next_request() -> Option<MainThreadRequest> {
    let receiver = REQUEST_RX.get()?;
    let guard = receiver.lock().expect("request queue lock poisoned");
    guard.try_recv().ok()
}

fn handle_request(request: MainThreadRequest) {
    match request {
        MainThreadRequest::OpenWindow { view_id, reply } => {
            let _ = reply.send(open_window(
                view_id,
                IrNode::Div(Box::new(DivNode {
                    id: None,
                    style: DivStyle::default(),
                    hover_style: DivStyle::default(),
                    focus_style: DivStyle::default(),
                    in_focus_style: DivStyle::default(),
                    active_style: DivStyle::default(),
                    disabled_style: DivStyle::default(),
                    disabled: false,
                    stack_priority: None,
                    occlude: false,
                    focusable: false,
                    tab_stop: None,
                    tab_index: None,
                    track_scroll: false,
                    anchor_scroll: false,
                    shortcuts: vec![],
                    children: vec![IrNode::text(format!("Hello from Guppy view {view_id}"))],
                    click: None,
                    hover: None,
                    focus: None,
                    blur: None,
                    key_down: None,
                    key_up: None,
                    context_menu: None,
                    drag_start: None,
                    drag_move: None,
                    drop: None,
                    mouse_down: None,
                    mouse_up: None,
                    mouse_move: None,
                    scroll_wheel: None,
                })),
            ));
        }
        MainThreadRequest::SetIr { view_id, ir, reply } => {
            let _ = reply.send(update_ir(view_id, ir));
        }
        MainThreadRequest::CloseWindow { view_id, reply } => {
            let _ = reply.send(close_window(view_id));
        }
        MainThreadRequest::ViewCount { reply } => {
            let _ = reply.send(view_count());
        }
    }
}
