use gpui::{
    App, Bounds, Context, CursorStyle, Element, ElementId, ElementInputHandler, Entity,
    EntityInputHandler, FocusHandle, Focusable, GlobalElementId, IntoElement, KeyBinding, LayoutId,
    MouseButton, MouseDownEvent, MouseMoveEvent, MouseUpEvent, PaintQuad, Pixels, Point, Render,
    SharedString, Style, TextRun, UTF16Selection, Window, actions, div, fill, hsla, point,
    prelude::*, px, relative, rgb, rgba,
};
use std::ops::Range;
use unicode_segmentation::UnicodeSegmentation;

unsafe extern "C" {
    fn guppy_c_send_change_event(
        view_id: u64,
        node_id_ptr: *const u8,
        node_id_len: usize,
        callback_id_ptr: *const u8,
        callback_id_len: usize,
        value_ptr: *const u8,
        value_len: usize,
    ) -> i32;
}

actions!(
    guppy_text_input,
    [
        Backspace,
        Delete,
        Left,
        Right,
        SelectLeft,
        SelectRight,
        SelectAll,
        Home,
        End,
        Newline,
        ShowCharacterPalette,
        Paste,
        Cut,
        Copy,
    ]
);

pub fn bind_keys(cx: &mut App) {
    cx.bind_keys([
        KeyBinding::new("backspace", Backspace, None),
        KeyBinding::new("delete", Delete, None),
        KeyBinding::new("left", Left, None),
        KeyBinding::new("right", Right, None),
        KeyBinding::new("shift-left", SelectLeft, None),
        KeyBinding::new("shift-right", SelectRight, None),
        KeyBinding::new("cmd-a", SelectAll, None),
        KeyBinding::new("enter", Newline, None),
        KeyBinding::new("cmd-v", Paste, None),
        KeyBinding::new("cmd-c", Copy, None),
        KeyBinding::new("cmd-x", Cut, None),
        KeyBinding::new("home", Home, None),
        KeyBinding::new("end", End, None),
        KeyBinding::new("ctrl-cmd-space", ShowCharacterPalette, None),
    ]);
}

pub struct BridgeTextInputOptions {
    pub view_id: u64,
    pub node_id: String,
    pub value: String,
    pub placeholder: String,
    pub change: Option<String>,
    pub disabled: bool,
    pub tab_index: Option<isize>,
    pub multiline: bool,
}

pub struct BridgeTextInput {
    pub view_id: u64,
    pub node_id: String,
    pub value: SharedString,
    pub placeholder: SharedString,
    pub change: Option<String>,
    pub disabled: bool,
    pub tab_index: Option<isize>,
    pub multiline: bool,
    focus_handle: FocusHandle,
    selected_range: Range<usize>,
    selection_reversed: bool,
    marked_range: Option<Range<usize>>,
    last_lines: Vec<LineLayout>,
    last_bounds: Option<Bounds<Pixels>>,
    is_selecting: bool,
}

impl BridgeTextInput {
    pub fn new(
        cx: &mut Context<crate::bridge_view::BridgeView>,
        options: BridgeTextInputOptions,
    ) -> Entity<Self> {
        let BridgeTextInputOptions {
            view_id,
            node_id,
            value,
            placeholder,
            change,
            disabled,
            tab_index,
            multiline,
        } = options;

        cx.new(|cx| Self {
            view_id,
            node_id,
            value: value.into(),
            placeholder: placeholder.into(),
            change,
            disabled,
            tab_index,
            multiline,
            focus_handle: focus_handle_for(cx, tab_index, disabled),
            selected_range: 0..0,
            selection_reversed: false,
            marked_range: None,
            last_lines: Vec::new(),
            last_bounds: None,
            is_selecting: false,
        })
    }

    pub fn sync_from_ir(
        &mut self,
        value: &str,
        placeholder: &str,
        change: Option<&str>,
        disabled: bool,
        tab_index: Option<isize>,
        multiline: bool,
    ) {
        if self.value.as_ref() != value {
            self.value = value.to_owned().into();
            let cursor = self.value.len();
            self.selected_range = cursor..cursor;
            self.selection_reversed = false;
            self.marked_range = None;
        }

        self.placeholder = placeholder.to_owned().into();
        self.change = change.map(str::to_owned);
        self.disabled = disabled;
        self.tab_index = tab_index;
        self.multiline = multiline;
        self.focus_handle = configure_focus_handle(self.focus_handle.clone(), tab_index, disabled);
    }

