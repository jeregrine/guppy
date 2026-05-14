use super::{
    TitlebarConfig, WindowBackgroundConfig, WindowBoundsState, WindowDecorationsConfig,
    WindowKindConfig, WindowOptionsConfig,
};
use eetf::{Atom, Binary, FixInteger, Map, Term};

fn atom(name: &str) -> Term {
    Term::Atom(Atom::from(name))
}

fn binary(value: &str) -> Term {
    Term::Binary(Binary {
        bytes: value.as_bytes().to_vec(),
    })
}

fn integer(value: i32) -> Term {
    Term::FixInteger(FixInteger { value })
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

#[test]
fn decodes_supported_window_options() {
    let options = WindowOptionsConfig::decode_etf(&encode(map(vec![
        (
            "window_bounds",
            map(vec![
                ("x", integer(10)),
                ("y", integer(20)),
                ("width", integer(800)),
                ("height", integer(600)),
                ("state", atom("maximized")),
            ]),
        ),
        (
            "titlebar",
            map(vec![
                ("title", binary("Guppy")),
                ("appears_transparent", atom("true")),
                (
                    "traffic_light_position",
                    map(vec![("x", integer(12)), ("y", integer(8))]),
                ),
            ]),
        ),
        ("focus", atom("false")),
        ("show", atom("true")),
        ("kind", atom("floating")),
        ("is_movable", atom("true")),
        ("is_resizable", atom("false")),
        ("is_minimizable", atom("true")),
        ("display_id", integer(2)),
        ("window_background", atom("transparent")),
        ("app_id", binary("dev.guppy.test")),
        (
            "window_min_size",
            map(vec![("width", integer(320)), ("height", integer(240))]),
        ),
        ("window_decorations", atom("client")),
        ("tabbing_identifier", binary("guppy-test")),
    ])))
    .unwrap();

    let bounds = options.window_bounds.unwrap();
    assert_eq!(bounds.x, Some(10));
    assert_eq!(bounds.y, Some(20));
    assert_eq!(bounds.width, 800);
    assert_eq!(bounds.height, 600);
    assert!(matches!(bounds.state, WindowBoundsState::Maximized));

    match options.titlebar.unwrap() {
        TitlebarConfig::Custom(titlebar) => {
            assert_eq!(titlebar.title.as_deref(), Some("Guppy"));
            assert_eq!(titlebar.appears_transparent, Some(true));
            let position = titlebar.traffic_light_position.unwrap();
            assert_eq!((position.x, position.y), (12, 8));
        }
        TitlebarConfig::Hidden => panic!("expected custom titlebar"),
    }

    assert_eq!(options.focus, Some(false));
    assert_eq!(options.show, Some(true));
    assert!(matches!(options.kind, Some(WindowKindConfig::Floating)));
    assert_eq!(options.is_movable, Some(true));
    assert_eq!(options.is_resizable, Some(false));
    assert_eq!(options.is_minimizable, Some(true));
    assert_eq!(options.display_id, Some(2));
    assert!(matches!(
        options.window_background,
        Some(WindowBackgroundConfig::Transparent)
    ));
    assert_eq!(options.app_id.as_deref(), Some("dev.guppy.test"));
    let min_size = options.window_min_size.unwrap();
    assert_eq!((min_size.width, min_size.height), (320, 240));
    assert!(matches!(
        options.window_decorations,
        Some(WindowDecorationsConfig::Client)
    ));
    assert_eq!(options.tabbing_identifier.as_deref(), Some("guppy-test"));
}

#[test]
fn rejects_invalid_window_option_atoms() {
    let err =
        WindowOptionsConfig::decode_etf(&encode(map(vec![("kind", atom("tooltip"))]))).unwrap_err();

    assert!(err.contains("invalid kind"));
}
