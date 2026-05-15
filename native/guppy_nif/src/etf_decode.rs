use eetf::{Atom, Binary, ByteList, List, Map, Term};
use std::collections::HashMap;
use std::io::Cursor;

pub(crate) fn decode_term(bytes: &[u8]) -> Result<Term, String> {
    Term::decode(Cursor::new(bytes)).map_err(|error| error.to_string())
}

pub(crate) fn expect_hash_map<'a>(
    term: &'a Term,
    description: &str,
) -> Result<&'a HashMap<Term, Term>, String> {
    match term {
        Term::Map(Map { map }) => Ok(map),
        other => Err(format!("expected {description}, got {other}")),
    }
}

pub(crate) fn expect_eetf_map<'a>(term: &'a Term, message: &str) -> Result<&'a Map, String> {
    match term {
        Term::Map(map) => Ok(map),
        _ => Err(message.to_owned()),
    }
}

pub(crate) fn expect_list(term: &Term) -> Result<&Vec<Term>, String> {
    match term {
        Term::List(List { elements }) => Ok(elements),
        other => Err(format!("expected list, got {other}")),
    }
}

pub(crate) fn get_atom_keyed_field<'a>(
    map: &'a HashMap<Term, Term>,
    key: &str,
) -> Option<&'a Term> {
    map.get(&Term::Atom(Atom::from(key)))
}

pub(crate) fn atom_name(term: &Term) -> Option<&str> {
    match term {
        Term::Atom(atom) => Some(atom.name.as_str()),
        _ => None,
    }
}

pub(crate) fn term_to_binary_string(term: &Term) -> Result<String, String> {
    term_to_binary_str(term).map(str::to_owned)
}

pub(crate) fn term_to_binary_str(term: &Term) -> Result<&str, String> {
    match term {
        Term::Binary(Binary { bytes }) | Term::ByteList(ByteList { bytes }) => {
            std::str::from_utf8(bytes).map_err(|error| error.to_string())
        }
        other => Err(format!("expected utf8 binary/string, got {other}")),
    }
}

pub(crate) fn term_to_string_or_atom(term: &Term, message: &str) -> Result<String, String> {
    match term {
        Term::Binary(Binary { bytes }) | Term::ByteList(ByteList { bytes }) => {
            std::str::from_utf8(bytes)
                .map(str::to_owned)
                .map_err(|error| error.to_string())
        }
        Term::Atom(Atom { name }) => Ok(name.clone()),
        _ => Err(message.to_owned()),
    }
}

pub(crate) fn term_key_matches(term: &Term, expected: &str) -> bool {
    match term {
        Term::Atom(atom) => atom.name == expected,
        Term::Binary(Binary { bytes }) => bytes.as_slice() == expected.as_bytes(),
        Term::ByteList(ByteList { bytes }) => bytes.as_slice() == expected.as_bytes(),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::{expect_hash_map, expect_list, term_key_matches, term_to_binary_string};
    use eetf::{Atom, Binary, Term};

    #[test]
    fn shared_helpers_preserve_contextual_error_fragments() {
        let atom = Term::Atom(Atom::from("not_a_map"));

        assert_eq!(
            expect_hash_map(&atom, "menu").unwrap_err(),
            "expected menu, got 'not_a_map'"
        );
        assert_eq!(
            expect_list(&atom).unwrap_err(),
            "expected list, got 'not_a_map'"
        );
        assert_eq!(
            term_to_binary_string(&atom).unwrap_err(),
            "expected utf8 binary/string, got 'not_a_map'"
        );
    }

    #[test]
    fn shared_key_matching_accepts_atom_and_binary_keys() {
        assert!(term_key_matches(&Term::Atom(Atom::from("width")), "width"));
        assert!(term_key_matches(
            &Term::Binary(Binary {
                bytes: b"width".to_vec()
            }),
            "width"
        ));
    }
}
