use super::{
    events::{self, BridgeDragState},
    identity::NodeIdentity,
    render_pass::RenderPass,
    style::{apply_div_style, apply_refinement_style},
};
use crate::bridge_view::BridgeView;
use crate::ir::{DivNode, ShortcutBinding};
use gpui::{
    AnyElement, AppContext, Context, Div, Empty, FocusHandle, InteractiveElement, IntoElement,
    KeyDownEvent, KeyUpEvent, MouseButton, MouseDownEvent, MouseMoveEvent, MouseUpEvent,
    ParentElement, ScrollAnchor, ScrollHandle, Stateful, StatefulInteractiveElement, Window,
    deferred, div,
};

struct DisabledEventFilter {
    disabled: bool,
}

impl DisabledEventFilter {
    fn new(disabled: bool) -> Self {
        Self { disabled }
    }

    fn callback<'a>(&self, callback: Option<&'a str>) -> Option<&'a str> {
        if self.disabled { None } else { callback }
    }

    fn shortcuts(&self, shortcuts: &[ShortcutBinding]) -> Vec<ShortcutBinding> {
        if self.disabled {
            Vec::new()
        } else {
            shortcuts.to_vec()
        }
    }

    fn tab_stop(&self, tab_stop: Option<bool>) -> Option<bool> {
        if self.disabled { None } else { tab_stop }
    }

    fn tab_index(&self, tab_index: Option<isize>) -> Option<isize> {
        if self.disabled { None } else { tab_index }
    }

    fn focusable(&self, focusable: bool) -> bool {
        focusable && !self.disabled
    }
}

struct DivPrepared<'a> {
    identity: DivIdentity,
    interactions: DivInteractionSpec<'a>,
    focus: DivFocusSpec,
}

impl DivPrepared<'_> {
    fn wants_focusable_element(&self) -> bool {
        self.interactions.keyboard_actionable || self.focus.focusable
    }
}

struct DivIdentity {
    view_id: u64,
    node_id: NodeIdentity,
    node_key: String,
}

struct DivInteractionSpec<'a> {
    click: Option<&'a str>,
    hover: Option<&'a str>,
    focus: Option<&'a str>,
    blur: Option<&'a str>,
    key_down: Option<&'a str>,
    key_up: Option<&'a str>,
    context_menu: Option<&'a str>,
    drag_start: Option<&'a str>,
    drag_move: Option<&'a str>,
    drop: Option<&'a str>,
    mouse_down: Option<&'a str>,
    mouse_up: Option<&'a str>,
    mouse_move: Option<&'a str>,
    scroll_wheel: Option<&'a str>,
    shortcuts: Vec<ShortcutBinding>,
    keyboard_actionable: bool,
}

struct DivFocusSpec {
    focusable: bool,
    tab_stop: Option<bool>,
    tab_index: Option<isize>,
    needs_focus_handle: bool,
}

struct DivRetainedState {
    tracked_scroll_handle: Option<ScrollHandle>,
    focus_handle: Option<FocusHandle>,
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    node: &DivNode,
    parent_scroll_handle: Option<ScrollHandle>,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let prepared = prepare_div(pass.view_id(), path, node);
    let retained = prepare_div_retained_state(pass, node, &prepared, window, cx);
    let child_elements = render_div_children(
        pass,
        path,
        node,
        parent_scroll_handle.clone(),
        &retained,
        window,
        cx,
    );

    let styled_div = build_base_div(&prepared.identity, node, child_elements);
    let styled_div = attach_scroll_and_focus(
        styled_div,
        node,
        &prepared,
        &retained,
        parent_scroll_handle.as_ref(),
    );
    let styled_div = attach_pointer_and_keyboard_interactions(styled_div, &prepared, &retained);
    let styled_div = apply_stateful_style_refinements(styled_div, node);

    finalize_div_layering(styled_div, node)
}