    pub fn focus_handle(&self) -> FocusHandle {
        self.focus_handle.clone()
    }

    fn send_change_event(&self) {
        let Some(callback_id) = self.change.as_ref() else {
            return;
        };

        unsafe {
            let _ = guppy_c_send_change_event(
                self.view_id,
                self.node_id.as_ptr(),
                self.node_id.len(),
                callback_id.as_ptr(),
                callback_id.len(),
                self.value.as_bytes().as_ptr(),
                self.value.len(),
            );
        }
    }

    fn left(&mut self, _: &Left, _: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        if self.selected_range.is_empty() {
            self.move_to(self.previous_boundary(self.cursor_offset()), cx);
        } else {
            self.move_to(self.selected_range.start, cx)
        }
    }

    fn right(&mut self, _: &Right, _: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        if self.selected_range.is_empty() {
            self.move_to(self.next_boundary(self.selected_range.end), cx);
        } else {
            self.move_to(self.selected_range.end, cx)
        }
    }

    fn select_left(&mut self, _: &SelectLeft, _: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        self.select_to(self.previous_boundary(self.cursor_offset()), cx);
    }

    fn select_right(&mut self, _: &SelectRight, _: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        self.select_to(self.next_boundary(self.cursor_offset()), cx);
    }

    fn select_all(&mut self, _: &SelectAll, _: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        self.move_to(0, cx);
        self.select_to(self.value.len(), cx)
    }

    fn home(&mut self, _: &Home, _: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        self.move_to(0, cx);
    }

    fn end(&mut self, _: &End, _: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        self.move_to(self.value.len(), cx);
    }

    fn backspace(&mut self, _: &Backspace, window: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        if self.selected_range.is_empty() {
            self.select_to(self.previous_boundary(self.cursor_offset()), cx)
        }
        self.replace_text_in_range(None, "", window, cx)
    }

    fn delete(&mut self, _: &Delete, window: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        if self.selected_range.is_empty() {
            self.select_to(self.next_boundary(self.cursor_offset()), cx)
        }
        self.replace_text_in_range(None, "", window, cx)
    }

    fn on_mouse_down(
        &mut self,
        event: &MouseDownEvent,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        if self.disabled {
            return;
        }

        self.is_selecting = true;

        if event.modifiers.shift {
            self.select_to(self.index_for_mouse_position(event.position), cx);
        } else {
            self.move_to(self.index_for_mouse_position(event.position), cx)
        }
    }

    fn on_mouse_up(&mut self, _: &MouseUpEvent, _window: &mut Window, _: &mut Context<Self>) {
        self.is_selecting = false;
    }

    fn on_mouse_move(&mut self, event: &MouseMoveEvent, _: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        if self.is_selecting {
            self.select_to(self.index_for_mouse_position(event.position), cx);
        }
    }

    fn show_character_palette(
        &mut self,
        _: &ShowCharacterPalette,
        window: &mut Window,
        _: &mut Context<Self>,
    ) {
        if self.disabled {
            return;
        }

        window.show_character_palette();
    }

    fn newline(&mut self, _: &Newline, window: &mut Window, cx: &mut Context<Self>) {
        if self.disabled || !self.multiline {
            return;
        }

        self.replace_text_in_range(None, "\n", window, cx);
    }

    fn paste(&mut self, _: &Paste, window: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        if let Some(text) = cx.read_from_clipboard().and_then(|item| item.text()) {
            let text = if self.multiline {
                text
            } else {
                text.replace("\n", " ")
            };
            self.replace_text_in_range(None, &text, window, cx);
        }
    }

    fn copy(&mut self, _: &Copy, _: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        if !self.selected_range.is_empty() {
            cx.write_to_clipboard(gpui::ClipboardItem::new_string(
                self.value[self.selected_range.clone()].to_string(),
            ));
        }
    }

