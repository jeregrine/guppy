use super::{NATIVE_EVENT_SEND_COUNT, NATIVE_EVENT_SEND_FAILURE_COUNT};
use std::collections::VecDeque;
use std::sync::Mutex;
use std::sync::atomic::Ordering;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct BasicEventSnapshot {
    pub event: &'static str,
    pub view_id: u64,
    pub node_id: Option<String>,
    pub callback_id: Option<String>,
    pub value: Option<String>,
    pub checked: Option<bool>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct RowControlEventSnapshot {
    pub event: &'static str,
    pub view_id: u64,
    pub node_id: String,
    pub callback_id: String,
    pub list_id: String,
    pub row_id: String,
    pub control_id: String,
    pub value: Option<String>,
    pub checked: Option<bool>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct MenuEventSnapshot {
    pub action_id: String,
    pub callback_id: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct SemanticEventSnapshot {
    pub event: &'static str,
    pub view_id: u64,
    pub node_id: String,
    pub callback_id: String,
    pub table_id: Option<String>,
    pub row_id: Option<String>,
    pub column_id: Option<String>,
    pub tree_id: Option<String>,
    pub item_id: Option<String>,
}

static BASIC_EVENT_SNAPSHOT: Mutex<VecDeque<BasicEventSnapshot>> = Mutex::new(VecDeque::new());
static ROW_CONTROL_EVENT_SNAPSHOT: Mutex<Option<RowControlEventSnapshot>> = Mutex::new(None);
static MENU_EVENT_SNAPSHOT: Mutex<Option<MenuEventSnapshot>> = Mutex::new(None);
static SEMANTIC_EVENT_SNAPSHOT: Mutex<Option<SemanticEventSnapshot>> = Mutex::new(None);

pub(crate) fn native_event_send_snapshot_for_test() -> (u64, u64) {
    (
        NATIVE_EVENT_SEND_COUNT.load(Ordering::Relaxed),
        NATIVE_EVENT_SEND_FAILURE_COUNT.load(Ordering::Relaxed),
    )
}

pub(crate) fn take_basic_event_snapshot_matching_for_test(
    event: &'static str,
    view_id: u64,
) -> Option<BasicEventSnapshot> {
    let mut snapshots = BASIC_EVENT_SNAPSHOT.lock().ok()?;
    let position = snapshots
        .iter()
        .position(|snapshot| snapshot.event == event && snapshot.view_id == view_id)?;
    snapshots.remove(position)
}

pub(crate) fn take_row_control_event_snapshot_for_test() -> Option<RowControlEventSnapshot> {
    ROW_CONTROL_EVENT_SNAPSHOT.lock().ok()?.take()
}

pub(crate) fn take_menu_event_snapshot_for_test() -> Option<MenuEventSnapshot> {
    MENU_EVENT_SNAPSHOT.lock().ok()?.take()
}

pub(crate) fn take_semantic_event_snapshot_for_test() -> Option<SemanticEventSnapshot> {
    SEMANTIC_EVENT_SNAPSHOT.lock().ok()?.take()
}

pub(super) fn record_basic_event_snapshot_for_test(
    event: &'static str,
    view_id: u64,
    node_id: Option<String>,
    callback_id: Option<String>,
    value: Option<String>,
    checked: Option<bool>,
) {
    if let Ok(mut snapshots) = BASIC_EVENT_SNAPSHOT.lock() {
        snapshots.push_back(BasicEventSnapshot {
            event,
            view_id,
            node_id,
            callback_id,
            value,
            checked,
        });
    }
}

pub(super) fn record_menu_event_snapshot_for_test(action_id: String, callback_id: String) {
    if let Ok(mut snapshot) = MENU_EVENT_SNAPSHOT.lock() {
        *snapshot = Some(MenuEventSnapshot {
            action_id,
            callback_id,
        });
    }
}

#[allow(clippy::too_many_arguments)]
pub(super) fn record_semantic_event_snapshot_for_test(
    event: &'static str,
    view_id: u64,
    node_id: String,
    callback_id: String,
    table_id: Option<String>,
    row_id: Option<String>,
    column_id: Option<String>,
    tree_id: Option<String>,
    item_id: Option<String>,
) {
    if let Ok(mut snapshot) = SEMANTIC_EVENT_SNAPSHOT.lock() {
        *snapshot = Some(SemanticEventSnapshot {
            event,
            view_id,
            node_id,
            callback_id,
            table_id,
            row_id,
            column_id,
            tree_id,
            item_id,
        });
    }
}

#[allow(clippy::too_many_arguments)]
pub(super) fn record_row_control_event_snapshot_for_test(
    event: &'static str,
    view_id: u64,
    node_id: String,
    callback_id: String,
    list_id: String,
    row_id: String,
    control_id: String,
    value: Option<String>,
    checked: Option<bool>,
) {
    if let Ok(mut snapshot) = ROW_CONTROL_EVENT_SNAPSHOT.lock() {
        *snapshot = Some(RowControlEventSnapshot {
            event,
            view_id,
            node_id,
            callback_id,
            list_id,
            row_id,
            control_id,
            value,
            checked,
        });
    }
}
