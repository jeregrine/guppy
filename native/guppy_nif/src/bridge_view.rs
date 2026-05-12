mod events;
mod identity;
mod render_checkbox;
mod render_div;
mod render_icon;
mod render_image;
mod render_pass;
mod render_radio;
mod render_scroll;
mod render_spacer;
mod render_text;
mod render_text_input;
mod render_uniform_list;
mod style;

use crate::bridge_text_input::BridgeTextInput;
use crate::ir::IrNode;
use gpui::{
    Context, Entity, FocusHandle, Render, ScrollHandle, Subscription, Window, div, prelude::*,
};
use std::collections::HashMap;

#[derive(Default)]
pub(crate) struct BridgeRetainedState {
    pub scroll_handles: HashMap<String, ScrollHandle>,
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

        div().size_full().child(root)
    }
}

impl BridgeView {
    fn prune_retained_state(&mut self, state: render_pass::RenderPassState) {
        self.retained
            .scroll_handles
            .retain(|node_id, _| state.live_scroll_ids.contains(node_id));
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
    use crate::ir::{DivNode, IrNode, ScrollAxis, StyleOp};
    use gpui::{Modifiers, Render, ScrollHandle, point, px};

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
        IrNode::Div(Box::new(DivNode {
            id: Some("tab_target".into()),
            style: vec![StyleOp::W96, StyleOp::H32].into(),
            hover_style: Vec::new().into(),
            focus_style: Vec::new().into(),
            in_focus_style: Vec::new().into(),
            active_style: Vec::new().into(),
            disabled_style: Vec::new().into(),
            disabled: false,
            stack_priority: None,
            occlude: false,
            focusable: true,
            tab_stop: Some(true),
            tab_index: Some(1),
            track_scroll: false,
            anchor_scroll: false,
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

    fn clickable_div() -> IrNode {
        IrNode::Div(Box::new(DivNode {
            id: Some("click_target".into()),
            style: vec![StyleOp::W96, StyleOp::H32, StyleOp::P4, StyleOp::Border1].into(),
            hover_style: Vec::new().into(),
            focus_style: Vec::new().into(),
            in_focus_style: Vec::new().into(),
            active_style: Vec::new().into(),
            disabled_style: Vec::new().into(),
            disabled: false,
            stack_priority: None,
            occlude: false,
            focusable: false,
            tab_stop: None,
            tab_index: None,
            track_scroll: false,
            anchor_scroll: false,
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
