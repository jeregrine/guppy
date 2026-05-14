use crate::bridge_text_input::{
    Copy as TextCopy, Cut as TextCut, Paste as TextPaste, SelectAll as TextSelectAll,
};
use eetf::{Atom, Binary, ByteList, List, Map, Term};
use gpui::{Action, App, KeyBinding, Keystroke, Menu, MenuItem, OsAction, SharedString};
use std::collections::HashMap;
use std::io::Cursor;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct MenuSpec {
    pub label: String,
    pub items: Vec<MenuItemSpec>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum MenuItemSpec {
    Separator,
    Submenu(MenuSpec),
    Action(MenuActionSpec),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct MenuActionSpec {
    pub id: String,
    pub label: String,
    pub callback: Option<String>,
    pub shortcut: Option<String>,
    pub enabled: bool,
    pub os_action: Option<MenuOsAction>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum MenuOsAction {
    Cut,
    Copy,
    Paste,
    SelectAll,
    Undo,
    Redo,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct GuppyMenuAction {
    pub id: String,
    pub callback: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct GuppyDisabledMenuAction {
    id: String,
    callback: Option<String>,
}

impl MenuSpec {
    pub fn decode_etf(bytes: &[u8]) -> Result<Vec<Self>, String> {
        let term = Term::decode(Cursor::new(bytes)).map_err(|error| error.to_string())?;
        decode_menus(&term)
    }
}

pub(crate) fn bind_menu_action(cx: &mut App) {
    cx.on_action(|action: &GuppyMenuAction, _cx| {
        let _ = crate::send_menu_action_event(&action.id, &action.callback);
    });
}

pub(crate) fn install_menus(cx: &mut App, menus: Vec<MenuSpec>) {
    cx.clear_key_bindings();
    crate::bridge_text_input::bind_keys(cx);
    crate::bridge_view::bind_focus_keys(cx);

    let key_bindings = key_bindings(&menus);
    if !key_bindings.is_empty() {
        cx.bind_keys(key_bindings);
    }

    cx.set_menus(to_gpui_menus(menus));
}

pub(crate) fn to_gpui_menus(menus: Vec<MenuSpec>) -> Vec<Menu> {
    menus.into_iter().map(to_gpui_menu).collect()
}

pub(crate) fn key_bindings(menus: &[MenuSpec]) -> Vec<KeyBinding> {
    let mut bindings = Vec::new();

    for menu in menus {
        collect_key_bindings(&menu.items, &mut bindings);
    }

    bindings
}

fn collect_key_bindings(items: &[MenuItemSpec], bindings: &mut Vec<KeyBinding>) {
    for item in items {
        match item {
            MenuItemSpec::Action(action) if action.enabled => {
                if let Some(shortcut) = action.shortcut.as_deref() {
                    match (action.os_action, action.callback.as_ref()) {
                        (Some(os_action), _) => {
                            push_os_action_key_binding(shortcut, os_action, bindings)
                        }
                        (None, Some(callback)) => bindings.push(KeyBinding::new(
                            shortcut,
                            GuppyMenuAction {
                                id: action.id.clone(),
                                callback: callback.clone(),
                            },
                            None,
                        )),
                        (None, None) => {}
                    }
                }
            }
            MenuItemSpec::Submenu(menu) => collect_key_bindings(&menu.items, bindings),
            _ => {}
        }
    }
}

fn push_os_action_key_binding(
    shortcut: &str,
    os_action: MenuOsAction,
    bindings: &mut Vec<KeyBinding>,
) {
    match os_action {
        MenuOsAction::Cut => bindings.push(KeyBinding::new(shortcut, TextCut, None)),
        MenuOsAction::Copy => bindings.push(KeyBinding::new(shortcut, TextCopy, None)),
        MenuOsAction::Paste => bindings.push(KeyBinding::new(shortcut, TextPaste, None)),
        MenuOsAction::SelectAll => bindings.push(KeyBinding::new(shortcut, TextSelectAll, None)),
        MenuOsAction::Undo | MenuOsAction::Redo => {}
    }
}

fn to_gpui_menu(menu: MenuSpec) -> Menu {
    Menu {
        name: SharedString::from(menu.label),
        items: menu.items.into_iter().map(to_gpui_menu_item).collect(),
    }
}

fn to_gpui_menu_item(item: MenuItemSpec) -> MenuItem {
    match item {
        MenuItemSpec::Separator => MenuItem::separator(),
        MenuItemSpec::Submenu(menu) => MenuItem::submenu(to_gpui_menu(menu)),
        MenuItemSpec::Action(action) => to_gpui_action_item(action),
    }
}

fn to_gpui_action_item(action: MenuActionSpec) -> MenuItem {
    if !action.enabled {
        return disabled_action_item(action);
    }

    match action.os_action {
        Some(MenuOsAction::Cut) => MenuItem::os_action(action.label, TextCut, OsAction::Cut),
        Some(MenuOsAction::Copy) => MenuItem::os_action(action.label, TextCopy, OsAction::Copy),
        Some(MenuOsAction::Paste) => MenuItem::os_action(action.label, TextPaste, OsAction::Paste),
        Some(MenuOsAction::SelectAll) => {
            MenuItem::os_action(action.label, TextSelectAll, OsAction::SelectAll)
        }
        Some(MenuOsAction::Undo) | Some(MenuOsAction::Redo) => disabled_action_item(action),
        None => {
            let callback = action
                .callback
                .expect("menu callback actions are validated before native rendering");
            MenuItem::action(
                action.label,
                GuppyMenuAction {
                    id: action.id,
                    callback,
                },
            )
        }
    }
}

fn disabled_action_item(action: MenuActionSpec) -> MenuItem {
    match action.os_action {
        Some(os_action) => MenuItem::os_action(
            action.label,
            GuppyDisabledMenuAction {
                id: action.id,
                callback: action.callback,
            },
            to_gpui_os_action(os_action),
        ),
        None => MenuItem::action(
            action.label,
            GuppyDisabledMenuAction {
                id: action.id,
                callback: action.callback,
            },
        ),
    }
}

fn to_gpui_os_action(action: MenuOsAction) -> OsAction {
    match action {
        MenuOsAction::Cut => OsAction::Cut,
        MenuOsAction::Copy => OsAction::Copy,
        MenuOsAction::Paste => OsAction::Paste,
        MenuOsAction::SelectAll => OsAction::SelectAll,
        MenuOsAction::Undo => OsAction::Undo,
        MenuOsAction::Redo => OsAction::Redo,
    }
}

impl Action for GuppyMenuAction {
    fn boxed_clone(&self) -> Box<dyn Action> {
        Box::new(self.clone())
    }

    fn partial_eq(&self, action: &dyn Action) -> bool {
        action.as_any().downcast_ref::<Self>() == Some(self)
    }

    fn name(&self) -> &'static str {
        Self::name_for_type()
    }

    fn name_for_type() -> &'static str
    where
        Self: Sized,
    {
        "guppy::MenuAction"
    }

    fn build(_value: serde_json::Value) -> anyhow::Result<Box<dyn Action>>
    where
        Self: Sized,
    {
        Err(anyhow::anyhow!(
            "Guppy menu actions are data-only native actions"
        ))
    }
}

impl Action for GuppyDisabledMenuAction {
    fn boxed_clone(&self) -> Box<dyn Action> {
        Box::new(self.clone())
    }

    fn partial_eq(&self, action: &dyn Action) -> bool {
        action.as_any().downcast_ref::<Self>() == Some(self)
    }

    fn name(&self) -> &'static str {
        Self::name_for_type()
    }

    fn name_for_type() -> &'static str
    where
        Self: Sized,
    {
        "guppy::DisabledMenuAction"
    }

    fn build(_value: serde_json::Value) -> anyhow::Result<Box<dyn Action>>
    where
        Self: Sized,
    {
        Err(anyhow::anyhow!(
            "Guppy disabled menu actions are not buildable"
        ))
    }
}

fn decode_menus(term: &Term) -> Result<Vec<MenuSpec>, String> {
    get_list(term)?
        .iter()
        .map(decode_menu)
        .collect::<Result<Vec<_>, _>>()
}

fn decode_menu(term: &Term) -> Result<MenuSpec, String> {
    let map = expect_map(term)?;
    ensure_allowed_fields(map, &["label", "items"], "menu")?;

    Ok(MenuSpec {
        label: get_string_field(map, "label")?,
        items: decode_menu_items(get_required_field(map, "items")?)?,
    })
}

fn decode_menu_items(term: &Term) -> Result<Vec<MenuItemSpec>, String> {
    get_list(term)?
        .iter()
        .map(decode_menu_item)
        .collect::<Result<Vec<_>, _>>()
}

fn decode_menu_item(term: &Term) -> Result<MenuItemSpec, String> {
    if matches!(term, Term::Atom(atom) if atom.name == "separator") {
        return Ok(MenuItemSpec::Separator);
    }

    let map = expect_map(term)?;

    if get_optional_boolean_field(map, "separator")? == Some(true) {
        ensure_allowed_fields(map, &["separator"], "menu item separator")?;
        return Ok(MenuItemSpec::Separator);
    }

    if get_field(map, "items").is_some() {
        ensure_allowed_fields(map, &["label", "items"], "menu item submenu")?;
        return Ok(MenuItemSpec::Submenu(MenuSpec {
            label: get_string_field(map, "label")?,
            items: decode_menu_items(get_required_field(map, "items")?)?,
        }));
    }

    ensure_allowed_fields(
        map,
        &[
            "id",
            "label",
            "callback",
            "shortcut",
            "enabled",
            "os_action",
        ],
        "menu item action",
    )?;

    let callback = get_optional_string_field(map, "callback")?;
    let os_action = get_optional_os_action_field(map, "os_action")?;

    match (&callback, os_action) {
        (Some(_), Some(_)) => {
            return Err("menu item cannot define both callback and os_action".to_owned());
        }
        (None, None) => return Err("menu item requires callback or os_action".to_owned()),
        _ => {}
    }

    Ok(MenuItemSpec::Action(MenuActionSpec {
        id: get_string_field(map, "id")?,
        label: get_string_field(map, "label")?,
        callback,
        shortcut: get_optional_shortcut_field(map, "shortcut")?,
        enabled: get_optional_boolean_field(map, "enabled")?.unwrap_or(true),
        os_action,
    }))
}

fn get_optional_shortcut_field(
    map: &HashMap<Term, Term>,
    key: &str,
) -> Result<Option<String>, String> {
    match get_field(map, key) {
        Some(term) => {
            let shortcut = term_to_string(term)?;
            Keystroke::parse(&shortcut).map_err(|error| error.to_string())?;
            Ok(Some(shortcut))
        }
        None => Ok(None),
    }
}

fn get_optional_os_action_field(
    map: &HashMap<Term, Term>,
    key: &str,
) -> Result<Option<MenuOsAction>, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) => parse_os_action(&atom.name).map(Some),
        Some(other) => Err(format!("expected os_action atom, got {other}")),
        None => Ok(None),
    }
}

