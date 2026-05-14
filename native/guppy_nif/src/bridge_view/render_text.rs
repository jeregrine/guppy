use super::{
    events,
    identity::NodeIdentity,
    render_pass::RenderPass,
    style::{apply_div_style, style_ops_to_highlight_style},
};
use crate::ir::{DivStyle, TextRunSegment};
use gpui::{
    AnyElement, HighlightStyle, InteractiveElement, InteractiveText, IntoElement, ParentElement,
    SharedString, StyledText, div,
};
use std::ops::Range;

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    id: Option<&str>,
    content: &str,
    runs: &[TextRunSegment],
    style: &DivStyle,
    click: Option<&str>,
) -> AnyElement {
    render_with_view_id(pass.view_id(), path, id, content, runs, style, click)
}

pub(crate) fn render_with_view_id(
    view_id: u64,
    path: &str,
    id: Option<&str>,
    content: &str,
    runs: &[TextRunSegment],
    style: &DivStyle,
    click: Option<&str>,
) -> AnyElement {
    let node_id = NodeIdentity::new(view_id, path, id);
    let interactive_text =
        InteractiveText::new(node_id.to_shared_string(), styled_text(content, runs));

    let element = match click {
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
    };

    if style.is_empty() {
        element
    } else {
        apply_div_style(
            div().id(SharedString::from(format!("{}::text_style", node_id))),
            style,
        )
        .child(element)
        .into_any_element()
    }
}

pub(crate) fn styled_text(content: &str, runs: &[TextRunSegment]) -> StyledText {
    let styled = StyledText::new(content.to_owned());

    if runs.is_empty() {
        styled
    } else {
        styled.with_highlights(rich_text_highlights(runs))
    }
}

pub(crate) fn rich_text_highlights(runs: &[TextRunSegment]) -> Vec<(Range<usize>, HighlightStyle)> {
    let mut offset = 0;
    runs.iter()
        .map(|run| {
            let start = offset;
            offset += run.text.len();
            (start..offset, style_ops_to_highlight_style(&run.style))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::rich_text_highlights;
    use crate::ir::{ColorToken, StyleOp, TextRunSegment};

    #[test]
    fn rich_text_highlights_preserve_utf8_byte_ranges() {
        let runs = vec![
            TextRunSegment {
                text: "Hi ".into(),
                style: vec![StyleOp::FontBold].into(),
            },
            TextRunSegment {
                text: "é".into(),
                style: vec![StyleOp::TextColor(ColorToken::Yellow)].into(),
            },
        ];

        let highlights = rich_text_highlights(&runs);

        assert_eq!(highlights[0].0, 0..3);
        assert_eq!(highlights[1].0, 3..5);
        assert!(highlights[0].1.font_weight.is_some());
        assert!(highlights[1].1.color.is_some());
    }
}
