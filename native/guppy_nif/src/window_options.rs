use crate::etf_decode;
use eetf::{Map, Term};
use gpui::{
    App, Bounds, DisplayId, Point, SharedString, TitlebarOptions, WindowBackgroundAppearance,
    WindowBounds, WindowDecorations, WindowKind, WindowOptions, point, px, size,
};

#[derive(Clone, Debug, Default)]
pub(crate) struct WindowOptionsConfig {
    pub window_bounds: Option<WindowBoundsConfig>,
    pub titlebar: Option<TitlebarConfig>,
    pub focus: Option<bool>,
    pub show: Option<bool>,
    pub kind: Option<WindowKindConfig>,
    pub is_movable: Option<bool>,
    pub is_resizable: Option<bool>,
    pub is_minimizable: Option<bool>,
    pub display_id: Option<u32>,
    pub window_background: Option<WindowBackgroundConfig>,
    pub app_id: Option<String>,
    pub window_min_size: Option<SizeConfig>,
    pub window_decorations: Option<WindowDecorationsConfig>,
    pub tabbing_identifier: Option<String>,
}

#[derive(Clone, Debug)]
pub(crate) struct WindowBoundsConfig {
    pub x: Option<i32>,
    pub y: Option<i32>,
    pub width: u32,
    pub height: u32,
    pub state: WindowBoundsState,
}

#[derive(Clone, Debug)]
pub(crate) enum TitlebarConfig {
    Hidden,
    Custom(TitlebarConfigOptions),
}

#[derive(Clone, Debug, Default)]
pub(crate) struct TitlebarConfigOptions {
    pub title: Option<String>,
    pub appears_transparent: Option<bool>,
    pub traffic_light_position: Option<PointConfig>,
}

#[derive(Clone, Copy, Debug)]
pub(crate) struct PointConfig {
    pub x: u32,
    pub y: u32,
}

#[derive(Clone, Copy, Debug)]
pub(crate) struct SizeConfig {
    pub width: u32,
    pub height: u32,
}

#[derive(Clone, Copy, Debug)]
pub(crate) enum WindowBoundsState {
    Windowed,
    Maximized,
    Fullscreen,
}

#[derive(Clone, Copy, Debug)]
pub(crate) enum WindowKindConfig {
    Normal,
    PopUp,
    Floating,
}

#[derive(Clone, Copy, Debug)]
pub(crate) enum WindowBackgroundConfig {
    Opaque,
    Transparent,
    Blurred,
}

#[derive(Clone, Copy, Debug)]
pub(crate) enum WindowDecorationsConfig {
    Server,
    Client,
}

impl WindowOptionsConfig {
    pub(crate) fn decode_etf(bytes: &[u8]) -> Result<Self, String> {
        let term = etf_decode::decode_term(bytes)?;
        Self::from_term(&term)
    }

    pub(crate) fn into_gpui(self, cx: &mut App) -> WindowOptions {
        let Self {
            window_bounds,
            titlebar,
            focus,
            show,
            kind,
            is_movable,
            is_resizable,
            is_minimizable,
            display_id,
            window_background,
            app_id,
            window_min_size,
            window_decorations,
            tabbing_identifier,
        } = self;

        let mut options = WindowOptions::default();
        let display_id = display_id.and_then(|id| display_id_from_raw(id, cx));

        if let Some(window_bounds) = window_bounds {
            options.window_bounds = Some(window_bounds.into_gpui(display_id, cx));
        }

        if let Some(titlebar) = titlebar {
            options.titlebar = match titlebar {
                TitlebarConfig::Hidden => None,
                TitlebarConfig::Custom(config) => Some(config.into_gpui()),
            };
        }

        if let Some(focus) = focus {
            options.focus = focus;
        }

        if let Some(show) = show {
            options.show = show;
        }

        if let Some(kind) = kind {
            options.kind = kind.to_gpui();
        }

        if let Some(is_movable) = is_movable {
            options.is_movable = is_movable;
        }

        if let Some(is_resizable) = is_resizable {
            options.is_resizable = is_resizable;
        }

        if let Some(is_minimizable) = is_minimizable {
            options.is_minimizable = is_minimizable;
        }

        options.display_id = display_id;

        if let Some(window_background) = window_background {
            options.window_background = window_background.to_gpui();
        }

        options.app_id = app_id;

        if let Some(window_min_size) = window_min_size {
            options.window_min_size = Some(window_min_size.to_gpui());
        }

        if let Some(window_decorations) = window_decorations {
            options.window_decorations = Some(window_decorations.to_gpui());
        }

        options.tabbing_identifier = tabbing_identifier;

        options
    }