fn parse_os_action(action: &str) -> Result<MenuOsAction, String> {
    match action {
        "cut" => Ok(MenuOsAction::Cut),
        "copy" => Ok(MenuOsAction::Copy),
        "paste" => Ok(MenuOsAction::Paste),
        "select_all" => Ok(MenuOsAction::SelectAll),
        "undo" => Ok(MenuOsAction::Undo),
        "redo" => Ok(MenuOsAction::Redo),
        other => Err(format!("unsupported os_action: {other}")),
    }
}

fn ensure_allowed_fields(
    map: &HashMap<Term, Term>,
    allowed: &[&str],
    context: &str,
) -> Result<(), String> {
    for key in map.keys() {
        let Term::Atom(atom) = key else {
            return Err(format!("{context} has non-atom key: {key}"));
        };

        if !allowed.contains(&atom.name.as_str()) {
            return Err(format!("unknown {context} key: {}", atom.name));
        }
    }

    Ok(())
}

fn get_required_field<'a>(map: &'a HashMap<Term, Term>, key: &str) -> Result<&'a Term, String> {
    get_field(map, key).ok_or_else(|| format!("missing required field: {key}"))
}

fn get_string_field(map: &HashMap<Term, Term>, key: &str) -> Result<String, String> {
    term_to_string(get_required_field(map, key)?)
}

