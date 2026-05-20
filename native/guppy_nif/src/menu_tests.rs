use super::{GuppyDockMenuAction, GuppyMenuAction, MenuItemSpec, MenuOsAction, MenuSpec};
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
fn decodes_and_maps_dock_menu_items_to_dock_actions() {
    let items = MenuItemSpec::decode_list_etf(&encode(list(vec![map(vec![
        ("id", binary("new_window")),
        ("label", binary("New Window")),
        ("callback", binary("new_window")),
    ])])))
    .unwrap();

    let gpui_items = super::to_gpui_dock_menu_items(items);

    match &gpui_items[0] {
        MenuItem::Action {
            name,
            action,
            os_action,
        } => {
            assert_eq!(name.as_ref(), "New Window");
            assert!(os_action.is_none());
            let action = action
                .as_any()
                .downcast_ref::<GuppyDockMenuAction>()
                .unwrap();
            assert_eq!(action.id, "new_window");
            assert_eq!(action.callback, "new_window");
        }
        other => panic!("expected action, got {}", menu_item_name(other)),
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

    let _ = crate::send_dock_menu_action_event("new_window", "new_window");
    let event = crate::take_menu_event_snapshot_for_test().unwrap();
    assert_eq!(event.action_id, "new_window");
    assert_eq!(event.callback_id, "new_window");
}

fn menu_item_name(item: &MenuItem) -> &'static str {
    match item {
        MenuItem::Separator => "separator",
        MenuItem::Submenu(_) => "submenu",
        MenuItem::SystemMenu(_) => "system_menu",
        MenuItem::Action { .. } => "action",
    }
}
