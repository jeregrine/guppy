use super::{identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::ir::DivStyle;
use gpui::{AnyElement, InteractiveElement, IntoElement, div};

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    id: Option<&str>,
    style: &DivStyle,
) -> AnyElement {
    let node_id = NodeIdentity::new(pass.view_id(), path, id);

    apply_div_style(div().id(node_id.to_shared_string()), style).into_any_element()
}
