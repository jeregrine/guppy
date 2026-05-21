use super::{BridgeRetainedState, BridgeView, render_pass::RenderPassState};
use crate::ir::{
    CanvasCommand, CanvasNode, ColorToken, DataTableCell, DataTableColumn, DataTableColumnWidth,
    DataTableNode, DataTableRow, DivNode, IrNode, ListItem, ScrollAxis, ShortcutBinding,
    StyleColor, StyleOp, TreeItem, TreeNode, UniformListItem,
};
use gpui::{
    KeybindingKeystroke, Keystroke, ListAlignment, ListState, Modifiers, MouseButton, Render,
    ScrollHandle, point, px, size,
};

#[test]
fn prune_retained_state_drops_dead_scroll_handles() {
    let mut view = BridgeView {
        view_id: 7,
        ir: IrNode::text("hello"),
        retained: BridgeRetainedState::default(),
    };

    view.retained
        .scroll_handles
        .insert("keep".into(), ScrollHandle::new());
    view.retained
        .scroll_handles
        .insert("drop".into(), ScrollHandle::new());

    let state = RenderPassState {
        live_scroll_ids: ["keep".to_string()].into_iter().collect(),
        ..Default::default()
    };

    view.prune_retained_state(state);

    assert!(view.retained.scroll_handles.contains_key("keep"));
    assert!(!view.retained.scroll_handles.contains_key("drop"));
}

#[test]
fn prune_retained_state_drops_dead_list_states() {
    let mut view = BridgeView {
        view_id: 7,
        ir: IrNode::text("hello"),
        retained: BridgeRetainedState::default(),
    };

    view.retained.list_states.insert(
        "keep".into(),
        ListState::new(1, ListAlignment::Top, px(100.0)),
    );
    view.retained.list_states.insert(
        "drop".into(),
        ListState::new(1, ListAlignment::Top, px(100.0)),
    );

    let state = RenderPassState {
        live_list_ids: ["keep".to_string()].into_iter().collect(),
        ..Default::default()
    };

    view.prune_retained_state(state);

    assert!(view.retained.list_states.contains_key("keep"));
    assert!(!view.retained.list_states.contains_key("drop"));
}

#[gpui::test]
fn simulated_gpui_click_reaches_native_event_bridge(cx: &mut gpui::TestAppContext) {
    let before = crate::native_event_send_snapshot_for_test();
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 42,
        ir: clickable_div(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_click(point(px(10.), px(10.)), Modifiers::none());

    let after = crate::native_event_send_snapshot_for_test();
    assert!(after.0 > before.0);
    assert!(after.1 > before.1);
}

#[gpui::test]
fn focused_child_shortcut_takes_priority_over_ancestor(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 65,
        ir: nested_shortcut_divs(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("tab");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["shortcut_child"].is_focused(window));
    });

    cx.simulate_keystrokes("cmd-k");

    let event = crate::take_basic_event_snapshot_matching_for_test("action", 65).unwrap();
    assert_eq!(event.event, "action");
    assert_eq!(event.view_id, 65);
    assert_eq!(event.node_id.as_deref(), Some("shortcut_child"));
    assert_eq!(event.callback_id.as_deref(), Some("child_action"));
    assert!(crate::take_basic_event_snapshot_matching_for_test("action", 65).is_none());
}

