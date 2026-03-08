use super::{identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::bridge_view::BridgeView;
use crate::ir::{DivStyle, IrNode, ScrollAxis};
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, ParentElement,
    StatefulInteractiveElement, Window, div,
};

pub(crate) struct ScrollSpec<'a> {
    pub path: &'a str,
    pub id: Option<&'a str>,
    pub axis: ScrollAxis,
    pub style: &'a DivStyle,
    pub children: &'a [IrNode],
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    spec: ScrollSpec<'_>,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let node_id = NodeIdentity::new(pass.view_id(), spec.path, spec.id);
    let scroll_handle = pass.retain_scroll_handle(node_id.as_ref());
    let child_elements = pass.render_children(
        spec.path,
        spec.children,
        Some(scroll_handle.clone()),
        window,
        cx,
    );

    let element = apply_div_style(
        div()
            .id(node_id.to_shared_string())
            .children(child_elements)
            .track_scroll(&scroll_handle),
        spec.style,
    );

    let element = match spec.axis {
        ScrollAxis::X => element.overflow_x_scroll(),
        ScrollAxis::Y => element.overflow_y_scroll(),
        ScrollAxis::Both => element.overflow_scroll(),
    };

    element.into_any_element()
}
