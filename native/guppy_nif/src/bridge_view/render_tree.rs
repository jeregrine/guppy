use super::{events, identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::{
    bridge_view::BridgeView,
    ir::{DivStyle, TreeItem, TreeNode},
};
use gpui::{
    AnyElement, Context, FocusHandle, InteractiveElement, IntoElement, KeyDownEvent, MouseButton,
    ParentElement, SharedString, StatefulInteractiveElement, Styled, Window, div, list,
};
use std::collections::HashMap;
const SELECT_EVENT: i32 = 1;
const TOGGLE_EVENT: i32 = 2;

#[derive(Clone, Debug, PartialEq)]
struct VisibleTreeItem {
    id: String,
    label: String,
    depth: usize,
    expanded: bool,
    has_children: bool,
    parent_id: Option<String>,
    style: DivStyle,
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    tree: &TreeNode,
    _window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, tree.id.as_deref());
    let tree_id = node_id.to_string();
    let visible_items = flatten_visible_tree_items(&tree.nodes);
    let state = pass.retain_list_state(&format!("{tree_id}.rows"), visible_items.len());
    let row_focus_handles = prepare_row_focus_handles(
        pass,
        &tree_id,
        &visible_items,
        tree.select.is_some() || tree.toggle.is_some() || tree.context_menu.is_some(),
        cx,
    );
    let row_style = tree.row_style.clone();
    let select = tree.select.clone();
    let toggle = tree.toggle.clone();
    let context_menu = tree.context_menu.clone();
    let tree_id_for_rows = tree_id.clone();

    let rows = list(state, move |index, _window, _cx| {
        visible_items
            .get(index)
            .map(|item| {
                let previous_focus = index
                    .checked_sub(1)
                    .and_then(|previous_index| visible_items.get(previous_index))
                    .and_then(|previous_item| row_focus_handles.get(&previous_item.id));
                let next_focus = visible_items
                    .get(index + 1)
                    .and_then(|next_item| row_focus_handles.get(&next_item.id));
                let parent_focus = item
                    .parent_id
                    .as_ref()
                    .and_then(|parent_id| row_focus_handles.get(parent_id));

                render_row(
                    view_id,
                    &tree_id_for_rows,
                    item,
                    &row_style,
                    select.as_deref(),
                    toggle.as_deref(),
                    context_menu.as_deref(),
                    row_focus_handles.get(&item.id),
                    previous_focus,
                    next_focus,
                    parent_focus,
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

fn prepare_row_focus_handles(
    pass: &mut RenderPass<'_>,
    tree_id: &str,
    visible_items: &[VisibleTreeItem],
    keyboard_enabled: bool,
    cx: &mut Context<BridgeView>,
) -> HashMap<String, FocusHandle> {
    if !keyboard_enabled {
        return HashMap::new();
    }

    visible_items
        .iter()
        .map(|item| {
            let row_id = tree_row_id(tree_id, &item.id);
            let focus_handle = pass.ensure_focus_handle(&row_id, cx, Some(true), None);
            (item.id.clone(), focus_handle)
        })
        .collect()
}

fn flatten_visible_tree_items(items: &[TreeItem]) -> Vec<VisibleTreeItem> {
    let mut visible = Vec::new();
    collect_visible_tree_items(items, 0, None, &mut visible);
    visible
}

fn collect_visible_tree_items(
    items: &[TreeItem],
    depth: usize,
    parent_id: Option<&str>,
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
            parent_id: parent_id.map(str::to_owned),
            style: item.style.clone(),
        });

        if item.expanded {
            collect_visible_tree_items(&item.children, depth + 1, Some(&item.id), visible);
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
    context_menu: Option<&str>,
    focus_handle: Option<&FocusHandle>,
    previous_focus: Option<&FocusHandle>,
    next_focus: Option<&FocusHandle>,
    parent_focus: Option<&FocusHandle>,
) -> AnyElement {
    let row_id = tree_row_id(tree_id, &item.id);
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

    let mut row = div()
        .id(SharedString::from(row_id.clone()))
        .flex()
        .flex_row()
        .children([disclosure.into_any_element(), label.into_any_element()]);

    if let Some(handle) = focus_handle {
        let focus_handle = handle.clone();
        row = row
            .track_focus(&focus_handle)
            .focusable()
            .on_any_mouse_down(move |_, window, _| {
                focus_handle.focus(window);
            });
    }

    if select.is_some() || (item.has_children && toggle.is_some()) || context_menu.is_some() {
        let select_callback = select.map(str::to_owned);
        let toggle_callback = toggle.map(str::to_owned);
        let context_menu_callback = context_menu.map(str::to_owned);
        let key_tree_id = tree_id.to_owned();
        let key_item_id = item.id.clone();
        let key_row_id = row_id.clone();
        let item = item.clone();
        let previous_focus = previous_focus.cloned();
        let next_focus = next_focus.cloned();
        let parent_focus = parent_focus.cloned();
        row = row.on_key_down(move |event: &KeyDownEvent, window, cx| {
            match event.keystroke.key.as_str() {
                "up" => {
                    if let Some(handle) = previous_focus.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "down" => {
                    if let Some(handle) = next_focus.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "left" if !(item.has_children && item.expanded) => {
                    if let Some(handle) = parent_focus.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                _ => {}
            }

            if let Some(callback_id) = context_menu_callback.as_deref()
                && events::is_context_menu_key(event)
            {
                events::emit_tree_keyboard_context_menu(
                    view_id,
                    &key_row_id,
                    callback_id,
                    &key_tree_id,
                    &key_item_id,
                    event,
                );
                cx.stop_propagation();
                return;
            }

            match tree_keyboard_action(
                event,
                &item,
                select_callback.as_deref(),
                toggle_callback.as_deref(),
            ) {
                Some(TreeKeyboardAction::Select(callback_id)) => {
                    events::emit_tree_event(
                        view_id,
                        SELECT_EVENT,
                        &key_row_id,
                        callback_id,
                        &key_tree_id,
                        &key_item_id,
                    );
                    cx.stop_propagation();
                }
                Some(TreeKeyboardAction::Toggle(callback_id)) => {
                    events::emit_tree_event(
                        view_id,
                        TOGGLE_EVENT,
                        &key_row_id,
                        callback_id,
                        &key_tree_id,
                        &key_item_id,
                    );
                    cx.stop_propagation();
                }
                None => {}
            }
        });
    }

    if let Some(callback_id) = context_menu {
        let callback_id = callback_id.to_owned();
        let tree_id = tree_id.to_owned();
        let item_id = item.id.clone();
        row = row.on_mouse_down(MouseButton::Right, move |event, _, _| {
            events::emit_tree_context_menu(
                view_id,
                &row_id,
                &callback_id,
                &tree_id,
                &item_id,
                event,
            );
        });
    }

    apply_tree_row_styles(row, row_style, &item.style).into_any_element()
}

fn tree_row_id(tree_id: &str, item_id: &str) -> String {
    format!("{tree_id}.row.{item_id}")
}

#[derive(Debug, PartialEq, Eq)]
enum TreeKeyboardAction<'a> {
    Select(&'a str),
    Toggle(&'a str),
}

fn tree_keyboard_action<'a>(
    event: &KeyDownEvent,
    item: &VisibleTreeItem,
    select: Option<&'a str>,
    toggle: Option<&'a str>,
) -> Option<TreeKeyboardAction<'a>> {
    match event.keystroke.key.as_str() {
        "enter" => select.map(TreeKeyboardAction::Select),
        "space" if item.has_children => toggle.map(TreeKeyboardAction::Toggle),
        "right" if item.has_children && !item.expanded => toggle.map(TreeKeyboardAction::Toggle),
        "left" if item.has_children && item.expanded => toggle.map(TreeKeyboardAction::Toggle),
        _ => None,
    }
}

fn apply_tree_row_styles<E>(element: E, row_style: &DivStyle, item_style: &DivStyle) -> E
where
    E: Styled + StatefulInteractiveElement,
{
    let element = apply_div_style(element, row_style);
    apply_div_style(element, item_style)
}

#[cfg(test)]
mod tests {
    use super::{SELECT_EVENT, TOGGLE_EVENT, apply_tree_row_styles, flatten_visible_tree_items};
    use crate::{
        bridge_view::events,
        ir::{StyleOp, TreeItem},
    };
    use gpui::{InteractiveElement, SharedString, Styled, div};

    #[test]
    fn flatten_visible_tree_items_carries_item_style_for_row_rendering() {
        let visible = flatten_visible_tree_items(&[TreeItem {
            id: "styled".into(),
            label: "Styled".into(),
            expanded: false,
            style: vec![StyleOp::Opacity(0.75)].into(),
            children: Vec::new().into(),
        }]);

        assert_eq!(visible[0].style.as_ref(), [StyleOp::Opacity(0.75)]);
    }

    #[test]
    fn tree_row_styles_apply_row_style_then_item_style() {
        let row_style = vec![StyleOp::Opacity(0.25)].into();
        let item_style = vec![StyleOp::Opacity(0.75)].into();
        let mut row = apply_tree_row_styles(
            div().id(SharedString::from("tree.row.styled")),
            &row_style,
            &item_style,
        );

        assert_eq!(row.style().opacity, Some(0.75));
    }

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
                    children: Vec::new().into(),
                }]
                .into(),
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
                    children: Vec::new().into(),
                }]
                .into(),
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
        assert_eq!(visible[1].parent_id.as_deref(), Some("open"));
        assert!(visible[0].has_children);
    }

    #[test]
    fn tree_events_include_semantic_identity() {
        use gpui::{Modifiers, MouseButton, MouseDownEvent, point, px};

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

        events::emit_tree_context_menu(
            9,
            "tree.row.child",
            "tree_context_menu",
            "tree",
            "child",
            &MouseDownEvent {
                position: point(px(12.0), px(8.0)),
                modifiers: Modifiers::none(),
                button: MouseButton::Right,
                click_count: 1,
                first_mouse: false,
            },
        );

        let event = crate::take_semantic_event_snapshot_for_test().unwrap();
        assert_eq!(event.event, "context_menu");
        assert_eq!(event.tree_id.as_deref(), Some("tree"));
        assert_eq!(event.item_id.as_deref(), Some("child"));
    }
}
