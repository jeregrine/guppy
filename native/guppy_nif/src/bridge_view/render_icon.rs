use super::{identity::NodeIdentity, render_pass::RenderPass};
use crate::bridge_view::render_image;
use crate::ir::{DivStyle, ImageObjectFit, ImageSource};
use gpui::AnyElement;

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    id: Option<&str>,
    source: &ImageSource,
    style: &DivStyle,
) -> AnyElement {
    let node_id = NodeIdentity::new(pass.view_id(), path, id);

    render_image::render(
        pass,
        path,
        Some(node_id.as_ref()),
        source,
        style,
        ImageObjectFit::Contain,
        false,
    )
}
