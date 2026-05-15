use super::{
    events::{self, RowControlEventContext},
    identity::{NodeIdentity, RowControlKey},
    render_checkbox,
    render_pass::RenderPass,
    render_radio, render_text,
    style::{apply_div_style, apply_refinement_style},
};
use crate::{
    bridge_view::BridgeView,
    ir::{CheckboxNode, DivNode, DivStyle, IrNode, ListItem, RadioNode},
};
use gpui::{
    AnyElement, Context, FocusHandle, InteractiveElement, IntoElement, KeyDownEvent, ParentElement,
    SharedString, StatefulInteractiveElement, Styled, Window, div, list,
};
use std::{collections::HashMap, sync::Arc};

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
struct RowControlLookupKey {
    row_id: String,
    control_id: String,
}

#[derive(Clone)]
struct RowControlRenderState {
    context: RowControlEventContext,
    focus_handle: Option<FocusHandle>,
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    id: Option<&str>,
    items: &Arc<[ListItem]>,
    style: &DivStyle,
    item_style: &DivStyle,
    click: Option<&str>,
    _window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, id);
    let list_key = node_id.to_string();
    let state = pass.retain_list_state(&list_key, items.len());
    let row_controls = prepare_row_control_states(pass, &list_key, items.as_ref(), cx);
    let focus_visible = pass.focus_visible();
    let items = items.clone();
    let item_style = item_style.clone();
    let click = click.map(str::to_owned);
    let item_list_key = list_key.clone();

    let list = list(state, move |index, window, _cx| {
        items
            .get(index)
            .map(|item| {
                render_item(
                    view_id,
                    &item_list_key,
                    item,
                    &item_style,
                    click.as_deref(),
                    &row_controls,
                    focus_visible,
                    window,
                )
            })
            .unwrap_or_else(|| div().into_any_element())
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

fn prepare_row_control_states(
    pass: &mut RenderPass<'_>,
    list_key: &str,
    items: &[ListItem],
    cx: &mut Context<BridgeView>,
) -> HashMap<RowControlLookupKey, RowControlRenderState> {
    let mut states = HashMap::new();

    for item in items {
        collect_row_control_states(pass, list_key, &item.id, &item.children, cx, &mut states);
    }

    states
}

fn collect_row_control_states(
    pass: &mut RenderPass<'_>,
    list_key: &str,
    row_id: &str,
    children: &[IrNode],
    cx: &mut Context<BridgeView>,
    states: &mut HashMap<RowControlLookupKey, RowControlRenderState>,
) {
    for child in children {
        match child {
            IrNode::Button(node) => {
                if let Some(control_id) = node.id.as_deref() {
                    insert_row_control_state(
                        pass,
                        list_key,
                        row_id,
                        control_id,
                        node.disabled,
                        node.tab_index,
                        cx,
                        states,
                    );
                }
            }
            IrNode::Checkbox(node) => {
                if let Some(control_id) = node.id.as_deref() {
                    insert_row_control_state(
                        pass,
                        list_key,
                        row_id,
                        control_id,
                        node.disabled,
                        node.tab_index,
                        cx,
                        states,
                    );
                }
            }
            IrNode::Radio(node) => {
                if let Some(control_id) = node.id.as_deref() {
                    insert_row_control_state(
                        pass,
                        list_key,
                        row_id,
                        control_id,
                        node.disabled,
                        node.tab_index,
                        cx,
                        states,
                    );
                }
            }
            IrNode::Div(node) => {
                collect_row_control_states(pass, list_key, row_id, &node.children, cx, states);
            }
            _ => {}
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn insert_row_control_state(
    pass: &mut RenderPass<'_>,
    list_key: &str,
    row_id: &str,
    control_id: &str,
    disabled: bool,
    tab_index: Option<isize>,
    cx: &mut Context<BridgeView>,
    states: &mut HashMap<RowControlLookupKey, RowControlRenderState>,
) {
    let key = RowControlKey::new(pass.view_id(), list_key, row_id, control_id).to_string();
    let focus_handle = if disabled {
        None
    } else {
        Some(pass.ensure_focus_handle(&key, cx, Some(true), tab_index))
    };

    states.insert(
        row_control_lookup_key(row_id, control_id),
        RowControlRenderState {
            context: RowControlEventContext {
                node_id: key,
                list_id: list_key.to_owned(),
                row_id: row_id.to_owned(),
                control_id: control_id.to_owned(),
            },
            focus_handle,
        },
    );
}

#[allow(clippy::too_many_arguments)]
fn render_item(
    view_id: u64,
    list_key: &str,
    item: &ListItem,
    item_style: &DivStyle,
    click: Option<&str>,
    row_controls: &HashMap<RowControlLookupKey, RowControlRenderState>,
    focus_visible: bool,
    window: &mut Window,
) -> AnyElement {
    let item_key = format!("{list_key}.{}", item.id);
    let children = item.children.iter().enumerate().map(|(index, child)| {
        render_static_node(
            view_id,
            list_key,
            &item.id,
            &format!("{item_key}.{index}"),
            child,
            row_controls,
            focus_visible,
            window,
        )
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

#[allow(clippy::too_many_arguments)]
fn render_static_node(
    view_id: u64,
    list_key: &str,
    row_id: &str,
    path: &str,
    ir: &IrNode,
    row_controls: &HashMap<RowControlLookupKey, RowControlRenderState>,
    focus_visible: bool,
    window: &mut Window,
) -> AnyElement {
    match ir {
        IrNode::Text {
            id,
            content,
            runs,
            style,
            click,
        } => render_text::render_with_view_id(
            view_id,
            path,
            id.as_deref(),
            content,
            runs,
            style,
            click.as_deref(),
        ),
        IrNode::Button(node) => render_row_button(
            view_id,
            row_id,
            path,
            node,
            row_controls,
            focus_visible,
            window,
        ),
        IrNode::Checkbox(node) => {
            render_row_checkbox(view_id, row_id, node, row_controls, focus_visible, window)
        }
        IrNode::Radio(node) => {
            render_row_radio(view_id, row_id, node, row_controls, focus_visible, window)
        }
        IrNode::Div(node) => render_static_div(
            view_id,
            list_key,
            row_id,
            path,
            node,
            row_controls,
            focus_visible,
            window,
        ),
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

#[allow(clippy::too_many_arguments)]
fn render_static_div(
    view_id: u64,
    list_key: &str,
    row_id: &str,
    path: &str,
    node: &DivNode,
    row_controls: &HashMap<RowControlLookupKey, RowControlRenderState>,
    focus_visible: bool,
    window: &mut Window,
) -> AnyElement {
    let node_id = NodeIdentity::new(view_id, path, node.id.as_deref());
    let node_key = node_id.to_string();
    let children = node.children.iter().enumerate().map(|(index, child)| {
        render_static_node(
            view_id,
            list_key,
            row_id,
            &format!("{path}.{index}"),
            child,
            row_controls,
            focus_visible,
            window,
        )
    });

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

fn render_row_button(
    view_id: u64,
    row_id: &str,
    path: &str,
    node: &DivNode,
    row_controls: &HashMap<RowControlLookupKey, RowControlRenderState>,
    focus_visible: bool,
    window: &mut Window,
) -> AnyElement {
    let Some(control_id) = node.id.as_deref() else {
        return unsupported_row_control(view_id, path, "button missing id");
    };
    let Some(state) = row_controls.get(&row_control_lookup_key(row_id, control_id)) else {
        return unsupported_row_control(view_id, path, "button state missing");
    };

    let children = node
        .children
        .iter()
        .enumerate()
        .map(|(index, child)| render_static_text_child(view_id, path, index, child));

    let mut button = apply_div_style(
        div()
            .id(SharedString::from(state.context.node_id.clone()))
            .children(children),
        &node.style,
    );

    button = attach_row_control_focus(button, state.focus_handle.as_ref());
    button = apply_row_control_styles(
        button,
        RowControlStyleSpec {
            disabled: node.disabled,
            hover_style: &node.hover_style,
            focus_style: &node.focus_style,
            focus_visible_style: &node.focus_visible_style,
            in_focus_style: &node.in_focus_style,
            active_style: &node.active_style,
            disabled_style: &node.disabled_style,
        },
        state.focus_handle.as_ref(),
        focus_visible,
        window,
    );

    if !node.disabled
        && let Some(callback_id) = node.click.as_ref()
    {
        let context = state.context.clone();
        let callback_id = callback_id.clone();
        button = button.on_click(move |_, _, _| {
            events::emit_row_control_click(view_id, &context, &callback_id);
        });
    }

    button.into_any_element()
}

fn render_static_text_child(view_id: u64, path: &str, index: usize, child: &IrNode) -> AnyElement {
    match child {
        IrNode::Text {
            id,
            content,
            runs,
            style,
            click,
        } => render_text::render_with_view_id(
            view_id,
            &format!("{path}.{index}"),
            id.as_deref(),
            content,
            runs,
            style,
            click.as_deref(),
        ),
        _ => div().into_any_element(),
    }
}

fn render_row_checkbox(
    view_id: u64,
    row_id: &str,
    node: &CheckboxNode,
    row_controls: &HashMap<RowControlLookupKey, RowControlRenderState>,
    focus_visible: bool,
    window: &mut Window,
) -> AnyElement {
    let Some(control_id) = node.id.as_deref() else {
        return unsupported_row_control(view_id, row_id, "checkbox missing id");
    };
    let Some(state) = row_controls.get(&row_control_lookup_key(row_id, control_id)) else {
        return unsupported_row_control(view_id, row_id, "checkbox state missing");
    };

    let mut checkbox = apply_div_style(
        div()
            .id(SharedString::from(state.context.node_id.clone()))
            .flex()
            .flex_row()
            .items_center()
            .gap_2()
            .child(render_checkbox::checkbox_indicator(
                node.checked,
                node.disabled,
            ))
            .child(render_checkbox::checkbox_label(node)),
        &node.style,
    );

    checkbox = attach_row_control_focus(checkbox, state.focus_handle.as_ref());
    checkbox = apply_row_control_styles(
        checkbox,
        RowControlStyleSpec {
            disabled: node.disabled,
            hover_style: &node.hover_style,
            focus_style: &node.focus_style,
            focus_visible_style: &node.focus_visible_style,
            in_focus_style: &node.in_focus_style,
            active_style: &node.active_style,
            disabled_style: &node.disabled_style,
        },
        state.focus_handle.as_ref(),
        focus_visible,
        window,
    );

    if !node.disabled
        && let Some(callback_id) = node.change.as_ref()
    {
        let next_checked = !node.checked;
        let click_context = state.context.clone();
        let click_callback_id = callback_id.clone();
        checkbox = checkbox.on_click(move |_, _, _| {
            events::emit_row_control_checkbox_change(
                view_id,
                &click_context,
                &click_callback_id,
                next_checked,
            );
        });

        let key_context = state.context.clone();
        let key_callback_id = callback_id.clone();
        checkbox = checkbox.on_key_down(move |event: &KeyDownEvent, _, cx| {
            if render_checkbox::is_checkbox_toggle_key(event) {
                events::emit_row_control_checkbox_change(
                    view_id,
                    &key_context,
                    &key_callback_id,
                    next_checked,
                );
                cx.stop_propagation();
            }
        });
    }

    checkbox.into_any_element()
}

fn render_row_radio(
    view_id: u64,
    row_id: &str,
    node: &RadioNode,
    row_controls: &HashMap<RowControlLookupKey, RowControlRenderState>,
    focus_visible: bool,
    window: &mut Window,
) -> AnyElement {
    let Some(control_id) = node.id.as_deref() else {
        return unsupported_row_control(view_id, row_id, "radio missing id");
    };
    let Some(state) = row_controls.get(&row_control_lookup_key(row_id, control_id)) else {
        return unsupported_row_control(view_id, row_id, "radio state missing");
    };

    let mut radio = apply_div_style(
        div()
            .id(SharedString::from(state.context.node_id.clone()))
            .flex()
            .flex_row()
            .items_center()
            .gap_2()
            .child(render_radio::radio_indicator(node.checked, node.disabled))
            .child(render_radio::radio_label(node)),
        &node.style,
    );

    radio = attach_row_control_focus(radio, state.focus_handle.as_ref());
    radio = apply_row_control_styles(
        radio,
        RowControlStyleSpec {
            disabled: node.disabled,
            hover_style: &node.hover_style,
            focus_style: &node.focus_style,
            focus_visible_style: &node.focus_visible_style,
            in_focus_style: &node.in_focus_style,
            active_style: &node.active_style,
            disabled_style: &node.disabled_style,
        },
        state.focus_handle.as_ref(),
        focus_visible,
        window,
    );

    if !node.disabled
        && let Some(callback_id) = node.change.as_ref()
    {
        let click_context = state.context.clone();
        let click_callback_id = callback_id.clone();
        let click_value = node.value.clone();
        radio = radio.on_click(move |_, _, _| {
            events::emit_row_control_change(
                view_id,
                &click_context,
                &click_callback_id,
                &click_value,
            );
        });

        let key_context = state.context.clone();
        let key_callback_id = callback_id.clone();
        let key_value = node.value.clone();
        radio = radio.on_key_down(move |event: &KeyDownEvent, _, cx| {
            if render_radio::is_radio_toggle_key(event) {
                events::emit_row_control_change(
                    view_id,
                    &key_context,
                    &key_callback_id,
                    &key_value,
                );
                cx.stop_propagation();
            }
        });
    }

    radio.into_any_element()
}

fn attach_row_control_focus(
    mut element: gpui::Stateful<gpui::Div>,
    focus_handle: Option<&FocusHandle>,
) -> gpui::Stateful<gpui::Div> {
    if let Some(handle) = focus_handle {
        let handle = handle.clone();
        element =
            element
                .track_focus(&handle)
                .focusable()
                .on_any_mouse_down(move |_, window, _| {
                    handle.focus(window);
                });
    }

    element
}

struct RowControlStyleSpec<'a> {
    disabled: bool,
    hover_style: &'a DivStyle,
    focus_style: &'a DivStyle,
    focus_visible_style: &'a DivStyle,
    in_focus_style: &'a DivStyle,
    active_style: &'a DivStyle,
    disabled_style: &'a DivStyle,
}

fn apply_row_control_styles(
    mut element: gpui::Stateful<gpui::Div>,
    spec: RowControlStyleSpec<'_>,
    focus_handle: Option<&FocusHandle>,
    focus_visible: bool,
    window: &mut Window,
) -> gpui::Stateful<gpui::Div> {
    if !spec.disabled && !spec.hover_style.is_empty() {
        let hover_ops = spec.hover_style.clone();
        element = element.hover(move |style| apply_refinement_style(style, &hover_ops));
    }

    if !spec.disabled
        && !spec.focus_visible_style.is_empty()
        && focus_visible
        && focus_handle.is_some_and(|handle| handle.is_focused(window))
    {
        element = apply_div_style(element, spec.focus_visible_style);
    }

    if !spec.disabled && !spec.focus_style.is_empty() {
        let focus_ops = spec.focus_style.clone();
        element = element.focus(move |style| apply_refinement_style(style, &focus_ops));
    }

    if !spec.disabled && !spec.in_focus_style.is_empty() {
        let in_focus_ops = spec.in_focus_style.clone();
        element = element.in_focus(move |style| apply_refinement_style(style, &in_focus_ops));
    }

    if !spec.disabled && !spec.active_style.is_empty() {
        let active_ops = spec.active_style.clone();
        element = element.active(move |style| apply_refinement_style(style, &active_ops));
    }

    if spec.disabled && !spec.disabled_style.is_empty() {
        element = apply_div_style(element, spec.disabled_style);
    }

    element
}

fn unsupported_row_control(view_id: u64, path: &str, message: &str) -> AnyElement {
    div()
        .id(SharedString::from(format!(
            "guppy-{view_id}-{path}-unsupported"
        )))
        .child(message.to_owned())
        .into_any_element()
}

fn row_control_lookup_key(row_id: &str, control_id: &str) -> RowControlLookupKey {
    RowControlLookupKey {
        row_id: row_id.to_owned(),
        control_id: control_id.to_owned(),
    }
}

#[cfg(test)]
mod tests {
    use super::row_control_lookup_key;

    #[test]
    fn row_control_lookup_keys_are_row_scoped() {
        assert_ne!(
            row_control_lookup_key("row_1", "done"),
            row_control_lookup_key("row_2", "done")
        );
    }

    #[test]
    fn row_control_lookup_keys_do_not_collide_on_delimiter_chars() {
        assert_ne!(
            row_control_lookup_key("row\0nested", "done"),
            row_control_lookup_key("row", "nested\0done")
        );
    }
}
