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

#[cfg(test)]
mod tests {
    use super::{image_source, to_gpui_object_fit};
    use crate::ir::{ImageObjectFit, ImageSource};
    use gpui::{ObjectFit, Resource};

    #[test]
    fn maps_image_sources_to_gpui_resources() {
        match image_source(&ImageSource::Uri("https://example.com/logo.svg".into())) {
            gpui::ImageSource::Resource(Resource::Uri(uri)) => {
                assert_eq!(uri.to_string(), "https://example.com/logo.svg")
            }
            _ => panic!("expected uri resource"),
        }

        match image_source(&ImageSource::Path("/tmp/logo.png".into())) {
            gpui::ImageSource::Resource(Resource::Path(path)) => {
                assert_eq!(path.to_string_lossy(), "/tmp/logo.png")
            }
            _ => panic!("expected path resource"),
        }

        match image_source(&ImageSource::Embedded("icons/release.svg".into())) {
            gpui::ImageSource::Resource(Resource::Embedded(path)) => {
                assert_eq!(path.as_ref(), "icons/release.svg")
            }
            _ => panic!("expected embedded resource"),
        }
    }

    #[test]
    fn maps_image_object_fit_to_gpui_object_fit() {
        assert!(matches!(
            to_gpui_object_fit(ImageObjectFit::Fill),
            ObjectFit::Fill
        ));
        assert!(matches!(
            to_gpui_object_fit(ImageObjectFit::Contain),
            ObjectFit::Contain
        ));
        assert!(matches!(
            to_gpui_object_fit(ImageObjectFit::Cover),
            ObjectFit::Cover
        ));
        assert!(matches!(
            to_gpui_object_fit(ImageObjectFit::ScaleDown),
            ObjectFit::ScaleDown
        ));
        assert!(matches!(
            to_gpui_object_fit(ImageObjectFit::None),
            ObjectFit::None
        ));
    }
}