#[gpui::test]
fn keyboard_context_menu_reaches_native_event_bridge(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 46,
        ir: context_menu_div(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("shift-f10");

    let event = crate::take_basic_event_snapshot_matching_for_test("context_menu", 46).unwrap();
    assert_eq!(event.event, "context_menu");
    assert_eq!(event.view_id, 46);
    assert_eq!(event.node_id.as_deref(), Some("click_target"));
    assert_eq!(event.callback_id.as_deref(), Some("contexted"));
}

#[gpui::test]
fn window_lifecycle_observers_reach_native_event_bridge(cx: &mut gpui::TestAppContext) {
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 48,
        ir: IrNode::text("Lifecycle"),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    let before_activation = crate::native_event_send_snapshot_for_test();
    cx.update(|window, _| window.activate_window());
    cx.run_until_parked();
    let after_activation = crate::native_event_send_snapshot_for_test();
    assert!(after_activation.0 >= before_activation.0 + 2);

    let event = crate::take_basic_event_snapshot_matching_for_test("window_focused", 48).unwrap();
    assert_eq!(event.event, "window_focused");
    assert_eq!(event.view_id, 48);

    cx.deactivate_window();

    let event = crate::take_basic_event_snapshot_matching_for_test("window_blurred", 48).unwrap();
    assert_eq!(event.event, "window_blurred");
    assert_eq!(event.view_id, 48);

    cx.simulate_resize(size(px(320.0), px(240.0)));

    let event = crate::take_basic_event_snapshot_matching_for_test("window_resized", 48).unwrap();
    assert_eq!(event.event, "window_resized");
    assert_eq!(event.view_id, 48);
}

#[gpui::test]
fn simulated_canvas_click_reaches_native_event_bridge(cx: &mut gpui::TestAppContext) {
    let before = crate::native_event_send_snapshot_for_test();
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 44,
        ir: canvas_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_click(point(px(10.), px(10.)), Modifiers::none());

    let after = crate::native_event_send_snapshot_for_test();
    assert!(after.0 > before.0);
    assert!(after.1 > before.1);
}

#[gpui::test]
fn simulated_canvas_context_menu_reaches_native_event_bridge(cx: &mut gpui::TestAppContext) {
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 47,
        ir: canvas_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_mouse_down(
        point(px(10.), px(10.)),
        MouseButton::Right,
        Modifiers::none(),
    );

    let event = crate::take_basic_event_snapshot_matching_for_test("context_menu", 47).unwrap();
    assert_eq!(event.event, "context_menu");
    assert_eq!(event.view_id, 47);
    assert_eq!(event.node_id.as_deref(), Some("summary_canvas"));
    assert_eq!(event.callback_id.as_deref(), Some("canvas_context_menu"));
}

#[gpui::test]
fn render_canvas_keeps_no_retained_resources(cx: &mut gpui::TestAppContext) {
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 45,
        ir: canvas_ir(),
        retained: BridgeRetainedState::default(),
    });

    view.update_in(cx, |view, window, view_cx| {
        let _ = view.render(window, view_cx);
        assert!(view.retained.scroll_handles.is_empty());
        assert!(view.retained.list_states.is_empty());
        assert!(view.retained.focus_handles.is_empty());
        assert!(view.retained.text_inputs.is_empty());
    });
}

#[gpui::test]
fn render_prunes_dead_list_row_control_focus_handles(cx: &mut gpui::TestAppContext) {
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 43,
        ir: list_with_row_button(),
        retained: BridgeRetainedState::default(),
    });

    view.update_in(cx, |view, window, view_cx| {
        let _ = view.render(window, view_cx);
        assert!(
            view.retained
                .focus_handles
                .contains_key("guppy-row-control:v1:43:746f646f5f6c697374:726f775f31:6f70656e")
        );

        view.ir = IrNode::text("no list anymore");
        let _ = view.render(window, view_cx);
        assert!(view.retained.focus_handles.is_empty());
    });
}

