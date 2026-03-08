use eetf::{Atom, Binary, ByteList, Map, Term};
use gpui::{
    App, Bounds, DisplayId, Point, SharedString, TitlebarOptions, WindowBackgroundAppearance,
    WindowBounds, WindowDecorations, WindowKind, WindowOptions, point, px, size,
};
use std::io::Cursor;

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
        let term = Term::decode(Cursor::new(bytes)).map_err(|error| error.to_string())?;
        Self::from_term(&term)
    }

    pub(crate) fn to_gpui(&self, cx: &mut App) -> WindowOptions {
        let mut options = WindowOptions::default();
        let display_id = self.display_id.map(display_id_from_raw);

        if let Some(window_bounds) = self.window_bounds.as_ref() {
            options.window_bounds = Some(window_bounds.to_gpui(display_id, cx));
        }

        if let Some(titlebar) = self.titlebar.as_ref() {
            options.titlebar = match titlebar {
                TitlebarConfig::Hidden => None,
                TitlebarConfig::Custom(config) => Some(config.to_gpui()),
            };
        }

        if let Some(focus) = self.focus {
            options.focus = focus;
        }

        if let Some(show) = self.show {
            options.show = show;
        }

        if let Some(kind) = self.kind {
            options.kind = kind.to_gpui();
        }

        if let Some(is_movable) = self.is_movable {
            options.is_movable = is_movable;
        }

        if let Some(is_resizable) = self.is_resizable {
            options.is_resizable = is_resizable;
        }

        if let Some(is_minimizable) = self.is_minimizable {
            options.is_minimizable = is_minimizable;
        }

        options.display_id = display_id;

        if let Some(window_background) = self.window_background {
            options.window_background = window_background.to_gpui();
        }

        if let Some(app_id) = self.app_id.as_ref() {
            options.app_id = Some(app_id.clone());
        }

        if let Some(window_min_size) = self.window_min_size {
            options.window_min_size = Some(window_min_size.to_gpui());
        }

        if let Some(window_decorations) = self.window_decorations {
            options.window_decorations = Some(window_decorations.to_gpui());
        }

        if let Some(tabbing_identifier) = self.tabbing_identifier.as_ref() {
            options.tabbing_identifier = Some(tabbing_identifier.clone());
        }

        options
    }

    fn from_term(term: &Term) -> Result<Self, String> {
        let map = expect_map(term)?;

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

    fn to_gpui(&self, display_id: Option<DisplayId>, cx: &mut App) -> WindowBounds {
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
        Ok(Self {
            title: get_optional_string_field(map, "title")?,
            appears_transparent: get_optional_bool_field(map, "appears_transparent")?,
            traffic_light_position: get_optional_map_field(map, "traffic_light_position")?
                .map(PointConfig::from_map)
                .transpose()?,
        })
    }

    fn to_gpui(&self) -> TitlebarOptions {
        TitlebarOptions {
            title: self
                .title
                .as_ref()
                .map(|title| SharedString::from(title.clone())),
            appears_transparent: self.appears_transparent.unwrap_or_default(),
            traffic_light_position: self.traffic_light_position.map(PointConfig::to_gpui),
        }
    }
}

impl PointConfig {
    fn from_map(map: &Map) -> Result<Self, String> {
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

fn parse_window_bounds_state(value: String) -> Result<WindowBoundsState, String> {
    match value.as_str() {
        "windowed" => Ok(WindowBoundsState::Windowed),
        "maximized" => Ok(WindowBoundsState::Maximized),
        "fullscreen" => Ok(WindowBoundsState::Fullscreen),
        _ => Err("invalid window_bounds.state".into()),
    }
}

fn parse_window_kind(value: String) -> Result<WindowKindConfig, String> {
    match value.as_str() {
        "normal" => Ok(WindowKindConfig::Normal),
        "popup" | "pop_up" => Ok(WindowKindConfig::PopUp),
        "floating" => Ok(WindowKindConfig::Floating),
        _ => Err("invalid kind".into()),
    }
}

fn parse_window_background(value: String) -> Result<WindowBackgroundConfig, String> {
    match value.as_str() {
        "opaque" => Ok(WindowBackgroundConfig::Opaque),
        "transparent" => Ok(WindowBackgroundConfig::Transparent),
        "blurred" => Ok(WindowBackgroundConfig::Blurred),
        _ => Err("invalid window_background".into()),
    }
}

fn display_id_from_raw(id: u32) -> DisplayId {
    unsafe { std::mem::transmute::<u32, DisplayId>(id) }
}

fn parse_window_decorations(value: String) -> Result<WindowDecorationsConfig, String> {
    match value.as_str() {
        "server" => Ok(WindowDecorationsConfig::Server),
        "client" => Ok(WindowDecorationsConfig::Client),
        _ => Err("invalid window_decorations".into()),
    }
}

fn get_field<'a>(map: &'a Map, key: &str) -> Option<&'a Term> {
    map.map
        .iter()
        .find_map(|(current_key, value)| key_matches(current_key, key).then_some(value))
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

fn get_optional_atom_field(map: &Map, key: &str) -> Result<Option<String>, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) => Ok(Some(atom.name.clone())),
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
            .to_string()
            .parse::<u32>()
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
            .to_string()
            .parse::<i32>()
            .map(Some)
            .map_err(|_| format!("invalid integer for {key}")),
        Some(_) => Err(format!("expected integer for {key}")),
        None => Ok(None),
    }
}

fn expect_map(term: &Term) -> Result<&Map, String> {
    match term {
        Term::Map(map) => Ok(map),
        _ => Err("expected map".into()),
    }
}

fn expect_string(term: &Term) -> Result<String, String> {
    match term {
        Term::Binary(Binary { bytes }) => {
            String::from_utf8(bytes.clone()).map_err(|e| e.to_string())
        }
        Term::ByteList(ByteList { bytes }) => {
            String::from_utf8(bytes.clone()).map_err(|e| e.to_string())
        }
        Term::Atom(Atom { name }) => Ok(name.clone()),
        _ => Err("expected string".into()),
    }
}

fn key_matches(term: &Term, expected: &str) -> bool {
    match term {
        Term::Atom(atom) => atom.name == expected,
        Term::Binary(Binary { bytes }) => bytes.as_slice() == expected.as_bytes(),
        Term::ByteList(ByteList { bytes }) => bytes.as_slice() == expected.as_bytes(),
        _ => false,
    }
}
