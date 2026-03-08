use super::{events, identity::NodeIdentity, render_pass::RenderPass};
use gpui::{AnyElement, InteractiveText, IntoElement, StyledText};

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    id: Option<&str>,
    content: &str,
    click: Option<&str>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, id);
    let interactive_text = InteractiveText::new(
        node_id.to_shared_string(),
        StyledText::new(content.to_owned()),
    );

    match click {
        Some(callback_id) if !content.is_empty() => {
            let callback_id = callback_id.to_owned();
            let click_node_id = node_id.to_string();
            let clickable_ranges = std::iter::once(0..content.len()).collect::<Vec<_>>();

            interactive_text
                .on_click(clickable_ranges, move |_, _, _| {
                    events::emit_click(view_id, &click_node_id, &callback_id);
                })
                .into_any_element()
        }
        _ => interactive_text.into_any_element(),
    }
}
