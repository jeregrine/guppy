use eetf::{Atom, Binary, ByteList, List, Map, Term, Tuple};
use gpui::{KeybindingKeystroke, Keystroke};
use std::collections::{HashMap, HashSet};
use std::io::Cursor;
use std::sync::{Arc, OnceLock};

pub type DivStyle = Arc<[StyleOp]>;

static IR_FIELD_KEYS: OnceLock<IrFieldKeys> = OnceLock::new();

struct IrFieldKeys {
    kind: Term,
    id: Term,
    content: Term,
    runs: Term,
    text: Term,
    value: Term,
    placeholder: Term,
    children: Term,
    items: Term,
    columns: Term,
    rows: Term,
    cells: Term,
    column_id: Term,
    width: Term,
    sortable: Term,
    header_style: Term,
    row_style: Term,
    cell_style: Term,
    selected_row_id: Term,
    selected_cell: Term,
    sort: Term,
    row_click: Term,
    cell_click: Term,
    direction: Term,
    nodes: Term,
    selected_id: Term,
    expanded: Term,
    select: Term,
    toggle: Term,
    commands: Term,
    op: Term,
    x: Term,
    y: Term,
    height: Term,
    fill: Term,
    color: Term,
    line_width: Term,
    interval: Term,
    radius: Term,
    options: Term,
    axis: Term,
    style: Term,
    item_style: Term,
    list_style: Term,
    option_style: Term,
    hover_style: Term,
    focus_style: Term,
    focus_visible_style: Term,
    in_focus_style: Term,
    active_style: Term,
    disabled_style: Term,
    animation: Term,
    duration_ms: Term,
    repeat: Term,
    from: Term,
    to: Term,
    disabled: Term,
    tab_index: Term,
    actions: Term,
    shortcuts: Term,
    label: Term,
    open: Term,
    events: Term,
    click: Term,
    close: Term,
    hover: Term,
    focus: Term,
    blur: Term,
    change: Term,
    key_down: Term,
    key_up: Term,
    context_menu: Term,
    drag_start: Term,
    drag_move: Term,
    drop: Term,
    mouse_down: Term,
    mouse_up: Term,
    mouse_move: Term,
    scroll_wheel: Term,
    stack_priority: Term,
    occlude: Term,
    focusable: Term,
    tab_stop: Term,
    track_scroll: Term,
    anchor_scroll: Term,
    tooltip: Term,
    source: Term,
    popover_style: Term,
    anchor: Term,
    anchor_position: Term,
    anchor_offset: Term,
    anchor_position_mode: Term,
    anchor_fit: Term,
    snap_margin: Term,
    close_on_click_outside: Term,
    object_fit: Term,
    grayscale: Term,
    checked: Term,
}

impl IrFieldKeys {
    fn new() -> Self {
        Self {
            kind: atom_term("kind"),
            id: atom_term("id"),
            content: atom_term("content"),
            runs: atom_term("runs"),
            text: atom_term("text"),
            value: atom_term("value"),
            placeholder: atom_term("placeholder"),
            children: atom_term("children"),
            items: atom_term("items"),
            columns: atom_term("columns"),
            rows: atom_term("rows"),
            cells: atom_term("cells"),
            column_id: atom_term("column_id"),
            width: atom_term("width"),
            sortable: atom_term("sortable"),
            header_style: atom_term("header_style"),
            row_style: atom_term("row_style"),
            cell_style: atom_term("cell_style"),
            selected_row_id: atom_term("selected_row_id"),
            selected_cell: atom_term("selected_cell"),
            sort: atom_term("sort"),
            row_click: atom_term("row_click"),
            cell_click: atom_term("cell_click"),
            direction: atom_term("direction"),
            nodes: atom_term("nodes"),
            selected_id: atom_term("selected_id"),
            expanded: atom_term("expanded"),
            select: atom_term("select"),
            toggle: atom_term("toggle"),
            commands: atom_term("commands"),
            op: atom_term("op"),
            x: atom_term("x"),
            y: atom_term("y"),
            height: atom_term("height"),
            fill: atom_term("fill"),
            color: atom_term("color"),
            line_width: atom_term("line_width"),
            interval: atom_term("interval"),
            radius: atom_term("radius"),
            options: atom_term("options"),
            axis: atom_term("axis"),
            style: atom_term("style"),
            item_style: atom_term("item_style"),
            list_style: atom_term("list_style"),
            option_style: atom_term("option_style"),
            hover_style: atom_term("hover_style"),
            focus_style: atom_term("focus_style"),
            focus_visible_style: atom_term("focus_visible_style"),
            in_focus_style: atom_term("in_focus_style"),
            active_style: atom_term("active_style"),
            disabled_style: atom_term("disabled_style"),
            animation: atom_term("animation"),
            duration_ms: atom_term("duration_ms"),
            repeat: atom_term("repeat"),
            from: atom_term("from"),
            to: atom_term("to"),
            disabled: atom_term("disabled"),
            tab_index: atom_term("tab_index"),
            actions: atom_term("actions"),
            shortcuts: atom_term("shortcuts"),
            label: atom_term("label"),
            open: atom_term("open"),
            events: atom_term("events"),
            click: atom_term("click"),
            close: atom_term("close"),
            hover: atom_term("hover"),
            focus: atom_term("focus"),
            blur: atom_term("blur"),
            change: atom_term("change"),
            key_down: atom_term("key_down"),
            key_up: atom_term("key_up"),
            context_menu: atom_term("context_menu"),
            drag_start: atom_term("drag_start"),
            drag_move: atom_term("drag_move"),
            drop: atom_term("drop"),
            mouse_down: atom_term("mouse_down"),
            mouse_up: atom_term("mouse_up"),
            mouse_move: atom_term("mouse_move"),
            scroll_wheel: atom_term("scroll_wheel"),
            stack_priority: atom_term("stack_priority"),
            occlude: atom_term("occlude"),
            focusable: atom_term("focusable"),
            tab_stop: atom_term("tab_stop"),
            track_scroll: atom_term("track_scroll"),
            anchor_scroll: atom_term("anchor_scroll"),
            tooltip: atom_term("tooltip"),
            source: atom_term("source"),
            popover_style: atom_term("popover_style"),
            anchor: atom_term("anchor"),
            anchor_position: atom_term("anchor_position"),
            anchor_offset: atom_term("anchor_offset"),
            anchor_position_mode: atom_term("anchor_position_mode"),
            anchor_fit: atom_term("anchor_fit"),
            snap_margin: atom_term("snap_margin"),
            close_on_click_outside: atom_term("close_on_click_outside"),
            object_fit: atom_term("object_fit"),
            grayscale: atom_term("grayscale"),
            checked: atom_term("checked"),
        }
    }
}

fn atom_term(name: &str) -> Term {
    Term::Atom(Atom::from(name))
}

fn field_keys() -> &'static IrFieldKeys {
    IR_FIELD_KEYS.get_or_init(IrFieldKeys::new)
}

#[derive(Clone, Debug, PartialEq)]
pub struct ShortcutBinding {
    pub shortcut: String,
    pub action: String,
    pub callback: String,
    pub parsed: KeybindingKeystroke,
}

