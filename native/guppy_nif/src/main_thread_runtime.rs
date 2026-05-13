use crate::bridge_text_input;
use crate::bridge_view::BridgeView;
use crate::ir::IrNode;
use crate::window_options::WindowOptionsConfig;
use async_task::spawn;
use gpui::{App, AppContext, Application, AsyncApp, PlatformDispatcher};
use std::cell::RefCell;
use std::collections::HashMap;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

thread_local! {
    static APP: RefCell<Option<AsyncApp>> = const { RefCell::new(None) };
    static WINDOWS: RefCell<HashMap<u64, gpui::WindowHandle<BridgeView>>> = RefCell::new(HashMap::new());
}

static REQUEST_TX: OnceLock<Sender<MainThreadRequest>> = OnceLock::new();
static REQUEST_RX: OnceLock<Mutex<Receiver<MainThreadRequest>>> = OnceLock::new();
static MAIN_THREAD_DISPATCHER: OnceLock<Mutex<Option<Arc<dyn PlatformDispatcher>>>> =
    OnceLock::new();
static REQUEST_DRAIN_SCHEDULED: AtomicBool = AtomicBool::new(false);

#[derive(Clone, Copy)]
pub(crate) struct RequestDeadline {
    expires_at: Instant,
}

impl RequestDeadline {
    pub(crate) fn after(timeout: Duration) -> Self {
        Self {
            expires_at: Instant::now() + timeout,
        }
    }

    fn expired(self) -> bool {
        Instant::now() >= self.expires_at
    }
}

pub(crate) enum MainThreadRequest {
    OpenWindow {
        deadline: RequestDeadline,
        view_id: u64,
        ir: IrNode,
        options: WindowOptionsConfig,
        reply: Sender<i32>,
    },
    SetIr {
        deadline: RequestDeadline,
        view_id: u64,
        ir: IrNode,
        reply: Sender<i32>,
    },
    CloseWindow {
        deadline: RequestDeadline,
        view_id: u64,
        reply: Sender<i32>,
    },
    CloseAll {
        deadline: RequestDeadline,
        reply: Sender<i32>,
    },
    CloseAllNoReply,
    ViewCount {
        deadline: RequestDeadline,
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
        crate::bridge_view::bind_focus_keys(cx);
        register_main_thread_dispatcher(cx);

        crate::notify_gui_started(1);
    });
}

pub(crate) fn enqueue_request(request: MainThreadRequest) -> Result<(), ()> {
    let sender = REQUEST_TX.get().ok_or(())?;
    sender.send(request).map_err(|_| ())?;
    schedule_request_drain()
}

pub fn open_window(view_id: u64, ir: IrNode, options: WindowOptionsConfig) -> i32 {
    APP.with(|app| {
        let app = app.borrow().as_ref().cloned();

        let Some(mut app) = app else {
            return -1;
        };

        let should_focus = options.focus.unwrap_or(true);
        let Ok(gpui_options) = app.update(|cx| options.to_gpui(cx)) else {
            return -1;
        };

        let result = app.open_window(gpui_options, move |_, cx| {
            cx.new(|_| BridgeView {
                view_id,
                ir,
                retained: Default::default(),
            })
        });

        match result {
            Ok(handle) => {
                if should_focus {
                    let _ = app.update(|cx| {
                        cx.activate(true);
                    });
                }

                let _ = handle.update(&mut app, |_, window, cx| {
                    if should_focus {
                        window.activate_window();
                    }

                    window.on_window_should_close(cx, move |_window, _cx| {
                        let _ = crate::send_window_close_requested_event(view_id);

                        WINDOWS.with(|windows| {
                            windows.borrow_mut().remove(&view_id);
                        });

                        let _ = crate::send_window_closed_event(view_id);
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

pub fn close_all_windows() -> i32 {
    let view_ids = WINDOWS.with(|windows| windows.borrow().keys().copied().collect::<Vec<_>>());

    for view_id in view_ids {
        let _ = close_window(view_id);
    }

    1
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

pub(crate) fn init_request_queue() {
    if REQUEST_TX.get().is_none() {
        let (tx, rx) = mpsc::channel();
        let _ = REQUEST_TX.set(tx);
        let _ = REQUEST_RX.set(Mutex::new(rx));
    }

    let _ = MAIN_THREAD_DISPATCHER.set(Mutex::new(None));
}

fn register_main_thread_dispatcher(cx: &mut App) {
    let dispatcher = cx.foreground_executor().dispatcher.clone();

    let Some(slot) = MAIN_THREAD_DISPATCHER.get() else {
        return;
    };

    let Ok(mut slot) = slot.lock() else {
        return;
    };

    *slot = Some(dispatcher);
}

fn schedule_request_drain() -> Result<(), ()> {
    if REQUEST_DRAIN_SCHEDULED.swap(true, Ordering::AcqRel) {
        return Ok(());
    }

    dispatch_request_drain().inspect_err(|_| {
        REQUEST_DRAIN_SCHEDULED.store(false, Ordering::Release);
    })
}

fn dispatch_request_drain() -> Result<(), ()> {
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
    loop {
        while let Some(request) = try_next_request() {
            handle_request(request);
        }

        REQUEST_DRAIN_SCHEDULED.store(false, Ordering::Release);

        let Some(request) = try_next_request() else {
            break;
        };

        let _ = REQUEST_DRAIN_SCHEDULED.swap(true, Ordering::AcqRel);
        handle_request(request);
    }
}

fn try_next_request() -> Option<MainThreadRequest> {
    let receiver = REQUEST_RX.get()?;
    let guard = receiver.lock().ok()?;
    guard.try_recv().ok()
}

fn handle_request(request: MainThreadRequest) {
    match request {
        MainThreadRequest::OpenWindow {
            deadline,
            view_id,
            ir,
            options,
            reply,
        } => {
            if !deadline.expired() {
                let _ = reply.send(open_window(view_id, ir, options));
            }
        }
        MainThreadRequest::SetIr {
            deadline,
            view_id,
            ir,
            reply,
        } => {
            if !deadline.expired() {
                let _ = reply.send(update_ir(view_id, ir));
            }
        }
        MainThreadRequest::CloseWindow {
            deadline,
            view_id,
            reply,
        } => {
            if !deadline.expired() {
                let _ = reply.send(close_window(view_id));
            }
        }
        MainThreadRequest::CloseAll { deadline, reply } => {
            if !deadline.expired() {
                let _ = reply.send(close_all_windows());
            }
        }
        MainThreadRequest::CloseAllNoReply => {
            let _ = close_all_windows();
        }
        MainThreadRequest::ViewCount { deadline, reply } => {
            if !deadline.expired() {
                let _ = reply.send(view_count());
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{MainThreadRequest, RequestDeadline, handle_request, view_count};
    use std::sync::mpsc;
    use std::time::Duration;

    #[test]
    fn expired_requests_do_not_reply_or_mutate_state() {
        let (reply, rx) = mpsc::channel();
        handle_request(MainThreadRequest::ViewCount {
            deadline: RequestDeadline::after(Duration::from_millis(0)),
            reply,
        });

        assert!(rx.try_recv().is_err());
    }

    #[test]
    fn live_requests_still_reply() {
        let (reply, rx) = mpsc::channel();
        handle_request(MainThreadRequest::ViewCount {
            deadline: RequestDeadline::after(Duration::from_secs(60)),
            reply,
        });

        assert_eq!(rx.try_recv().unwrap(), view_count());
    }
}
