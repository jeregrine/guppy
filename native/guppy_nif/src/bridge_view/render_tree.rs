use super::{events, identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::{
    bridge_view::BridgeView,
    ir::{TreeItem, TreeNode},
};
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, ParentElement, SharedString,
    StatefulInteractiveElement, Styled, Window, div, list,
};
use std::sync::Arc;

const SELECT_EVENT: i32 = 1;
const TOGGLE_EVENT: i32 = 2;

#[derive(Clone, Debug, PartialEq, Eq)]
struct VisibleTreeItem {
    id: String,
    label: String,
    depth: usize,
    expanded: bool,
    has_children: bool,
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    tree: &TreeNode,
    _window: &mut Window,
    _cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, tree.id.as_deref());
    let tree_id = node_id.to_string();
    let visible_items: Arc<[VisibleTreeItem]> = flatten_visible_tree_items(&tree.nodes).into();
    let state = pass.retain_list_state(&format!("{tree_id}.rows"), visible_items.len());
    let row_style = tree.row_style.clone();
    let select = tree.select.clone();
    let toggle = tree.toggle.clone();
    let tree_id_for_rows = tree_id.clone();

    let rows = list(state, move |index, _window, _cx| {
        visible_items
            .get(index)
            .map(|item| {
                render_row(
                    view_id,
                    &tree_id_for_rows,
                    item,
                    &row_style,
                    select.as_deref(),
                    toggle.as_deref(),
                )
            })
            .unwrap_or_else(|| div().into_any_element())
    })
    .size_full();

    apply_div_style(
        div()
            .id(node_id.to_shared_string())
            .flex()
            .flex_col()
            .size_full()
            .child(rows),
        &tree.style,
    )
    .into_any_element()
}

fn flatten_visible_tree_items(items: &[TreeItem]) -> Vec<VisibleTreeItem> {
    let mut visible = Vec::new();
    collect_visible_tree_items(items, 0, &mut visible);
    visible
}

fn collect_visible_tree_items(
    items: &[TreeItem],
    depth: usize,
    visible: &mut Vec<VisibleTreeItem>,
) {
    for item in items {
        let has_children = !item.children.is_empty();
        visible.push(VisibleTreeItem {
            id: item.id.clone(),
            label: item.label.clone(),
            depth,
            expanded: item.expanded,
            has_children,
        });

        if item.expanded {
            collect_visible_tree_items(&item.children, depth + 1, visible);
        }
    }
}

fn render_row(
    view_id: u64,
    tree_id: &str,
    item: &VisibleTreeItem,
    row_style: &crate::ir::DivStyle,
    select: Option<&str>,
    toggle: Option<&str>,
) -> AnyElement {
    let row_id = format!("{tree_id}.row.{}", item.id);
    let disclosure_id = format!("{row_id}.toggle");
    let label_id = format!("{row_id}.label");
    let indent = "  ".repeat(item.depth);
    let marker = if item.has_children {
        if item.expanded { "▾" } else { "▸" }
    } else {
        "•"
    };

    let mut disclosure = div()
        .id(SharedString::from(disclosure_id.clone()))
        .p_2()
        .child(format!("{indent}{marker}"));

    if item.has_children
        && let Some(callback_id) = toggle
    {
        let callback_id = callback_id.to_owned();
        let tree_id = tree_id.to_owned();
        let item_id = item.id.clone();
        disclosure = disclosure.on_click(move |_, _, _| {
            events::emit_tree_event(
                view_id,
                TOGGLE_EVENT,
                &disclosure_id,
                &callback_id,
                &tree_id,
                &item_id,
            );
        });
    }

    let mut label = div()
        .id(SharedString::from(label_id.clone()))
        .p_2()
        .flex_1()
        .child(item.label.clone());

    if let Some(callback_id) = select {
        let callback_id = callback_id.to_owned();
        let tree_id = tree_id.to_owned();
        let item_id = item.id.clone();
        label = label.on_click(move |_, _, _| {
            events::emit_tree_event(
                view_id,
                SELECT_EVENT,
                &label_id,
                &callback_id,
                &tree_id,
                &item_id,
            );
        });
    }

    apply_div_style(
        div()
            .id(SharedString::from(row_id))
            .flex()
            .flex_row()
            .children([disclosure.into_any_element(), label.into_any_element()]),
        row_style,
    )
    .into_any_element()
}

#[cfg(test)]
mod tests {
    use super::{SELECT_EVENT, TOGGLE_EVENT, flatten_visible_tree_items};
    use crate::{bridge_view::events, ir::TreeItem};

    #[test]
    fn flatten_visible_tree_items_only_includes_expanded_descendants() {
        let visible = flatten_visible_tree_items(&[
            TreeItem {
                id: "open".into(),
                label: "Open".into(),
                expanded: true,
                style: Vec::new().into(),
                children: vec![TreeItem {
                    id: "child".into(),
                    label: "Child".into(),
                    expanded: false,
                    style: Vec::new().into(),
                    children: Vec::new(),
                }],
            },
            TreeItem {
                id: "closed".into(),
                label: "Closed".into(),
                expanded: false,
                style: Vec::new().into(),
                children: vec![TreeItem {
                    id: "hidden".into(),
                    label: "Hidden".into(),
                    expanded: false,
                    style: Vec::new().into(),
                    children: Vec::new(),
                }],
            },
        ]);

        assert_eq!(
            visible
                .iter()
                .map(|item| item.id.as_str())
                .collect::<Vec<_>>(),
            ["open", "child", "closed"]
        );
        assert_eq!(visible[1].depth, 1);
        assert!(visible[0].has_children);
    }

    #[test]
    fn tree_events_include_semantic_identity() {
        events::emit_tree_event(
            9,
            SELECT_EVENT,
            "tree.row.child.label",
            "select_node",
            "tree",
            "child",
        );
        let event = crate::take_semantic_event_snapshot_for_test().unwrap();
        assert_eq!(event.event, "tree_select");
        assert_eq!(event.view_id, 9);
        assert_eq!(event.tree_id.as_deref(), Some("tree"));
        assert_eq!(event.item_id.as_deref(), Some("child"));

        events::emit_tree_event(
            9,
            TOGGLE_EVENT,
            "tree.row.child.toggle",
            "toggle_node",
            "tree",
            "child",
        );
        let event = crate::take_semantic_event_snapshot_for_test().unwrap();
        assert_eq!(event.event, "tree_toggle");
        assert_eq!(event.tree_id.as_deref(), Some("tree"));
        assert_eq!(event.item_id.as_deref(), Some("child"));
    }
}