fn prepare_div<'a>(view_id: u64, path: &str, node: &'a DivNode) -> DivPrepared<'a> {
    let identity = prepare_div_identity(view_id, path, node.id.as_deref());
    let disabled = DisabledEventFilter::new(node.disabled);

    let click = disabled.callback(node.click.as_deref());
    let shortcuts = disabled.shortcuts(&node.shortcuts);
    let keyboard_actionable = click.is_some() || !shortcuts.is_empty();

    let focusable = disabled.focusable(node.focusable);
    let tab_stop = disabled.tab_stop(node.tab_stop);
    let tab_stop = if keyboard_actionable {
        Some(tab_stop.unwrap_or(true))
    } else {
        tab_stop
    };
    let tab_index = disabled.tab_index(node.tab_index);

    let interactions = DivInteractionSpec {
        click,
        hover: disabled.callback(node.hover.as_deref()),
        focus: disabled.callback(node.focus.as_deref()),
        blur: disabled.callback(node.blur.as_deref()),
        key_down: disabled.callback(node.key_down.as_deref()),
        key_up: disabled.callback(node.key_up.as_deref()),
        context_menu: disabled.callback(node.context_menu.as_deref()),
        drag_start: disabled.callback(node.drag_start.as_deref()),
        drag_move: disabled.callback(node.drag_move.as_deref()),
        drop: disabled.callback(node.drop.as_deref()),
        mouse_down: disabled.callback(node.mouse_down.as_deref()),
        mouse_up: disabled.callback(node.mouse_up.as_deref()),
        mouse_move: disabled.callback(node.mouse_move.as_deref()),
        scroll_wheel: disabled.callback(node.scroll_wheel.as_deref()),
        shortcuts,
        keyboard_actionable,
    };

    let focus = DivFocusSpec {
        focusable,
        tab_stop,
        tab_index,
        needs_focus_handle: interactions.keyboard_actionable
            || focusable
            || tab_stop.is_some()
            || tab_index.is_some()
            || !node.focus_style.is_empty()
            || !node.in_focus_style.is_empty()
            || interactions.focus.is_some()
            || interactions.blur.is_some()
            || interactions.key_down.is_some()
            || interactions.key_up.is_some(),
    };

    DivPrepared {
        identity,
        interactions,
        focus,
    }
}

fn prepare_div_identity(view_id: u64, path: &str, explicit_id: Option<&str>) -> DivIdentity {
    let node_id = NodeIdentity::new(view_id, path, explicit_id);
    let node_key = node_id.to_string();

    DivIdentity {
        view_id,
        node_id,
        node_key,
    }
}

fn prepare_div_retained_state(
    pass: &mut RenderPass<'_>,
    node: &DivNode,
    prepared: &DivPrepared<'_>,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> DivRetainedState {
    let tracked_scroll_handle = if node.track_scroll {
        Some(pass.retain_scroll_handle(&prepared.identity.node_key))
    } else {
        None
    };

    let focus_handle = if prepared.focus.needs_focus_handle {
        Some(pass.ensure_focus_handle(
            &prepared.identity.node_key,
            cx,
            prepared.focus.tab_stop,
            prepared.focus.tab_index,
        ))
    } else {
        None
    };

    if let Some(handle) = focus_handle.as_ref() {
        pass.register_focus_callbacks(
            &prepared.identity.node_key,
            handle,
            prepared.interactions.focus,
            prepared.interactions.blur,
            window,
            cx,
        );
    }

    DivRetainedState {
        tracked_scroll_handle,
        focus_handle,
    }
}

