use crate::ir::IrNode;
use gpui::{
    AnyElement, App, Application, AsyncApp, Bounds, Context, SharedString, Window, WindowBounds,
    WindowOptions, div, prelude::*, px, rgb,
};
use std::cell::RefCell;
use std::collections::HashMap;
use std::sync::mpsc::{self, Receiver, Sender, TryRecvError};
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

unsafe extern "C" {
    fn guppy_c_gui_started(status: i32);
    fn guppy_c_send_click_event(
        view_id: u64,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
    ) -> i32;
    fn guppy_c_send_window_closed_event(view_id: u64) -> i32;
}

thread_local! {
    static APP: RefCell<Option<AsyncApp>> = const { RefCell::new(None) };
    static WINDOWS: RefCell<HashMap<u64, gpui::WindowHandle<BridgeView>>> = RefCell::new(HashMap::new());
}

static REQUEST_TX: OnceLock<Sender<MainThreadRequest>> = OnceLock::new();
static REQUEST_RX: OnceLock<Mutex<Receiver<MainThreadRequest>>> = OnceLock::new();

pub(crate) enum MainThreadRequest {
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
}

pub struct BridgeView {
    pub view_id: u64,
    pub ir: IrNode,
}

impl Render for BridgeView {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .size_full()
            .p_6()
            .bg(rgb(0x202020))
            .text_color(rgb(0xffffff))
            .child(render_ir(self.view_id, "root", &self.ir))
    }
}

pub fn run_app(open_boot_window: bool) {
    init_request_queue();

    Application::new().run(move |cx: &mut App| {
        APP.with(|app| {
            *app.borrow_mut() = Some(cx.to_async());
        });

        start_request_poller(cx);

        unsafe { guppy_c_gui_started(1) };

        if open_boot_window {
            let _ = open_window(0, IrNode::text("Hello from Guppy NIF + GPUI"));
        }
    });
}

pub(crate) fn enqueue_request(request: MainThreadRequest) -> Result<(), ()> {
    let sender = REQUEST_TX.get().ok_or(())?;
    sender.send(request).map_err(|_| ())
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
                    gpui::point(px(100.0), px(100.0)),
                    gpui::point(px(740.0), px(500.0)),
                ))),
                ..Default::default()
            },
            move |_, cx| cx.new(|_| BridgeView { view_id, ir }),
        );

        match result {
            Ok(handle) => {
                let _ = app.update(|cx| {
                    cx.activate(true);
                });

                let _ = handle.update(&mut app, |_, window, cx| {
                    window.activate_window();
                    window.on_window_should_close(cx, move |_window, _cx| {
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

pub fn mount_ir(view_id: u64, ir: IrNode) -> i32 {
    update_ir(view_id, ir)
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

fn render_ir(view_id: u64, path: &str, ir: &IrNode) -> AnyElement {
    match ir {
        IrNode::Text(content) => SharedString::from(content.clone()).into_any_element(),
        IrNode::Div { children, click } => render_div(view_id, path, children, click.as_deref()),
    }
}

fn render_div(view_id: u64, path: &str, children: &[IrNode], click: Option<&str>) -> AnyElement {
    let child_elements = children
        .iter()
        .enumerate()
        .map(|(index, child)| render_ir(view_id, &format!("{path}.{index}"), child))
        .collect::<Vec<_>>();

    match click {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();

            div()
                .id(SharedString::from(format!("guppy-{view_id}-{path}")))
                .flex()
                .flex_col()
                .gap_2()
                .cursor_pointer()
                .active(|style| style.opacity(0.85))
                .children(child_elements)
                .on_click(move |_, _, _| unsafe {
                    let _ = guppy_c_send_click_event(
                        view_id,
                        callback_id.as_ptr(),
                        callback_id.len(),
                    );
                })
                .into_any_element()
        }
        None => div()
            .flex()
            .flex_col()
            .gap_2()
            .children(child_elements)
            .into_any_element(),
    }
}

fn init_request_queue() {
    if REQUEST_TX.get().is_none() {
        let (tx, rx) = mpsc::channel();
        let _ = REQUEST_TX.set(tx);
        let _ = REQUEST_RX.set(Mutex::new(rx));
    }
}

fn start_request_poller(cx: &mut App) {
    cx.spawn(async move |cx| loop {
        drain_requests();
        cx.background_executor().timer(Duration::from_millis(16)).await;
    })
    .detach();
}

fn drain_requests() {
    let Some(receiver) = REQUEST_RX.get() else {
        return;
    };

    loop {
        let next = {
            let guard = receiver.lock().expect("request queue lock poisoned");
            guard.try_recv()
        };

        match next {
            Ok(request) => handle_request(request),
            Err(TryRecvError::Empty) | Err(TryRecvError::Disconnected) => break,
        }
    }
}

fn handle_request(request: MainThreadRequest) {
    match request {
        MainThreadRequest::OpenWindow { view_id, reply } => {
            let _ = reply.send(open_window(
                view_id,
                IrNode::Div {
                    children: vec![IrNode::text(format!("Hello from Guppy view {view_id}"))],
                    click: None,
                },
            ));
        }
        MainThreadRequest::MountIr { view_id, ir, reply } => {
            let _ = reply.send(mount_ir(view_id, ir));
        }
        MainThreadRequest::UpdateIr { view_id, ir, reply } => {
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
