use crate::bridge_text_input;
use crate::bridge_view::BridgeView;
use crate::ir::IrNode;
use crate::menu::{self, MenuItemSpec, MenuSpec};
use crate::window_options::WindowOptionsConfig;
use async_task::spawn;
#[cfg(target_os = "macos")]
use cocoa::{
    appkit::{NSApp, NSModalResponse, NSOpenPanel, NSSavePanel},
    base::{BOOL, NO, YES, id, nil},
    foundation::{NSArray, NSAutoreleasePool, NSString, NSURL},
};
use gpui::{App, AppContext, Application, AsyncApp, ClipboardItem, PlatformDispatcher};
#[cfg(not(target_os = "macos"))]
use gpui::{PathPromptOptions, SharedString};
#[cfg(target_os = "macos")]
use objc::{msg_send, sel, sel_impl};
use std::cell::RefCell;
use std::collections::HashMap;
#[cfg(target_os = "macos")]
use std::ffi::CStr;
#[cfg(target_os = "macos")]
use std::os::raw::c_char;
#[cfg(not(target_os = "macos"))]
use std::path::{Path, PathBuf};
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

#[derive(Clone)]
pub(crate) struct RequestDeadline {
    started_at: Instant,
    timeout: Duration,
    canceled: Arc<AtomicBool>,
}

impl RequestDeadline {
    pub(crate) fn after(timeout: Duration) -> Self {
        Self {
            started_at: Instant::now(),
            timeout,
            canceled: Arc::new(AtomicBool::new(false)),
        }
    }

    fn cancel(&self) {
        self.canceled.store(true, Ordering::Release);
    }