#[gpui::test]
fn simulated_list_row_button_click_reaches_native_event_bridge(cx: &mut gpui::TestAppContext) {
    let before = crate::native_event_send_snapshot_for_test();
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 43,
        ir: list_with_row_button(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_click(point(px(10.), px(10.)), Modifiers::none());

    let after = crate::native_event_send_snapshot_for_test();
    assert!(after.0 > before.0);
    assert!(after.1 > before.1);

    let event = crate::take_row_control_event_snapshot_for_test().unwrap();
    assert_eq!(event.event, "click");
    assert_eq!(event.view_id, 43);
    assert_eq!(event.callback_id, "open_row");
    assert_eq!(event.list_id, "todo_list");
    assert_eq!(event.row_id, "row_1");
    assert_eq!(event.control_id, "open");
    assert_eq!(
        event.node_id,
        "guppy-row-control:v1:43:746f646f5f6c697374:726f775f31:6f70656e"
    );
}

#[gpui::test]
fn simulated_uniform_list_context_menu_reaches_native_event_bridge(cx: &mut gpui::TestAppContext) {
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 51,
        ir: IrNode::UniformList {
            id: Some("uniform_items".into()),
            items: vec![UniformListItem {
                id: "item_1".into(),
                label: "Item 1".into(),
            }]
            .into(),
            style: vec![StyleOp::W96, StyleOp::H32].into(),
            item_style: Vec::new().into(),
            click: None,
            context_menu: Some("uniform_context".into()),
        },
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_mouse_down(
        point(px(10.), px(10.)),
        MouseButton::Right,
        Modifiers::none(),
    );

    let event = crate::take_basic_event_snapshot_matching_for_test("context_menu", 51).unwrap();
    assert_eq!(event.event, "context_menu");
    assert_eq!(event.node_id.as_deref(), Some("uniform_items.item_1"));
    assert_eq!(event.callback_id.as_deref(), Some("uniform_context"));
}

#[gpui::test]
fn sortable_data_table_headers_are_keyboard_actionable(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 56,
        ir: data_table_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("enter");

    let event =
        crate::take_semantic_event_snapshot_matching_for_test("data_table_sort", 56).unwrap();
    assert_eq!(event.event, "data_table_sort");
    assert_eq!(event.view_id, 56);
    assert_eq!(event.node_id, "tasks.header.task");
    assert_eq!(event.callback_id, "sort_table");
    assert_eq!(event.table_id.as_deref(), Some("tasks"));
    assert_eq!(event.column_id.as_deref(), Some("task"));
}

#[gpui::test]
fn simulated_list_row_context_menu_reaches_native_event_bridge(cx: &mut gpui::TestAppContext) {
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 49,
        ir: list_with_row_button(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_mouse_down(
        point(px(10.), px(10.)),
        MouseButton::Right,
        Modifiers::none(),
    );

    let event = crate::take_basic_event_snapshot_matching_for_test("context_menu", 49).unwrap();
    assert_eq!(event.event, "context_menu");
    assert_eq!(event.view_id, 49);
    assert_eq!(event.node_id.as_deref(), Some("todo_list.row_1"));
    assert_eq!(event.callback_id.as_deref(), Some("row_context"));
}

#[gpui::test]
fn tab_key_moves_focus_across_guppy_tab_stops(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);

    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 12,
        ir: IrNode::Div(Box::new(DivNode {
            id: Some("root".into()),
            style: Vec::new().into(),
            hover_style: Vec::new().into(),
            focus_style: Vec::new().into(),
            focus_visible_style: Vec::new().into(),
            in_focus_style: Vec::new().into(),
            active_style: Vec::new().into(),
            disabled_style: Vec::new().into(),
            animation: None,
            disabled: false,
            stack_priority: None,
            occlude: false,
            focusable: false,
            tab_stop: None,
            tab_index: None,
            track_scroll: false,
            anchor_scroll: false,
            scroll_to: false,
            tooltip: None,
            shortcuts: Vec::new().into(),
            children: vec![
                tab_stop_div_with("second", 2),
                tab_stop_div_with("first", 1),
            ]
            .into(),
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
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");

    view.update_in(cx, |view, window, _view_cx| {
        assert!(view.retained.focus_visible);
        assert!(view.retained.focus_handles["first"].is_focused(window));
        assert!(!view.retained.focus_handles["second"].is_focused(window));
    });

    cx.simulate_keystrokes("tab");

    view.update_in(cx, |view, window, _view_cx| {
        assert!(view.retained.focus_visible);
        assert!(!view.retained.focus_handles["first"].is_focused(window));
        assert!(view.retained.focus_handles["second"].is_focused(window));
    });

    cx.simulate_click(point(px(10.), px(10.)), Modifiers::none());

    view.update_in(cx, |view, _window, _view_cx| {
        assert!(!view.retained.focus_visible);
    });
}

#[gpui::test]
fn render_retains_scroll_and_focus_state_for_compliance_smoke(cx: &mut gpui::TestAppContext) {
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 10,
        ir: IrNode::Scroll {
            id: Some("compliance_scroll".into()),
            axis: ScrollAxis::Y,
            style: Vec::new().into(),
            children: vec![tab_stop_div()].into(),
        },
        retained: BridgeRetainedState::default(),
    });

    view.update_in(cx, |view, window, view_cx| {
        let _ = view.render(window, view_cx);

        assert!(
            view.retained
                .scroll_handles
                .contains_key("compliance_scroll")
        );
        assert!(view.retained.focus_handles.contains_key("tab_target"));
    });
}

#[gpui::test]
fn simulated_text_input_context_menu_reaches_native_event_bridge(cx: &mut gpui::TestAppContext) {
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 50,
        ir: IrNode::TextInput {
            id: Some("name_input".into()),
            value: "Jason".into(),
            placeholder: "Name".into(),
            style: vec![StyleOp::W96, StyleOp::H32].into(),
            disabled: false,
            tab_index: None,
            change: None,
            focus: None,
            blur: None,
            context_menu: Some("name_context".into()),
        },
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_mouse_down(
        point(px(10.), px(10.)),
        MouseButton::Right,
        Modifiers::none(),
    );

    let event = crate::take_basic_event_snapshot_matching_for_test("context_menu", 50).unwrap();
    assert_eq!(event.event, "context_menu");
    assert_eq!(event.view_id, 50);
    assert_eq!(event.node_id.as_deref(), Some("name_input"));
    assert_eq!(event.callback_id.as_deref(), Some("name_context"));
}

#[gpui::test]
fn simulated_textarea_context_menu_reaches_native_event_bridge(cx: &mut gpui::TestAppContext) {
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 52,
        ir: IrNode::Textarea {
            id: Some("notes_input".into()),
            value: "Notes".into(),
            placeholder: "Notes".into(),
            style: vec![StyleOp::W96, StyleOp::H32].into(),
            disabled: false,
            tab_index: None,
            change: None,
            focus: None,
            blur: None,
            context_menu: Some("notes_context".into()),
        },
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_mouse_down(
        point(px(10.), px(10.)),
        MouseButton::Right,
        Modifiers::none(),
    );

    let event = crate::take_basic_event_snapshot_matching_for_test("context_menu", 52).unwrap();
    assert_eq!(event.event, "context_menu");
    assert_eq!(event.node_id.as_deref(), Some("notes_input"));
    assert_eq!(event.callback_id.as_deref(), Some("notes_context"));
}

#[gpui::test]
fn data_table_header_arrow_keys_move_focus(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 64,
        ir: header_navigation_data_table_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.header.task"].is_focused(window));
    });

    cx.simulate_keystrokes("right");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.header.status"].is_focused(window));
    });

    cx.simulate_keystrokes("left");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.header.task"].is_focused(window));
    });
}

