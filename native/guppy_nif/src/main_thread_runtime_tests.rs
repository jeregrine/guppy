use super::{
    APP, MainThreadRequest, RequestDeadline, close_window, enqueue_request, handle_request,
    init_request_queue, open_window, owner_view_id_exists, try_next_request, view_count,
};
use crate::ir::{CanvasCommand, CanvasNode, IrNode, StyleColor};
use crate::window_options::WindowOptionsConfig;
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
fn file_dialog_owner_view_id_requires_live_native_window() {
    assert!(owner_view_id_exists(None));
    assert!(!owner_view_id_exists(Some(9_999)));
}

#[test]
fn expired_focus_window_requests_do_not_reply() {
    let (reply, receiver) = mpsc::channel();

    handle_request(MainThreadRequest::FocusWindow {
        deadline: RequestDeadline::after(Duration::from_millis(0)),
        view_id: 7,
        reply,
    });

    assert!(receiver.try_recv().is_err());
}

#[test]
fn expired_app_badge_requests_do_not_reply() {
    let (reply, receiver) = mpsc::channel();

    handle_request(MainThreadRequest::SetAppBadge {
        deadline: RequestDeadline::after(Duration::from_millis(0)),
        label: Some("3".into()),
        reply,
    });

    assert!(receiver.try_recv().is_err());
}

#[test]
fn expired_file_dialog_requests_do_not_reply() {
    let (open_reply, open_rx) = mpsc::channel();
    handle_request(MainThreadRequest::OpenFileDialog {
        deadline: RequestDeadline::after(Duration::from_millis(0)),
        files: true,
        directories: false,
        multiple: true,
        prompt: Some("Open".into()),
        directory: Some("/tmp".into()),
        filters: vec!["ex".into()],
        owner_view_id: Some(123),
        reply: open_reply,
    });

    assert!(open_rx.try_recv().is_err());

    let (save_reply, save_rx) = mpsc::channel();
    handle_request(MainThreadRequest::SaveFileDialog {
        deadline: RequestDeadline::after(Duration::from_millis(0)),
        directory: Some("/tmp".into()),
        default_name: Some("guppy.txt".into()),
        filters: vec!["txt".into()],
        owner_view_id: Some(123),
        reply: save_reply,
    });

    assert!(save_rx.try_recv().is_err());
}

#[test]
fn expired_canvas_set_ir_requests_do_not_reply_or_mutate_state() {
    let (reply, rx) = mpsc::channel();
    handle_request(MainThreadRequest::SetIr {
        deadline: RequestDeadline::after(Duration::from_millis(0)),
        view_id: 99,
        ir: IrNode::Canvas(Box::new(CanvasNode {
            id: Some("expired_canvas".into()),
            commands: vec![CanvasCommand::Rect {
                x: 0.0,
                y: 0.0,
                width: 10.0,
                height: 10.0,
                fill: StyleColor::Hex(0x0f172a),
                radius: 0.0,
            }]
            .into(),
            style: Vec::new().into(),
            click: None,
            context_menu: None,
        })),
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

#[test]
fn very_large_deadlines_do_not_panic_or_expire_immediately() {
    let deadline = RequestDeadline::after(Duration::MAX);

    assert!(!deadline.expired());
}

#[test]
fn enqueue_failure_cancels_queued_request_before_later_drain() {
    init_request_queue();
    while try_next_request().is_some() {}

    let (reply, rx) = mpsc::channel();
    let request = MainThreadRequest::ViewCount {
        deadline: RequestDeadline::after(Duration::from_secs(60)),
        reply,
    };

    assert!(enqueue_request(request).is_err());

    let queued = try_next_request().expect("request should remain queued after scheduling failure");
    handle_request(queued);

    assert!(rx.try_recv().is_err());
}

#[gpui::test]
fn duplicate_open_window_returns_zero_without_overwriting_existing_handle(
    cx: &mut gpui::TestAppContext,
) {
    APP.with(|app| {
        *app.borrow_mut() = Some(cx.to_async());
    });

    let view_id = 987_654_321;
    let before = view_count();
    let _ = close_window(view_id);

    assert_eq!(
        open_window(
            view_id,
            IrNode::text("first"),
            WindowOptionsConfig::default()
        ),
        1
    );
    assert_eq!(view_count(), before + 1);

    assert_eq!(
        open_window(
            view_id,
            IrNode::text("duplicate"),
            WindowOptionsConfig::default()
        ),
        0
    );
    assert_eq!(view_count(), before + 1);

    assert_eq!(close_window(view_id), 1);
    assert_eq!(view_count(), before);

    APP.with(|app| {
        *app.borrow_mut() = None;
    });
}
