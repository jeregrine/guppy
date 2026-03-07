use eetf::{Atom, Binary, ByteList, List, Map, Term};
use std::collections::HashMap;
use std::io::Cursor;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct DivStyle {
    pub flex: bool,
    pub flex_col: bool,
    pub flex_1: bool,
    pub size_full: bool,
    pub gap_2: bool,
    pub p_2: bool,
    pub p_4: bool,
    pub p_6: bool,
    pub w_64: bool,
    pub items_center: bool,
    pub justify_center: bool,
    pub cursor_pointer: bool,
    pub rounded_md: bool,
    pub border_1: bool,
    pub overflow_y_scroll: bool,
    pub bg: Option<ColorToken>,
    pub text_color: Option<ColorToken>,
    pub border_color: Option<ColorToken>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ColorToken {
    Red,
    Green,
    Blue,
    Yellow,
    Black,
    White,
    Gray,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum IrNode {
    Text {
        id: Option<String>,
        content: String,
        click: Option<String>,
    },
    Div {
        id: Option<String>,
        style: DivStyle,
        children: Vec<IrNode>,
        click: Option<String>,
    },
}

impl IrNode {
    pub fn text(content: impl Into<String>) -> Self {
        Self::Text {
            id: None,
            content: content.into(),
            click: None,
        }
    }

    pub fn decode_etf(bytes: &[u8]) -> Result<Self, String> {
        let term = Term::decode(Cursor::new(bytes)).map_err(|error| error.to_string())?;
        Self::from_term(&term)
    }

    fn from_term(term: &Term) -> Result<Self, String> {
        let map = expect_map(term)?;
        let kind = get_atom_field(map, "kind")?;
        let id = get_optional_string_field(map, "id")?;

        match kind.as_str() {
            "text" => Ok(Self::Text {
                id,
                content: get_string_field(map, "content")?,
                click: get_click_event(map)?,
            }),
            "div" => {
                let children = match get_field(map, "children") {
                    Some(term) => get_list(term)?
                        .iter()
                        .map(Self::from_term)
                        .collect::<Result<Vec<_>, _>>()?,
                    None => Vec::new(),
                };

                Ok(Self::Div {
                    id,
                    style: get_div_style(map)?,
                    children,
                    click: get_click_event(map)?,
                })
            }
            other => Err(format!("unsupported ir kind: {other}")),
        }
    }
}

fn expect_map(term: &Term) -> Result<&HashMap<Term, Term>, String> {
    match term {
        Term::Map(Map { map }) => Ok(map),
        other => Err(format!("expected map ir node, got {other}")),
    }
}

fn get_field<'a>(map: &'a HashMap<Term, Term>, key: &str) -> Option<&'a Term> {
    map.get(&Term::Atom(Atom::from(key)))
}

fn get_atom_field(map: &HashMap<Term, Term>, key: &str) -> Result<String, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) => Ok(atom.name.clone()),
        Some(other) => Err(format!("expected atom field {key}, got {other}")),
        None => Err(format!("missing required field: {key}")),
    }
}

fn get_string_field(map: &HashMap<Term, Term>, key: &str) -> Result<String, String> {
    match get_field(map, key) {
        Some(term) => term_to_string(term),
        None => Err(format!("missing required field: {key}")),
    }
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

fn get_div_style(map: &HashMap<Term, Term>) -> Result<DivStyle, String> {
    let Some(style_term) = get_field(map, "style") else {
        return Ok(DivStyle::default());
    };

    let style_map = expect_map(style_term)?;

    Ok(DivStyle {
        flex: get_bool_style(style_map, "flex")?,
        flex_col: get_bool_style(style_map, "flex_col")?,
        flex_1: get_bool_style(style_map, "flex_1")?,
        size_full: get_bool_style(style_map, "size_full")?,
        gap_2: get_bool_style(style_map, "gap_2")?,
        p_2: get_bool_style(style_map, "p_2")?,
        p_4: get_bool_style(style_map, "p_4")?,
        p_6: get_bool_style(style_map, "p_6")?,
        w_64: get_bool_style(style_map, "w_64")?,
        items_center: get_bool_style(style_map, "items_center")?,
        justify_center: get_bool_style(style_map, "justify_center")?,
        cursor_pointer: get_bool_style(style_map, "cursor_pointer")?,
        rounded_md: get_bool_style(style_map, "rounded_md")?,
        border_1: get_bool_style(style_map, "border_1")?,
        overflow_y_scroll: get_bool_style(style_map, "overflow_y_scroll")?,
        bg: get_color_style(style_map, "bg")?,
        text_color: get_color_style(style_map, "text_color")?,
        border_color: get_color_style(style_map, "border_color")?,
    })
}

fn get_bool_style(map: &HashMap<Term, Term>, key: &str) -> Result<bool, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) if atom.name == "true" => Ok(true),
        Some(Term::Atom(atom)) if atom.name == "false" => Ok(false),
        Some(other) => Err(format!("expected boolean style {key}, got {other}")),
        None => Ok(false),
    }
}

fn get_color_style(map: &HashMap<Term, Term>, key: &str) -> Result<Option<ColorToken>, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) => Ok(Some(parse_color_token(&atom.name)?)),
        Some(other) => Err(format!("expected color style {key}, got {other}")),
        None => Ok(None),
    }
}

fn parse_color_token(token: &str) -> Result<ColorToken, String> {
    match token {
        "red" => Ok(ColorToken::Red),
        "green" => Ok(ColorToken::Green),
        "blue" => Ok(ColorToken::Blue),
        "yellow" => Ok(ColorToken::Yellow),
        "black" => Ok(ColorToken::Black),
        "white" => Ok(ColorToken::White),
        "gray" => Ok(ColorToken::Gray),
        other => Err(format!("unsupported color token: {other}")),
    }
}

fn get_click_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    let Some(events_term) = get_field(map, "events") else {
        return Ok(None);
    };

    let events = expect_map(events_term)?;

    match get_field(events, "click") {
        Some(term) => term_to_string(term).map(Some),
        None => Ok(None),
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
            String::from_utf8(bytes.clone()).map_err(|error| error.to_string())
        }
        other => Err(format!("expected utf8 binary/string, got {other}")),
    }
}
