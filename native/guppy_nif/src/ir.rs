use eetf::{Atom, Binary, ByteList, List, Map, Term, Tuple};
use std::collections::HashMap;
use std::io::Cursor;

pub type DivStyle = Vec<StyleOp>;

#[derive(Clone, Debug, PartialEq)]
pub enum StyleOp {
    Flex,
    FlexCol,
    FlexRow,
    FlexWrap,
    FlexNowrap,
    FlexNone,
    FlexAuto,
    FlexGrow,
    FlexShrink,
    FlexShrink0,
    Flex1,
    SizeFull,
    WFull,
    HFull,
    W32,
    W64,
    W96,
    H32,
    MinW32,
    MinH0,
    MinHFull,
    MaxW64,
    MaxW96,
    MaxWFull,
    MaxH32,
    MaxH96,
    MaxHFull,
    Gap1,
    Gap2,
    Gap4,
    P1,
    P2,
    P4,
    P6,
    P8,
    Px2,
    Py2,
    Pt2,
    Pr2,
    Pb2,
    Pl2,
    M2,
    Mx2,
    My2,
    Mt2,
    Mr2,
    Mb2,
    Ml2,
    Relative,
    Absolute,
    Top0,
    Right0,
    Bottom0,
    Left0,
    Inset0,
    Top1,
    Right1,
    Top2,
    Right2,
    Bottom2,
    Left2,
    TextLeft,
    TextCenter,
    TextRight,
    WhitespaceNormal,
    WhitespaceNowrap,
    Truncate,
    TextEllipsis,
    LineClamp2,
    LineClamp3,
    TextXs,
    TextSm,
    TextBase,
    TextLg,
    TextXl,
    Text2xl,
    Text3xl,
    LeadingNone,
    LeadingTight,
    LeadingSnug,
    LeadingNormal,
    LeadingRelaxed,
    LeadingLoose,
    FontThin,
    FontExtralight,
    FontLight,
    FontNormal,
    FontMedium,
    FontSemibold,
    FontBold,
    FontExtrabold,
    FontBlack,
    Italic,
    NotItalic,
    Underline,
    LineThrough,
    ItemsStart,
    ItemsCenter,
    ItemsEnd,
    JustifyStart,
    JustifyCenter,
    JustifyEnd,
    JustifyBetween,
    JustifyAround,
    CursorPointer,
    RoundedSm,
    RoundedMd,
    RoundedLg,
    RoundedXl,
    Rounded2xl,
    RoundedFull,
    Border1,
    Border2,
    BorderDashed,
    BorderT1,
    BorderR1,
    BorderB1,
    BorderL1,
    ShadowSm,
    ShadowMd,
    ShadowLg,
    OverflowScroll,
    OverflowXScroll,
    OverflowYScroll,
    OverflowHidden,
    OverflowXHidden,
    OverflowYHidden,
    Bg(ColorToken),
    TextColor(ColorToken),
    BorderColor(ColorToken),
    BgHex(String),
    TextColorHex(String),
    BorderColorHex(String),
    Opacity(f32),
    WPx(f32),
    WRem(f32),
    WFrac(f32),
    HPx(f32),
    HRem(f32),
    HFrac(f32),
    ScrollbarWidthPx(f32),
    ScrollbarWidthRem(f32),
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

#[derive(Clone, Debug, PartialEq)]
pub enum IrNode {
    Text {
        id: Option<String>,
        content: String,
        click: Option<String>,
    },
    Div {
        id: Option<String>,
        style: DivStyle,
        hover_style: DivStyle,
        focus_style: DivStyle,
        focusable: bool,
        tab_stop: Option<bool>,
        tab_index: Option<isize>,
        track_scroll: bool,
        anchor_scroll: bool,
        children: Vec<IrNode>,
        click: Option<String>,
        hover: Option<String>,
        focus: Option<String>,
        blur: Option<String>,
        key_down: Option<String>,
        key_up: Option<String>,
        context_menu: Option<String>,
        drag_start: Option<String>,
        drag_move: Option<String>,
        drop: Option<String>,
        mouse_down: Option<String>,
        mouse_up: Option<String>,
        mouse_move: Option<String>,
        scroll_wheel: Option<String>,
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
                    hover_style: get_div_hover_style(map)?,
                    focus_style: get_div_focus_style(map)?,
                    focusable: get_boolean_field(map, "focusable")?,
                    tab_stop: get_optional_boolean_field(map, "tab_stop")?,
                    tab_index: get_optional_integer_field(map, "tab_index")?,
                    track_scroll: get_boolean_field(map, "track_scroll")?,
                    anchor_scroll: get_boolean_field(map, "anchor_scroll")?,
                    children,
                    click: get_click_event(map)?,
                    hover: get_hover_event(map)?,
                    focus: get_focus_event(map)?,
                    blur: get_blur_event(map)?,
                    key_down: get_key_down_event(map)?,
                    key_up: get_key_up_event(map)?,
                    context_menu: get_context_menu_event(map)?,
                    drag_start: get_drag_start_event(map)?,
                    drag_move: get_drag_move_event(map)?,
                    drop: get_drop_event(map)?,
                    mouse_down: get_mouse_down_event(map)?,
                    mouse_up: get_mouse_up_event(map)?,
                    mouse_move: get_mouse_move_event(map)?,
                    scroll_wheel: get_scroll_wheel_event(map)?,
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

fn get_boolean_field(map: &HashMap<Term, Term>, key: &str) -> Result<bool, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) if atom.name == "true" => Ok(true),
        Some(Term::Atom(atom)) if atom.name == "false" => Ok(false),
        Some(other) => Err(format!("expected boolean field {key}, got {other}")),
        None => Ok(false),
    }
}