#[gpui::test]
fn data_table_header_down_and_cell_up_move_focus(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 63,
        ir: navigable_data_table_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.header.task"].is_focused(window));
    });

    cx.simulate_keystrokes("down");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.cell.row_1.task"].is_focused(window));
    });

    cx.simulate_keystrokes("up");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.header.task"].is_focused(window));
    });
}

#[gpui::test]
fn data_table_rows_and_cells_are_keyboard_actionable(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 59,
        ir: data_table_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("enter");

    let event =
        crate::take_semantic_event_snapshot_matching_for_test("data_table_row_click", 59).unwrap();
    assert_eq!(event.node_id, "tasks.row.row_1");
    assert_eq!(event.callback_id, "select_row");
    assert_eq!(event.table_id.as_deref(), Some("tasks"));
    assert_eq!(event.row_id.as_deref(), Some("row_1"));
    assert_eq!(event.column_id, None);

    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("enter");

    let event =
        crate::take_semantic_event_snapshot_matching_for_test("data_table_cell_click", 59).unwrap();
    assert_eq!(event.node_id, "tasks.cell.row_1.task");
    assert_eq!(event.callback_id, "select_cell");
    assert_eq!(event.table_id.as_deref(), Some("tasks"));
    assert_eq!(event.row_id.as_deref(), Some("row_1"));
    assert_eq!(event.column_id.as_deref(), Some("task"));
}

