use super::{identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::ir::{DivStyle, ImageObjectFit, ImageSource};
use gpui::{AnyElement, InteractiveElement, IntoElement, ObjectFit, StyledImage, img};
use std::path::PathBuf;

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    id: Option<&str>,
    source: &ImageSource,
    style: &DivStyle,
    object_fit: ImageObjectFit,
    grayscale: bool,
) -> AnyElement {
    let node_id = NodeIdentity::new(pass.view_id(), path, id);

    let element = apply_div_style(
        img(image_source(source))
            .id(node_id.to_shared_string())
            .object_fit(to_gpui_object_fit(object_fit))
            .grayscale(grayscale),
        style,
    );

    element.into_any_element()
}

fn image_source(source: &ImageSource) -> gpui::ImageSource {
    match source {
        ImageSource::Auto(value) => value.clone().into(),
        ImageSource::Uri(value) => {
            gpui::ImageSource::Resource(gpui::Resource::Uri(value.clone().into()))
        }
        ImageSource::Path(value) => {
            gpui::ImageSource::Resource(gpui::Resource::Path(PathBuf::from(value).into()))
        }
        ImageSource::Embedded(value) => {
            gpui::ImageSource::Resource(gpui::Resource::Embedded(value.clone().into()))
        }
    }
}

fn to_gpui_object_fit(object_fit: ImageObjectFit) -> ObjectFit {
    match object_fit {
        ImageObjectFit::Fill => ObjectFit::Fill,
        ImageObjectFit::Contain => ObjectFit::Contain,
        ImageObjectFit::Cover => ObjectFit::Cover,
        ImageObjectFit::ScaleDown => ObjectFit::ScaleDown,
        ImageObjectFit::None => ObjectFit::None,
    }
}