fn get_optional_string_field(
    map: &HashMap<Term, Term>,
    key: &str,
) -> Result<Option<String>, String> {
    match get_field(map, key) {
        Some(term) => term_to_string(term).map(Some),
        None => Ok(None),
    }
}

fn get_optional_boolean_field(
    map: &HashMap<Term, Term>,
    key: &str,
) -> Result<Option<bool>, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) if atom.name == "true" => Ok(Some(true)),
        Some(Term::Atom(atom)) if atom.name == "false" => Ok(Some(false)),
        Some(other) => Err(format!("expected boolean field {key}, got {other}")),
        None => Ok(None),
    }
}

fn get_field<'a>(map: &'a HashMap<Term, Term>, key: &str) -> Option<&'a Term> {
    map.get(&Term::Atom(Atom::from(key)))
}

fn expect_map(term: &Term) -> Result<&HashMap<Term, Term>, String> {
    match term {
        Term::Map(Map { map }) => Ok(map),
        other => Err(format!("expected map, got {other}")),
    }
}

fn get_list(term: &Term) -> Result<&Vec<Term>, String> {
    match term {
        Term::List(List { elements }) => Ok(elements),
        other => Err(format!("expected list, got {other}")),
    }
}

fn term_to_string(term: &Term) -> Result<String, String> {
    match term {
        Term::Binary(Binary { bytes }) | Term::ByteList(ByteList { bytes }) => {
            std::str::from_utf8(bytes)
                .map(str::to_owned)
                .map_err(|error| error.to_string())
        }
        other => Err(format!("expected utf8 binary/string, got {other}")),
    }
}