#[gpui::test]
fn data_table_rows_and_cells_support_keyboard_context_menu(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 60,
        ir: data_table_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("shift-f10");

    let event = crate::take_semantic_event_snapshot_matching_for_test("context_menu", 60).unwrap();
    assert_eq!(event.node_id, "tasks.row.row_1");
    assert_eq!(event.callback_id, "row_context");
    assert_eq!(event.table_id.as_deref(), Some("tasks"));
    assert_eq!(event.row_id.as_deref(), Some("row_1"));
    assert_eq!(event.column_id, None);

    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("shift-f10");

    let event = crate::take_semantic_event_snapshot_matching_for_test("context_menu", 60).unwrap();
    assert_eq!(event.node_id, "tasks.cell.row_1.task");
    assert_eq!(event.callback_id, "cell_context");
    assert_eq!(event.table_id.as_deref(), Some("tasks"));
    assert_eq!(event.row_id.as_deref(), Some("row_1"));
    assert_eq!(event.column_id.as_deref(), Some("task"));
}

#[gpui::test]
fn tree_rows_are_keyboard_actionable(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 57,
        ir: tree_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("enter");

    let event = crate::take_semantic_event_snapshot_matching_for_test("tree_select", 57).unwrap();
    assert_eq!(event.event, "tree_select");
    assert_eq!(event.view_id, 57);
    assert_eq!(event.node_id, "outline.row.root");
    assert_eq!(event.callback_id, "select_node");
    assert_eq!(event.tree_id.as_deref(), Some("outline"));
    assert_eq!(event.item_id.as_deref(), Some("root"));

    cx.simulate_keystrokes("space");

    let event = crate::take_semantic_event_snapshot_matching_for_test("tree_toggle", 57).unwrap();
    assert_eq!(event.event, "tree_toggle");
    assert_eq!(event.view_id, 57);
    assert_eq!(event.node_id, "outline.row.root");
    assert_eq!(event.callback_id, "toggle_node");
    assert_eq!(event.tree_id.as_deref(), Some("outline"));
    assert_eq!(event.item_id.as_deref(), Some("root"));
}

#[gpui::test]
fn data_table_arrow_keys_move_body_focus(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 62,
        ir: navigable_data_table_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("tab");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.row.row_1"].is_focused(window));
    });

    cx.simulate_keystrokes("down");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.row.row_2"].is_focused(window));
    });

    cx.simulate_keystrokes("up");
    cx.simulate_keystrokes("tab");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.cell.row_1.task"].is_focused(window));
    });

    cx.simulate_keystrokes("right");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.cell.row_1.status"].is_focused(window));
    });

    cx.simulate_keystrokes("down");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["tasks.cell.row_2.status"].is_focused(window));
    });
}

#[gpui::test]
fn tree_arrow_keys_move_row_focus(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 61,
        ir: tree_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["outline.row.root"].is_focused(window));
    });

    cx.simulate_keystrokes("down");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["outline.row.child"].is_focused(window));
    });

    cx.simulate_keystrokes("up");

    view.update_in(cx, |view, window, _| {
        assert!(view.retained.focus_handles["outline.row.root"].is_focused(window));
    });
}

#[gpui::test]
fn tree_rows_support_keyboard_context_menu(cx: &mut gpui::TestAppContext) {
    cx.update(super::bind_focus_keys);
    let (_view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 58,
        ir: tree_ir(),
        retained: BridgeRetainedState::default(),
    });

    cx.update(|window, cx| window.draw(cx).clear());
    cx.simulate_keystrokes("tab");
    cx.simulate_keystrokes("shift-f10");

    let event = crate::take_semantic_event_snapshot_matching_for_test("context_menu", 58).unwrap();
    assert_eq!(event.event, "context_menu");
    assert_eq!(event.view_id, 58);
    assert_eq!(event.node_id, "outline.row.root");
    assert_eq!(event.callback_id, "tree_context_menu");
    assert_eq!(event.tree_id.as_deref(), Some("outline"));
    assert_eq!(event.item_id.as_deref(), Some("root"));
}

