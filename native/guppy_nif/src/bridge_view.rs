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
    App, Context, Entity, FocusHandle, KeyBinding, ListState, MouseDownEvent, Render, ScrollAnchor,
    ScrollHandle, Subscription, Window, actions, div, prelude::*,
};
use std::collections::{HashMap, HashSet};

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
    pub scroll_anchors: HashMap<String, ScrollAnchor>,
    pub requested_scroll_anchor_ids: HashSet<String>,
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
            .scroll_anchors
            .retain(|node_id, _| state.live_scroll_anchor_ids.contains(node_id));
        self.retained
            .requested_scroll_anchor_ids
            .retain(|node_id| state.live_scroll_anchor_ids.contains(node_id));
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
#[path = "bridge_view_tests.rs"]
mod tests;
