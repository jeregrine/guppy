use gpui::SharedString;
use std::fmt;

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub(crate) struct NodeIdentity {
    resolved: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub(crate) struct RowControlKey {
    resolved: String,
}

impl NodeIdentity {
    pub fn new(view_id: u64, path: &str, explicit_id: Option<&str>) -> Self {
        let resolved = match explicit_id {
            Some(id) => id.to_owned(),
            None => format!("guppy-{view_id}-{path}"),
        };

        Self { resolved }
    }

    pub fn to_shared_string(&self) -> SharedString {
        SharedString::from(self.resolved.clone())
    }
}

impl AsRef<str> for NodeIdentity {
    fn as_ref(&self) -> &str {
        &self.resolved
    }
}

impl fmt::Display for NodeIdentity {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.resolved)
    }
}

impl RowControlKey {
    pub fn new(view_id: u64, list_identity: &str, row_id: &str, control_id: &str) -> Self {
        Self {
            resolved: format!(
                "guppy-row-control:v1:{view_id}:{}:{}:{}",
                hex_encode_component(list_identity),
                hex_encode_component(row_id),
                hex_encode_component(control_id)
            ),
        }
    }
}

fn hex_encode_component(value: &str) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut encoded = String::with_capacity(value.len() * 2);

    for byte in value.as_bytes() {
        encoded.push(HEX[(byte >> 4) as usize] as char);
        encoded.push(HEX[(byte & 0x0f) as usize] as char);
    }

    encoded
}

impl AsRef<str> for RowControlKey {
    fn as_ref(&self) -> &str {
        &self.resolved
    }
}

impl fmt::Display for RowControlKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.resolved)
    }
}

#[cfg(test)]
mod tests {
    use super::{NodeIdentity, RowControlKey};

    #[test]
    fn explicit_id_wins_over_generated_path() {
        let identity = NodeIdentity::new(42, "root.1.2", Some("save_button"));
        assert_eq!(identity.to_string(), "save_button");
    }

    #[test]
    fn generated_id_uses_view_id_and_path() {
        let identity = NodeIdentity::new(42, "root.1.2", None);
        assert_eq!(identity.to_string(), "guppy-42-root.1.2");
    }

    #[test]
    fn row_control_key_uses_list_row_and_control_identity() {
        let key = RowControlKey::new(42, "todos", "row_1", "done");
        assert_eq!(
            key.to_string(),
            "guppy-row-control:v1:42:746f646f73:726f775f31:646f6e65"
        );
    }

    #[test]
    fn row_control_key_does_not_collide_on_delimiter_chars() {
        let key_a = RowControlKey::new(42, "todos:row", "item", "done");
        let key_b = RowControlKey::new(42, "todos", "row:item", "done");

        assert_ne!(key_a, key_b);
    }
}