    fn cut(&mut self, _: &Cut, window: &mut Window, cx: &mut Context<Self>) {
        if self.disabled {
            return;
        }

        if !self.selected_range.is_empty() {
            cx.write_to_clipboard(gpui::ClipboardItem::new_string(
                self.value[self.selected_range.clone()].to_string(),
            ));
            self.replace_text_in_range(None, "", window, cx)
        }
    }

    fn move_to(&mut self, offset: usize, cx: &mut Context<Self>) {
        self.selected_range = offset..offset;
        cx.notify()
    }

    fn cursor_offset(&self) -> usize {
        if self.selection_reversed {
            self.selected_range.start
        } else {
            self.selected_range.end
        }
    }

    fn index_for_mouse_position(&self, position: Point<Pixels>) -> usize {
        if self.value.is_empty() {
            return 0;
        }

        let Some(bounds) = self.last_bounds.as_ref() else {
            return 0;
        };
        if position.y < bounds.top() {
            return 0;
        }
        if position.y > bounds.bottom() {
            return self.value.len();
        }
        let local_y = position.y - bounds.top();
        let line = self
            .last_lines
            .iter()
            .find(|line| local_y >= line.top && local_y <= line.bottom)
            .or_else(|| self.last_lines.last());

        line.map(|line| line.start + line.layout.closest_index_for_x(position.x - bounds.left()))
            .unwrap_or(0)
    }

    fn select_to(&mut self, offset: usize, cx: &mut Context<Self>) {
        if self.selection_reversed {
            self.selected_range.start = offset
        } else {
            self.selected_range.end = offset
        };
        if self.selected_range.end < self.selected_range.start {
            self.selection_reversed = !self.selection_reversed;
            self.selected_range = self.selected_range.end..self.selected_range.start;
        }
        cx.notify()
    }

    fn offset_from_utf16(&self, offset: usize) -> usize {
        let mut utf8_offset = 0;
        let mut utf16_count = 0;

        for ch in self.value.chars() {
            if utf16_count >= offset {
                break;
            }
            utf16_count += ch.len_utf16();
            utf8_offset += ch.len_utf8();
        }

        utf8_offset
    }

    fn offset_to_utf16(&self, offset: usize) -> usize {
        let mut utf16_offset = 0;
        let mut utf8_count = 0;

        for ch in self.value.chars() {
            if utf8_count >= offset {
                break;
            }
            utf8_count += ch.len_utf8();
            utf16_offset += ch.len_utf16();
        }

        utf16_offset
    }

    fn range_to_utf16(&self, range: &Range<usize>) -> Range<usize> {
        self.offset_to_utf16(range.start)..self.offset_to_utf16(range.end)
    }

    fn range_from_utf16(&self, range_utf16: &Range<usize>) -> Range<usize> {
        self.offset_from_utf16(range_utf16.start)..self.offset_from_utf16(range_utf16.end)
    }

    fn previous_boundary(&self, offset: usize) -> usize {
        self.value
            .grapheme_indices(true)
            .rev()
            .find_map(|(idx, _)| (idx < offset).then_some(idx))
            .unwrap_or(0)
    }

    fn next_boundary(&self, offset: usize) -> usize {
        self.value
            .grapheme_indices(true)
            .find_map(|(idx, _)| (idx > offset).then_some(idx))
            .unwrap_or(self.value.len())
    }

    fn line_for_offset(&self, offset: usize) -> Option<&LineLayout> {
        self.last_lines
            .iter()
            .find(|line| offset >= line.start && offset <= line.end)
            .or_else(|| self.last_lines.last())
    }
}

impl EntityInputHandler for BridgeTextInput {
    fn text_for_range(
        &mut self,
        range_utf16: Range<usize>,
        actual_range: &mut Option<Range<usize>>,
        _window: &mut Window,
        _cx: &mut Context<Self>,
    ) -> Option<String> {
        let range = self.range_from_utf16(&range_utf16);
        actual_range.replace(self.range_to_utf16(&range));
        Some(self.value[range].to_string())
    }

    fn selected_text_range(
        &mut self,
        _ignore_disabled_input: bool,
        _window: &mut Window,
        _cx: &mut Context<Self>,
    ) -> Option<UTF16Selection> {
        Some(UTF16Selection {
            range: self.range_to_utf16(&self.selected_range),
            reversed: self.selection_reversed,
        })
    }

