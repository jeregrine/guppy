use super::{identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::ir::{DivStyle, UniformListItem};
use gpui::{
    AnyElement, InteractiveElement, IntoElement, ParentElement, SharedString,
    StatefulInteractiveElement, Styled, div, uniform_list,
};
use std::sync::Arc;

unsafe extern "C" {
    fn guppy_c_send_click_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
    ) -> i32;
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    id: Option<&str>,
    items: &Arc<[UniformListItem]>,
    style: &DivStyle,
    item_style: &DivStyle,
    click: Option<&str>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, id);
    let list_key = node_id.to_string();
    let element_id = node_id.to_shared_string();
    let items = items.clone();
    let item_style = item_style.clone();
    let click = click.map(str::to_owned);
    let item_list_key = list_key.clone();

    let list = uniform_list(element_id, items.len(), move |range, _window, _cx| {
        range
            .filter_map(|index| items.get(index).cloned())
            .map(|item| render_item(view_id, &item_list_key, item, &item_style, click.as_deref()))
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

fn render_item(
    view_id: u64,
    list_key: &str,
    item: UniformListItem,
    item_style: &DivStyle,
    click: Option<&str>,
) -> AnyElement {
    let item_key = format!("{list_key}.{}", item.id);
    let mut row = apply_div_style(
        div()
            .id(SharedString::from(item_key.clone()))
            .w_full()
            .px_2()
            .py_2()
            .child(item.label),
        item_style,
    );

    if let Some(callback_id) = click {
        let callback_id = callback_id.to_owned();
        row = row.on_click(move |_, _, _| {
            emit_item_click(view_id, &item_key, &callback_id);
        });
    }

    row.into_any_element()
}

fn emit_item_click(view_id: u64, node_id: &str, callback_id: &str) {
    // SAFETY: the FFI call copies the provided string bytes before returning; node_id and
    // callback_id are valid Rust string slices for the duration of the call.
    unsafe {
        let _ = guppy_c_send_click_event(
            view_id,
            node_id.as_ptr(),
            node_id.len(),
            callback_id.as_ptr(),
            callback_id.len(),
        );
    }
}

#[cfg(test)]
mod tests {
    use super::render_item;
    use crate::ir::UniformListItem;

    #[test]
    fn render_item_accepts_stable_item_identity() {
        let item = UniformListItem {
            id: "item_1".into(),
            label: "Item 1".into(),
        };
        let _ = render_item(1, "list", item, &Vec::new().into(), Some("clicked"));
    }
}