fn get_optional_boolean_field(
    map: &HashMap<Term, Term>,
    key: &str,
) -> Result<Option<bool>, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) if atom.name == "true" => Ok(Some(true)),
        Some(Term::Atom(atom)) if atom.name == "false" => Ok(Some(false)),
        Some(other) => Err(format!("expected optional boolean field {key}, got {other}")),
        None => Ok(None),
    }
}

fn get_optional_integer_field(
    map: &HashMap<Term, Term>,
    key: &str,
) -> Result<Option<isize>, String> {
    match get_field(map, key) {
        Some(Term::FixInteger(value)) => Ok(Some(value.value as isize)),
        Some(Term::BigInteger(value)) => value
            .to_string()
            .parse::<isize>()
            .map(Some)
            .map_err(|error| format!("invalid integer field {key}: {error}")),
        Some(other) => Err(format!("expected optional integer field {key}, got {other}")),
        None => Ok(None),
    }
}

fn get_div_style(map: &HashMap<Term, Term>) -> Result<DivStyle, String> {
    get_style_list_field(map, "style")
}

fn get_div_hover_style(map: &HashMap<Term, Term>) -> Result<DivStyle, String> {
    get_style_list_field(map, "hover_style")
}

fn get_div_focus_style(map: &HashMap<Term, Term>) -> Result<DivStyle, String> {
    get_style_list_field(map, "focus_style")
}

fn get_style_list_field(map: &HashMap<Term, Term>, key: &str) -> Result<DivStyle, String> {
    let Some(style_term) = get_field(map, key) else {
        return Ok(Vec::new());
    };

    let style_list = get_list(style_term)?;
    style_list.iter().map(parse_style_op).collect()
}