    fn marked_text_range(
        &self,
        _window: &mut Window,
        _cx: &mut Context<Self>,
    ) -> Option<Range<usize>> {
        self.marked_range
            .as_ref()
            .map(|range| self.range_to_utf16(range))
    }

    fn unmark_text(&mut self, _window: &mut Window, _cx: &mut Context<Self>) {
        self.marked_range = None;
    }

    fn replace_text_in_range(
        &mut self,
        range_utf16: Option<Range<usize>>,
        new_text: &str,
        _: &mut Window,
        cx: &mut Context<Self>,
    ) {
        if self.disabled {
            return;
        }

        let range = range_utf16
            .as_ref()
            .map(|range_utf16| self.range_from_utf16(range_utf16))
            .or(self.marked_range.clone())
            .unwrap_or(self.selected_range.clone());

        self.value =
            (self.value[0..range.start].to_owned() + new_text + &self.value[range.end..]).into();
        self.selected_range = range.start + new_text.len()..range.start + new_text.len();
        self.marked_range.take();
        self.send_change_event();
        cx.notify();
    }

    fn replace_and_mark_text_in_range(
        &mut self,
        range_utf16: Option<Range<usize>>,
        new_text: &str,
        new_selected_range_utf16: Option<Range<usize>>,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        if self.disabled {
            return;
        }

        let range = range_utf16
            .as_ref()
            .map(|range_utf16| self.range_from_utf16(range_utf16))
            .or(self.marked_range.clone())
            .unwrap_or(self.selected_range.clone());

        self.value =
            (self.value[0..range.start].to_owned() + new_text + &self.value[range.end..]).into();
        if !new_text.is_empty() {
            self.marked_range = Some(range.start..range.start + new_text.len());
        } else {
            self.marked_range = None;
        }
        self.selected_range = new_selected_range_utf16
            .as_ref()
            .map(|range_utf16| self.range_from_utf16(range_utf16))
            .map(|new_range| new_range.start + range.start..new_range.end + range.start)
            .unwrap_or_else(|| range.start + new_text.len()..range.start + new_text.len());

        self.send_change_event();
        cx.notify();
    }

    fn bounds_for_range(
        &mut self,
        range_utf16: Range<usize>,
        bounds: Bounds<Pixels>,
        _window: &mut Window,
        _cx: &mut Context<Self>,
    ) -> Option<Bounds<Pixels>> {
        let range = self.range_from_utf16(&range_utf16);
        let line = self.line_for_offset(range.start)?;
        Some(Bounds::from_corners(
            point(
                bounds.left()
                    + line
                        .layout
                        .x_for_index(range.start.saturating_sub(line.start)),
                bounds.top() + line.top,
            ),
            point(
                bounds.left()
                    + line
                        .layout
                        .x_for_index(range.end.min(line.end).saturating_sub(line.start)),
                bounds.top() + line.bottom,
            ),
        ))
    }

    fn character_index_for_point(
        &mut self,
        point: Point<Pixels>,
        _window: &mut Window,
        _cx: &mut Context<Self>,
    ) -> Option<usize> {
        let line_point = self.last_bounds?.localize(&point)?;
        let line = self
            .last_lines
            .iter()
            .find(|line| line_point.y >= line.top && line_point.y <= line.bottom)
            .or_else(|| self.last_lines.last())?;
        let utf8_index = line.start + line.layout.index_for_x(line_point.x)?;
        Some(self.offset_to_utf16(utf8_index))
    }
}

struct TextElement {
    input: Entity<BridgeTextInput>,
}

struct LineLayout {
    start: usize,
    end: usize,
    top: Pixels,
    bottom: Pixels,
    layout: gpui::ShapedLine,
}

struct PrepaintState {
    lines: Vec<LineLayout>,
    cursor: Option<PaintQuad>,
    selections: Vec<PaintQuad>,
}

impl IntoElement for TextElement {
    type Element = Self;

    fn into_element(self) -> Self::Element {
        self
    }
}

impl Element for TextElement {
    type RequestLayoutState = ();
    type PrepaintState = PrepaintState;

