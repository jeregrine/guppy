use super::{identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::bridge_text_input::{BridgeTextInput, BridgeTextInputOptions};
use crate::bridge_view::BridgeView;
use crate::ir::DivStyle;
use gpui::{AnyElement, Context, InteractiveElement, IntoElement, ParentElement, div};

pub(crate) struct TextInputSpec<'a> {
    pub path: &'a str,
    pub id: Option<&'a str>,
    pub value: &'a str,
    pub placeholder: &'a str,
    pub style: &'a DivStyle,
    pub disabled: bool,
    pub tab_index: Option<isize>,
    pub change: Option<&'a str>,
}

fn upsert_text_input_entity(
    pass: &mut RenderPass<'_>,
    node_id: &str,
    spec: &TextInputSpec<'_>,
    cx: &mut Context<BridgeView>,
) -> gpui::Entity<BridgeTextInput> {
    pass.mark_text_input_live(node_id);

    let entity = match pass.text_input_entity(node_id) {
        Some(entity) => entity,
        None => {
            let entity = BridgeTextInput::new(
                cx,
                BridgeTextInputOptions {
                    view_id: pass.view_id(),
                    node_id: node_id.to_owned(),
                    value: spec.value.to_owned(),
                    placeholder: spec.placeholder.to_owned(),
                    change: spec.change.map(str::to_owned),
                    disabled: spec.disabled,
                    tab_index: spec.tab_index,
                },
            );
            pass.insert_text_input_entity(node_id, entity.clone());
            entity
        }
    };

    entity.update(cx, |input, _cx| {
        input.sync_from_ir(
            spec.value,
            spec.placeholder,
            spec.change,
            spec.disabled,
            spec.tab_index,
        );
    });

    entity
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    spec: TextInputSpec<'_>,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let node_id = NodeIdentity::new(pass.view_id(), spec.path, spec.id);
    let entity = upsert_text_input_entity(pass, node_id.as_ref(), &spec, cx);

    apply_div_style(
        div().id(node_id.to_shared_string()).child(entity),
        spec.style,
    )
    .into_any_element()
}
