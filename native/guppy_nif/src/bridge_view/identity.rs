use gpui::SharedString;
use std::fmt;

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub(crate) struct NodeIdentity {
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

#[cfg(test)]
mod tests {
    use super::NodeIdentity;

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
}
