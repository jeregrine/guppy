use super::{
    events,
    identity::NodeIdentity,
    style::{apply_div_style, style_color_to_color},
};
use crate::{
    bridge_view::BridgeView,
    ir::{CanvasCommand, CanvasNode},
};
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, MouseButton, ParentElement, Styled,
    Window, bounds, canvas, div, fill, pattern_slash, point, px, size,
};

pub(crate) fn render(
    view_id: u64,
    path: &str,
    node: &CanvasNode,
    _window: &mut Window,
    _cx: &mut Context<BridgeView>,
) -> AnyElement {
    let node_id = NodeIdentity::new(view_id, path, node.id.as_deref());
    let canvas_id = node_id.to_string();
    let commands = node.commands.clone();

    let canvas_element = canvas(
        |_, _, _| (),
        move |canvas_bounds, (), window, _cx| {
            for command in commands.iter() {
                paint_command(canvas_bounds, command, window);
            }
        },
    )
    .size_full();

    let mut wrapper = apply_div_style(
        div().id(node_id.to_shared_string()).child(canvas_element),
        &node.style,
    );

    if let Some(callback_id) = node.click.as_ref() {
        let callback_id = callback_id.clone();
        let click_canvas_id = canvas_id.clone();
        wrapper = wrapper.on_mouse_down(MouseButton::Left, move |_, _, _| {
            events::emit_click(view_id, &click_canvas_id, &callback_id);
        });
    }

    if let Some(callback_id) = node.context_menu.as_ref() {
        let callback_id = callback_id.clone();
        let context_canvas_id = canvas_id.clone();
        wrapper = wrapper.on_mouse_down(MouseButton::Right, move |event, _, _| {
            events::emit_context_menu(view_id, &context_canvas_id, &callback_id, event);
        });
    }

    wrapper.into_any_element()
}

fn paint_command(
    canvas_bounds: gpui::Bounds<gpui::Pixels>,
    command: &CanvasCommand,
    window: &mut Window,
) {
    match command {
        CanvasCommand::Rect {
            x,
            y,
            width,
            height,
            fill: color,
            radius,
        } => paint_rect(
            canvas_bounds,
            CanvasRect::new(*x, *y, *width, *height),
            style_color_to_color(color),
            *radius,
            window,
        ),
        CanvasCommand::PatternRect {
            x,
            y,
            width,
            height,
            color,
            line_width,
            interval,
            radius,
        } => paint_rect(
            canvas_bounds,
            CanvasRect::new(*x, *y, *width, *height),
            pattern_slash(style_color_to_color(color), *line_width, *interval),
            *radius,
            window,
        ),
    }
}

#[derive(Clone, Copy)]
struct CanvasRect {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
}

impl CanvasRect {
    fn new(x: f32, y: f32, width: f32, height: f32) -> Self {
        Self {
            x,
            y,
            width,
            height,
        }
    }
}

fn paint_rect(
    canvas_bounds: gpui::Bounds<gpui::Pixels>,
    rect: CanvasRect,
    background: impl Into<gpui::Background>,
    radius: f32,
    window: &mut Window,
) {
    window
        .paint_quad(fill(command_bounds(canvas_bounds, rect), background).corner_radii(px(radius)));
}

fn command_bounds(
    canvas_bounds: gpui::Bounds<gpui::Pixels>,
    rect: CanvasRect,
) -> gpui::Bounds<gpui::Pixels> {
    bounds(
        point(
            canvas_bounds.origin.x + px(rect.x),
            canvas_bounds.origin.y + px(rect.y),
        ),
        size(px(rect.width), px(rect.height)),
    )
}

#[cfg(test)]
mod tests {
    use crate::bridge_view::events;

    #[test]
    fn canvas_click_event_uses_canvas_identity() {
        events::emit_click(11, "summary_canvas", "canvas_clicked");
        let after = crate::native_event_send_snapshot_for_test();
        assert!(after.0 > 0);
    }

    #[test]
    fn canvas_context_menu_event_uses_canvas_identity() {
        use gpui::{KeyDownEvent, Keystroke};

        events::emit_keyboard_context_menu(
            11,
            "summary_canvas",
            "canvas_context_menu",
            &KeyDownEvent {
                keystroke: Keystroke::parse("shift-f10").expect("valid keystroke"),
                is_held: false,
            },
        );

        let event = crate::take_basic_event_snapshot_for_test().unwrap();
        assert_eq!(event.event, "context_menu");
        assert_eq!(event.node_id.as_deref(), Some("summary_canvas"));
        assert_eq!(event.callback_id.as_deref(), Some("canvas_context_menu"));
    }
}