    fn expired(&self) -> bool {
        self.canceled.load(Ordering::Acquire) || self.started_at.elapsed() >= self.timeout
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
    FocusWindow {
        deadline: RequestDeadline,
        view_id: u64,
        reply: Sender<i32>,
    },
    CloseAll {
        deadline: RequestDeadline,
        reply: Sender<i32>,
    },
    SetMenus {
        deadline: RequestDeadline,
        menus: Vec<MenuSpec>,
        reply: Sender<i32>,
    },
    SetDockMenu {
        deadline: RequestDeadline,
        items: Vec<MenuItemSpec>,
        reply: Sender<i32>,
    },
    SetAppBadge {
        deadline: RequestDeadline,
        label: Option<String>,
        reply: Sender<i32>,
    },
    OpenFileDialog {
        deadline: RequestDeadline,
        files: bool,
        directories: bool,
        multiple: bool,
        prompt: Option<String>,
        directory: Option<String>,
        filters: Vec<String>,
        owner_view_id: Option<u64>,
        reply: Sender<Result<Option<Vec<String>>, ()>>,
    },
    SaveFileDialog {
        deadline: RequestDeadline,
        directory: Option<String>,
        default_name: Option<String>,
        filters: Vec<String>,
        owner_view_id: Option<u64>,
        reply: Sender<Result<Option<String>, ()>>,
    },
    ReadClipboardText {
        deadline: RequestDeadline,
        reply: Sender<Result<Option<String>, ()>>,
    },
    WriteClipboardText {
        deadline: RequestDeadline,
        text: String,
        reply: Sender<i32>,
    },
    CloseAllNoReply,
    ViewCount {
        deadline: RequestDeadline,
        reply: Sender<u64>,
    },
}

impl MainThreadRequest {
    fn deadline(&self) -> Option<&RequestDeadline> {
        match self {
            MainThreadRequest::OpenWindow { deadline, .. }
            | MainThreadRequest::SetIr { deadline, .. }
            | MainThreadRequest::CloseWindow { deadline, .. }
            | MainThreadRequest::FocusWindow { deadline, .. }
            | MainThreadRequest::CloseAll { deadline, .. }
            | MainThreadRequest::SetMenus { deadline, .. }
            | MainThreadRequest::SetDockMenu { deadline, .. }
            | MainThreadRequest::SetAppBadge { deadline, .. }
            | MainThreadRequest::OpenFileDialog { deadline, .. }
            | MainThreadRequest::SaveFileDialog { deadline, .. }
            | MainThreadRequest::ReadClipboardText { deadline, .. }
            | MainThreadRequest::WriteClipboardText { deadline, .. }
            | MainThreadRequest::ViewCount { deadline, .. } => Some(deadline),
            MainThreadRequest::CloseAllNoReply => None,
        }
    }
}

pub fn run_app() {
    init_request_queue();

    Application::new().run(move |cx: &mut App| {
        APP.with(|app| {
            *app.borrow_mut() = Some(cx.to_async());
        });

        bridge_text_input::bind_keys(cx);
        crate::bridge_view::bind_focus_keys(cx);
        menu::bind_menu_action(cx);
        register_main_thread_dispatcher(cx);

        crate::notify_gui_started(1);
    });
}

pub(crate) fn enqueue_request(request: MainThreadRequest) -> Result<(), ()> {
    let cancel_deadline = request.deadline().cloned();
    let sender = REQUEST_TX.get().ok_or(())?;
    sender.send(request).map_err(|_| ())?;

    if schedule_request_drain().is_err() {
        if let Some(deadline) = cancel_deadline {
            deadline.cancel();
        }

        return Err(());
    }

    Ok(())
}

pub fn open_window(view_id: u64, ir: IrNode, options: WindowOptionsConfig) -> i32 {
    if WINDOWS.with(|windows| windows.borrow().contains_key(&view_id)) {
        return 0;
    }

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

pub fn focus_window(view_id: u64) -> i32 {
    let handle = WINDOWS.with(|windows| windows.borrow().get(&view_id).cloned());

    let Some(handle) = handle else {
        return 0;
    };

    APP.with(|app| {
        let app = app.borrow().as_ref().cloned();

        let Some(mut app) = app else {
            return -1;
        };

        match handle.update(&mut app, |_, window, _| window.activate_window()) {
            Ok(_) => 1,
            Err(_) => -1,
        }
    })
}

pub fn view_count() -> u64 {
    WINDOWS.with(|windows| windows.borrow().len() as u64)
}

pub fn set_menus(menus: Vec<MenuSpec>) -> i32 {
    APP.with(|app| {
        let app = app.borrow().as_ref().cloned();

        let Some(app) = app else {
            return -1;
        };

        let result = app.update(move |cx| menu::install_menus(cx, menus));

        match result {
            Ok(_) => 1,
            Err(_) => -1,
        }
    })
}

pub fn set_dock_menu(items: Vec<MenuItemSpec>) -> i32 {
    APP.with(|app| {
        let app = app.borrow().as_ref().cloned();

        let Some(app) = app else {
            return -1;
        };

        let result = app.update(move |cx| cx.set_dock_menu(menu::to_gpui_dock_menu_items(items)));

        match result {
            Ok(_) => 1,
            Err(_) => -1,
        }
    })
}

pub fn set_app_badge(label: Option<String>) -> i32 {
    APP.with(|app| {
        let app = app.borrow().as_ref().cloned();

        let Some(app) = app else {
            return -1;
        };

        app.update(move |_| set_platform_app_badge(label))
            .unwrap_or(-1)
    })
}

#[cfg(target_os = "macos")]
#[allow(unexpected_cfgs)]
fn set_platform_app_badge(label: Option<String>) -> i32 {
    unsafe {
        let app: id = NSApp();
        if app == nil {
            return -1;
        }

        let dock_tile: id = msg_send![app, dockTile];
        if dock_tile == nil {
            return -1;
        }

        let badge_label = label
            .as_deref()
            .map(|label| NSString::alloc(nil).init_str(label).autorelease())
            .unwrap_or(nil);

        let _: () = msg_send![dock_tile, setBadgeLabel: badge_label];
        let _: () = msg_send![dock_tile, display];
        1
    }
}

#[cfg(not(target_os = "macos"))]
fn set_platform_app_badge(_label: Option<String>) -> i32 {
    -1
}

#[allow(clippy::too_many_arguments)]
pub fn open_file_dialog(
    deadline: RequestDeadline,
    files: bool,
    directories: bool,
    multiple: bool,
    prompt: Option<String>,
    directory: Option<String>,
    filters: Vec<String>,
    owner_view_id: Option<u64>,
    reply: Sender<Result<Option<Vec<String>>, ()>>,
) {
    APP.with(|app| {
        let Some(app) = app.borrow().as_ref().cloned() else {
            let _ = reply.send(Err(()));
            return;
        };

        if !owner_view_id_exists(owner_view_id) {
            let _ = reply.send(Err(()));
            return;
        }

        #[cfg(target_os = "macos")]
        let _ = app;

        #[cfg(target_os = "macos")]
        {
            let result = run_open_file_dialog_macos(
                files,
                directories,
                multiple,
                prompt,
                directory,
                filters,
            );

            if !deadline.expired() {
                let _ = reply.send(result);
            }
        }

        #[cfg(not(target_os = "macos"))]
        {
            if directory.is_some() || !filters.is_empty() {
                let _ = reply.send(Err(()));
                return;
            }

            let options = PathPromptOptions {
                files,
                directories,
                multiple,
                prompt: prompt.map(SharedString::from),
            };

            let receiver = match app.update(move |cx| cx.prompt_for_paths(options)) {
                Ok(receiver) => receiver,
                Err(_) => {
                    let _ = reply.send(Err(()));
                    return;
                }
            };

            let executor = app.background_executor().clone();
            executor
                .spawn(async move {
                    let result = match receiver.await {
                        Ok(Ok(Some(paths))) => {
                            Ok(Some(paths.into_iter().map(path_to_string).collect()))
                        }
                        Ok(Ok(None)) => Ok(None),
                        Ok(Err(_)) | Err(_) => Err(()),
                    };

                    if !deadline.expired() {
                        let _ = reply.send(result);
                    }
                })
                .detach();
        }
    });
}

pub fn save_file_dialog(
    deadline: RequestDeadline,
    directory: Option<String>,
    default_name: Option<String>,
    filters: Vec<String>,
    owner_view_id: Option<u64>,
    reply: Sender<Result<Option<String>, ()>>,
) {
    APP.with(|app| {
        let Some(app) = app.borrow().as_ref().cloned() else {
            let _ = reply.send(Err(()));
            return;
        };

        if !owner_view_id_exists(owner_view_id) {
            let _ = reply.send(Err(()));
            return;
        }

        #[cfg(target_os = "macos")]
        let _ = app;

        #[cfg(target_os = "macos")]
        {
            let result = run_save_file_dialog_macos(directory, default_name, filters);

            if !deadline.expired() {
                let _ = reply.send(result);
            }
        }

        #[cfg(not(target_os = "macos"))]
        {
            if !filters.is_empty() {
                let _ = reply.send(Err(()));
                return;
            }

            let directory = directory
                .map(PathBuf::from)
                .or_else(|| std::env::current_dir().ok())
                .unwrap_or_else(|| PathBuf::from("."));

            let receiver = match app.update(move |cx| {
                cx.prompt_for_new_path(Path::new(&directory), default_name.as_deref())
            }) {
                Ok(receiver) => receiver,
                Err(_) => {
                    let _ = reply.send(Err(()));
                    return;
                }
            };

            let executor = app.background_executor().clone();
            executor
                .spawn(async move {
                    let result = match receiver.await {
                        Ok(Ok(Some(path))) => Ok(Some(path_to_string(path))),
                        Ok(Ok(None)) => Ok(None),
                        Ok(Err(_)) | Err(_) => Err(()),
                    };

                    if !deadline.expired() {
                        let _ = reply.send(result);
                    }
                })
                .detach();
        }
    });
}

#[cfg(target_os = "macos")]
#[allow(unexpected_cfgs)]
fn run_open_file_dialog_macos(
    files: bool,
    directories: bool,
    multiple: bool,
    prompt: Option<String>,
    directory: Option<String>,
    filters: Vec<String>,
) -> Result<Option<Vec<String>>, ()> {
    unsafe {
        let panel = NSOpenPanel::openPanel(nil);
        panel.setCanChooseDirectories_(objc_bool(directories));
        panel.setCanChooseFiles_(objc_bool(files));
        panel.setAllowsMultipleSelection_(objc_bool(multiple));
        panel.setCanCreateDirectories(objc_bool(true));
        panel.setResolvesAliases_(objc_bool(false));

        if let Some(prompt) = prompt.as_deref() {
            let _: () = msg_send![panel, setPrompt: ns_string(prompt)];
        }

        set_panel_directory(panel, directory.as_deref());
        set_allowed_file_types(panel, &filters);

        let response: NSModalResponse = msg_send![panel, runModal];
        if response != NSModalResponse::NSModalResponseOk {
            return Ok(None);
        }

        let urls = panel.URLs();
        let mut paths = Vec::new();
        for index in 0..urls.count() {
            let url = urls.objectAtIndex(index);
            if let Some(path) = ns_url_to_path_string(url) {
                paths.push(path);
            }
        }

        Ok(Some(paths))
    }
}

#[cfg(target_os = "macos")]
#[allow(unexpected_cfgs)]
fn run_save_file_dialog_macos(
    directory: Option<String>,
    default_name: Option<String>,
    filters: Vec<String>,
) -> Result<Option<String>, ()> {
    unsafe {
        let panel = NSSavePanel::savePanel(nil);
        set_panel_directory(panel, directory.as_deref());
        set_allowed_file_types(panel, &filters);

        if let Some(default_name) = default_name.as_deref() {
            let _: () = msg_send![panel, setNameFieldStringValue: ns_string(default_name)];
        }

        let response: NSModalResponse = msg_send![panel, runModal];
        if response != NSModalResponse::NSModalResponseOk {
            return Ok(None);
        }

        let url: id = msg_send![panel, URL];
        Ok(ns_url_to_path_string(url))
    }
}

#[cfg(target_os = "macos")]
#[allow(unexpected_cfgs)]
unsafe fn set_panel_directory(panel: id, directory: Option<&str>) {
    if let Some(directory) = directory {
        unsafe {
            let path = ns_string(directory);
            let url = NSURL::fileURLWithPath_isDirectory_(nil, path, objc_bool(true));
            let _: () = msg_send![panel, setDirectoryURL: url];
        }
    }
}

#[cfg(target_os = "macos")]
#[allow(unexpected_cfgs)]
unsafe fn set_allowed_file_types(panel: id, filters: &[String]) {
    if filters.is_empty() {
        return;
    }

    unsafe {
        let objects = filters
            .iter()
            .map(|filter| ns_string(filter))
            .collect::<Vec<_>>();
        let file_types = NSArray::arrayWithObjects(nil, &objects);
        let _: () = msg_send![panel, setAllowedFileTypes: file_types];
    }
}

#[cfg(target_os = "macos")]
#[allow(unexpected_cfgs)]
unsafe fn ns_url_to_path_string(url: id) -> Option<String> {
    if url == nil {
        return None;
    }

    unsafe {
        let path: id = msg_send![url, path];
        if path == nil {
            return None;
        }

        let bytes: *const c_char = msg_send![path, UTF8String];
        if bytes.is_null() {
            return None;
        }

        Some(CStr::from_ptr(bytes).to_string_lossy().into_owned())
    }
}

#[cfg(target_os = "macos")]
unsafe fn ns_string(string: &str) -> id {
    unsafe { NSString::alloc(nil).init_str(string).autorelease() }
}

#[cfg(target_os = "macos")]
fn objc_bool(value: bool) -> BOOL {
    if value { YES } else { NO }
}

fn owner_view_id_exists(owner_view_id: Option<u64>) -> bool {
    match owner_view_id {
        Some(view_id) => WINDOWS.with(|windows| windows.borrow().contains_key(&view_id)),
        None => true,
    }
}

#[cfg(not(target_os = "macos"))]
fn path_to_string(path: PathBuf) -> String {
    path.to_string_lossy().into_owned()
}

pub fn read_clipboard_text() -> Result<Option<String>, ()> {
    APP.with(|app| {
        let app = app.borrow().as_ref().cloned().ok_or(())?;

        app.update(|cx| cx.read_from_clipboard().and_then(|item| item.text()))
            .map_err(|_| ())
    })
}

pub fn write_clipboard_text(text: String) -> i32 {
    APP.with(|app| {
        let app = app.borrow().as_ref().cloned();

        let Some(app) = app else {
            return -1;
        };

        let result = app.update(move |cx| cx.write_to_clipboard(ClipboardItem::new_string(text)));

        match result {
            Ok(_) => 1,
            Err(_) => -1,
        }
    })
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
        MainThreadRequest::FocusWindow {
            deadline,
            view_id,
            reply,
        } => {
            if !deadline.expired() {
                let _ = reply.send(focus_window(view_id));
            }
        }
        MainThreadRequest::CloseAll { deadline, reply } => {
            if !deadline.expired() {
                let _ = reply.send(close_all_windows());
            }
        }
        MainThreadRequest::SetMenus {
            deadline,
            menus,
            reply,
        } => {
            if !deadline.expired() {
                let _ = reply.send(set_menus(menus));
            }
        }
        MainThreadRequest::SetDockMenu {
            deadline,
            items,
            reply,
        } => {
            if !deadline.expired() {
                let _ = reply.send(set_dock_menu(items));
            }
        }
        MainThreadRequest::SetAppBadge {
            deadline,
            label,
            reply,
        } => {
            if !deadline.expired() {
                let _ = reply.send(set_app_badge(label));
            }
        }
        MainThreadRequest::OpenFileDialog {
            deadline,
            files,
            directories,
            multiple,
            prompt,
            directory,
            filters,
            owner_view_id,
            reply,
        } => {
            if !deadline.expired() {
                open_file_dialog(
                    deadline,
                    files,
                    directories,
                    multiple,
                    prompt,
                    directory,
                    filters,
                    owner_view_id,
                    reply,
                );
            }
        }
        MainThreadRequest::SaveFileDialog {
            deadline,
            directory,
            default_name,
            filters,
            owner_view_id,
            reply,
        } => {
            if !deadline.expired() {
                save_file_dialog(
                    deadline,
                    directory,
                    default_name,
                    filters,
                    owner_view_id,
                    reply,
                );
            }
        }
        MainThreadRequest::ReadClipboardText { deadline, reply } => {
            if !deadline.expired() {
                let _ = reply.send(read_clipboard_text());
            }
        }
        MainThreadRequest::WriteClipboardText {
            deadline,
            text,
            reply,
        } => {
            if !deadline.expired() {
                let _ = reply.send(write_clipboard_text(text));
            }
        }
        MainThreadRequest::CloseAllNoReply => {
            let _ = set_menus(Vec::new());
            let _ = set_dock_menu(Vec::new());
            let _ = set_app_badge(None);
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
#[path = "main_thread_runtime_tests.rs"]
mod tests;
