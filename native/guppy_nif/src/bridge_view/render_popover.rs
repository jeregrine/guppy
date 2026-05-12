use super::{events, identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::bridge_view::BridgeView;
use crate::ir::{DivStyle, IrNode};
use gpui::{
    AnyElement, Context, Corner, InteractiveElement, IntoElement, ParentElement, SharedString,
    StatefulInteractiveElement, Styled, Window, anchored, deferred, div, px, rgb,
};

pub(crate) struct PopoverSpec<'a> {
    pub path: &'a str,
    pub id: Option<&'a str>,
    pub label: &'a str,
    pub open: bool,
    pub style: &'a DivStyle,
    pub popover_style: &'a DivStyle,
    pub disabled: bool,
    pub click: Option<&'a str>,
    pub close: Option<&'a str>,
    pub children: &'a [IrNode],
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    spec: PopoverSpec<'_>,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, spec.path, spec.id);
    let node_key = node_id.to_string();

    let mut trigger = apply_div_style(
        div()
            .id(node_id.to_shared_string())
            .flex()
            .items_center()
            .justify_center()
            .px_2()
            .py_2()
            .rounded_md()
            .border_1()
            .border_color(rgb(0x94a3b8))
            .bg(if spec.disabled {
                rgb(0x334155)
            } else {
                rgb(0x1d4ed8)
            })
            .text_color(rgb(0xffffff))
            .child(spec.label.to_owned()),
        spec.style,
    );

    if !spec.disabled
        && let Some(callback_id) = spec.click
    {
        let click_node_id = node_key.clone();
        let callback_id = callback_id.to_owned();
        trigger = trigger.on_click(move |_, _, _| {
            events::emit_click(view_id, &click_node_id, &callback_id);
        });
    }

    if spec.open {
        let child_elements = pass.render_children(
            &format!("{}.popover", spec.path),
            spec.children,
            None,
            window,
            cx,
        );
        let mut content = apply_div_style(
            div()
                .id(SharedString::from(format!("{node_key}.popover")))
                .flex()
                .flex_col()
                .gap_2()
                .p_3()
                .rounded_md()
                .border_1()
                .shadow_lg()
                .bg(rgb(0xffffff))
                .text_color(rgb(0x111827))
                .children(child_elements),
            spec.popover_style,
        );

        if !spec.disabled
            && let Some(callback_id) = spec.close
        {
            let close_node_id = format!("{node_key}.popover");
            let callback_id = callback_id.to_owned();
            content = content.on_mouse_down_out(move |_, _, _| {
                events::emit_click(view_id, &close_node_id, &callback_id);
            });
        }

        trigger = trigger.child(
            deferred(
                anchored()
                    .anchor(Corner::TopLeft)
                    .snap_to_window_with_margin(px(8.0))
                    .child(content),
            )
            .priority(1),
        );
    }

    trigger.into_any_element()
}

#[cfg(test)]
mod tests {
    use super::PopoverSpec;

    #[test]
    fn popover_spec_tracks_open_and_callbacks() {
        let style = Vec::new().into();
        let spec = PopoverSpec {
            path: "root",
            id: Some("menu"),
            label: "Open",
            open: true,
            style: &style,
            popover_style: &style,
            disabled: false,
            click: Some("open_menu"),
            close: Some("close_menu"),
            children: &[],
        };

        assert!(spec.open);
        assert_eq!(spec.click, Some("open_menu"));
        assert_eq!(spec.close, Some("close_menu"));
    }
}
