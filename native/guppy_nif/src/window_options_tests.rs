use super::{
    TitlebarConfig, WindowBackgroundConfig, WindowBoundsState, WindowDecorationsConfig,
    WindowKindConfig, WindowOptionsConfig,
};
use eetf::{Atom, BigInteger, Binary, FixInteger, Map, Term};

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

fn bigint_i32(value: i32) -> Term {
    Term::BigInteger(BigInteger::from(value))
}

fn bigint_u32(value: u32) -> Term {
    Term::BigInteger(BigInteger::from(value))
}

fn map(entries: Vec<(&str, Term)>) -> Term {
    raw_map(
        entries
            .into_iter()
            .map(|(key, value)| (atom(key), value))
            .collect(),
    )
}

fn raw_map(entries: Vec<(Term, Term)>) -> Term {
    Term::Map(Map {
        map: entries.into_iter().collect(),
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
fn decodes_big_integer_window_option_numbers() {
    let options = WindowOptionsConfig::decode_etf(&encode(map(vec![
        (
            "window_bounds",
            map(vec![
                ("x", bigint_i32(-12)),
                ("y", bigint_i32(24)),
                ("width", bigint_u32(1024)),
                ("height", bigint_u32(768)),
            ]),
        ),
        ("display_id", bigint_u32(3)),
    ])))
    .unwrap();

    let bounds = options.window_bounds.unwrap();
    assert_eq!(bounds.x, Some(-12));
    assert_eq!(bounds.y, Some(24));
    assert_eq!(bounds.width, 1024);
    assert_eq!(bounds.height, 768);
    assert_eq!(options.display_id, Some(3));
}

#[gpui::test]
fn maps_display_ids_through_active_gpui_displays(cx: &mut gpui::TestAppContext) {
    cx.update(|cx| {
        let displays = cx.displays();
        let display = displays
            .first()
            .expect("test app should expose a display")
            .id();
        let active_ids = displays
            .iter()
            .map(|display| u32::from(display.id()))
            .collect::<std::collections::HashSet<_>>();
        let valid_id = u32::from(display);
        let missing_id = (0..=10)
            .find(|candidate| !active_ids.contains(candidate))
            .unwrap_or(u32::MAX - 1);

        let valid = WindowOptionsConfig {
            display_id: Some(valid_id),
            ..Default::default()
        }
        .into_gpui(cx);
        assert_eq!(valid.display_id, Some(display));

        let missing = WindowOptionsConfig {
            display_id: Some(missing_id),
            ..Default::default()
        }
        .into_gpui(cx);
        assert_eq!(missing.display_id, None);

        let out_of_range = WindowOptionsConfig {
            display_id: Some(u32::MAX),
            ..Default::default()
        }
        .into_gpui(cx);
        assert_eq!(out_of_range.display_id, None);
    });
}

#[test]
fn rejects_unknown_window_option_keys() {
    let top_err =
        WindowOptionsConfig::decode_etf(&encode(map(vec![("unknown", atom("true"))]))).unwrap_err();
    assert!(
        top_err.contains("unsupported window options field"),
        "unexpected error: {top_err}"
    );

    let nested_err = WindowOptionsConfig::decode_etf(&encode(map(vec![(
        "window_bounds",
        map(vec![
            ("width", integer(800)),
            ("height", integer(600)),
            ("unknown", atom("true")),
        ]),
    )])))
    .unwrap_err();
    assert!(
        nested_err.contains("unsupported window_bounds field"),
        "unexpected error: {nested_err}"
    );
}

#[test]
fn rejects_invalid_window_option_atoms() {
    let err =
        WindowOptionsConfig::decode_etf(&encode(map(vec![("kind", atom("tooltip"))]))).unwrap_err();

    assert!(err.contains("invalid kind"));
}

#[test]
fn rejects_non_atom_window_option_keys() {
    let err =
        WindowOptionsConfig::decode_etf(&encode(raw_map(vec![(binary("focus"), atom("true"))])))
            .unwrap_err();

    assert!(
        err.contains("non-atom field key"),
        "unexpected error: {err}"
    );
}

#[test]
fn rejects_atom_values_for_string_window_options() {
    let err =
        WindowOptionsConfig::decode_etf(&encode(map(vec![("app_id", atom("dev.guppy.test"))])))
            .unwrap_err();

    assert!(
        err.contains("expected utf8 binary/string"),
        "unexpected error: {err}"
    );
}