#[cfg(test)]
mod tests {
    use super::{GuppyMenuAction, MenuItemSpec, MenuOsAction, MenuSpec};
    use crate::bridge_text_input;
    use eetf::{Atom, Binary, List, Map, Term};
    use gpui::{Action, MenuItem, OsAction};

    fn atom(name: &str) -> Term {
        Term::Atom(Atom::from(name))
    }

    fn binary(value: &str) -> Term {
        Term::Binary(Binary {
            bytes: value.as_bytes().to_vec(),
        })
    }

    fn list(elements: Vec<Term>) -> Term {
        Term::List(List { elements })
    }

    fn map(entries: Vec<(&str, Term)>) -> Term {
        Term::Map(Map {
            map: entries
                .into_iter()
                .map(|(key, value)| (atom(key), value))
                .collect(),
        })
    }

    fn encode(term: Term) -> Vec<u8> {
        let mut bytes = Vec::new();
        term.encode(&mut bytes).unwrap();
        bytes
    }

    fn sample_menus() -> Vec<MenuSpec> {
        MenuSpec::decode_etf(&encode(list(vec![map(vec![
            ("label", binary("File")),
            (
                "items",
                list(vec![
                    map(vec![
                        ("id", binary("new_file")),
                        ("label", binary("New File")),
                        ("callback", binary("new_file")),
                        ("shortcut", binary("cmd-n")),
                    ]),
                    atom("separator"),
                    map(vec![
                        ("label", binary("Edit")),
                        (
                            "items",
                            list(vec![map(vec![
                                ("id", binary("copy")),
                                ("label", binary("Copy")),
                                ("os_action", atom("copy")),
                            ])]),
                        ),
                    ]),
                ]),
            ),
        ])])))
        .unwrap()
    }

    #[test]
    fn decodes_menu_specs() {
        let menus = sample_menus();

        assert_eq!(menus[0].label, "File");
        match &menus[0].items[0] {
            MenuItemSpec::Action(action) => {
                assert_eq!(action.callback.as_deref(), Some("new_file"));
                assert_eq!(action.shortcut.as_deref(), Some("cmd-n"));
            }
            other => panic!("expected action, got {other:?}"),
        }
        assert!(matches!(menus[0].items[1], MenuItemSpec::Separator));
        match &menus[0].items[2] {
            MenuItemSpec::Submenu(menu) => match &menu.items[0] {
                MenuItemSpec::Action(action) => {
                    assert_eq!(action.callback, None);
                    assert_eq!(action.os_action, Some(MenuOsAction::Copy));
                }
                other => panic!("expected action, got {other:?}"),
            },
            other => panic!("expected submenu, got {other:?}"),
        }
    }

