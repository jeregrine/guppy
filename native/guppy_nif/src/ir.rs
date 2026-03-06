use eetf::{Atom, Binary, ByteList, List, Map, Term};
use std::collections::HashMap;
use std::io::Cursor;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum IrNode {
    Text(String),
    Div { children: Vec<IrNode>, click: Option<String> },
}

impl IrNode {
    pub fn text(content: impl Into<String>) -> Self {
        Self::Text(content.into())
    }

    pub fn decode_etf(bytes: &[u8]) -> Result<Self, String> {
        let term = Term::decode(Cursor::new(bytes)).map_err(|error| error.to_string())?;
        Self::from_term(&term)
    }

    fn from_term(term: &Term) -> Result<Self, String> {
        let map = expect_map(term)?;
        let kind = get_atom_field(map, "kind")?;

        match kind.as_str() {
            "text" => Ok(Self::Text(get_string_field(map, "content")?)),
            "div" => {
                let children = match get_field(map, "children") {
                    Some(term) => get_list(term)?
                        .iter()
                        .map(Self::from_term)
                        .collect::<Result<Vec<_>, _>>()?,
                    None => Vec::new(),
                };

                Ok(Self::Div {
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