#[gpui::test]
fn render_retains_data_table_and_tree_list_states(cx: &mut gpui::TestAppContext) {
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 55,
        ir: IrNode::Div(Box::new(DivNode {
            id: Some("semantic_root".into()),
            style: Vec::new().into(),
            hover_style: Vec::new().into(),
            focus_style: Vec::new().into(),
            focus_visible_style: Vec::new().into(),
            in_focus_style: Vec::new().into(),
            active_style: Vec::new().into(),
            disabled_style: Vec::new().into(),
            animation: None,
            disabled: false,
            stack_priority: None,
            occlude: false,
            focusable: false,
            tab_stop: None,
            tab_index: None,
            track_scroll: false,
            anchor_scroll: false,
            scroll_to: false,
            tooltip: None,
            shortcuts: Vec::new().into(),
            children: vec![data_table_ir(), tree_ir()].into(),
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
        retained: BridgeRetainedState::default(),
    });

    view.update_in(cx, |view, window, view_cx| {
        let _ = view.render(window, view_cx);
        assert!(view.retained.list_states.contains_key("tasks.rows"));
        assert!(view.retained.list_states.contains_key("outline.rows"));
    });
}

#[gpui::test]
fn render_prunes_dead_text_input_entities(cx: &mut gpui::TestAppContext) {
    let (view, cx) = cx.add_window_view(|_, _| BridgeView {
        view_id: 9,
        ir: IrNode::TextInput {
            id: Some("name_input".into()),
            value: "Jason".into(),
            placeholder: "Name".into(),
            style: Vec::new().into(),
            disabled: false,
            tab_index: None,
            change: Some("name_changed".into()),
            focus: Some("name_focused".into()),
            blur: Some("name_blurred".into()),
            context_menu: Some("name_context".into()),
        },
        retained: BridgeRetainedState::default(),
    });

    view.update_in(cx, |view, window, view_cx| {
        let _ = view.render(window, view_cx);
        assert_eq!(view.retained.text_inputs.len(), 1);

        view.ir = IrNode::text("no input anymore");
        let _ = view.render(window, view_cx);
        assert!(view.retained.text_inputs.is_empty());
    });
}

fn tab_stop_div() -> IrNode {
    tab_stop_div_with("tab_target", 1)
}

fn tab_stop_div_with(id: &str, tab_index: isize) -> IrNode {
    IrNode::Div(Box::new(DivNode {
        id: Some(id.into()),
        style: vec![StyleOp::W96, StyleOp::H32].into(),
        hover_style: Vec::new().into(),
        focus_style: Vec::new().into(),
        focus_visible_style: vec![StyleOp::Border1].into(),
        in_focus_style: Vec::new().into(),
        active_style: Vec::new().into(),
        disabled_style: Vec::new().into(),
        animation: None,
        disabled: false,
        stack_priority: None,
        occlude: false,
        focusable: true,
        tab_stop: Some(true),
        tab_index: Some(tab_index),
        track_scroll: false,
        anchor_scroll: false,
        scroll_to: false,
        tooltip: None,
        shortcuts: Vec::new().into(),
        children: vec![IrNode::text("tab target")].into(),
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
    }))
}

fn data_table_ir() -> IrNode {
    IrNode::DataTable(Box::new(DataTableNode {
        id: Some("tasks".into()),
        columns: vec![DataTableColumn {
            id: "task".into(),
            label: "Task".into(),
            width: DataTableColumnWidth::Fr(1),
            sortable: true,
            style: Vec::new().into(),
        }]
        .into(),
        rows: vec![DataTableRow {
            id: "row_1".into(),
            cells: vec![DataTableCell {
                column_id: "task".into(),
                children: vec![IrNode::text("Ship")].into(),
                style: Vec::new().into(),
            }]
            .into(),
            style: Vec::new().into(),
        }]
        .into(),
        style: vec![StyleOp::W96, StyleOp::H32].into(),
        header_style: Vec::new().into(),
        row_style: Vec::new().into(),
        cell_style: Vec::new().into(),
        selected_row_id: Some("row_1".into()),
        selected_cell: Some(("row_1".into(), "task".into())),
        sort: None,
        row_click: Some("select_row".into()),
        cell_click: Some("select_cell".into()),
        sort_callback: Some("sort_table".into()),
        row_context_menu: Some("row_context".into()),
        cell_context_menu: Some("cell_context".into()),
    }))
}

fn header_navigation_data_table_ir() -> IrNode {
    IrNode::DataTable(Box::new(DataTableNode {
        id: Some("tasks".into()),
        columns: vec![
            DataTableColumn {
                id: "task".into(),
                label: "Task".into(),
                width: DataTableColumnWidth::Fr(1),
                sortable: true,
                style: Vec::new().into(),
            },
            DataTableColumn {
                id: "status".into(),
                label: "Status".into(),
                width: DataTableColumnWidth::Fr(1),
                sortable: true,
                style: Vec::new().into(),
            },
        ]
        .into(),
        rows: vec![data_table_row_for_navigation("row_1", "Ship", "Ready")].into(),
        style: vec![StyleOp::W96, StyleOp::H32].into(),
        header_style: Vec::new().into(),
        row_style: Vec::new().into(),
        cell_style: Vec::new().into(),
        selected_row_id: None,
        selected_cell: None,
        sort: None,
        row_click: Some("select_row".into()),
        cell_click: Some("select_cell".into()),
        sort_callback: Some("sort_table".into()),
        row_context_menu: Some("row_context".into()),
        cell_context_menu: Some("cell_context".into()),
    }))
}

fn navigable_data_table_ir() -> IrNode {
    IrNode::DataTable(Box::new(DataTableNode {
        id: Some("tasks".into()),
        columns: vec![
            DataTableColumn {
                id: "task".into(),
                label: "Task".into(),
                width: DataTableColumnWidth::Fr(1),
                sortable: true,
                style: Vec::new().into(),
            },
            DataTableColumn {
                id: "status".into(),
                label: "Status".into(),
                width: DataTableColumnWidth::Fr(1),
                sortable: false,
                style: Vec::new().into(),
            },
        ]
        .into(),
        rows: vec![
            data_table_row_for_navigation("row_1", "Ship", "Ready"),
            data_table_row_for_navigation("row_2", "Test", "Blocked"),
        ]
        .into(),
        style: vec![StyleOp::W96, StyleOp::H32].into(),
        header_style: Vec::new().into(),
        row_style: Vec::new().into(),
        cell_style: Vec::new().into(),
        selected_row_id: None,
        selected_cell: None,
        sort: None,
        row_click: Some("select_row".into()),
        cell_click: Some("select_cell".into()),
        sort_callback: Some("sort_table".into()),
        row_context_menu: Some("row_context".into()),
        cell_context_menu: Some("cell_context".into()),
    }))
}

fn data_table_row_for_navigation(id: &str, task: &str, status: &str) -> DataTableRow {
    DataTableRow {
        id: id.into(),
        cells: vec![
            DataTableCell {
                column_id: "task".into(),
                children: vec![IrNode::text(task)].into(),
                style: Vec::new().into(),
            },
            DataTableCell {
                column_id: "status".into(),
                children: vec![IrNode::text(status)].into(),
                style: Vec::new().into(),
            },
        ]
        .into(),
        style: Vec::new().into(),
    }
}

fn tree_ir() -> IrNode {
    IrNode::Tree(Box::new(TreeNode {
        id: Some("outline".into()),
        nodes: vec![TreeItem {
            id: "root".into(),
            label: "Root".into(),
            expanded: true,
            children: vec![TreeItem {
                id: "child".into(),
                label: "Child".into(),
                expanded: false,
                children: Vec::new().into(),
                style: Vec::new().into(),
            }]
            .into(),
            style: Vec::new().into(),
        }]
        .into(),
        style: vec![StyleOp::W96, StyleOp::H32].into(),
        row_style: Vec::new().into(),
        selected_id: Some("child".into()),
        select: Some("select_node".into()),
        toggle: Some("toggle_node".into()),
        context_menu: Some("tree_context_menu".into()),
    }))
}

fn canvas_ir() -> IrNode {
    IrNode::Canvas(Box::new(CanvasNode {
        id: Some("summary_canvas".into()),
        commands: vec![
            CanvasCommand::Rect {
                x: 0.0,
                y: 0.0,
                width: 120.0,
                height: 80.0,
                fill: StyleColor::Hex(0x0f172a),
                radius: 0.0,
            },
            CanvasCommand::PatternRect {
                x: 12.0,
                y: 12.0,
                width: 96.0,
                height: 24.0,
                color: StyleColor::Token(ColorToken::Blue),
                line_width: 0.05,
                interval: 0.12,
                radius: 8.0,
            },
        ]
        .into(),
        style: vec![StyleOp::WPx(120.0), StyleOp::HPx(80.0)].into(),
        click: Some("canvas_clicked".into()),
        context_menu: Some("canvas_context_menu".into()),
    }))
}

fn list_with_row_button() -> IrNode {
    IrNode::List {
        id: Some("todo_list".into()),
        items: vec![ListItem {
            id: "row_1".into(),
            children: vec![IrNode::Button(Box::new(DivNode {
                id: Some("open".into()),
                style: vec![StyleOp::W96, StyleOp::H32, StyleOp::P4, StyleOp::Border1].into(),
                hover_style: Vec::new().into(),
                focus_style: Vec::new().into(),
                focus_visible_style: Vec::new().into(),
                in_focus_style: Vec::new().into(),
                active_style: Vec::new().into(),
                disabled_style: Vec::new().into(),
                animation: None,
                disabled: false,
                stack_priority: None,
                occlude: false,
                focusable: true,
                tab_stop: Some(true),
                tab_index: None,
                track_scroll: false,
                anchor_scroll: false,
                scroll_to: false,
                tooltip: None,
                shortcuts: Vec::new().into(),
                children: vec![IrNode::text("Open")].into(),
                click: Some("open_row".into()),
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
            }))]
            .into(),
        }]
        .into(),
        style: vec![StyleOp::W96, StyleOp::H32].into(),
        item_style: Vec::new().into(),
        click: None,
        context_menu: Some("row_context".into()),
    }
}

fn nested_shortcut_divs() -> IrNode {
    let child = IrNode::Div(Box::new(shortcut_div(
        "shortcut_child",
        2,
        "child_action",
        vec![IrNode::text("child")],
    )));

    IrNode::Div(Box::new(shortcut_div(
        "shortcut_parent",
        1,
        "parent_action",
        vec![child],
    )))
}

fn shortcut_div(id: &str, tab_index: isize, callback: &str, children: Vec<IrNode>) -> DivNode {
    DivNode {
        id: Some(id.into()),
        style: vec![StyleOp::W96, StyleOp::H32, StyleOp::P4, StyleOp::Border1].into(),
        hover_style: Vec::new().into(),
        focus_style: Vec::new().into(),
        focus_visible_style: Vec::new().into(),
        in_focus_style: Vec::new().into(),
        active_style: Vec::new().into(),
        disabled_style: Vec::new().into(),
        animation: None,
        disabled: false,
        stack_priority: None,
        occlude: false,
        focusable: false,
        tab_stop: Some(true),
        tab_index: Some(tab_index),
        track_scroll: false,
        anchor_scroll: false,
        scroll_to: false,
        tooltip: None,
        shortcuts: vec![shortcut_binding("cmd-k", "open", callback)].into(),
        children: children.into(),
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
    }
}

fn shortcut_binding(shortcut: &str, action: &str, callback: &str) -> ShortcutBinding {
    ShortcutBinding {
        shortcut: shortcut.into(),
        action: action.into(),
        callback: callback.into(),
        parsed: KeybindingKeystroke::from_keystroke(Keystroke::parse(shortcut).unwrap()),
    }
}

fn context_menu_div() -> IrNode {
    let mut node = clickable_div();

    if let IrNode::Div(div) = &mut node {
        div.context_menu = Some("contexted".into());
    }

    node
}

fn clickable_div() -> IrNode {
    IrNode::Div(Box::new(DivNode {
        id: Some("click_target".into()),
        style: vec![StyleOp::W96, StyleOp::H32, StyleOp::P4, StyleOp::Border1].into(),
        hover_style: Vec::new().into(),
        focus_style: Vec::new().into(),
        focus_visible_style: Vec::new().into(),
        in_focus_style: Vec::new().into(),
        active_style: Vec::new().into(),
        disabled_style: Vec::new().into(),
        animation: None,
        disabled: false,
        stack_priority: None,
        occlude: false,
        focusable: false,
        tab_stop: None,
        tab_index: None,
        track_scroll: false,
        anchor_scroll: false,
        scroll_to: false,
        tooltip: None,
        shortcuts: Vec::new().into(),
        children: vec![IrNode::text("click me")].into(),
        click: Some("clicked".into()),
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
    }))
}
