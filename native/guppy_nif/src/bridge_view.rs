mod events;
mod identity;
mod render_canvas;
mod render_checkbox;
mod render_data_table;
mod render_div;
mod render_icon;
mod render_image;
mod render_list;
mod render_pass;
mod render_popover;
mod render_radio;
mod render_scroll;
mod render_select;
mod render_spacer;
mod render_text;
mod render_text_input;
mod render_tree;
mod render_uniform_list;
mod style;

use crate::bridge_text_input::BridgeTextInput;
use crate::ir::IrNode;
use gpui::{
    App, Context, Entity, FocusHandle, KeyBinding, ListState, MouseDownEvent, Render, ScrollHandle,
    Subscription, Window, actions, div, prelude::*,
};
use std::collections::HashMap;

actions!(guppy, [FocusNext, FocusPrev]);

pub(crate) fn bind_focus_keys(cx: &mut App) {
    cx.bind_keys([
        KeyBinding::new("tab", FocusNext, None),
        KeyBinding::new("shift-tab", FocusPrev, None),
    ]);
}

#[derive(Default)]
pub(crate) struct BridgeRetainedState {
    pub root_focus_handle: Option<FocusHandle>,
    pub focus_visible: bool,
    pub scroll_handles: HashMap<String, ScrollHandle>,
    pub list_states: HashMap<String, ListState>,
    pub focus_handles: HashMap<String, FocusHandle>,
    pub focus_subscriptions: Vec<Subscription>,
    pub text_inputs: HashMap<String, Entity<BridgeTextInput>>,
}

pub struct BridgeView {
    pub view_id: u64,
    pub ir: IrNode,
    pub retained: BridgeRetainedState,
}

impl Render for BridgeView {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        self.retained.focus_subscriptions.clear();

        let root = {
            let mut pass = render_pass::RenderPass::new(self.view_id, &mut self.retained);
            let root = pass.render_node("root", &self.ir, None, window, cx);
            let state = pass.finish();
            self.prune_retained_state(state);
            root
        };

        let root_focus_handle = self
            .retained
            .root_focus_handle
            .get_or_insert_with(|| cx.focus_handle())
            .clone();

        if window.focused(cx).is_none() {
            window.focus(&root_focus_handle);
        }

        div()
            .size_full()
            .track_focus(&root_focus_handle)
            .on_any_mouse_down(cx.listener(Self::hide_focus_visible))
            .on_action(cx.listener(Self::focus_next))
            .on_action(cx.listener(Self::focus_prev))
            .child(root)
    }
}

impl BridgeView {
    fn focus_next(&mut self, _: &FocusNext, window: &mut Window, _: &mut Context<Self>) {
        self.retained.focus_visible = true;
        window.focus_next();
    }

    fn focus_prev(&mut self, _: &FocusPrev, window: &mut Window, _: &mut Context<Self>) {
        self.retained.focus_visible = true;
        window.focus_prev();
    }

    fn hide_focus_visible(&mut self, _: &MouseDownEvent, _: &mut Window, _: &mut Context<Self>) {
        self.retained.focus_visible = false;
    }

    fn prune_retained_state(&mut self, state: render_pass::RenderPassState) {
        self.retained
            .scroll_handles
            .retain(|node_id, _| state.live_scroll_ids.contains(node_id));
        self.retained
            .list_states
            .retain(|node_id, _| state.live_list_ids.contains(node_id));
        self.retained
            .focus_handles
            .retain(|node_id, _| state.live_focus_ids.contains(node_id));
        self.retained
            .text_inputs
            .retain(|node_id, _| state.live_text_input_ids.contains(node_id));
    }
}

#[cfg(test)]
mod tests {
    use super::{BridgeRetainedState, BridgeView, render_pass::RenderPassState};
    use crate::ir::{
        CanvasCommand, CanvasNode, ColorToken, DataTableCell, DataTableColumn,
        DataTableColumnWidth, DataTableNode, DataTableRow, DivNode, IrNode, ListItem, ScrollAxis,
        StyleColor, StyleOp, TreeItem, TreeNode,
    };
    use gpui::{ListAlignment, ListState, Modifiers, Render, ScrollHandle, point, px};

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
                    .contains_key("guppy-row-control:43:todo_list:row_1:open")
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
        assert_eq!(event.node_id, "guppy-row-control:43:todo_list:row_1:open");
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
                tooltip: None,
                shortcuts: Vec::new(),
                children: vec![
                    tab_stop_div_with("second", 2),
                    tab_stop_div_with("first", 1),
                ],
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
                children: vec![tab_stop_div()],
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
                tooltip: None,
                shortcuts: Vec::new(),
                children: vec![data_table_ir(), tree_ir()],
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
            tooltip: None,
            shortcuts: Vec::new(),
            children: vec![IrNode::text("tab target")],
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
                    children: vec![IrNode::text("Ship")],
                    style: Vec::new().into(),
                }],
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
        }))
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
                    children: Vec::new(),
                    style: Vec::new().into(),
                }],
                style: Vec::new().into(),
            }],
            style: vec![StyleOp::W96, StyleOp::H32].into(),
            row_style: Vec::new().into(),
            selected_id: Some("child".into()),
            select: Some("select_node".into()),
            toggle: Some("toggle_node".into()),
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
                    fill: StyleColor::Hex("#0f172a".into()),
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
                    tooltip: None,
                    shortcuts: Vec::new(),
                    children: vec![IrNode::text("Open")],
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
                }))],
            }]
            .into(),
            style: vec![StyleOp::W96, StyleOp::H32].into(),
            item_style: Vec::new().into(),
            click: None,
        }
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
            tooltip: None,
            shortcuts: Vec::new(),
            children: vec![IrNode::text("click me")],
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
}