fn parse_style_op(term: &Term) -> Result<StyleOp, String> {
    match term {
        Term::Atom(atom) => parse_style_flag(&atom.name),
        Term::Tuple(Tuple { elements }) if elements.len() == 2 => {
            let key = match &elements[0] {
                Term::Atom(atom) => atom.name.as_str(),
                other => return Err(format!("expected style tuple key atom, got {other}")),
            };

            match key {
                "bg" => Ok(StyleOp::Bg(parse_atom_color(&elements[1])?)),
                "text_color" => Ok(StyleOp::TextColor(parse_atom_color(&elements[1])?)),
                "border_color" => Ok(StyleOp::BorderColor(parse_atom_color(&elements[1])?)),
                "bg_hex" => Ok(StyleOp::BgHex(term_to_string(&elements[1])?)),
                "text_color_hex" => Ok(StyleOp::TextColorHex(term_to_string(&elements[1])?)),
                "border_color_hex" => Ok(StyleOp::BorderColorHex(term_to_string(&elements[1])?)),
                "opacity" => Ok(StyleOp::Opacity(parse_f32(&elements[1])?)),
                "w_px" => Ok(StyleOp::WPx(parse_f32(&elements[1])?)),
                "w_rem" => Ok(StyleOp::WRem(parse_f32(&elements[1])?)),
                "w_frac" => Ok(StyleOp::WFrac(parse_f32(&elements[1])?)),
                "h_px" => Ok(StyleOp::HPx(parse_f32(&elements[1])?)),
                "h_rem" => Ok(StyleOp::HRem(parse_f32(&elements[1])?)),
                "h_frac" => Ok(StyleOp::HFrac(parse_f32(&elements[1])?)),
                "scrollbar_width_px" => Ok(StyleOp::ScrollbarWidthPx(parse_f32(&elements[1])?)),
                "scrollbar_width_rem" => Ok(StyleOp::ScrollbarWidthRem(parse_f32(&elements[1])?)),
                other => Err(format!("unsupported style tuple key: {other}")),
            }
        }
        other => Err(format!("unsupported style op: {other}")),
    }
}