    fn from_term(term: &Term) -> Result<Self, String> {
        let map = expect_map(term)?;
        ensure_allowed_fields(
            map,
            &[
                "window_bounds",
                "titlebar",
                "focus",
                "show",
                "kind",
                "is_movable",
                "is_resizable",
                "is_minimizable",
                "display_id",
                "window_background",
                "app_id",
                "window_min_size",
                "window_decorations",
                "tabbing_identifier",
            ],
            "window options",
        )?;

        Ok(Self {
            window_bounds: get_optional_map_field(map, "window_bounds")?
                .map(WindowBoundsConfig::from_map)
                .transpose()?,
            titlebar: match get_field(map, "titlebar") {
                Some(Term::Atom(atom)) if atom.name == "false" => Some(TitlebarConfig::Hidden),
                Some(term) => Some(TitlebarConfig::Custom(TitlebarConfigOptions::from_map(
                    expect_map(term)?,
                )?)),
                None => None,
            },
            focus: get_optional_bool_field(map, "focus")?,
            show: get_optional_bool_field(map, "show")?,
            kind: get_optional_atom_field(map, "kind")?
                .map(parse_window_kind)
                .transpose()?,
            is_movable: get_optional_bool_field(map, "is_movable")?,
            is_resizable: get_optional_bool_field(map, "is_resizable")?,
            is_minimizable: get_optional_bool_field(map, "is_minimizable")?,
            display_id: get_optional_u32_field(map, "display_id")?,
            window_background: get_optional_atom_field(map, "window_background")?
                .map(parse_window_background)
                .transpose()?,
            app_id: get_optional_string_field(map, "app_id")?,
            window_min_size: get_optional_map_field(map, "window_min_size")?
                .map(SizeConfig::from_map)
                .transpose()?,
            window_decorations: get_optional_atom_field(map, "window_decorations")?
                .map(parse_window_decorations)
                .transpose()?,
            tabbing_identifier: get_optional_string_field(map, "tabbing_identifier")?,
        })
    }
}

impl WindowBoundsConfig {
    fn from_map(map: &Map) -> Result<Self, String> {
        ensure_allowed_fields(
            map,
            &["x", "y", "width", "height", "state"],
            "window_bounds",
        )?;

        Ok(Self {
            x: get_optional_i32_field(map, "x")?,
            y: get_optional_i32_field(map, "y")?,
            width: get_u32_field(map, "width")?,
            height: get_u32_field(map, "height")?,
            state: get_optional_atom_field(map, "state")?
                .map(parse_window_bounds_state)
                .transpose()?
                .unwrap_or(WindowBoundsState::Windowed),
        })
    }

    fn into_gpui(self, display_id: Option<DisplayId>, cx: &mut App) -> WindowBounds {
        let size_px = size(px(self.width as f32), px(self.height as f32));

        let bounds = match (self.x, self.y) {
            (Some(x), Some(y)) => Bounds::from_corners(
                point(px(x as f32), px(y as f32)),
                point(
                    px(x as f32 + self.width as f32),
                    px(y as f32 + self.height as f32),
                ),
            ),
            _ => Bounds::centered(display_id, size_px, cx),
        };

        match self.state {
            WindowBoundsState::Windowed => WindowBounds::Windowed(bounds),
            WindowBoundsState::Maximized => WindowBounds::Maximized(bounds),
            WindowBoundsState::Fullscreen => WindowBounds::Fullscreen(bounds),
        }
    }
}

impl TitlebarConfigOptions {
    fn from_map(map: &Map) -> Result<Self, String> {
        ensure_allowed_fields(
            map,
            &["title", "appears_transparent", "traffic_light_position"],
            "titlebar",
        )?;

        Ok(Self {
            title: get_optional_string_field(map, "title")?,
            appears_transparent: get_optional_bool_field(map, "appears_transparent")?,
            traffic_light_position: get_optional_map_field(map, "traffic_light_position")?
                .map(PointConfig::from_map)
                .transpose()?,
        })
    }

    fn into_gpui(self) -> TitlebarOptions {
        TitlebarOptions {
            title: self.title.map(SharedString::from),
            appears_transparent: self.appears_transparent.unwrap_or_default(),
            traffic_light_position: self.traffic_light_position.map(PointConfig::to_gpui),
        }
    }
}

impl PointConfig {
    fn from_map(map: &Map) -> Result<Self, String> {
        ensure_allowed_fields(map, &["x", "y"], "point")?;

        Ok(Self {
            x: get_u32_field(map, "x")?,
            y: get_u32_field(map, "y")?,
        })
    }

    fn to_gpui(self) -> Point<gpui::Pixels> {
        point(px(self.x as f32), px(self.y as f32))
    }
}

impl SizeConfig {
    fn from_map(map: &Map) -> Result<Self, String> {
        ensure_allowed_fields(map, &["width", "height"], "size")?;

        Ok(Self {
            width: get_u32_field(map, "width")?,
            height: get_u32_field(map, "height")?,
        })
    }

    fn to_gpui(self) -> gpui::Size<gpui::Pixels> {
        size(px(self.width as f32), px(self.height as f32))
    }
}

impl WindowKindConfig {
    fn to_gpui(self) -> WindowKind {
        match self {
            Self::Normal => WindowKind::Normal,
            Self::PopUp => WindowKind::PopUp,
            Self::Floating => WindowKind::Floating,
        }
    }
}

