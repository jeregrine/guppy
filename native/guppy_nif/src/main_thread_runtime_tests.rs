use super::{MainThreadRequest, RequestDeadline, handle_request, view_count};
use crate::ir::{CanvasCommand, CanvasNode, IrNode, StyleColor};
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