    #[test]
    fn rejects_invalid_shortcuts() {
        let err = MenuSpec::decode_etf(&encode(list(vec![map(vec![
            ("label", binary("File")),
            (
                "items",
                list(vec![map(vec![
                    ("id", binary("bad")),
                    ("label", binary("Bad")),
                    ("callback", binary("bad")),
                    ("shortcut", binary("cmd-n-extra")),
                ])]),
            ),
        ])])))
        .unwrap_err();

        assert!(err.contains("invalid") || err.contains("keystroke"));
    }

    #[test]
    fn rejects_action_items_without_callback_or_os_action() {
        let err = MenuSpec::decode_etf(&encode(list(vec![map(vec![
            ("label", binary("File")),
            (
                "items",
                list(vec![map(vec![
                    ("id", binary("bad")),
                    ("label", binary("Bad")),
                ])]),
            ),
        ])])))
        .unwrap_err();

        assert!(err.contains("callback or os_action"));
    }

    #[test]
    fn menu_action_identity_compares_payloads() {
        let first = GuppyMenuAction {
            id: "new_file".into(),
            callback: "new_file".into(),
        };
        let same = GuppyMenuAction {
            id: "new_file".into(),
            callback: "new_file".into(),
        };
        let different = GuppyMenuAction {
            id: "open_file".into(),
            callback: "open_file".into(),
        };

        assert!(first.partial_eq(&same));
        assert!(!first.partial_eq(&different));
    }

    #[test]
    fn maps_custom_and_os_actions_to_gpui_menu_items() {
        let gpui_menus = super::to_gpui_menus(sample_menus());
        assert_eq!(gpui_menus[0].name.as_ref(), "File");

        match &gpui_menus[0].items[0] {
            MenuItem::Action {
                name,
                action,
                os_action,
            } => {
                assert_eq!(name.as_ref(), "New File");
                assert!(os_action.is_none());
                let action = action.as_any().downcast_ref::<GuppyMenuAction>().unwrap();
                assert_eq!(action.id, "new_file");
                assert_eq!(action.callback, "new_file");
            }
            other => panic!("expected action, got {}", menu_item_name(other)),
        }

        match &gpui_menus[0].items[2] {
            MenuItem::Submenu(menu) => match &menu.items[0] {
                MenuItem::Action {
                    name,
                    action,
                    os_action,
                } => {
                    assert_eq!(name.as_ref(), "Copy");
                    assert!(matches!(os_action, Some(action) if *action == OsAction::Copy));
                    assert!(action.as_any().is::<bridge_text_input::Copy>());
                }
                other => panic!("expected submenu action, got {}", menu_item_name(other)),
            },
            other => panic!("expected submenu, got {}", menu_item_name(other)),
        }
    }

    #[test]
    fn key_bindings_are_derived_from_current_menu_specs() {
        let menus = sample_menus();
        let bindings = super::key_bindings(&menus);
        assert_eq!(bindings.len(), 1);
        assert!(bindings[0].action().as_any().is::<GuppyMenuAction>());

        let replacement = vec![MenuSpec {
            label: "Edit".into(),
            items: vec![MenuItemSpec::Action(super::MenuActionSpec {
                id: "select_all".into(),
                label: "Select All".into(),
                callback: None,
                shortcut: Some("cmd-a".into()),
                enabled: true,
                os_action: Some(MenuOsAction::SelectAll),
            })],
        }];
        let replacement_bindings = super::key_bindings(&replacement);
        assert_eq!(replacement_bindings.len(), 1);
        assert!(
            replacement_bindings[0]
                .action()
                .as_any()
                .is::<bridge_text_input::SelectAll>()
        );

        assert!(super::key_bindings(&[]).is_empty());
    }

    #[test]
    fn send_menu_action_records_callback_payload() {
        let before = crate::native_event_send_snapshot_for_test();
        let _ = crate::send_menu_action_event("new_file", "new_file");
        let after = crate::native_event_send_snapshot_for_test();

        assert!(after.0 > before.0);
        let event = crate::take_menu_event_snapshot_for_test().unwrap();
        assert_eq!(event.action_id, "new_file");
        assert_eq!(event.callback_id, "new_file");
    }

    fn menu_item_name(item: &MenuItem) -> &'static str {
        match item {
            MenuItem::Separator => "separator",
            MenuItem::Submenu(_) => "submenu",
            MenuItem::SystemMenu(_) => "system_menu",
            MenuItem::Action { .. } => "action",
        }
    }
}