impl WindowBackgroundConfig {
    fn to_gpui(self) -> WindowBackgroundAppearance {
        match self {
            Self::Opaque => WindowBackgroundAppearance::Opaque,
            Self::Transparent => WindowBackgroundAppearance::Transparent,
            Self::Blurred => WindowBackgroundAppearance::Blurred,
        }
    }
}

impl WindowDecorationsConfig {
    fn to_gpui(self) -> WindowDecorations {
        match self {
            Self::Server => WindowDecorations::Server,
            Self::Client => WindowDecorations::Client,
        }
    }
}

fn parse_window_bounds_state(value: &str) -> Result<WindowBoundsState, String> {
    match value {
        "windowed" => Ok(WindowBoundsState::Windowed),
        "maximized" => Ok(WindowBoundsState::Maximized),
        "fullscreen" => Ok(WindowBoundsState::Fullscreen),
        _ => Err("invalid window_bounds.state".into()),
    }
}

fn parse_window_kind(value: &str) -> Result<WindowKindConfig, String> {
    match value {
        "normal" => Ok(WindowKindConfig::Normal),
        "popup" | "pop_up" => Ok(WindowKindConfig::PopUp),
        "floating" => Ok(WindowKindConfig::Floating),
        _ => Err("invalid kind".into()),
    }
}

fn parse_window_background(value: &str) -> Result<WindowBackgroundConfig, String> {
    match value {
        "opaque" => Ok(WindowBackgroundConfig::Opaque),
        "transparent" => Ok(WindowBackgroundConfig::Transparent),
        "blurred" => Ok(WindowBackgroundConfig::Blurred),
        _ => Err("invalid window_background".into()),
    }
}

fn display_id_from_raw(id: u32, cx: &mut App) -> Option<DisplayId> {
    cx.displays()
        .iter()
        .map(|display| display.id())
        .find(|display_id| u32::from(*display_id) == id)
}

fn parse_window_decorations(value: &str) -> Result<WindowDecorationsConfig, String> {
    match value {
        "server" => Ok(WindowDecorationsConfig::Server),
        "client" => Ok(WindowDecorationsConfig::Client),
        _ => Err("invalid window_decorations".into()),
    }
}

fn get_field<'a>(map: &'a Map, key: &str) -> Option<&'a Term> {
    etf_decode::get_atom_keyed_field(&map.map, key)
}

fn ensure_allowed_fields(map: &Map, allowed: &[&str], context: &str) -> Result<(), String> {
    etf_decode::ensure_atom_keyed_allowed_fields(&map.map, allowed, context)
}

fn get_optional_map_field<'a>(map: &'a Map, key: &str) -> Result<Option<&'a Map>, String> {
    match get_field(map, key) {
        Some(term) => Ok(Some(expect_map(term)?)),
        None => Ok(None),
    }
}

fn get_optional_bool_field(map: &Map, key: &str) -> Result<Option<bool>, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) => match atom.name.as_str() {
            "true" => Ok(Some(true)),
            "false" => Ok(Some(false)),
            _ => Err(format!("expected boolean for {key}")),
        },
        Some(_) => Err(format!("expected boolean for {key}")),
        None => Ok(None),
    }
}

fn get_optional_string_field(map: &Map, key: &str) -> Result<Option<String>, String> {
    match get_field(map, key) {
        Some(term) => Ok(Some(expect_string(term)?)),
        None => Ok(None),
    }
}

fn get_optional_atom_field<'a>(map: &'a Map, key: &str) -> Result<Option<&'a str>, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) => Ok(Some(atom.name.as_str())),
        Some(_) => Err(format!("expected atom for {key}")),
        None => Ok(None),
    }
}

fn get_u32_field(map: &Map, key: &str) -> Result<u32, String> {
    get_optional_u32_field(map, key)?.ok_or_else(|| format!("missing required field {key}"))
}

fn get_optional_u32_field(map: &Map, key: &str) -> Result<Option<u32>, String> {
    match get_field(map, key) {
        Some(Term::FixInteger(value)) if value.value >= 0 => u32::try_from(value.value)
            .map(Some)
            .map_err(|_| format!("invalid integer for {key}")),
        Some(Term::BigInteger(value)) => value
            .value
            .clone()
            .try_into()
            .map(Some)
            .map_err(|_| format!("invalid integer for {key}")),
        Some(_) => Err(format!("expected positive integer for {key}")),
        None => Ok(None),
    }
}

fn get_optional_i32_field(map: &Map, key: &str) -> Result<Option<i32>, String> {
    match get_field(map, key) {
        Some(Term::FixInteger(value)) => Ok(Some(value.value)),
        Some(Term::BigInteger(value)) => value
            .value
            .clone()
            .try_into()
            .map(Some)
            .map_err(|_| format!("invalid integer for {key}")),
        Some(_) => Err(format!("expected integer for {key}")),
        None => Ok(None),
    }
}

fn expect_map(term: &Term) -> Result<&Map, String> {
    etf_decode::expect_eetf_map(term, "expected map")
}

fn expect_string(term: &Term) -> Result<String, String> {
    etf_decode::term_to_binary_string(term)
}

#[cfg(test)]
#[path = "window_options_tests.rs"]
mod tests;
