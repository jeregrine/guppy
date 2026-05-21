use super::{
    events,
    identity::NodeIdentity,
    render_pass::RenderPass,
    style::{apply_div_style, apply_semantic_focus_visible_affordance},
};
use crate::{
    bridge_view::BridgeView,
    ir::{DivStyle, UniformListItem},
    native_events,
};
use gpui::{
    AnyElement, Context, FocusHandle, InteractiveElement, IntoElement, KeyDownEvent, MouseButton,
    ParentElement, SharedString, StatefulInteractiveElement, Styled, Window, div, uniform_list,
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
                let previous_focus = index
                    .checked_sub(1)
                    .and_then(|previous_index| items.get(previous_index))
                    .and_then(|previous_item| focus_handles.get(&previous_item.id));
                let next_focus = items
                    .get(index + 1)
                    .and_then(|next_item| focus_handles.get(&next_item.id));

                Some(render_item(
                    view_id,
                    &item_list_key,
                    item,
                    &item_style,
                    click.as_deref(),
                    context_menu.as_deref(),
                    focus_handles.get(&item.id),
                    previous_focus,
                    next_focus,
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
    if !keyboard_enabled {
        return HashMap::new();
    }

    items
        .iter()
        .map(|item| {
            let item_key = uniform_item_id(list_key, &item.id);
            let focus_handle = pass.ensure_focus_handle(&item_key, cx, Some(true), None);
            (item.id.clone(), focus_handle)
        })
        .collect()
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
    previous_focus: Option<&FocusHandle>,
    next_focus: Option<&FocusHandle>,
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

    if click.is_some() || context_menu.is_some() {
        let click_callback = click.map(str::to_owned);
        let context_menu_callback = context_menu.map(str::to_owned);
        let key_item_key = item_key.clone();
        let previous_focus = previous_focus.cloned();
        let next_focus = next_focus.cloned();
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
                _ => {}
            }

            if let Some(callback_id) = context_menu_callback.as_deref()
                && events::is_context_menu_key(event)
            {
                events::emit_keyboard_context_menu(view_id, &key_item_key, callback_id, event);
                cx.stop_propagation();
                return;
            }

            if let Some(callback_id) = click_callback.as_deref()
                && is_activation_key(event)
            {
                emit_item_click(view_id, &key_item_key, callback_id);
                cx.stop_propagation();
            }
        });
    }

    if let Some(callback_id) = click {
        let callback_id = callback_id.to_owned();
        let click_item_key = item_key.clone();
        row = row.on_click(move |_, _, _| {
            emit_item_click(view_id, &click_item_key, &callback_id);
        });
    }

    if let Some(callback_id) = context_menu {
        let callback_id = callback_id.to_owned();
        let context_item_key = item_key.clone();
        row = row.on_mouse_down(MouseButton::Right, move |event, _, _| {
            events::emit_context_menu(view_id, &context_item_key, &callback_id, event);
        });
    }

    apply_semantic_focus_visible_affordance(row, show_focus_visible).into_any_element()
}

fn uniform_item_id(list_key: &str, item_id: &str) -> String {
    format!("{list_key}.{item_id}")
}

fn is_activation_key(event: &KeyDownEvent) -> bool {
    if event.is_held {
        return false;
    }

    matches!(event.keystroke.key.as_str(), "enter" | "space")
}

fn emit_item_click(view_id: u64, node_id: &str, callback_id: &str) {
    let _ = native_events::send_click_event(view_id, node_id, callback_id);
}

#[cfg(test)]
mod tests {
    use super::uniform_item_id;

    #[test]
    fn uniform_item_ids_are_stable() {
        assert_eq!(uniform_item_id("list", "item_1"), "list.item_1");
    }
}
