mod events;
mod identity;
mod render_div;
mod render_pass;
mod render_scroll;
mod render_text;
mod render_text_input;
mod style;

use crate::bridge_text_input::BridgeTextInput;
use crate::ir::IrNode;
use gpui::{
    Context, Entity, FocusHandle, Render, ScrollHandle, Subscription, Window, div, prelude::*, rgb,
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

        div()
            .size_full()
            .p_6()
            .bg(rgb(0x202020))
            .text_color(rgb(0xffffff))
            .child(root)
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
    use crate::ir::IrNode;
    use gpui::ScrollHandle;

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
}