    fn id(&self) -> Option<ElementId> {
        None
    }

    fn source_location(&self) -> Option<&'static core::panic::Location<'static>> {
        None
    }

    fn request_layout(
        &mut self,
        _id: Option<&GlobalElementId>,
        _inspector_id: Option<&gpui::InspectorElementId>,
        window: &mut Window,
        cx: &mut App,
    ) -> (LayoutId, Self::RequestLayoutState) {
        let input = self.input.read(cx);
        let mut style = Style::default();
        style.size.width = relative(1.).into();
        style.size.height = if input.multiline {
            (window.line_height() * 5.).into()
        } else {
            window.line_height().into()
        };
        (window.request_layout(style, [], cx), ())
    }

    fn prepaint(
        &mut self,
        _id: Option<&GlobalElementId>,
        _inspector_id: Option<&gpui::InspectorElementId>,
        bounds: Bounds<Pixels>,
        _request_layout: &mut Self::RequestLayoutState,
        window: &mut Window,
        cx: &mut App,
    ) -> Self::PrepaintState {
        let input = self.input.read(cx);
        let content = input.value.clone();
        let selected_range = input.selected_range.clone();
        let cursor = input.cursor_offset();
        let style = window.text_style();

        let (display_text, text_color) = if content.is_empty() {
            (input.placeholder.clone(), hsla(0., 0., 0., 0.35))
        } else {
            (content, style.color)
        };

        let font_size = style.font_size.to_pixels(window.rem_size());
        let line_height = window.line_height();
        let mut lines = Vec::new();
        let mut selections = Vec::new();
        let mut cursor_quad = None;

        for (line_index, (start, end)) in line_ranges(display_text.as_ref()).into_iter().enumerate()
        {
            let line_text = display_text[start..end].to_string();
            let run = TextRun {
                len: line_text.len(),
                font: style.font(),
                color: text_color,
                background_color: None,
                underline: None,
                strikethrough: None,
            };
            let layout = window
                .text_system()
                .shape_line(line_text.into(), font_size, &[run], None);
            let top = line_height * line_index as f32;
            let bottom = top + line_height;

            if selected_range.is_empty() && cursor >= start && cursor <= end {
                let cursor_pos = layout.x_for_index(cursor.saturating_sub(start));
                cursor_quad = Some(fill(
                    Bounds::new(
                        point(bounds.left() + cursor_pos, bounds.top() + top),
                        gpui::size(px(2.), line_height),
                    ),
                    gpui::blue(),
                ));
            } else if !selected_range.is_empty() {
                let selection_start = selected_range.start.max(start);
                let selection_end = selected_range.end.min(end);
                if selection_start < selection_end {
                    selections.push(fill(
                        Bounds::from_corners(
                            point(
                                bounds.left()
                                    + layout.x_for_index(selection_start.saturating_sub(start)),
                                bounds.top() + top,
                            ),
                            point(
                                bounds.left()
                                    + layout.x_for_index(selection_end.saturating_sub(start)),
                                bounds.top() + bottom,
                            ),
                        ),
                        rgba(0x3311ff30),
                    ));
                }
            }

            lines.push(LineLayout {
                start,
                end,
                top,
                bottom,
                layout,
            });
        }

        PrepaintState {
            lines,
            cursor: cursor_quad,
            selections,
        }
    }

    fn paint(
        &mut self,
        _id: Option<&GlobalElementId>,
        _inspector_id: Option<&gpui::InspectorElementId>,
        bounds: Bounds<Pixels>,
        _request_layout: &mut Self::RequestLayoutState,
        prepaint: &mut Self::PrepaintState,
        window: &mut Window,
        cx: &mut App,
    ) {
        let focus_handle = self.input.read(cx).focus_handle.clone();
        let disabled = self.input.read(cx).disabled;
        if !disabled {
            window.handle_input(
                &focus_handle,
                ElementInputHandler::new(bounds, self.input.clone()),
                cx,
            );
        }
        for selection in prepaint.selections.drain(..) {
            window.paint_quad(selection)
        }

        for line in &prepaint.lines {
            line.layout
                .paint(
                    point(bounds.left(), bounds.top() + line.top),
                    window.line_height(),
                    window,
                    cx,
                )
                .unwrap();
        }

        if focus_handle.is_focused(window)
            && let Some(cursor) = prepaint.cursor.take()
            && !disabled
        {
            window.paint_quad(cursor);
        }

        let lines = std::mem::take(&mut prepaint.lines);
        self.input.update(cx, |input, _cx| {
            input.last_lines = lines;
            input.last_bounds = Some(bounds);
        });
    }
}

