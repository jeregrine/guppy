mod events;
mod identity;
mod render_canvas;
mod render_checkbox;
mod render_choice;
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
use crate::native_events::{self, WindowBoundsEventPayload};
use gpui::{
    App, Bounds, Context, Entity, FocusHandle, KeyBinding, ListState, MouseDownEvent, Pixels,
    Render, ScrollAnchor, ScrollHandle, Subscription, Window, actions, div, prelude::*,
};
use std::cell::RefCell;
use std::collections::{HashMap, HashSet};

thread_local! {
    static ACTIVE_WINDOW_VIEW_IDS: RefCell<HashSet<u64>> = RefCell::new(HashSet::new());
}

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
    pub lifecycle_subscriptions: Vec<Subscription>,
    pub last_window_bounds: Option<Bounds<Pixels>>,
    pub last_window_active: Option<bool>,
    pub text_inputs: HashMap<String, Entity<BridgeTextInput>>,
}

pub struct BridgeView {
    pub view_id: u64,
    pub ir: IrNode,
    pub retained: BridgeRetainedState,
}

fn window_bounds_payload(bounds: Bounds<Pixels>) -> WindowBoundsEventPayload {
    WindowBoundsEventPayload {
        x: f64::from(bounds.origin.x),
        y: f64::from(bounds.origin.y),
        width: f64::from(bounds.size.width),
        height: f64::from(bounds.size.height),
    }
}

fn mark_initial_app_window_active(view_id: u64, active: bool) {
    if active {
        ACTIVE_WINDOW_VIEW_IDS.with(|view_ids| {
            view_ids.borrow_mut().insert(view_id);
        });
    }
}

fn emit_app_activation_change(view_id: u64, active: bool) {
    ACTIVE_WINDOW_VIEW_IDS.with(|view_ids| {
        let mut view_ids = view_ids.borrow_mut();

        if active {
            if view_ids.insert(view_id) && view_ids.len() == 1 {
                let _ = native_events::send_app_activated_event();
            }
        } else if view_ids.remove(&view_id) && view_ids.is_empty() {
            let _ = native_events::send_app_deactivated_event();
        }
    });
}

impl Render for BridgeView {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        self.retained.focus_subscriptions.clear();
        self.ensure_window_lifecycle_observers(window, cx);

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
    fn ensure_window_lifecycle_observers(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        if !self.retained.lifecycle_subscriptions.is_empty() {
            return;
        }

        self.retained.last_window_bounds = Some(window.bounds());
        let active = window.is_window_active();
        self.retained.last_window_active = Some(active);
        mark_initial_app_window_active(self.view_id, active);

        self.retained
            .lifecycle_subscriptions
            .push(cx.observe_window_bounds(window, Self::window_bounds_changed));
        self.retained
            .lifecycle_subscriptions
            .push(cx.observe_window_activation(window, Self::window_activation_changed));
    }

    fn window_bounds_changed(&mut self, window: &mut Window, _: &mut Context<Self>) {
        let bounds = window.bounds();
        let previous = self.retained.last_window_bounds.replace(bounds);

        let Some(previous) = previous else {
            return;
        };

        let payload = window_bounds_payload(bounds);

        if previous.origin != bounds.origin {
            let _ = native_events::send_window_moved_event(self.view_id, payload);
        }

        if previous.size != bounds.size {
            let _ = native_events::send_window_resized_event(self.view_id, payload);
        }
    }

    fn window_activation_changed(&mut self, window: &mut Window, _: &mut Context<Self>) {
        let active = window.is_window_active();

        if self.retained.last_window_active.replace(active) == Some(active) {
            return;
        }

        emit_app_activation_change(self.view_id, active);

        let _ = if active {
            native_events::send_window_focused_event(self.view_id)
        } else {
            native_events::send_window_blurred_event(self.view_id)
        };
    }

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