#[derive(Clone, Debug, PartialEq)]
pub enum StyleOp {
    Grid,
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
    ColSpanFull,
    RowSpanFull,
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
    BgLinearGradient {
        angle: f32,
        from: LinearGradientStop,
        to: LinearGradientStop,
    },
    Opacity(f32),
    GridCols(u16),
    GridRows(u16),
    ColSpan(u16),
    RowSpan(u16),
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
pub enum ScrollAxis {
    X,
    Y,
    Both,
}

#[derive(Clone, Debug, PartialEq)]
pub enum StyleColor {
    Token(ColorToken),
    Hex(String),
}

#[derive(Clone, Debug, PartialEq)]
pub struct LinearGradientStop {
    pub color: StyleColor,
    pub percentage: f32,
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
pub enum ImageSource {
    Auto(String),
    Uri(String),
    Path(String),
    Embedded(String),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ImageObjectFit {
    Fill,
    Contain,
    Cover,
    ScaleDown,
    None,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PopoverAnchor {
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PopoverAnchorPositionMode {
    Window,
    Local,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PopoverAnchorFit {
    SwitchAnchor,
    SnapToWindow,
    SnapToWindowWithMargin,
}

#[derive(Clone, Debug, PartialEq)]
pub struct CheckboxNode {
    pub id: Option<String>,
    pub label: String,
    pub checked: bool,
    pub style: DivStyle,
    pub hover_style: DivStyle,
    pub focus_style: DivStyle,
    pub focus_visible_style: DivStyle,
    pub in_focus_style: DivStyle,
    pub active_style: DivStyle,
    pub disabled_style: DivStyle,
    pub disabled: bool,
    pub tab_index: Option<isize>,
    pub change: Option<String>,
    pub focus: Option<String>,
    pub blur: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TextRunSegment {
    pub text: String,
    pub style: DivStyle,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RadioNode {
    pub id: Option<String>,
    pub label: String,
    pub value: String,
    pub checked: bool,
    pub style: DivStyle,
    pub hover_style: DivStyle,
    pub focus_style: DivStyle,
    pub focus_visible_style: DivStyle,
    pub in_focus_style: DivStyle,
    pub active_style: DivStyle,
    pub disabled_style: DivStyle,
    pub disabled: bool,
    pub tab_index: Option<isize>,
    pub change: Option<String>,
    pub focus: Option<String>,
    pub blur: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct UniformListItem {
    pub id: String,
    pub label: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ListItem {
    pub id: String,
    pub children: Arc<[IrNode]>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum DataTableColumnWidth {
    Auto,
    Px(f32),
    Fr(u32),
}

#[derive(Clone, Debug, PartialEq)]
pub struct DataTableColumn {
    pub id: String,
    pub label: String,
    pub width: DataTableColumnWidth,
    pub sortable: bool,
    pub style: DivStyle,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DataTableCell {
    pub column_id: String,
    pub children: Arc<[IrNode]>,
    pub style: DivStyle,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DataTableRow {
    pub id: String,
    pub cells: Arc<[DataTableCell]>,
    pub style: DivStyle,
}

#[derive(Clone, Debug, PartialEq)]
pub enum DataTableSortDirection {
    Asc,
    Desc,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DataTableSort {
    pub column_id: String,
    pub direction: DataTableSortDirection,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DataTableNode {
    pub id: Option<String>,
    pub columns: Arc<[DataTableColumn]>,
    pub rows: Arc<[DataTableRow]>,
    pub style: DivStyle,
    pub header_style: DivStyle,
    pub row_style: DivStyle,
    pub cell_style: DivStyle,
    pub selected_row_id: Option<String>,
    pub selected_cell: Option<(String, String)>,
    pub sort: Option<DataTableSort>,
    pub row_click: Option<String>,
    pub cell_click: Option<String>,
    pub sort_callback: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TreeItem {
    pub id: String,
    pub label: String,
    pub expanded: bool,
    pub children: Arc<[TreeItem]>,
    pub style: DivStyle,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TreeNode {
    pub id: Option<String>,
    pub nodes: Arc<[TreeItem]>,
    pub style: DivStyle,
    pub row_style: DivStyle,
    pub selected_id: Option<String>,
    pub select: Option<String>,
    pub toggle: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum CanvasCommand {
    Rect {
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        fill: StyleColor,
        radius: f32,
    },
    PatternRect {
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        color: StyleColor,
        line_width: f32,
        interval: f32,
        radius: f32,
    },
}

#[derive(Clone, Debug, PartialEq)]
pub struct CanvasNode {
    pub id: Option<String>,
    pub commands: Arc<[CanvasCommand]>,
    pub style: DivStyle,
    pub click: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct SelectOption {
    pub value: String,
    pub label: String,
    pub disabled: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct SelectNode {
    pub id: Option<String>,
    pub value: Option<String>,
    pub open: bool,
    pub placeholder: String,
    pub options: Arc<[SelectOption]>,
    pub style: DivStyle,
    pub list_style: DivStyle,
    pub option_style: DivStyle,
    pub disabled: bool,
    pub tab_index: Option<isize>,
    pub click: Option<String>,
    pub change: Option<String>,
    pub close: Option<String>,
    pub focus: Option<String>,
    pub blur: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct AnimationSpec {
    pub id: String,
    pub duration_ms: u64,
    pub repeat: bool,
    pub from: f32,
    pub to: f32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DivNode {
    pub id: Option<String>,
    pub style: DivStyle,
    pub hover_style: DivStyle,
    pub focus_style: DivStyle,
    pub focus_visible_style: DivStyle,
    pub in_focus_style: DivStyle,
    pub active_style: DivStyle,
    pub disabled_style: DivStyle,
    pub animation: Option<AnimationSpec>,
    pub disabled: bool,
    pub stack_priority: Option<usize>,
    pub occlude: bool,
    pub focusable: bool,
    pub tab_stop: Option<bool>,
    pub tab_index: Option<isize>,
    pub track_scroll: bool,
    pub anchor_scroll: bool,
    pub tooltip: Option<String>,
    pub shortcuts: Arc<[ShortcutBinding]>,
    pub children: Arc<[IrNode]>,
    pub click: Option<String>,
    pub hover: Option<String>,
    pub focus: Option<String>,
    pub blur: Option<String>,
    pub key_down: Option<String>,
    pub key_up: Option<String>,
    pub context_menu: Option<String>,
    pub drag_start: Option<String>,
    pub drag_move: Option<String>,
    pub drop: Option<String>,
    pub mouse_down: Option<String>,
    pub mouse_up: Option<String>,
    pub mouse_move: Option<String>,
    pub scroll_wheel: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum IrNode {
    Text {
        id: Option<String>,
        content: String,
        runs: Arc<[TextRunSegment]>,
        style: DivStyle,
        click: Option<String>,
    },
    TextInput {
        id: Option<String>,
        value: String,
        placeholder: String,
        style: DivStyle,
        disabled: bool,
        tab_index: Option<isize>,
        change: Option<String>,
        focus: Option<String>,
        blur: Option<String>,
    },
    Textarea {
        id: Option<String>,
        value: String,
        placeholder: String,
        style: DivStyle,
        disabled: bool,
        tab_index: Option<isize>,
        change: Option<String>,
        focus: Option<String>,
        blur: Option<String>,
    },
    Scroll {
        id: Option<String>,
        axis: ScrollAxis,
        style: DivStyle,
        children: Arc<[IrNode]>,
    },
    Image {
        id: Option<String>,
        source: ImageSource,
        style: DivStyle,
        object_fit: ImageObjectFit,
        grayscale: bool,
    },
    Icon {
        id: Option<String>,
        source: ImageSource,
        style: DivStyle,
    },
    Button(Box<DivNode>),
    Checkbox(Box<CheckboxNode>),
    Radio(Box<RadioNode>),
    UniformList {
        id: Option<String>,
        items: Arc<[UniformListItem]>,
        style: DivStyle,
        item_style: DivStyle,
        click: Option<String>,
    },
    List {
        id: Option<String>,
        items: Arc<[ListItem]>,
        style: DivStyle,
        item_style: DivStyle,
        click: Option<String>,
    },
    DataTable(Box<DataTableNode>),
    Tree(Box<TreeNode>),
    Canvas(Box<CanvasNode>),
    Select(Box<SelectNode>),
    Popover {
        id: Option<String>,
        label: String,
        open: bool,
        style: DivStyle,
        popover_style: DivStyle,
        anchor: PopoverAnchor,
        anchor_position: Option<(f32, f32)>,
        anchor_offset: Option<(f32, f32)>,
        anchor_position_mode: PopoverAnchorPositionMode,
        anchor_fit: PopoverAnchorFit,
        snap_margin: f32,
        close_on_click_outside: bool,
        stack_priority: Option<usize>,
        disabled: bool,
        click: Option<String>,
        close: Option<String>,
        children: Arc<[IrNode]>,
    },
    Spacer {
        id: Option<String>,
        style: DivStyle,
    },
    Div(Box<DivNode>),
}

impl IrNode {
    pub fn text(content: impl Into<String>) -> Self {
        Self::Text {
            id: None,
            content: content.into(),
            runs: Arc::new([]),
            style: Vec::new().into(),
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
            "text" => {
                let content = get_string_field(map, "content")?;
                let runs = get_text_runs_field(map, &content)?;

                Ok(Self::Text {
                    id,
                    content,
                    runs,
                    style: get_div_style(map)?,
                    click: get_click_event(map)?,
                })
            }
            "text_input" => Ok(Self::TextInput {
                id,
                value: get_string_field(map, "value")?,
                placeholder: get_optional_string_field(map, "placeholder")?.unwrap_or_default(),
                style: get_div_style(map)?,
                disabled: get_boolean_field(map, "disabled")?,
                tab_index: get_optional_integer_field(map, "tab_index")?,
                change: get_change_event(map)?,
                focus: get_focus_event(map)?,
                blur: get_blur_event(map)?,
            }),
            "textarea" => Ok(Self::Textarea {
                id,
                value: get_string_field(map, "value")?,
                placeholder: get_optional_string_field(map, "placeholder")?.unwrap_or_default(),
                style: get_div_style(map)?,
                disabled: get_boolean_field(map, "disabled")?,
                tab_index: get_optional_integer_field(map, "tab_index")?,
                change: get_change_event(map)?,
                focus: get_focus_event(map)?,
                blur: get_blur_event(map)?,
            }),
            "scroll" => Ok(Self::Scroll {
                id,
                axis: get_scroll_axis_field(map)?,
                style: get_div_style(map)?,
                children: get_child_nodes_field(map)?,
            }),
            "uniform_list" => Ok(Self::UniformList {
                id,
                items: get_uniform_list_items_field(map)?,
                style: get_div_style(map)?,
                item_style: get_style_list_field(map, "item_style")?,
                click: get_click_event(map)?,
            }),
            "list" => Ok(Self::List {
                id,
                items: get_list_items_field(map)?,
                style: get_div_style(map)?,
                item_style: get_style_list_field(map, "item_style")?,
                click: get_click_event(map)?,
            }),
            "data_table" => {
                let columns = get_data_table_columns_field(map)?;
                let column_ids = columns
                    .iter()
                    .map(|column| column.id.as_str())
                    .collect::<HashSet<_>>();
                let rows = get_data_table_rows_field(map, &column_ids)?;
                let row_ids = rows
                    .iter()
                    .map(|row| row.id.as_str())
                    .collect::<HashSet<_>>();
                let selected_row_id = get_optional_string_field(map, "selected_row_id")?;
                ensure_optional_id_known(
                    selected_row_id.as_deref(),
                    &row_ids,
                    "unknown data_table selected row",
                )?;
                let selected_cell = get_optional_string_pair_field(map, "selected_cell")?;
                if let Some((row_id, column_id)) = selected_cell.as_ref() {
                    ensure_id_known(row_id, &row_ids, "unknown data_table selected row")?;
                    ensure_id_known(column_id, &column_ids, "unknown data_table selected column")?;
                }
                let sort = get_data_table_sort_field(map, &column_ids)?;

                Ok(Self::DataTable(Box::new(DataTableNode {
                    id,
                    columns,
                    rows,
                    style: get_div_style(map)?,
                    header_style: get_style_list_field(map, "header_style")?,
                    row_style: get_style_list_field(map, "row_style")?,
                    cell_style: get_style_list_field(map, "cell_style")?,
                    selected_row_id,
                    selected_cell,
                    sort,
                    row_click: get_optional_event(map, "row_click")?,
                    cell_click: get_optional_event(map, "cell_click")?,
                    sort_callback: get_optional_event(map, "sort")?,
                })))
            }
            "tree" => Ok(Self::Tree(Box::new(TreeNode {
                id,
                nodes: get_tree_nodes_field(map)?,
                style: get_div_style(map)?,
                row_style: get_style_list_field(map, "row_style")?,
                selected_id: get_optional_string_field(map, "selected_id")?,
                select: get_optional_event(map, "select")?,
                toggle: get_optional_event(map, "toggle")?,
            }))),
            "canvas" => Ok(Self::Canvas(Box::new(CanvasNode {
                id,
                commands: get_canvas_commands_field(map)?,
                style: get_div_style(map)?,
                click: get_click_event(map)?,
            }))),
            "select" => Ok(Self::Select(Box::new(SelectNode {
                id,
                value: get_optional_string_field(map, "value")?,
                open: get_boolean_field(map, "open")?,
                placeholder: get_optional_string_field(map, "placeholder")?
                    .unwrap_or_else(|| "Select…".into()),
                options: get_select_options_field(map)?,
                style: get_div_style(map)?,
                list_style: get_style_list_field(map, "list_style")?,
                option_style: get_style_list_field(map, "option_style")?,
                disabled: get_boolean_field(map, "disabled")?,
                tab_index: get_optional_integer_field(map, "tab_index")?,
                click: get_click_event(map)?,
                change: get_change_event(map)?,
                close: get_close_event(map)?,
                focus: get_focus_event(map)?,
                blur: get_blur_event(map)?,
            }))),
            "popover" => Ok(Self::Popover {
                id,
                label: get_string_field(map, "label")?,
                open: get_required_boolean_field(map, "open")?,
                style: get_div_style(map)?,
                popover_style: get_style_list_field(map, "popover_style")?,
                anchor: get_popover_anchor_field(map)?,
                anchor_position: get_optional_point_field(map, "anchor_position")?,
                anchor_offset: get_optional_point_field(map, "anchor_offset")?,
                anchor_position_mode: get_popover_anchor_position_mode_field(map)?,
                anchor_fit: get_popover_anchor_fit_field(map)?,
                snap_margin: get_non_neg_f32_field(map, "snap_margin", 8.0)?,
                close_on_click_outside: get_boolean_field(map, "close_on_click_outside")?
                    || get_field(map, "close_on_click_outside").is_none(),
                stack_priority: get_optional_usize_field(map, "stack_priority")?.or(Some(1)),
                disabled: get_boolean_field(map, "disabled")?,
                click: get_click_event(map)?,
                close: get_close_event(map)?,
                children: get_child_nodes_field(map)?,
            }),
            "image" => Ok(Self::Image {
                id,
                source: get_image_source_field(map)?,
                style: get_div_style(map)?,
                object_fit: get_image_object_fit_field(map)?,
                grayscale: get_boolean_field(map, "grayscale")?,
            }),
            "icon" => Ok(Self::Icon {
                id,
                source: get_image_source_field(map)?,
                style: get_div_style(map)?,
            }),
            "checkbox" => Ok(Self::Checkbox(Box::new(decode_checkbox_node(map, id)?))),
            "radio" => Ok(Self::Radio(Box::new(decode_radio_node(map, id)?))),
            "spacer" => Ok(Self::Spacer {
                id,
                style: get_div_style(map)?,
            }),
            "button" => Ok(Self::Button(Box::new(decode_button_node(map, id)?))),
            "div" => {
                let children = get_child_nodes_field(map)?;
                let actions = get_div_actions(map)?;

                Ok(Self::Div(Box::new(DivNode {
                    id,
                    style: get_div_style(map)?,
                    hover_style: get_div_hover_style(map)?,
                    focus_style: get_div_focus_style(map)?,
                    focus_visible_style: get_div_focus_visible_style(map)?,
                    in_focus_style: get_div_in_focus_style(map)?,
                    active_style: get_div_active_style(map)?,
                    disabled_style: get_div_disabled_style(map)?,
                    animation: get_animation_field(map)?,
                    disabled: get_boolean_field(map, "disabled")?,
                    stack_priority: get_optional_usize_field(map, "stack_priority")?,
                    occlude: get_boolean_field(map, "occlude")?,
                    focusable: get_boolean_field(map, "focusable")?,
                    tab_stop: get_optional_boolean_field(map, "tab_stop")?,
                    tab_index: get_optional_integer_field(map, "tab_index")?,
                    track_scroll: get_boolean_field(map, "track_scroll")?,
                    anchor_scroll: get_boolean_field(map, "anchor_scroll")?,
                    tooltip: get_optional_string_field(map, "tooltip")?,
                    shortcuts: get_div_shortcuts(map, &actions)?,
                    children: children.into(),
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
                })))
            }
            other => Err(format!("unsupported ir kind: {other}")),
        }
    }
}

fn get_child_nodes_field(map: &HashMap<Term, Term>) -> Result<Arc<[IrNode]>, String> {
    let Some(children_term) = get_field(map, "children") else {
        return Ok(Arc::new([]));
    };

    get_list(children_term)?
        .iter()
        .map(IrNode::from_term)
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn decode_button_node(map: &HashMap<Term, Term>, id: Option<String>) -> Result<DivNode, String> {
    let actions = get_div_actions(map)?;
    let label = get_string_field(map, "label")?;
    let style = prepend_style(default_button_style(), get_div_style(map)?);
    let hover_style = get_div_hover_style(map)?;
    let focus_style = prepend_style(default_button_focus_style(), get_div_focus_style(map)?);
    let focus_visible_style = get_div_focus_visible_style(map)?;
    let in_focus_style = get_div_in_focus_style(map)?;
    let active_style = prepend_style(default_button_active_style(), get_div_active_style(map)?);
    let disabled_style = prepend_style(
        default_button_disabled_style(),
        get_div_disabled_style(map)?,
    );

    Ok(DivNode {
        id,
        style,
        hover_style,
        focus_style,
        focus_visible_style,
        in_focus_style,
        active_style,
        disabled_style,
        animation: get_animation_field(map)?,
        disabled: get_boolean_field(map, "disabled")?,
        stack_priority: None,
        occlude: false,
        focusable: true,
        tab_stop: Some(true),
        tab_index: get_optional_integer_field(map, "tab_index")?,
        track_scroll: false,
        anchor_scroll: false,
        tooltip: get_optional_string_field(map, "tooltip")?,
        shortcuts: get_div_shortcuts(map, &actions)?,
        children: vec![IrNode::text(label)].into(),
        click: get_click_event(map)?,
        hover: get_hover_event(map)?,
        focus: get_focus_event(map)?,
        blur: get_blur_event(map)?,
        key_down: get_key_down_event(map)?,
        key_up: get_key_up_event(map)?,
        context_menu: get_context_menu_event(map)?,
        drag_start: None,
        drag_move: None,
        drop: None,
        mouse_down: get_mouse_down_event(map)?,
        mouse_up: get_mouse_up_event(map)?,
        mouse_move: get_mouse_move_event(map)?,
        scroll_wheel: None,
    })
}

fn decode_checkbox_node(
    map: &HashMap<Term, Term>,
    id: Option<String>,
) -> Result<CheckboxNode, String> {
    Ok(CheckboxNode {
        id,
        label: get_string_field(map, "label")?,
        checked: get_required_boolean_field(map, "checked")?,
        style: get_div_style(map)?,
        hover_style: get_div_hover_style(map)?,
        focus_style: get_div_focus_style(map)?,
        focus_visible_style: get_div_focus_visible_style(map)?,
        in_focus_style: get_div_in_focus_style(map)?,
        active_style: get_div_active_style(map)?,
        disabled_style: get_div_disabled_style(map)?,
        disabled: get_boolean_field(map, "disabled")?,
        tab_index: get_optional_integer_field(map, "tab_index")?,
        change: get_change_event(map)?,
        focus: get_focus_event(map)?,
        blur: get_blur_event(map)?,
    })
}

fn decode_radio_node(map: &HashMap<Term, Term>, id: Option<String>) -> Result<RadioNode, String> {
    Ok(RadioNode {
        id,
        label: get_string_field(map, "label")?,
        value: get_string_field(map, "value")?,
        checked: get_required_boolean_field(map, "checked")?,
        style: get_div_style(map)?,
        hover_style: get_div_hover_style(map)?,
        focus_style: get_div_focus_style(map)?,
        focus_visible_style: get_div_focus_visible_style(map)?,
        in_focus_style: get_div_in_focus_style(map)?,
        active_style: get_div_active_style(map)?,
        disabled_style: get_div_disabled_style(map)?,
        disabled: get_boolean_field(map, "disabled")?,
        tab_index: get_optional_integer_field(map, "tab_index")?,
        change: get_change_event(map)?,
        focus: get_focus_event(map)?,
        blur: get_blur_event(map)?,
    })
}

fn expect_map(term: &Term) -> Result<&HashMap<Term, Term>, String> {
    match term {
        Term::Map(Map { map }) => Ok(map),
        other => Err(format!("expected map ir node, got {other}")),
    }
}

fn get_field<'a>(map: &'a HashMap<Term, Term>, key: &str) -> Option<&'a Term> {
    map.get(field_key(key)?)
}

fn field_key(key: &str) -> Option<&'static Term> {
    let keys = field_keys();

    Some(match key {
        "kind" => &keys.kind,
        "id" => &keys.id,
        "content" => &keys.content,
        "runs" => &keys.runs,
        "text" => &keys.text,
        "value" => &keys.value,
        "placeholder" => &keys.placeholder,
        "children" => &keys.children,
        "items" => &keys.items,
        "columns" => &keys.columns,
        "rows" => &keys.rows,
        "cells" => &keys.cells,
        "column_id" => &keys.column_id,
        "width" => &keys.width,
        "sortable" => &keys.sortable,
        "header_style" => &keys.header_style,
        "row_style" => &keys.row_style,
        "cell_style" => &keys.cell_style,
        "selected_row_id" => &keys.selected_row_id,
        "selected_cell" => &keys.selected_cell,
        "sort" => &keys.sort,
        "row_click" => &keys.row_click,
        "cell_click" => &keys.cell_click,
        "direction" => &keys.direction,
        "nodes" => &keys.nodes,
        "selected_id" => &keys.selected_id,
        "expanded" => &keys.expanded,
        "select" => &keys.select,
        "toggle" => &keys.toggle,
        "commands" => &keys.commands,
        "op" => &keys.op,
        "x" => &keys.x,
        "y" => &keys.y,
        "height" => &keys.height,
        "fill" => &keys.fill,
        "color" => &keys.color,
        "line_width" => &keys.line_width,
        "interval" => &keys.interval,
        "radius" => &keys.radius,
        "options" => &keys.options,
        "axis" => &keys.axis,
        "style" => &keys.style,
        "item_style" => &keys.item_style,
        "list_style" => &keys.list_style,
        "option_style" => &keys.option_style,
        "hover_style" => &keys.hover_style,
        "focus_style" => &keys.focus_style,
        "focus_visible_style" => &keys.focus_visible_style,
        "in_focus_style" => &keys.in_focus_style,
        "active_style" => &keys.active_style,
        "disabled_style" => &keys.disabled_style,
        "animation" => &keys.animation,
        "duration_ms" => &keys.duration_ms,
        "repeat" => &keys.repeat,
        "from" => &keys.from,
        "to" => &keys.to,
        "disabled" => &keys.disabled,
        "tab_index" => &keys.tab_index,
        "actions" => &keys.actions,
        "shortcuts" => &keys.shortcuts,
        "label" => &keys.label,
        "open" => &keys.open,
        "events" => &keys.events,
        "click" => &keys.click,
        "close" => &keys.close,
        "hover" => &keys.hover,
        "focus" => &keys.focus,
        "blur" => &keys.blur,
        "change" => &keys.change,
        "key_down" => &keys.key_down,
        "key_up" => &keys.key_up,
        "context_menu" => &keys.context_menu,
        "drag_start" => &keys.drag_start,
        "drag_move" => &keys.drag_move,
        "drop" => &keys.drop,
        "mouse_down" => &keys.mouse_down,
        "mouse_up" => &keys.mouse_up,
        "mouse_move" => &keys.mouse_move,
        "scroll_wheel" => &keys.scroll_wheel,
        "stack_priority" => &keys.stack_priority,
        "occlude" => &keys.occlude,
        "focusable" => &keys.focusable,
        "tab_stop" => &keys.tab_stop,
        "track_scroll" => &keys.track_scroll,
        "anchor_scroll" => &keys.anchor_scroll,
        "tooltip" => &keys.tooltip,
        "source" => &keys.source,
        "popover_style" => &keys.popover_style,
        "anchor" => &keys.anchor,
        "anchor_position" => &keys.anchor_position,
        "anchor_offset" => &keys.anchor_offset,
        "anchor_position_mode" => &keys.anchor_position_mode,
        "anchor_fit" => &keys.anchor_fit,
        "snap_margin" => &keys.snap_margin,
        "close_on_click_outside" => &keys.close_on_click_outside,
        "object_fit" => &keys.object_fit,
        "grayscale" => &keys.grayscale,
        "checked" => &keys.checked,
        _ => return None,
    })
}

fn get_atom_field(map: &HashMap<Term, Term>, key: &str) -> Result<String, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) => Ok(atom.name.clone()),
        Some(other) => Err(format!("expected atom field {key}, got {other}")),
        None => Err(format!("missing required field: {key}")),
    }
}

fn get_scroll_axis_field(map: &HashMap<Term, Term>) -> Result<ScrollAxis, String> {
    match get_field(map, "axis") {
        Some(Term::Atom(atom)) if atom.name == "x" => Ok(ScrollAxis::X),
        Some(Term::Atom(atom)) if atom.name == "y" => Ok(ScrollAxis::Y),
        Some(Term::Atom(atom)) if atom.name == "both" => Ok(ScrollAxis::Both),
        Some(other) => Err(format!("expected scroll axis atom, got {other}")),
        None => Ok(ScrollAxis::Y),
    }
}

fn get_image_source_field(map: &HashMap<Term, Term>) -> Result<ImageSource, String> {
    match get_field(map, "source") {
        Some(Term::Binary(_)) | Some(Term::ByteList(_)) => {
            term_to_string(get_field(map, "source").expect("source field present"))
                .map(ImageSource::Auto)
        }
        Some(Term::Tuple(Tuple { elements })) if elements.len() == 2 => {
            let kind = match &elements[0] {
                Term::Atom(atom) => atom.name.as_str(),
                other => return Err(format!("expected image source kind atom, got {other}")),
            };

            let value = term_to_string(&elements[1])?;

            match kind {
                "uri" => Ok(ImageSource::Uri(value)),
                "path" => Ok(ImageSource::Path(value)),
                "embedded" => Ok(ImageSource::Embedded(value)),
                other => Err(format!("unsupported image source kind: {other}")),
            }
        }
        Some(other) => Err(format!(
            "expected image source string or tuple, got {other}"
        )),
        None => Err("missing required field: source".into()),
    }
}

fn get_image_object_fit_field(map: &HashMap<Term, Term>) -> Result<ImageObjectFit, String> {
    match get_field(map, "object_fit") {
        Some(Term::Atom(atom)) if atom.name == "fill" => Ok(ImageObjectFit::Fill),
        Some(Term::Atom(atom)) if atom.name == "contain" => Ok(ImageObjectFit::Contain),
        Some(Term::Atom(atom)) if atom.name == "cover" => Ok(ImageObjectFit::Cover),
        Some(Term::Atom(atom)) if atom.name == "scale_down" => Ok(ImageObjectFit::ScaleDown),
        Some(Term::Atom(atom)) if atom.name == "none" => Ok(ImageObjectFit::None),
        Some(other) => Err(format!("expected image object_fit atom, got {other}")),
        None => Ok(ImageObjectFit::Contain),
    }
}

fn get_popover_anchor_field(map: &HashMap<Term, Term>) -> Result<PopoverAnchor, String> {
    match get_field(map, "anchor") {
        Some(Term::Atom(atom)) if atom.name == "top_left" => Ok(PopoverAnchor::TopLeft),
        Some(Term::Atom(atom)) if atom.name == "top_right" => Ok(PopoverAnchor::TopRight),
        Some(Term::Atom(atom)) if atom.name == "bottom_left" => Ok(PopoverAnchor::BottomLeft),
        Some(Term::Atom(atom)) if atom.name == "bottom_right" => Ok(PopoverAnchor::BottomRight),
        Some(other) => Err(format!("expected popover anchor atom, got {other}")),
        None => Ok(PopoverAnchor::TopLeft),
    }
}

fn get_popover_anchor_position_mode_field(
    map: &HashMap<Term, Term>,
) -> Result<PopoverAnchorPositionMode, String> {
    match get_field(map, "anchor_position_mode") {
        Some(Term::Atom(atom)) if atom.name == "window" => Ok(PopoverAnchorPositionMode::Window),
        Some(Term::Atom(atom)) if atom.name == "local" => Ok(PopoverAnchorPositionMode::Local),
        Some(other) => Err(format!(
            "expected popover anchor_position_mode atom, got {other}"
        )),
        None => Ok(PopoverAnchorPositionMode::Window),
    }
}

fn get_popover_anchor_fit_field(map: &HashMap<Term, Term>) -> Result<PopoverAnchorFit, String> {
    match get_field(map, "anchor_fit") {
        Some(Term::Atom(atom)) if atom.name == "switch_anchor" => {
            Ok(PopoverAnchorFit::SwitchAnchor)
        }
        Some(Term::Atom(atom)) if atom.name == "snap_to_window" => {
            Ok(PopoverAnchorFit::SnapToWindow)
        }
        Some(Term::Atom(atom)) if atom.name == "snap_to_window_with_margin" => {
            Ok(PopoverAnchorFit::SnapToWindowWithMargin)
        }
        Some(other) => Err(format!("expected popover anchor_fit atom, got {other}")),
        None => Ok(PopoverAnchorFit::SnapToWindowWithMargin),
    }
}

fn get_optional_point_field(
    map: &HashMap<Term, Term>,
    key: &str,
) -> Result<Option<(f32, f32)>, String> {
    let Some(term) = get_field(map, key) else {
        return Ok(None);
    };

    let Term::Tuple(Tuple { elements }) = term else {
        return Err(format!(
            "expected optional point tuple field {key}, got {term}"
        ));
    };

    if elements.len() != 2 {
        return Err(format!(
            "expected optional point tuple field {key} with 2 elements, got {term}"
        ));
    }

    Ok(Some((parse_f32(&elements[0])?, parse_f32(&elements[1])?)))
}

fn get_f32_field(map: &HashMap<Term, Term>, key: &str) -> Result<f32, String> {
    match get_field(map, key) {
        Some(term) => parse_f32(term),
        None => Err(format!("missing required field: {key}")),
    }
}

fn get_positive_f32_field(map: &HashMap<Term, Term>, key: &str) -> Result<f32, String> {
    let value = get_f32_field(map, key)?;
    if value > 0.0 {
        Ok(value)
    } else {
        Err(format!(
            "expected positive numeric field {key}, got {value}"
        ))
    }
}

fn get_positive_unit_f32_field(map: &HashMap<Term, Term>, key: &str) -> Result<f32, String> {
    let value = get_f32_field(map, key)?;
    if value > 0.0 && value <= 1.0 {
        Ok(value)
    } else {
        Err(format!("expected unit numeric field {key}, got {value}"))
    }
}

fn get_non_neg_f32_field(
    map: &HashMap<Term, Term>,
    key: &str,
    default: f32,
) -> Result<f32, String> {
    let Some(term) = get_field(map, key) else {
        return Ok(default);
    };

    let value = parse_f32(term)?;
    if value >= 0.0 {
        Ok(value)
    } else {
        Err(format!(
            "expected non-negative numeric field {key}, got {term}"
        ))
    }
}

fn get_string_field(map: &HashMap<Term, Term>, key: &str) -> Result<String, String> {
    match get_field(map, key) {
        Some(term) => term_to_string(term),
        None => Err(format!("missing required field: {key}")),
    }
}

fn get_animation_field(map: &HashMap<Term, Term>) -> Result<Option<AnimationSpec>, String> {
    let Some(term) = get_field(map, "animation") else {
        return Ok(None);
    };

    let animation = expect_map(term)?;
    let duration_ms = get_optional_u64_field(animation, "duration_ms")?.unwrap_or(1_000);
    if duration_ms == 0 {
        return Err("expected positive animation duration_ms".into());
    }

    Ok(Some(AnimationSpec {
        id: get_string_field(animation, "id")?,
        duration_ms,
        repeat: get_boolean_field(animation, "repeat")?,
        from: get_unit_f32_field(animation, "from", 0.0)?,
        to: get_unit_f32_field(animation, "to", 1.0)?,
    }))
}

fn get_text_runs_field(
    map: &HashMap<Term, Term>,
    content: &str,
) -> Result<Arc<[TextRunSegment]>, String> {
    let Some(runs_term) = get_field(map, "runs") else {
        return Ok(Arc::new([]));
    };

    let runs = get_list(runs_term)?
        .iter()
        .map(|term| {
            let run = expect_map(term)?;
            Ok(TextRunSegment {
                text: get_string_field(run, "text")?,
                style: get_style_list_field(run, "style")?,
            })
        })
        .collect::<Result<Vec<_>, String>>()?;

    let joined = runs.iter().map(|run| run.text.as_str()).collect::<String>();
    if joined == content {
        Ok(runs.into())
    } else {
        Err(format!(
            "text runs content mismatch: expected {content:?}, got {joined:?}"
        ))
    }
}

fn get_uniform_list_items_field(
    map: &HashMap<Term, Term>,
) -> Result<Arc<[UniformListItem]>, String> {
    let Some(items_term) = get_field(map, "items") else {
        return Err("missing required field: items".into());
    };

    get_list(items_term)?
        .iter()
        .map(|term| {
            let item = expect_map(term)?;
            ensure_allowed_fields(item, &["id", "label"], "uniform_list item")?;
            Ok(UniformListItem {
                id: get_string_field(item, "id")?,
                label: get_string_field(item, "label")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn get_list_items_field(map: &HashMap<Term, Term>) -> Result<Arc<[ListItem]>, String> {
    let Some(items_term) = get_field(map, "items") else {
        return Err("missing required field: items".into());
    };

    get_list(items_term)?
        .iter()
        .map(|term| {
            let item = expect_map(term)?;
            ensure_allowed_fields(item, &["id", "children"], "list item")?;
            let Some(children_term) = get_field(item, "children") else {
                return Err("missing required field: list item children".into());
            };
            let children = get_list(children_term)?
                .iter()
                .map(decode_list_row_child_term)
                .collect::<Result<Vec<_>, _>>()?;
            ensure_unique_list_row_control_ids(&children)?;

            Ok(ListItem {
                id: get_string_field(item, "id")?,
                children: children.into(),
            })
        })
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn get_data_table_columns_field(
    map: &HashMap<Term, Term>,
) -> Result<Arc<[DataTableColumn]>, String> {
    let Some(columns_term) = get_field(map, "columns") else {
        return Err("missing required field: columns".into());
    };

    let mut seen = HashSet::new();
    get_list(columns_term)?
        .iter()
        .map(|term| {
            let column = expect_map(term)?;
            ensure_allowed_fields(
                column,
                &["id", "label", "width", "sortable", "style"],
                "data_table column",
            )?;
            let id = get_string_field(column, "id")?;
            if !seen.insert(id.clone()) {
                return Err(format!("duplicate data_table column id: {id}"));
            }

            Ok(DataTableColumn {
                id,
                label: get_string_field(column, "label")?,
                width: get_data_table_column_width(column)?,
                sortable: get_boolean_field(column, "sortable")?,
                style: get_div_style(column)?,
            })
        })
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn get_data_table_column_width(map: &HashMap<Term, Term>) -> Result<DataTableColumnWidth, String> {
    let Some(width) = get_field(map, "width") else {
        return Ok(DataTableColumnWidth::Auto);
    };

    match width {
        Term::Atom(atom) if atom.name == "auto" => Ok(DataTableColumnWidth::Auto),
        Term::Tuple(Tuple { elements }) if elements.len() == 2 => {
            let kind = match &elements[0] {
                Term::Atom(atom) => atom.name.as_str(),
                other => {
                    return Err(format!(
                        "expected data_table column width kind atom, got {other}"
                    ));
                }
            };

            match kind {
                "px" => {
                    let px = parse_f32(&elements[1])?;
                    if px > 0.0 {
                        Ok(DataTableColumnWidth::Px(px))
                    } else {
                        Err(format!(
                            "expected positive data_table px width, got {width}"
                        ))
                    }
                }
                "fr" => parse_positive_u32(&elements[1]).map(DataTableColumnWidth::Fr),
                other => Err(format!("unsupported data_table column width kind: {other}")),
            }
        }
        other => Err(format!("expected data_table column width, got {other}")),
    }
}

fn get_data_table_rows_field(
    map: &HashMap<Term, Term>,
    column_ids: &HashSet<&str>,
) -> Result<Arc<[DataTableRow]>, String> {
    let Some(rows_term) = get_field(map, "rows") else {
        return Err("missing required field: rows".into());
    };

    let mut seen = HashSet::new();
    get_list(rows_term)?
        .iter()
        .map(|term| {
            let row = expect_map(term)?;
            ensure_allowed_fields(row, &["id", "cells", "style"], "data_table row")?;
            let id = get_string_field(row, "id")?;
            if !seen.insert(id.clone()) {
                return Err(format!("duplicate data_table row id: {id}"));
            }

            Ok(DataTableRow {
                id,
                cells: get_data_table_cells(row, column_ids)?,
                style: get_div_style(row)?,
            })
        })
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn get_data_table_cells(
    row: &HashMap<Term, Term>,
    column_ids: &HashSet<&str>,
) -> Result<Arc<[DataTableCell]>, String> {
    let Some(cells_term) = get_field(row, "cells") else {
        return Err("missing required field: data_table row cells".into());
    };

    let mut seen = HashSet::new();
    get_list(cells_term)?
        .iter()
        .map(|term| {
            let cell = expect_map(term)?;
            ensure_allowed_fields(cell, &["column_id", "children", "style"], "data_table cell")?;
            let column_id = get_string_field(cell, "column_id")?;
            ensure_id_known(&column_id, column_ids, "unknown data_table cell column")?;
            if !seen.insert(column_id.clone()) {
                return Err(format!("duplicate data_table cell column: {column_id}"));
            }

            Ok(DataTableCell {
                column_id,
                children: get_data_table_cell_children(cell)?,
                style: get_div_style(cell)?,
            })
        })
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn get_data_table_cell_children(map: &HashMap<Term, Term>) -> Result<Arc<[IrNode]>, String> {
    let Some(children_term) = get_field(map, "children") else {
        return Err("missing required field: data_table cell children".into());
    };

    get_list(children_term)?
        .iter()
        .map(decode_data_table_cell_child_term)
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn decode_data_table_cell_child_term(term: &Term) -> Result<IrNode, String> {
    let map = expect_map(term)?;
    let kind = get_atom_field(map, "kind")?;

    match kind.as_str() {
        "text" => {
            ensure_allowed_fields(
                map,
                &["kind", "content", "id", "style", "runs", "events"],
                "data_table cell text",
            )?;
            ensure_allowed_event_fields(map, &["click"], "data_table cell text events")?;
            IrNode::from_term(term)
        }
        "spacer" => {
            ensure_allowed_fields(map, &["kind", "id", "style"], "data_table cell spacer")?;
            IrNode::from_term(term)
        }
        "div" => decode_static_list_row_div(map),
        _ => Err(format!("unsupported data_table cell child kind: {kind}")),
    }
}

fn get_data_table_sort_field(
    map: &HashMap<Term, Term>,
    column_ids: &HashSet<&str>,
) -> Result<Option<DataTableSort>, String> {
    let Some(sort_term) = get_field(map, "sort") else {
        return Ok(None);
    };

    let sort = expect_map(sort_term)?;
    ensure_allowed_fields(sort, &["column_id", "direction"], "data_table sort")?;
    let column_id = get_string_field(sort, "column_id")?;
    ensure_id_known(&column_id, column_ids, "unknown data_table sort column")?;
    let direction = match get_field(sort, "direction") {
        Some(Term::Atom(atom)) if atom.name == "asc" => DataTableSortDirection::Asc,
        Some(Term::Atom(atom)) if atom.name == "desc" => DataTableSortDirection::Desc,
        Some(other) => {
            return Err(format!(
                "expected data_table sort direction atom, got {other}"
            ));
        }
        None => return Err("missing required field: direction".into()),
    };

    Ok(Some(DataTableSort {
        column_id,
        direction,
    }))
}

fn get_tree_nodes_field(map: &HashMap<Term, Term>) -> Result<Arc<[TreeItem]>, String> {
    let Some(nodes_term) = get_field(map, "nodes") else {
        return Err("missing required field: nodes".into());
    };

    let mut seen = HashSet::new();
    get_tree_nodes(nodes_term, &mut seen)
}

fn get_tree_nodes(term: &Term, seen: &mut HashSet<String>) -> Result<Arc<[TreeItem]>, String> {
    get_list(term)?
        .iter()
        .map(|term| get_tree_item(term, seen))
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn get_tree_item(term: &Term, seen: &mut HashSet<String>) -> Result<TreeItem, String> {
    let item = expect_map(term)?;
    ensure_allowed_fields(
        item,
        &["id", "label", "expanded", "children", "style"],
        "tree item",
    )?;
    let id = get_string_field(item, "id")?;
    if !seen.insert(id.clone()) {
        return Err(format!("duplicate tree item id: {id}"));
    }

    let children = match get_field(item, "children") {
        Some(children) => get_tree_nodes(children, seen)?,
        None => Arc::new([]),
    };

    Ok(TreeItem {
        id,
        label: get_string_field(item, "label")?,
        expanded: get_boolean_field(item, "expanded")?,
        children,
        style: get_div_style(item)?,
    })
}

fn ensure_optional_id_known(
    id: Option<&str>,
    known: &HashSet<&str>,
    context: &str,
) -> Result<(), String> {
    if let Some(id) = id {
        ensure_id_known(id, known, context)?;
    }

    Ok(())
}

fn ensure_id_known(id: &str, known: &HashSet<&str>, context: &str) -> Result<(), String> {
    if known.contains(id) {
        Ok(())
    } else {
        Err(format!("{context}: {id}"))
    }
}

fn get_canvas_commands_field(map: &HashMap<Term, Term>) -> Result<Arc<[CanvasCommand]>, String> {
    let Some(commands_term) = get_field(map, "commands") else {
        return Err("missing required field: commands".into());
    };

    get_list(commands_term)?
        .iter()
        .map(decode_canvas_command)
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn decode_canvas_command(term: &Term) -> Result<CanvasCommand, String> {
    let command = expect_map(term)?;
    let op = get_atom_field(command, "op")?;
    let x = get_f32_field(command, "x")?;
    let y = get_f32_field(command, "y")?;
    let width = get_positive_f32_field(command, "width")?;
    let height = get_positive_f32_field(command, "height")?;

    match op.as_str() {
        "rect" => {
            ensure_allowed_fields(
                command,
                &["op", "x", "y", "width", "height", "fill", "radius"],
                "canvas rect command",
            )?;
            Ok(CanvasCommand::Rect {
                x,
                y,
                width,
                height,
                fill: get_canvas_color_field(command, "fill")?,
                radius: get_non_neg_f32_field(command, "radius", 0.0)?,
            })
        }
        "rounded_rect" => {
            ensure_allowed_fields(
                command,
                &["op", "x", "y", "width", "height", "fill", "radius"],
                "canvas rounded_rect command",
            )?;
            if get_field(command, "radius").is_none() {
                return Err("missing required field: radius".into());
            }
            Ok(CanvasCommand::Rect {
                x,
                y,
                width,
                height,
                fill: get_canvas_color_field(command, "fill")?,
                radius: get_non_neg_f32_field(command, "radius", 0.0)?,
            })
        }
        "pattern_rect" => {
            ensure_allowed_fields(
                command,
                &[
                    "op",
                    "x",
                    "y",
                    "width",
                    "height",
                    "color",
                    "line_width",
                    "interval",
                    "radius",
                ],
                "canvas pattern_rect command",
            )?;
            Ok(CanvasCommand::PatternRect {
                x,
                y,
                width,
                height,
                color: get_canvas_color_field(command, "color")?,
                line_width: get_positive_unit_f32_field(command, "line_width")?,
                interval: get_positive_unit_f32_field(command, "interval")?,
                radius: get_non_neg_f32_field(command, "radius", 0.0)?,
            })
        }
        other => Err(format!("unsupported canvas command op: {other}")),
    }
}

fn get_canvas_color_field(map: &HashMap<Term, Term>, key: &str) -> Result<StyleColor, String> {
    match get_field(map, key) {
        Some(term) => parse_style_color(term),
        None => Err(format!("missing required field: {key}")),
    }
}

fn get_select_options_field(map: &HashMap<Term, Term>) -> Result<Arc<[SelectOption]>, String> {
    let Some(options_term) = get_field(map, "options") else {
        return Err("missing required field: options".into());
    };

    get_list(options_term)?
        .iter()
        .map(|term| {
            let option = expect_map(term)?;
            ensure_allowed_fields(option, &["value", "label", "disabled"], "select option")?;
            Ok(SelectOption {
                value: get_string_field(option, "value")?,
                label: get_string_field(option, "label")?,
                disabled: get_boolean_field(option, "disabled")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn decode_list_row_child_term(term: &Term) -> Result<IrNode, String> {
    let map = expect_map(term)?;
    let kind = get_atom_field(map, "kind")?;

    match kind.as_str() {
        "text" => {
            ensure_allowed_fields(
                map,
                &["kind", "content", "id", "style", "runs", "events"],
                "list row text",
            )?;
            ensure_allowed_event_fields(map, &["click"], "list row text events")?;
            IrNode::from_term(term)
        }
        "spacer" => {
            ensure_allowed_fields(map, &["kind", "id", "style"], "list row spacer")?;
            IrNode::from_term(term)
        }
        "div" => decode_static_list_row_div(map),
        "button" => decode_list_row_button(map),
        "checkbox" => decode_list_row_checkbox(map),
        "radio" => decode_list_row_radio(map),
        _ => Err(format!("unsupported list row child kind: {kind}")),
    }
}

fn decode_list_row_button(map: &HashMap<Term, Term>) -> Result<IrNode, String> {
    ensure_allowed_fields(
        map,
        &[
            "kind",
            "label",
            "id",
            "style",
            "hover_style",
            "focus_style",
            "focus_visible_style",
            "in_focus_style",
            "active_style",
            "disabled_style",
            "disabled",
            "tab_index",
            "events",
        ],
        "list row button",
    )?;
    ensure_allowed_event_fields(map, &["click"], "list row button events")?;
    let id = get_list_row_control_id(map, "button")?;
    Ok(IrNode::Button(Box::new(decode_button_node(map, Some(id))?)))
}

fn decode_list_row_checkbox(map: &HashMap<Term, Term>) -> Result<IrNode, String> {
    ensure_allowed_fields(
        map,
        &[
            "kind",
            "label",
            "checked",
            "id",
            "style",
            "hover_style",
            "focus_style",
            "focus_visible_style",
            "in_focus_style",
            "active_style",
            "disabled_style",
            "disabled",
            "tab_index",
            "events",
        ],
        "list row checkbox",
    )?;
    ensure_allowed_event_fields(map, &["change"], "list row checkbox events")?;
    let id = get_list_row_control_id(map, "checkbox")?;
    Ok(IrNode::Checkbox(Box::new(decode_checkbox_node(
        map,
        Some(id),
    )?)))
}

fn decode_list_row_radio(map: &HashMap<Term, Term>) -> Result<IrNode, String> {
    ensure_allowed_fields(
        map,
        &[
            "kind",
            "label",
            "value",
            "checked",
            "id",
            "style",
            "hover_style",
            "focus_style",
            "focus_visible_style",
            "in_focus_style",
            "active_style",
            "disabled_style",
            "disabled",
            "tab_index",
            "events",
        ],
        "list row radio",
    )?;
    ensure_allowed_event_fields(map, &["change"], "list row radio events")?;
    let id = get_list_row_control_id(map, "radio")?;
    Ok(IrNode::Radio(Box::new(decode_radio_node(map, Some(id))?)))
}

fn get_list_row_control_id(map: &HashMap<Term, Term>, kind: &str) -> Result<String, String> {
    get_optional_string_field(map, "id")?
        .ok_or_else(|| format!("missing list row control id: {kind}"))
}

fn decode_static_list_row_div(map: &HashMap<Term, Term>) -> Result<IrNode, String> {
    ensure_allowed_fields(
        map,
        &["kind", "children", "id", "style", "disabled", "events"],
        "list row div",
    )?;
    ensure_allowed_event_fields(map, &["click"], "list row div events")?;

    let Some(children_term) = get_field(map, "children") else {
        return Err("missing required field: list row div children".into());
    };

    let children = get_list(children_term)?
        .iter()
        .map(decode_list_row_child_term)
        .collect::<Result<Vec<_>, _>>()?;
    let empty_style = empty_style();

    Ok(IrNode::Div(Box::new(DivNode {
        id: get_optional_string_field(map, "id")?,
        style: get_div_style(map)?,
        hover_style: empty_style.clone(),
        focus_style: empty_style.clone(),
        focus_visible_style: empty_style.clone(),
        in_focus_style: empty_style.clone(),
        active_style: empty_style.clone(),
        disabled_style: empty_style,
        animation: None,
        disabled: get_boolean_field(map, "disabled")?,
        stack_priority: None,
        occlude: false,
        focusable: false,
        tab_stop: None,
        tab_index: None,
        track_scroll: false,
        anchor_scroll: false,
        tooltip: None,
        shortcuts: Arc::new([]),
        children: children.into(),
        click: get_click_event(map)?,
        hover: None,
        focus: None,
        blur: None,
        key_down: None,
        key_up: None,
        context_menu: None,
        drag_start: None,
        drag_move: None,
        drop: None,
        mouse_down: None,
        mouse_up: None,
        mouse_move: None,
        scroll_wheel: None,
    })))
}

fn ensure_unique_list_row_control_ids(children: &[IrNode]) -> Result<(), String> {
    let mut seen = HashSet::new();
    collect_list_row_control_ids(children, &mut seen)
}

fn collect_list_row_control_ids(
    children: &[IrNode],
    seen: &mut HashSet<String>,
) -> Result<(), String> {
    for child in children {
        match child {
            IrNode::Button(node) => track_list_row_control_id(node.id.as_deref(), seen)?,
            IrNode::Checkbox(node) => track_list_row_control_id(node.id.as_deref(), seen)?,
            IrNode::Radio(node) => track_list_row_control_id(node.id.as_deref(), seen)?,
            IrNode::Div(node) => collect_list_row_control_ids(&node.children, seen)?,
            _ => {}
        }
    }

    Ok(())
}

fn track_list_row_control_id(id: Option<&str>, seen: &mut HashSet<String>) -> Result<(), String> {
    let Some(id) = id else {
        return Err("missing list row control id".into());
    };

    if seen.insert(id.to_owned()) {
        Ok(())
    } else {
        Err(format!("duplicate list row control id: {id}"))
    }
}

fn empty_style() -> DivStyle {
    Vec::new().into()
}

fn ensure_allowed_fields(
    map: &HashMap<Term, Term>,
    allowed: &[&str],
    context: &str,
) -> Result<(), String> {
    for key in map.keys() {
        let known = allowed
            .iter()
            .filter_map(|allowed_key| field_key(allowed_key))
            .any(|allowed_key| key == allowed_key);

        if !known {
            return Err(format!("unsupported {context} field: {key}"));
        }
    }

    Ok(())
}

fn ensure_allowed_event_fields(
    map: &HashMap<Term, Term>,
    allowed: &[&str],
    context: &str,
) -> Result<(), String> {
    let Some(events_term) = get_field(map, "events") else {
        return Ok(());
    };

    ensure_allowed_fields(expect_map(events_term)?, allowed, context)
}

#[cfg(test)]
fn validate_list_row_children(children: &[IrNode]) -> Result<(), String> {
    for child in children {
        validate_list_row_child(child)?;
    }

    Ok(())
}

#[cfg(test)]
fn validate_list_row_child(node: &IrNode) -> Result<(), String> {
    match node {
        IrNode::Text { .. } | IrNode::Spacer { .. } => Ok(()),
        IrNode::Div(node) => validate_static_list_row_div(node),
        other => Err(format!(
            "unsupported list row child kind: {}",
            ir_node_kind(other)
        )),
    }
}

#[cfg(test)]
fn validate_static_list_row_div(node: &DivNode) -> Result<(), String> {
    if !node.hover_style.is_empty()
        || !node.focus_style.is_empty()
        || !node.focus_visible_style.is_empty()
        || !node.in_focus_style.is_empty()
        || !node.active_style.is_empty()
        || !node.disabled_style.is_empty()
        || node.animation.is_some()
        || node.stack_priority.is_some()
        || node.occlude
        || node.focusable
        || node.tab_stop.is_some()
        || node.tab_index.is_some()
        || node.track_scroll
        || node.anchor_scroll
        || node.tooltip.is_some()
        || !node.shortcuts.is_empty()
        || node.hover.is_some()
        || node.focus.is_some()
        || node.blur.is_some()
        || node.key_down.is_some()
        || node.key_up.is_some()
        || node.context_menu.is_some()
        || node.drag_start.is_some()
        || node.drag_move.is_some()
        || node.drop.is_some()
        || node.mouse_down.is_some()
        || node.mouse_up.is_some()
        || node.mouse_move.is_some()
        || node.scroll_wheel.is_some()
    {
        return Err("unsupported list row div field".into());
    }

    validate_list_row_children(&node.children)
}

#[cfg(test)]
fn ir_node_kind(node: &IrNode) -> &'static str {
    match node {
        IrNode::Text { .. } => "text",
        IrNode::TextInput { .. } => "text_input",
        IrNode::Textarea { .. } => "textarea",
        IrNode::Scroll { .. } => "scroll",
        IrNode::Image { .. } => "image",
        IrNode::Icon { .. } => "icon",
        IrNode::Button(_) => "button",
        IrNode::Checkbox(_) => "checkbox",
        IrNode::Radio(_) => "radio",
        IrNode::UniformList { .. } => "uniform_list",
        IrNode::List { .. } => "list",
        IrNode::DataTable(_) => "data_table",
        IrNode::Tree(_) => "tree",
        IrNode::Canvas(_) => "canvas",
        IrNode::Select(_) => "select",
        IrNode::Popover { .. } => "popover",
        IrNode::Spacer { .. } => "spacer",
        IrNode::Div(_) => "div",
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

fn get_optional_string_pair_field(
    map: &HashMap<Term, Term>,
    key: &str,
) -> Result<Option<(String, String)>, String> {
    let Some(term) = get_field(map, key) else {
        return Ok(None);
    };

    let Term::Tuple(Tuple { elements }) = term else {
        return Err(format!(
            "expected string pair tuple field {key}, got {term}"
        ));
    };

    if elements.len() != 2 {
        return Err(format!(
            "expected string pair tuple field {key} with 2 elements, got {term}"
        ));
    }

    Ok(Some((
        term_to_string(&elements[0])?,
        term_to_string(&elements[1])?,
    )))
}

fn get_boolean_field(map: &HashMap<Term, Term>, key: &str) -> Result<bool, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) if atom.name == "true" => Ok(true),
        Some(Term::Atom(atom)) if atom.name == "false" => Ok(false),
        Some(other) => Err(format!("expected boolean field {key}, got {other}")),
        None => Ok(false),
    }
}

fn get_required_boolean_field(map: &HashMap<Term, Term>, key: &str) -> Result<bool, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) if atom.name == "true" => Ok(true),
        Some(Term::Atom(atom)) if atom.name == "false" => Ok(false),
        Some(other) => Err(format!(
            "expected required boolean field {key}, got {other}"
        )),
        None => Err(format!("missing required field: {key}")),
    }
}

fn get_optional_boolean_field(
    map: &HashMap<Term, Term>,
    key: &str,
) -> Result<Option<bool>, String> {
    match get_field(map, key) {
        Some(Term::Atom(atom)) if atom.name == "true" => Ok(Some(true)),
        Some(Term::Atom(atom)) if atom.name == "false" => Ok(Some(false)),
        Some(other) => Err(format!(
            "expected optional boolean field {key}, got {other}"
        )),
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
        Some(other) => Err(format!(
            "expected optional integer field {key}, got {other}"
        )),
        None => Ok(None),
    }
}

fn get_unit_f32_field(map: &HashMap<Term, Term>, key: &str, default: f32) -> Result<f32, String> {
    let Some(term) = get_field(map, key) else {
        return Ok(default);
    };

    let value = parse_f32(term)?;
    if (0.0..=1.0).contains(&value) {
        Ok(value)
    } else {
        Err(format!("expected unit numeric field {key}, got {term}"))
    }
}

fn get_optional_u64_field(map: &HashMap<Term, Term>, key: &str) -> Result<Option<u64>, String> {
    match get_field(map, key) {
        Some(Term::FixInteger(value)) => u64::try_from(value.value)
            .map(Some)
            .map_err(|_| format!("expected non-negative integer field {key}, got {value:?}")),
        Some(Term::BigInteger(value)) => value
            .value
            .clone()
            .try_into()
            .map(Some)
            .map_err(|_| format!("expected non-negative integer field {key}, got {value:?}")),
        Some(other) => Err(format!("expected integer field {key}, got {other}")),
        None => Ok(None),
    }
}

fn parse_positive_u32(term: &Term) -> Result<u32, String> {
    match term {
        Term::FixInteger(value) => u32::try_from(value.value)
            .ok()
            .filter(|value| *value > 0)
            .ok_or_else(|| format!("expected positive u32, got {term}")),
        Term::BigInteger(value) => value
            .to_string()
            .parse::<u32>()
            .ok()
            .filter(|value| *value > 0)
            .ok_or_else(|| format!("expected positive u32, got {term}")),
        other => Err(format!("expected positive u32, got {other}")),
    }
}

fn get_optional_usize_field(map: &HashMap<Term, Term>, key: &str) -> Result<Option<usize>, String> {
    match get_field(map, key) {
        Some(Term::FixInteger(value)) => usize::try_from(value.value)
            .map(Some)
            .map_err(|error| format!("invalid usize field {key}: {error}")),
        Some(Term::BigInteger(value)) => value
            .to_string()
            .parse::<usize>()
            .map(Some)
            .map_err(|error| format!("invalid usize field {key}: {error}")),
        Some(other) => Err(format!("expected optional usize field {key}, got {other}")),
        None => Ok(None),
    }
}

fn default_button_style() -> DivStyle {
    vec![
        StyleOp::Flex,
        StyleOp::JustifyCenter,
        StyleOp::ItemsCenter,
        StyleOp::TextCenter,
        StyleOp::P2,
        StyleOp::RoundedMd,
        StyleOp::Border1,
        StyleOp::BorderColor(ColorToken::White),
        StyleOp::Bg(ColorToken::Gray),
        StyleOp::TextColor(ColorToken::White),
        StyleOp::CursorPointer,
    ]
    .into()
}

fn default_button_focus_style() -> DivStyle {
    vec![StyleOp::BorderColor(ColorToken::Yellow)].into()
}

fn default_button_active_style() -> DivStyle {
    vec![StyleOp::Opacity(0.85)].into()
}

fn default_button_disabled_style() -> DivStyle {
    vec![StyleOp::Opacity(0.45)].into()
}

fn prepend_style(defaults: DivStyle, style: DivStyle) -> DivStyle {
    if defaults.is_empty() {
        return style;
    }

    if style.is_empty() {
        return defaults;
    }

    defaults
        .iter()
        .cloned()
        .chain(style.iter().cloned())
        .collect::<Vec<_>>()
        .into()
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

fn get_div_focus_visible_style(map: &HashMap<Term, Term>) -> Result<DivStyle, String> {
    get_style_list_field(map, "focus_visible_style")
}

fn get_div_in_focus_style(map: &HashMap<Term, Term>) -> Result<DivStyle, String> {
    get_style_list_field(map, "in_focus_style")
}

fn get_div_active_style(map: &HashMap<Term, Term>) -> Result<DivStyle, String> {
    get_style_list_field(map, "active_style")
}

fn get_div_disabled_style(map: &HashMap<Term, Term>) -> Result<DivStyle, String> {
    get_style_list_field(map, "disabled_style")
}

fn get_div_actions(map: &HashMap<Term, Term>) -> Result<HashMap<String, String>, String> {
    let Some(actions_term) = get_field(map, "actions") else {
        return Ok(HashMap::new());
    };

    let actions_map = expect_map(actions_term)?;
    let mut actions = HashMap::new();

    for (action_term, callback_term) in actions_map {
        let action_name = term_to_string(action_term)?;
        let callback_id = term_to_string(callback_term)?;
        actions.insert(action_name, callback_id);
    }

    Ok(actions)
}

fn get_div_shortcuts(
    map: &HashMap<Term, Term>,
    actions: &HashMap<String, String>,
) -> Result<Arc<[ShortcutBinding]>, String> {
    let Some(shortcuts_term) = get_field(map, "shortcuts") else {
        return Ok(Arc::new([]));
    };

    let shortcuts = get_list(shortcuts_term)?;
    shortcuts
        .iter()
        .map(|shortcut| parse_shortcut_binding(shortcut, actions))
        .collect::<Result<Vec<_>, _>>()
        .map(Into::into)
}

fn parse_shortcut_binding(
    term: &Term,
    actions: &HashMap<String, String>,
) -> Result<ShortcutBinding, String> {
    let Term::Tuple(Tuple { elements }) = term else {
        return Err(format!("expected shortcut tuple, got {term}"));
    };

    if elements.len() != 2 {
        return Err(format!(
            "expected shortcut tuple with 2 elements, got {term}"
        ));
    }

    let shortcut = term_to_string(&elements[0])?;
    let action = term_to_string(&elements[1])?;
    let callback = actions
        .get(&action)
        .cloned()
        .ok_or_else(|| format!("shortcut references unknown action: {action}"))?;

    Keystroke::parse(&shortcut)
        .map(KeybindingKeystroke::from_keystroke)
        .map_err(|error| error.to_string())
        .map(|parsed| ShortcutBinding {
            shortcut,
            action,
            callback,
            parsed,
        })
}

fn get_style_list_field(map: &HashMap<Term, Term>, key: &str) -> Result<DivStyle, String> {
    let Some(style_term) = get_field(map, key) else {
        return Ok(Vec::new().into());
    };

    let style_list = get_list(style_term)?;
    let ops = style_list
        .iter()
        .map(parse_style_op)
        .collect::<Result<Vec<_>, _>>()?;
    Ok(ops.into())
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
                "bg_hex" => Ok(StyleOp::BgHex(parse_hex_style_color(&elements[1])?)),
                "text_color_hex" => Ok(StyleOp::TextColorHex(parse_hex_style_color(&elements[1])?)),
                "border_color_hex" => Ok(StyleOp::BorderColorHex(parse_hex_style_color(
                    &elements[1],
                )?)),
                "bg_linear_gradient" => {
                    let (angle, from, to) = parse_linear_gradient_options(&elements[1])?;
                    Ok(StyleOp::BgLinearGradient { angle, from, to })
                }
                "opacity" => Ok(StyleOp::Opacity(parse_unit_style_f32(
                    &elements[1],
                    "opacity",
                )?)),
                "grid_cols" => Ok(StyleOp::GridCols(parse_grid_u16(&elements[1])?)),
                "grid_rows" => Ok(StyleOp::GridRows(parse_grid_u16(&elements[1])?)),
                "col_span" => Ok(StyleOp::ColSpan(parse_grid_u16(&elements[1])?)),
                "row_span" => Ok(StyleOp::RowSpan(parse_grid_u16(&elements[1])?)),
                "w_px" => Ok(StyleOp::WPx(parse_non_negative_style_f32(
                    &elements[1],
                    "w_px",
                )?)),
                "w_rem" => Ok(StyleOp::WRem(parse_non_negative_style_f32(
                    &elements[1],
                    "w_rem",
                )?)),
                "w_frac" => Ok(StyleOp::WFrac(parse_unit_style_f32(
                    &elements[1],
                    "w_frac",
                )?)),
                "h_px" => Ok(StyleOp::HPx(parse_non_negative_style_f32(
                    &elements[1],
                    "h_px",
                )?)),
                "h_rem" => Ok(StyleOp::HRem(parse_non_negative_style_f32(
                    &elements[1],
                    "h_rem",
                )?)),
                "h_frac" => Ok(StyleOp::HFrac(parse_unit_style_f32(
                    &elements[1],
                    "h_frac",
                )?)),
                "scrollbar_width_px" => Ok(StyleOp::ScrollbarWidthPx(
                    parse_non_negative_style_f32(&elements[1], "scrollbar_width_px")?,
                )),
                "scrollbar_width_rem" => Ok(StyleOp::ScrollbarWidthRem(
                    parse_non_negative_style_f32(&elements[1], "scrollbar_width_rem")?,
                )),
                other => Err(format!("unsupported style tuple key: {other}")),
            }
        }
        other => Err(format!("unsupported style op: {other}")),
    }
}

fn parse_style_flag(token: &str) -> Result<StyleOp, String> {
    match token {
        "grid" => Ok(StyleOp::Grid),
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
        "col_span_full" => Ok(StyleOp::ColSpanFull),
        "row_span_full" => Ok(StyleOp::RowSpanFull),
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

fn parse_linear_gradient_options(
    term: &Term,
) -> Result<(f32, LinearGradientStop, LinearGradientStop), String> {
    let options = get_list(term)?;
    let mut angle = None;
    let mut from = None;
    let mut to = None;

    for option in options {
        let Term::Tuple(Tuple { elements }) = option else {
            return Err(format!("expected gradient option tuple, got {option}"));
        };

        if elements.len() != 2 {
            return Err(format!(
                "expected gradient option tuple with 2 elements, got {option}"
            ));
        }

        let Term::Atom(key) = &elements[0] else {
            return Err(format!(
                "expected gradient option key atom, got {}",
                elements[0]
            ));
        };

        match key.name.as_str() {
            "angle" => {
                if angle.is_some() {
                    return Err("duplicate gradient angle option".into());
                }

                angle = Some(parse_gradient_angle(&elements[1])?);
            }
            "from" => {
                if from.is_some() {
                    return Err("duplicate gradient from option".into());
                }

                from = Some(parse_linear_gradient_stop(&elements[1])?);
            }
            "to" => {
                if to.is_some() {
                    return Err("duplicate gradient to option".into());
                }

                to = Some(parse_linear_gradient_stop(&elements[1])?);
            }
            other => return Err(format!("unsupported gradient option: {other}")),
        }
    }

    Ok((
        angle.ok_or_else(|| "missing gradient angle option".to_string())?,
        from.ok_or_else(|| "missing gradient from option".to_string())?,
        to.ok_or_else(|| "missing gradient to option".to_string())?,
    ))
}

fn parse_gradient_angle(term: &Term) -> Result<f32, String> {
    let value = parse_f32(term)?;

    if value.is_finite() && (0.0..=360.0).contains(&value) {
        Ok(value)
    } else {
        Err(format!("invalid gradient angle: {value}"))
    }
}

fn parse_linear_gradient_stop(term: &Term) -> Result<LinearGradientStop, String> {
    let Term::Tuple(Tuple { elements }) = term else {
        return Err(format!("expected gradient stop tuple, got {term}"));
    };

    if elements.len() != 2 {
        return Err(format!(
            "expected gradient stop tuple with 2 elements, got {term}"
        ));
    }

    Ok(LinearGradientStop {
        color: parse_style_color(&elements[0])?,
        percentage: parse_gradient_percentage(&elements[1])?,
    })
}

fn parse_gradient_percentage(term: &Term) -> Result<f32, String> {
    let value = parse_f32(term)?;

    if value.is_finite() && (0.0..=1.0).contains(&value) {
        Ok(value)
    } else {
        Err(format!("invalid gradient percentage: {value}"))
    }
}

fn parse_style_color(term: &Term) -> Result<StyleColor, String> {
    match term {
        Term::Atom(atom) => parse_color_token(&atom.name).map(StyleColor::Token),
        Term::Binary(_) | Term::ByteList(_) => parse_strict_hex_color(term)
            .map(StyleColor::Hex)
            .map_err(|error| format!("invalid gradient color: {error}")),
        other => Err(format!(
            "expected gradient color atom or #RRGGBB string, got {other}"
        )),
    }
}

fn parse_hex_style_color(term: &Term) -> Result<String, String> {
    let value = term_to_string(term)?;

    if is_hex_color(&value, false) {
        Ok(value)
    } else {
        Err(format!("invalid style hex color: {value}"))
    }
}

fn parse_strict_hex_color(term: &Term) -> Result<String, String> {
    let value = term_to_string(term)?;

    if is_hex_color(&value, true) {
        Ok(value)
    } else {
        Err(format!("invalid strict hex color: {value}"))
    }
}

fn is_hex_color(value: &str, require_hash: bool) -> bool {
    let normalized = value.strip_prefix('#').unwrap_or(value);
    (!require_hash || value.starts_with('#'))
        && normalized.len() == 6
        && normalized.bytes().all(|byte| byte.is_ascii_hexdigit())
}

fn parse_unit_style_f32(term: &Term, key: &str) -> Result<f32, String> {
    let value = parse_f32(term)?;

    if value.is_finite() && (0.0..=1.0).contains(&value) {
        Ok(value)
    } else {
        Err(format!("invalid unit numeric style {key}: {value}"))
    }
}

fn parse_non_negative_style_f32(term: &Term, key: &str) -> Result<f32, String> {
    let value = parse_f32(term)?;

    if value.is_finite() && value >= 0.0 {
        Ok(value)
    } else {
        Err(format!("invalid non-negative numeric style {key}: {value}"))
    }
}

fn parse_grid_u16(term: &Term) -> Result<u16, String> {
    let value = match term {
        Term::FixInteger(value) => value.value,
        Term::BigInteger(value) => value
            .value
            .clone()
            .try_into()
            .map_err(|_| format!("expected positive grid integer <= 65535, got {term}"))?,
        other => return Err(format!("expected positive grid integer, got {other}")),
    };

    u16::try_from(value)
        .ok()
        .filter(|value| *value >= 1)
        .ok_or_else(|| format!("expected positive grid integer <= 65535, got {term}"))
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

fn get_close_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "close")
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

fn get_change_event(map: &HashMap<Term, Term>) -> Result<Option<String>, String> {
    get_optional_event(map, "change")
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

#[cfg(test)]
#[path = "ir_tests.rs"]
mod tests;
