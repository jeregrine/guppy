use super::{BridgeView, events, render_pass::RenderPass};
use gpui::{
    App, Context, FocusHandle, InteractiveElement, KeyDownEvent, MouseButton,
    StatefulInteractiveElement, Window,
};
use std::collections::HashMap;

/// Focus targets for roving keyboard navigation. A `None` slot lets the key
/// fall through to the surrounding handler.
#[derive(Default, Clone)]
pub(crate) struct NavigationTargets {
    pub up: Option<FocusHandle>,
    pub down: Option<FocusHandle>,
    pub left: Option<FocusHandle>,
    pub right: Option<FocusHandle>,
    pub home: Option<FocusHandle>,
    pub end: Option<FocusHandle>,
}

impl NavigationTargets {
    pub fn target(&self, key: &str) -> Option<&FocusHandle> {
        match key {
            "up" => self.up.as_ref(),
            "down" => self.down.as_ref(),
            "left" => self.left.as_ref(),
            "right" => self.right.as_ref(),
            "home" => self.home.as_ref(),
            "end" => self.end.as_ref(),
            _ => None,
        }
    }

    /// Focuses the matched target; returns true when the event was handled.
    pub fn handle(&self, event: &KeyDownEvent, window: &mut Window, cx: &mut App) -> bool {
        let Some(handle) = self.target(event.keystroke.key.as_str()) else {
            return false;
        };

        handle.focus(window);
        cx.stop_propagation();
        true
    }
}

/// Up/down/home/end targets around `index` in an ordered item list.
pub(crate) fn vertical_neighbors<T>(
    items: &[T],
    index: usize,
    handles: &HashMap<String, FocusHandle>,
    id_of: impl Fn(&T) -> &str,
) -> NavigationTargets {
    let handle_for = |item: Option<&T>| item.and_then(|item| handles.get(id_of(item))).cloned();

    NavigationTargets {
        up: handle_for(
            index
                .checked_sub(1)
                .and_then(|previous| items.get(previous)),
        ),
        down: handle_for(items.get(index + 1)),
        home: handle_for(items.first()),
        end: handle_for(items.last()),
        ..Default::default()
    }
}

/// Enter/space activation for rows, cells, and headers; held key repeat must
/// not spam discrete activation events.
pub(crate) fn is_activation_key(event: &KeyDownEvent) -> bool {
    !event.is_held && matches!(event.keystroke.key.as_str(), "enter" | "space")
}

/// Roving focus handles for keyboard-actionable rows, keyed by item id.
/// `entries` yields `(item_id, retained_identity_key)` pairs.
pub(crate) fn prepare_focus_handles(
    pass: &mut RenderPass<'_>,
    cx: &mut Context<BridgeView>,
    keyboard_enabled: bool,
    entries: impl IntoIterator<Item = (String, String)>,
) -> HashMap<String, FocusHandle> {
    if !keyboard_enabled {
        return HashMap::new();
    }

    entries
        .into_iter()
        .map(|(item_id, identity_key)| {
            let focus_handle = pass.ensure_focus_handle(&identity_key, cx, Some(true), None);
            (item_id, focus_handle)
        })
        .collect()
}

/// The shared list-row interaction surface: roving navigation, keyboard
/// context menu, enter/space activation, click, and right-click context menu.
pub(crate) struct RowInteractionSpec<'a> {
    pub view_id: u64,
    pub row_key: &'a str,
    pub click: Option<&'a str>,
    pub context_menu: Option<&'a str>,
    pub targets: NavigationTargets,
}

pub(crate) fn attach_row_interactions<E>(mut row: E, spec: RowInteractionSpec<'_>) -> E
where
    E: InteractiveElement + StatefulInteractiveElement,
{
    let view_id = spec.view_id;

    if spec.click.is_some() || spec.context_menu.is_some() {
        let click_callback = spec.click.map(str::to_owned);
        let context_menu_callback = spec.context_menu.map(str::to_owned);
        let key_row_key = spec.row_key.to_owned();
        let targets = spec.targets;
        row = row.on_key_down(move |event: &KeyDownEvent, window, cx| {
            if targets.handle(event, window, cx) {
                return;
            }

            if let Some(callback_id) = context_menu_callback.as_deref()
                && events::is_context_menu_key(event)
            {
                events::emit_keyboard_context_menu(view_id, &key_row_key, callback_id, event);
                cx.stop_propagation();
                return;
            }

            if let Some(callback_id) = click_callback.as_deref()
                && is_activation_key(event)
            {
                events::emit_click(view_id, &key_row_key, callback_id);
                cx.stop_propagation();
            }
        });
    }

    if let Some(callback_id) = spec.click {
        let callback_id = callback_id.to_owned();
        let click_row_key = spec.row_key.to_owned();
        row = row.on_click(move |_, _, _| {
            events::emit_click(view_id, &click_row_key, &callback_id);
        });
    }

    if let Some(callback_id) = spec.context_menu {
        let callback_id = callback_id.to_owned();
        let context_row_key = spec.row_key.to_owned();
        row = row.on_mouse_down(MouseButton::Right, move |event, _, _| {
            events::emit_context_menu(view_id, &context_row_key, &callback_id, event);
        });
    }

    row
}

#[cfg(test)]
mod tests {
    use super::{NavigationTargets, is_activation_key, vertical_neighbors};
    use gpui::{KeyDownEvent, Keystroke};
    use std::collections::HashMap;

    fn key_event(key: &str, is_held: bool) -> KeyDownEvent {
        KeyDownEvent {
            keystroke: Keystroke::parse(key).unwrap(),
            is_held,
        }
    }

    #[test]
    fn activation_keys_match_enter_and_space_and_ignore_held_repeat() {
        assert!(is_activation_key(&key_event("enter", false)));
        assert!(is_activation_key(&key_event("space", false)));
        assert!(!is_activation_key(&key_event("enter", true)));
        assert!(!is_activation_key(&key_event("space", true)));
        assert!(!is_activation_key(&key_event("tab", false)));
    }

    #[test]
    fn empty_targets_match_no_keys() {
        let targets = NavigationTargets::default();

        for key in ["up", "down", "left", "right", "home", "end", "enter"] {
            assert!(targets.target(key).is_none(), "unexpected target for {key}");
        }
    }

    #[gpui::test]
    fn vertical_neighbors_map_list_positions(cx: &mut gpui::TestAppContext) {
        let items = vec!["a".to_owned(), "b".to_owned(), "c".to_owned()];
        let handles: HashMap<String, gpui::FocusHandle> = cx.update(|cx| {
            items
                .iter()
                .map(|id| (id.clone(), cx.focus_handle()))
                .collect()
        });

        let middle = vertical_neighbors(&items, 1, &handles, |id| id.as_str());
        assert_eq!(middle.up.as_ref(), handles.get("a"));
        assert_eq!(middle.down.as_ref(), handles.get("c"));
        assert_eq!(middle.home.as_ref(), handles.get("a"));
        assert_eq!(middle.end.as_ref(), handles.get("c"));

        let first = vertical_neighbors(&items, 0, &handles, |id| id.as_str());
        assert!(first.up.is_none());
        assert_eq!(first.down.as_ref(), handles.get("b"));

        let last = vertical_neighbors(&items, 2, &handles, |id| id.as_str());
        assert!(last.down.is_none());
        assert_eq!(last.up.as_ref(), handles.get("b"));
    }
}
