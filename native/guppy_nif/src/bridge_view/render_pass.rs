use super::{
    BridgeRetainedState, BridgeView, events, render_div, render_image, render_scroll,
    render_spacer, render_text, render_text_input,
};
use crate::bridge_text_input::BridgeTextInput;
use crate::ir::IrNode;
use gpui::{AnyElement, Context, Entity, FocusHandle, ScrollHandle, Window};
use std::collections::HashSet;

#[derive(Default)]
pub(crate) struct RenderPassState {
    pub live_scroll_ids: HashSet<String>,
    pub live_focus_ids: HashSet<String>,
    pub live_text_input_ids: HashSet<String>,
    pub registered_focus_callbacks: HashSet<String>,
}

pub(crate) struct RenderPass<'a> {
    view_id: u64,
    retained: &'a mut BridgeRetainedState,
    state: RenderPassState,
}

impl<'a> RenderPass<'a> {
    pub fn new(view_id: u64, retained: &'a mut BridgeRetainedState) -> Self {
        Self {
            view_id,
            retained,
            state: RenderPassState::default(),
        }
    }

    pub fn finish(self) -> RenderPassState {
        self.state
    }

    pub fn view_id(&self) -> u64 {
        self.view_id
    }

    pub fn render_node(
        &mut self,
        path: &str,
        ir: &IrNode,
        parent_scroll_handle: Option<ScrollHandle>,
        window: &mut Window,
        cx: &mut Context<BridgeView>,
    ) -> AnyElement {
        match ir {
            IrNode::Text { id, content, click } => {
                render_text::render(self, path, id.as_deref(), content, click.as_deref())
            }
            IrNode::TextInput {
                id,
                value,
                placeholder,
                style,
                disabled,
                tab_index,
                change,
            } => render_text_input::render(
                self,
                render_text_input::TextInputSpec {
                    path,
                    id: id.as_deref(),
                    value,
                    placeholder,
                    style,
                    disabled: *disabled,
                    tab_index: *tab_index,
                    change: change.as_deref(),
                },
                cx,
            ),
            IrNode::Scroll {
                id,
                axis,
                style,
                children,
            } => render_scroll::render(
                self,
                render_scroll::ScrollSpec {
                    path,
                    id: id.as_deref(),
                    axis: *axis,
                    style,
                    children,
                },
                window,
                cx,
            ),
            IrNode::Image {
                id,
                source,
                style,
                object_fit,
                grayscale,
            } => render_image::render(
                self,
                path,
                id.as_deref(),
                source,
                style,
                *object_fit,
                *grayscale,
            ),
            IrNode::Spacer { id, style } => render_spacer::render(self, path, id.as_deref(), style),
            IrNode::Div(div) => {
                render_div::render(self, path, div, parent_scroll_handle, window, cx)
            }
        }
    }

    pub fn render_children(
        &mut self,
        path: &str,
        children: &[IrNode],
        parent_scroll_handle: Option<ScrollHandle>,
        window: &mut Window,
        cx: &mut Context<BridgeView>,
    ) -> Vec<AnyElement> {
        children
            .iter()
            .enumerate()
            .map(|(index, child)| {
                self.render_node(
                    &format!("{path}.{index}"),
                    child,
                    parent_scroll_handle.clone(),
                    window,
                    cx,
                )
            })
            .collect()
    }

    pub fn retain_scroll_handle(&mut self, node_id: &str) -> ScrollHandle {
        self.state.live_scroll_ids.insert(node_id.to_owned());
        self.retained
            .scroll_handles
            .entry(node_id.to_owned())
            .or_default()
            .clone()
    }

    pub fn ensure_focus_handle(
        &mut self,
        node_id: &str,
        cx: &mut Context<BridgeView>,
        tab_stop: Option<bool>,
        tab_index: Option<isize>,
    ) -> FocusHandle {
        self.state.live_focus_ids.insert(node_id.to_owned());

        let handle = self
            .retained
            .focus_handles
            .entry(node_id.to_owned())
            .or_insert_with(|| cx.focus_handle())
            .clone();

        let handle = match tab_stop {
            Some(tab_stop) => handle.tab_stop(tab_stop),
            None => handle,
        };

        match tab_index {
            Some(tab_index) => handle.tab_index(tab_index),
            None => handle,
        }
    }

    pub fn register_focus_callbacks(
        &mut self,
        node_id: &str,
        focus_handle: &FocusHandle,
        focus: Option<&str>,
        blur: Option<&str>,
        window: &mut Window,
        cx: &mut Context<BridgeView>,
    ) {
        let Some(_) = focus.or(blur) else {
            return;
        };

        if self.state.registered_focus_callbacks.contains(node_id) {
            return;
        }

        let view_id = self.view_id;

        if let Some(callback_id) = focus {
            let focus_node_id = node_id.to_owned();
            let callback_id = callback_id.to_owned();
            let subscription = cx.on_focus(focus_handle, window, move |_, _, _| {
                events::emit_focus(view_id, &focus_node_id, &callback_id);
            });
            self.retained.focus_subscriptions.push(subscription);
        }

        if let Some(callback_id) = blur {
            let blur_node_id = node_id.to_owned();
            let callback_id = callback_id.to_owned();
            let subscription = cx.on_blur(focus_handle, window, move |_, _, _| {
                events::emit_blur(view_id, &blur_node_id, &callback_id);
            });
            self.retained.focus_subscriptions.push(subscription);
        }

        self.state
            .registered_focus_callbacks
            .insert(node_id.to_owned());
    }

    pub fn mark_text_input_live(&mut self, node_id: &str) {
        self.state.live_text_input_ids.insert(node_id.to_owned());
    }

    pub fn text_input_entity(&mut self, node_id: &str) -> Option<Entity<BridgeTextInput>> {
        self.retained.text_inputs.get(node_id).cloned()
    }

    pub fn insert_text_input_entity(&mut self, node_id: &str, entity: Entity<BridgeTextInput>) {
        self.retained.text_inputs.insert(node_id.to_owned(), entity);
    }
}

#[cfg(test)]
mod tests {
    use super::RenderPass;
    use crate::{bridge_view::BridgeView, ir::IrNode};

    #[gpui::test]
    fn register_focus_callbacks_dedupes_per_node(cx: &mut gpui::TestAppContext) {
        let (view, cx) = cx.add_window_view(|_, _| BridgeView {
            view_id: 7,
            ir: IrNode::text("hello"),
            retained: Default::default(),
        });

        view.update_in(cx, |view, window, view_cx| {
            let focus_handle = view_cx.focus_handle();
            let mut pass = RenderPass::new(view.view_id, &mut view.retained);

            pass.register_focus_callbacks(
                "field",
                &focus_handle,
                Some("focused"),
                Some("blurred"),
                window,
                view_cx,
            );
            pass.register_focus_callbacks(
                "field",
                &focus_handle,
                Some("focused"),
                Some("blurred"),
                window,
                view_cx,
            );

            let state = pass.finish();

            assert_eq!(view.retained.focus_subscriptions.len(), 2);
            assert!(state.registered_focus_callbacks.contains("field"));
        });
    }
}