fn parse_style_flag(token: &str) -> Result<StyleOp, String> {
    match token {
        "flex" => Ok(StyleOp::Flex),
        "flex_col" => Ok(StyleOp::FlexCol),
        "flex_row" => Ok(StyleOp::FlexRow),
        "flex_wrap" => Ok(StyleOp::FlexWrap),
        "flex_nowrap" => Ok(StyleOp::FlexNowrap),
        "flex_none" => Ok(StyleOp::FlexNone),
        "flex_auto" => Ok(StyleOp::FlexAuto),
        "flex_grow" => Ok(StyleOp::FlexGrow),
        "flex_shrink" => Ok(StyleOp::FlexShrink),
        "flex_shrink_0" => Ok(StyleOp::FlexShrink0),
        "flex_1" => Ok(StyleOp::Flex1),
        "size_full" => Ok(StyleOp::SizeFull),
        "w_full" => Ok(StyleOp::WFull),
        "h_full" => Ok(StyleOp::HFull),
        "w_32" => Ok(StyleOp::W32),
        "w_64" => Ok(StyleOp::W64),
        "w_96" => Ok(StyleOp::W96),
        "h_32" => Ok(StyleOp::H32),
        "min_w_32" => Ok(StyleOp::MinW32),
        "min_h_0" => Ok(StyleOp::MinH0),
        "min_h_full" => Ok(StyleOp::MinHFull),
        "max_w_64" => Ok(StyleOp::MaxW64),
        "max_w_96" => Ok(StyleOp::MaxW96),
        "max_w_full" => Ok(StyleOp::MaxWFull),
        "max_h_32" => Ok(StyleOp::MaxH32),
        "max_h_96" => Ok(StyleOp::MaxH96),
        "max_h_full" => Ok(StyleOp::MaxHFull),
        "gap_1" => Ok(StyleOp::Gap1),
        "gap_2" => Ok(StyleOp::Gap2),
        "gap_4" => Ok(StyleOp::Gap4),
        "p_1" => Ok(StyleOp::P1),
        "p_2" => Ok(StyleOp::P2),
        "p_4" => Ok(StyleOp::P4),
        "p_6" => Ok(StyleOp::P6),
        "p_8" => Ok(StyleOp::P8),
        "px_2" => Ok(StyleOp::Px2),
        "py_2" => Ok(StyleOp::Py2),
        "pt_2" => Ok(StyleOp::Pt2),
        "pr_2" => Ok(StyleOp::Pr2),
        "pb_2" => Ok(StyleOp::Pb2),
        "pl_2" => Ok(StyleOp::Pl2),
        "m_2" => Ok(StyleOp::M2),
        "mx_2" => Ok(StyleOp::Mx2),
        "my_2" => Ok(StyleOp::My2),
        "mt_2" => Ok(StyleOp::Mt2),
        "mr_2" => Ok(StyleOp::Mr2),
        "mb_2" => Ok(StyleOp::Mb2),
        "ml_2" => Ok(StyleOp::Ml2),
        "relative" => Ok(StyleOp::Relative),
        "absolute" => Ok(StyleOp::Absolute),
        "top_0" => Ok(StyleOp::Top0),
        "right_0" => Ok(StyleOp::Right0),
        "bottom_0" => Ok(StyleOp::Bottom0),
        "left_0" => Ok(StyleOp::Left0),
        "inset_0" => Ok(StyleOp::Inset0),
        "top_1" => Ok(StyleOp::Top1),
        "right_1" => Ok(StyleOp::Right1),
        "top_2" => Ok(StyleOp::Top2),
        "right_2" => Ok(StyleOp::Right2),
        "bottom_2" => Ok(StyleOp::Bottom2),
        "left_2" => Ok(StyleOp::Left2),
        "text_left" => Ok(StyleOp::TextLeft),
        "text_center" => Ok(StyleOp::TextCenter),
        "text_right" => Ok(StyleOp::TextRight),
        "whitespace_normal" => Ok(StyleOp::WhitespaceNormal),
        "whitespace_nowrap" => Ok(StyleOp::WhitespaceNowrap),
        "truncate" => Ok(StyleOp::Truncate),
        "text_ellipsis" => Ok(StyleOp::TextEllipsis),
        "line_clamp_2" => Ok(StyleOp::LineClamp2),
        "line_clamp_3" => Ok(StyleOp::LineClamp3),
        "text_xs" => Ok(StyleOp::TextXs),
        "text_sm" => Ok(StyleOp::TextSm),
        "text_base" => Ok(StyleOp::TextBase),
        "text_lg" => Ok(StyleOp::TextLg),
        "text_xl" => Ok(StyleOp::TextXl),
        "text_2xl" => Ok(StyleOp::Text2xl),
        "text_3xl" => Ok(StyleOp::Text3xl),
        "leading_none" => Ok(StyleOp::LeadingNone),
        "leading_tight" => Ok(StyleOp::LeadingTight),
        "leading_snug" => Ok(StyleOp::LeadingSnug),
        "leading_normal" => Ok(StyleOp::LeadingNormal),
        "leading_relaxed" => Ok(StyleOp::LeadingRelaxed),
        "leading_loose" => Ok(StyleOp::LeadingLoose),
        "font_thin" => Ok(StyleOp::FontThin),
        "font_extralight" => Ok(StyleOp::FontExtralight),
        "font_light" => Ok(StyleOp::FontLight),
        "font_normal" => Ok(StyleOp::FontNormal),
        "font_medium" => Ok(StyleOp::FontMedium),
        "font_semibold" => Ok(StyleOp::FontSemibold),
        "font_bold" => Ok(StyleOp::FontBold),
        "font_extrabold" => Ok(StyleOp::FontExtrabold),
        "font_black" => Ok(StyleOp::FontBlack),
        "italic" => Ok(StyleOp::Italic),
        "not_italic" => Ok(StyleOp::NotItalic),
        "underline" => Ok(StyleOp::Underline),
        "line_through" => Ok(StyleOp::LineThrough),
        "items_start" => Ok(StyleOp::ItemsStart),
        "items_center" => Ok(StyleOp::ItemsCenter),
        "items_end" => Ok(StyleOp::ItemsEnd),
        "justify_start" => Ok(StyleOp::JustifyStart),
        "justify_center" => Ok(StyleOp::JustifyCenter),
        "justify_end" => Ok(StyleOp::JustifyEnd),
        "justify_between" => Ok(StyleOp::JustifyBetween),
        "justify_around" => Ok(StyleOp::JustifyAround),
        "cursor_pointer" => Ok(StyleOp::CursorPointer),
        "rounded_sm" => Ok(StyleOp::RoundedSm),
        "rounded_md" => Ok(StyleOp::RoundedMd),
        "rounded_lg" => Ok(StyleOp::RoundedLg),
        "rounded_xl" => Ok(StyleOp::RoundedXl),
        "rounded_2xl" => Ok(StyleOp::Rounded2xl),
        "rounded_full" => Ok(StyleOp::RoundedFull),
        "border_1" => Ok(StyleOp::Border1),
        "border_2" => Ok(StyleOp::Border2),
        "border_dashed" => Ok(StyleOp::BorderDashed),
        "border_t_1" => Ok(StyleOp::BorderT1),
        "border_r_1" => Ok(StyleOp::BorderR1),
        "border_b_1" => Ok(StyleOp::BorderB1),
        "border_l_1" => Ok(StyleOp::BorderL1),
        "shadow_sm" => Ok(StyleOp::ShadowSm),
        "shadow_md" => Ok(StyleOp::ShadowMd),
        "shadow_lg" => Ok(StyleOp::ShadowLg),
        "overflow_scroll" => Ok(StyleOp::OverflowScroll),
        "overflow_x_scroll" => Ok(StyleOp::OverflowXScroll),
        "overflow_y_scroll" => Ok(StyleOp::OverflowYScroll),
        "overflow_hidden" => Ok(StyleOp::OverflowHidden),
        "overflow_x_hidden" => Ok(StyleOp::OverflowXHidden),
        "overflow_y_hidden" => Ok(StyleOp::OverflowYHidden),
        other => Err(format!("unsupported style token: {other}")),
    }
}

