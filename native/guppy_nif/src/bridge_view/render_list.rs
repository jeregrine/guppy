use super::{events, identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::ir::{DivNode, DivStyle, IrNode, ListItem};
use gpui::{
    AnyElement, InteractiveElement, InteractiveText, IntoElement, ParentElement, SharedString,
    StatefulInteractiveElement, Styled, StyledText, div, list,
};
use std::sync::Arc;

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    id: Option<&str>,
    items: &[ListItem],
    style: &DivStyle,
    item_style: &DivStyle,
    click: Option<&str>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, id);
    let list_key = node_id.to_string();
    let state = pass.retain_list_state(&list_key, items.len());
    let items: Arc<[ListItem]> = items.to_vec().into();
    let item_style = item_style.clone();
    let click = click.map(str::to_owned);
    let item_list_key = list_key.clone();

    let list = list(state, move |index, _window, _cx| {
        items
            .get(index)
            .cloned()
            .map(|item| render_item(view_id, &item_list_key, item, &item_style, click.as_deref()))
            .unwrap_or_else(|| div().into_any_element())
    });

    apply_div_style(
        div()
            .id(SharedString::from(format!("{list_key}.wrapper")))
            .child(list),
        style,
    )
    .into_any_element()
}

fn render_item(
    view_id: u64,
    list_key: &str,
    item: ListItem,
    item_style: &DivStyle,
    click: Option<&str>,
) -> AnyElement {
    let item_key = format!("{list_key}.{}", item.id);
    let children =
        item.children.iter().enumerate().map(|(index, child)| {
            render_static_node(view_id, &format!("{item_key}.{index}"), child)
        });

    let mut row = apply_div_style(
        div()
            .id(SharedString::from(item_key.clone()))
            .w_full()
            .children(children),
        item_style,
    );

    if let Some(callback_id) = click {
        let callback_id = callback_id.to_owned();
        row = row.on_click(move |_, _, _| {
            events::emit_click(view_id, &item_key, &callback_id);
        });
    }

    row.into_any_element()
}

fn render_static_node(view_id: u64, path: &str, ir: &IrNode) -> AnyElement {
    match ir {
        IrNode::Text {
            id,
            content,
            style,
            click,
        } => render_static_text(
            view_id,
            path,
            id.as_deref(),
            content,
            style,
            click.as_deref(),
        ),
        IrNode::Div(node) => render_static_div(view_id, path, node),
        IrNode::Spacer { id, style } => {
            let node_id = NodeIdentity::new(view_id, path, id.as_deref());
            apply_div_style(div().id(node_id.to_shared_string()), style).into_any_element()
        }
        _ => div()
            .id(SharedString::from(format!(
                "guppy-{view_id}-{path}-unsupported"
            )))
            .child("Unsupported list row child")
            .into_any_element(),
    }
}

fn render_static_text(
    view_id: u64,
    path: &str,
    id: Option<&str>,
    content: &str,
    style: &DivStyle,
    click: Option<&str>,
) -> AnyElement {
    let node_id = NodeIdentity::new(view_id, path, id);
    let interactive_text = InteractiveText::new(
        node_id.to_shared_string(),
        StyledText::new(content.to_owned()),
    );

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

fn render_static_div(view_id: u64, path: &str, node: &DivNode) -> AnyElement {
    let node_id = NodeIdentity::new(view_id, path, node.id.as_deref());
    let node_key = node_id.to_string();
    let children = node
        .children
        .iter()
        .enumerate()
        .map(|(index, child)| render_static_node(view_id, &format!("{path}.{index}"), child));

    let mut element = apply_div_style(
        div().id(node_id.to_shared_string()).children(children),
        &node.style,
    );

    if !node.disabled
        && let Some(callback_id) = node.click.as_ref()
    {
        let callback_id = callback_id.clone();
        element = element.on_click(move |_, _, _| {
            events::emit_click(view_id, &node_key, &callback_id);
        });
    }

    element.into_any_element()
}

#[cfg(test)]
mod tests {
    use super::render_item;
    use crate::ir::{DivNode, IrNode, ListItem};

    #[test]
    fn render_item_accepts_nested_row_ir() {
        let item = ListItem {
            id: "item_1".into(),
            children: vec![IrNode::Div(Box::new(DivNode {
                id: Some("item_1_card".into()),
                style: Vec::new().into(),
                hover_style: Vec::new().into(),
                focus_style: Vec::new().into(),
                in_focus_style: Vec::new().into(),
                active_style: Vec::new().into(),
                disabled_style: Vec::new().into(),
                disabled: false,
                stack_priority: None,
                occlude: false,
                focusable: false,
                tab_stop: None,
                tab_index: None,
                track_scroll: false,
                anchor_scroll: false,
                tooltip: None,
                shortcuts: Vec::new(),
                children: vec![IrNode::text("Item 1")],
                click: Some("row_clicked".into()),
                hover: None,
                focus: None,
                blur: None,
                key_down: None,
                key_up: None,
                context_menu: None,
                drag_start: None,
                drag_move: None,
                drop: None,
                mouse_down: None,
                mouse_up: None,
                mouse_move: None,
                scroll_wheel: None,
            }))],
        };

        let _ = render_item(1, "list", item, &Vec::new().into(), Some("clicked"));
    }
}
