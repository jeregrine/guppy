use super::{
    identity::NodeIdentity,
    render_pass::RenderPass,
    roving,
    style::{apply_div_style, apply_semantic_focus_visible_affordance},
};
use crate::{
    bridge_view::BridgeView,
    ir::{DivStyle, UniformListItem},
};
use gpui::{
    AnyElement, Context, FocusHandle, InteractiveElement, IntoElement, ParentElement, SharedString,
    StatefulInteractiveElement, Styled, Window, div, uniform_list,
};
use std::{collections::HashMap, sync::Arc};

#[allow(clippy::too_many_arguments)]
pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    id: Option<&str>,
    items: &Arc<[UniformListItem]>,
    style: &DivStyle,
    item_style: &DivStyle,
    click: Option<&str>,
    context_menu: Option<&str>,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, id);
    let list_key = node_id.to_string();
    let element_id = node_id.to_shared_string();
    let focus_handles = prepare_item_focus_handles(
        pass,
        &list_key,
        items.as_ref(),
        click.is_some() || context_menu.is_some(),
        cx,
    );
    let focus_visible = pass.focus_visible();
    let items = items.clone();
    let item_style = item_style.clone();
    let click = click.map(str::to_owned);
    let context_menu = context_menu.map(str::to_owned);
    let item_list_key = list_key.clone();

    let list = uniform_list(element_id, items.len(), move |range, window, _cx| {
        range
            .filter_map(|index| {
                let item = items.get(index)?;
                let targets =
                    roving::vertical_neighbors(&items, index, &focus_handles, |item| &item.id);

                Some(render_item(
                    view_id,
                    &item_list_key,
                    item,
                    &item_style,
                    click.as_deref(),
                    context_menu.as_deref(),
                    focus_handles.get(&item.id),
                    targets,
                    focus_visible,
                    window,
                ))
            })
            .collect::<Vec<_>>()
    })
    .size_full();

    apply_div_style(
        div()
            .id(SharedString::from(format!("{list_key}.wrapper")))
            .child(list),
        style,
    )
    .into_any_element()
}

fn prepare_item_focus_handles(
    pass: &mut RenderPass<'_>,
    list_key: &str,
    items: &[UniformListItem],
    keyboard_enabled: bool,
    cx: &mut Context<BridgeView>,
) -> HashMap<String, FocusHandle> {
    roving::prepare_focus_handles(
        pass,
        cx,
        keyboard_enabled,
        items
            .iter()
            .map(|item| (item.id.clone(), uniform_item_id(list_key, &item.id)))
            .collect::<Vec<_>>(),
    )
}

#[allow(clippy::too_many_arguments)]
fn render_item(
    view_id: u64,
    list_key: &str,
    item: &UniformListItem,
    item_style: &DivStyle,
    click: Option<&str>,
    context_menu: Option<&str>,
    focus_handle: Option<&FocusHandle>,
    targets: roving::NavigationTargets,
    focus_visible: bool,
    window: &Window,
) -> AnyElement {
    let item_key = uniform_item_id(list_key, &item.id);
    let mut row = apply_div_style(
        div()
            .id(SharedString::from(item_key.clone()))
            .w_full()
            .px_2()
            .py_2()
            .child(item.label.clone()),
        item_style,
    );
    let show_focus_visible =
        focus_visible && focus_handle.is_some_and(|handle| handle.is_focused(window));

    if let Some(handle) = focus_handle {
        let focus_handle = handle.clone();
        row = row
            .track_focus(&focus_handle)
            .focusable()
            .on_any_mouse_down(move |_, window, _| {
                focus_handle.focus(window);
            });
    }

    row = roving::attach_row_interactions(
        row,
        roving::RowInteractionSpec {
            view_id,
            row_key: &item_key,
            click,
            context_menu,
            targets,
        },
    );

    apply_semantic_focus_visible_affordance(row, show_focus_visible).into_any_element()
}

fn uniform_item_id(list_key: &str, item_id: &str) -> String {
    format!("{list_key}.{item_id}")
}

#[cfg(test)]
mod tests {
    use super::uniform_item_id;

    #[test]
    fn uniform_item_ids_are_stable() {
        assert_eq!(uniform_item_id("list", "item_1"), "list.item_1");
    }
}
