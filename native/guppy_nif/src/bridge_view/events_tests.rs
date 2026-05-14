use super::matching_shortcut;
use crate::ir::ShortcutBinding;
use gpui::{KeyDownEvent, KeybindingKeystroke, Keystroke};

fn shortcut(shortcut: &str, action: &str, callback: &str) -> ShortcutBinding {
    let parsed = Keystroke::parse(shortcut).expect("valid shortcut");
    ShortcutBinding {
        shortcut: shortcut.to_owned(),
        action: action.to_owned(),
        callback: callback.to_owned(),
        parsed: KeybindingKeystroke::from_keystroke(parsed),
    }
}

#[test]
fn matching_shortcut_ignores_held_keys() {
    let shortcuts = vec![shortcut("ctrl-j", "primary", "primary_action")];
    let event = KeyDownEvent {
        keystroke: Keystroke::parse("ctrl-j").expect("valid keystroke"),
        is_held: true,
    };

    assert!(matching_shortcut(&event, &shortcuts).is_none());
}

#[test]
fn matching_shortcut_returns_matching_binding() {
    let shortcuts = vec![
        shortcut("ctrl-k", "secondary", "secondary_action"),
        shortcut("ctrl-j", "primary", "primary_action"),
    ];
    let event = KeyDownEvent {
        keystroke: Keystroke::parse("ctrl-j").expect("valid keystroke"),
        is_held: false,
    };

    let matched = matching_shortcut(&event, &shortcuts).expect("shortcut should match");
    assert_eq!(matched.action, "primary");
    assert_eq!(matched.callback, "primary_action");
}