fn parse_atom_color(term: &Term) -> Result<ColorToken, String> {
    match term {
        Term::Atom(atom) => parse_color_token(&atom.name),
        other => Err(format!("expected style tuple value atom, got {other}")),
    }
}

fn parse_f32(term: &Term) -> Result<f32, String> {
    match term {
        Term::FixInteger(value) => Ok(value.value as f32),
        Term::BigInteger(value) => value
            .to_string()
            .parse::<f32>()
            .map_err(|error| format!("invalid numeric style value {value}: {error}")),
        Term::Float(value) => Ok(value.value as f32),
        other => Err(format!("expected numeric style tuple value, got {other}")),
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
    get_optional_event(map, "click")
}

fn get_hover_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "hover")
}

fn get_focus_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "focus")
}

fn get_blur_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "blur")
}

fn get_key_down_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "key_down")
}

fn get_key_up_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "key_up")
}

fn get_context_menu_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "context_menu")
}

fn get_drag_start_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "drag_start")
}

fn get_drag_move_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "drag_move")
}

fn get_drop_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "drop")
}

fn get_mouse_down_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "mouse_down")
}

fn get_mouse_up_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "mouse_up")
}

fn get_mouse_move_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "mouse_move")
}

fn get_scroll_wheel_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "scroll_wheel")
}

fn get_optional_event(map: &HashMap<Term, Term>, key: &str) -> Result<Option<String>, String> {
    let Some(events_term) = get_field(map, "events") else {
        return Ok(None);
    };

    let events = expect_map(events_term)?;

    match get_field(events, key) {
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