fn render_div_children(
    pass: &mut RenderPass<'_>,
    path: &str,
    node: &DivNode,
    parent_scroll_handle: Option<ScrollHandle>,
    retained: &DivRetainedState,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> Vec<AnyElement> {
    let child_scroll_handle = retained
        .tracked_scroll_handle
        .clone()
        .or(parent_scroll_handle);

    pass.render_children(path, &node.children, child_scroll_handle, window, cx)
}

fn build_base_div(
    identity: &DivIdentity,
    node: &DivNode,
    child_elements: Vec<AnyElement>,
) -> Stateful<Div> {
    let styled_div = apply_div_style(
        div()
            .id(identity.node_id.to_shared_string())
            .children(child_elements),
        &node.style,
    );

    if node.occlude {
        styled_div.occlude()
    } else {
        styled_div
    }
}

fn attach_scroll_and_focus(
    styled_div: Stateful<Div>,
    node: &DivNode,
    prepared: &DivPrepared<'_>,
    retained: &DivRetainedState,
    parent_scroll_handle: Option<&ScrollHandle>,
) -> Stateful<Div> {
    let styled_div = match retained.tracked_scroll_handle.as_ref() {
        Some(handle) => styled_div.track_scroll(handle),
        None => styled_div,
    };

    let styled_div = if node.anchor_scroll {
        match parent_scroll_handle {
            Some(handle) => {
                styled_div.anchor_scroll(Some(ScrollAnchor::for_handle(handle.clone())))
            }
            None => styled_div,
        }
    } else {
        styled_div
    };

    match retained.focus_handle.as_ref() {
        Some(handle) => {
            let styled_div = styled_div.track_focus(handle);
            if prepared.wants_focusable_element() {
                styled_div.focusable()
            } else {
                styled_div
            }
        }
        None => styled_div,
    }
}

fn attach_pointer_and_keyboard_interactions(
    styled_div: Stateful<Div>,
    prepared: &DivPrepared<'_>,
    retained: &DivRetainedState,
) -> Stateful<Div> {
    let view_id = prepared.identity.view_id;
    let node_key = &prepared.identity.node_key;
    let interactions = &prepared.interactions;

    let styled_div = match interactions.hover {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let hover_node_id = node_key.clone();
            styled_div.on_hover(move |hovered, _, _| {
                events::emit_hover(view_id, &hover_node_id, &callback_id, *hovered);
            })
        }
        None => styled_div,
    };

    let styled_div = match retained.focus_handle.as_ref() {
        Some(handle) => {
            let handle = handle.clone();
            styled_div.on_any_mouse_down(move |_, window, _| {
                handle.focus(window);
            })
        }
        None => styled_div,
    };

    let styled_div = if interactions.key_down.is_some() || !interactions.shortcuts.is_empty() {
        let key_down_callback_id = interactions.key_down.map(str::to_owned);
        let key_down_node_id = node_key.clone();
        let shortcut_bindings = interactions.shortcuts.clone();

        styled_div.on_key_down(move |event: &KeyDownEvent, _, cx| {
            if let Some(callback_id) = key_down_callback_id.as_ref() {
                events::emit_key_down(view_id, &key_down_node_id, callback_id, event);
            }

            if let Some(shortcut) = events::matching_shortcut(event, &shortcut_bindings) {
                events::emit_action(view_id, &key_down_node_id, shortcut, event);
                cx.stop_propagation();
            }
        })
    } else {
        styled_div
    };

    let styled_div = match interactions.key_up {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let key_up_node_id = node_key.clone();
            styled_div.on_key_up(move |event: &KeyUpEvent, _, _| {
                events::emit_key_up(view_id, &key_up_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match interactions.context_menu {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let context_menu_node_id = node_key.clone();
            styled_div.on_mouse_down(MouseButton::Right, move |event: &MouseDownEvent, _, _| {
                events::emit_context_menu(view_id, &context_menu_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match interactions.drop {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let drop_node_id = node_key.clone();
            styled_div.on_drop::<BridgeDragState>(move |drag, _, _| {
                events::emit_drop(view_id, &drop_node_id, &callback_id, &drag.source_id);
            })
        }
        None => styled_div,
    };

    let styled_div = match interactions.drag_move {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let drag_move_node_id = node_key.clone();
            styled_div.on_drag_move::<BridgeDragState>(move |event, _, cx| {
                let drag = event.drag(cx);
                events::emit_drag_move(
                    view_id,
                    &drag_move_node_id,
                    &callback_id,
                    &drag.source_id,
                    event.event.pressed_button,
                    event.event.position,
                    &event.event.modifiers,
                );
            })
        }
        None => styled_div,
    };

    let styled_div = match interactions.drag_start {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let drag_start_node_id = node_key.clone();
            let drag_source_id = node_key.clone();
            styled_div.on_drag(
                BridgeDragState {
                    source_id: drag_source_id,
                },
                move |drag, _, _, cx| {
                    events::emit_drag_start(
                        view_id,
                        &drag_start_node_id,
                        &callback_id,
                        &drag.source_id,
                    );
                    cx.new(|_| Empty)
                },
            )
        }
        None if interactions.drag_move.is_some() => {
            let drag_source_id = node_key.clone();
            styled_div.on_drag(
                BridgeDragState {
                    source_id: drag_source_id,
                },
                move |_, _, _, cx| cx.new(|_| Empty),
            )
        }
        None => styled_div,
    };

    let styled_div = match interactions.mouse_down {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let mouse_down_node_id = node_key.clone();
            styled_div.on_any_mouse_down(move |event: &MouseDownEvent, _, _| {
                events::emit_mouse_down(view_id, &mouse_down_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match interactions.mouse_up {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let mouse_up_node_id = node_key.clone();
            styled_div.capture_any_mouse_up(move |event: &MouseUpEvent, _, _| {
                events::emit_mouse_up(view_id, &mouse_up_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match interactions.mouse_move {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let mouse_move_node_id = node_key.clone();
            styled_div.on_mouse_move(move |event: &MouseMoveEvent, _, _| {
                events::emit_mouse_move(view_id, &mouse_move_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    let styled_div = match interactions.scroll_wheel {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let scroll_node_id = node_key.clone();
            styled_div.on_scroll_wheel(move |event: &gpui::ScrollWheelEvent, _, _| {
                events::emit_scroll_wheel(view_id, &scroll_node_id, &callback_id, event);
            })
        }
        None => styled_div,
    };

    match interactions.click {
        Some(callback_id) => {
            let callback_id = callback_id.to_owned();
            let click_node_id = node_key.clone();
            styled_div.on_click(move |_, _, _| {
                events::emit_click(view_id, &click_node_id, &callback_id);
            })
        }
        None => styled_div,
    }
}

fn apply_stateful_style_refinements(
    mut styled_div: Stateful<Div>,
    node: &DivNode,
) -> Stateful<Div> {
    if !node.disabled && !node.focus_style.is_empty() {
        let focus_ops = node.focus_style.clone();
        styled_div = styled_div.focus(move |style| apply_refinement_style(style, &focus_ops));
    }

    if !node.disabled && !node.in_focus_style.is_empty() {
        let in_focus_ops = node.in_focus_style.clone();
        styled_div = styled_div.in_focus(move |style| apply_refinement_style(style, &in_focus_ops));
    }

    if !node.disabled && !node.hover_style.is_empty() {
        let hover_ops = node.hover_style.clone();
        styled_div = styled_div.hover(move |style| apply_refinement_style(style, &hover_ops));
    }

    if !node.disabled && !node.active_style.is_empty() {
        let active_ops = node.active_style.clone();
        styled_div = styled_div.active(move |style| apply_refinement_style(style, &active_ops));
    }

    if node.disabled && !node.disabled_style.is_empty() {
        styled_div = apply_div_style(styled_div, &node.disabled_style);
    }

    styled_div
}

fn finalize_div_layering(styled_div: Stateful<Div>, node: &DivNode) -> AnyElement {
    let element = styled_div.into_any_element();

    match node.stack_priority {
        Some(priority) => deferred(element).with_priority(priority).into_any_element(),
        None => element,
    }
}