fn line_ranges(text: &str) -> Vec<(usize, usize)> {
    if text.is_empty() {
        return vec![(0, 0)];
    }

    let mut ranges = Vec::new();
    let mut start = 0;
    for (index, ch) in text.char_indices() {
        if ch == '\n' {
            ranges.push((start, index));
            start = index + ch.len_utf8();
        }
    }
    ranges.push((start, text.len()));
    ranges
}

impl Render for BridgeTextInput {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let background = if self.disabled {
            rgb(0x2f2f2f)
        } else {
            rgb(0xffffff)
        };
        let text_color = if self.disabled {
            rgb(0x9f9f9f)
        } else {
            rgb(0x111111)
        };
        let border_color = if self.disabled {
            rgb(0x666666)
        } else {
            rgb(0xd0d0d0)
        };
        let handle = self.focus_handle.clone();

        div()
            .w_full()
            .key_context("BridgeTextInput")
            .track_focus(&handle)
            .cursor(if self.disabled {
                CursorStyle::Arrow
            } else {
                CursorStyle::IBeam
            })
            .on_action(cx.listener(Self::backspace))
            .on_action(cx.listener(Self::delete))
            .on_action(cx.listener(Self::left))
            .on_action(cx.listener(Self::right))
            .on_action(cx.listener(Self::select_left))
            .on_action(cx.listener(Self::select_right))
            .on_action(cx.listener(Self::select_all))
            .on_action(cx.listener(Self::home))
            .on_action(cx.listener(Self::end))
            .on_action(cx.listener(Self::newline))
            .on_action(cx.listener(Self::show_character_palette))
            .on_action(cx.listener(Self::paste))
            .on_action(cx.listener(Self::cut))
            .on_action(cx.listener(Self::copy))
            .on_mouse_down(MouseButton::Left, cx.listener(Self::on_mouse_down))
            .on_mouse_up(MouseButton::Left, cx.listener(Self::on_mouse_up))
            .on_mouse_up_out(MouseButton::Left, cx.listener(Self::on_mouse_up))
            .on_mouse_move(cx.listener(Self::on_mouse_move))
            .child(
                div()
                    .w_full()
                    .h(if self.multiline { px(120.0) } else { px(36.0) })
                    .p(px(6.0))
                    .rounded_md()
                    .border_1()
                    .border_color(border_color)
                    .bg(background)
                    .text_color(text_color)
                    .child(TextElement { input: cx.entity() }),
            )
    }
}

impl Focusable for BridgeTextInput {
    fn focus_handle(&self, _: &App) -> FocusHandle {
        self.focus_handle.clone()
    }
}

fn focus_handle_for(
    cx: &mut Context<BridgeTextInput>,
    tab_index: Option<isize>,
    disabled: bool,
) -> FocusHandle {
    configure_focus_handle(cx.focus_handle(), tab_index, disabled)
}

fn configure_focus_handle(
    focus_handle: FocusHandle,
    tab_index: Option<isize>,
    disabled: bool,
) -> FocusHandle {
    let focus_handle = focus_handle.tab_stop(!disabled);

    match tab_index {
        Some(index) => focus_handle.tab_index(index),
        None => focus_handle,
    }
}

#[cfg(test)]
mod tests {
    use super::line_ranges;

    #[test]
    fn line_ranges_preserve_empty_multiline_segments() {
        assert_eq!(line_ranges(""), vec![(0, 0)]);
        assert_eq!(line_ranges("one\ntwo"), vec![(0, 3), (4, 7)]);
        assert_eq!(line_ranges("one\n"), vec![(0, 3), (4, 4)]);
        assert_eq!(line_ranges("one\n\nthree"), vec![(0, 3), (4, 4), (5, 10)]);
    }
}
