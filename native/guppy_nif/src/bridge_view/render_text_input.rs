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

#[cfg(test)]
mod tests {
    use super::{TextInputSpec, upsert_text_input_entity};
    use crate::{bridge_view::BridgeView, ir::IrNode};

    #[gpui::test]
    fn upsert_text_input_reuses_existing_entity_and_syncs_state(cx: &mut gpui::TestAppContext) {
        let (view, cx) = cx.add_window_view(|_, _| BridgeView {
            view_id: 11,
            ir: IrNode::text("hello"),
            retained: Default::default(),
        });

        view.update_in(cx, |view, _window, view_cx| {
            let mut pass = super::RenderPass::new(view.view_id, &mut view.retained);
            let style = Vec::new();

            let first = upsert_text_input_entity(
                &mut pass,
                "name_input",
                &TextInputSpec {
                    path: "root.0",
                    id: Some("name_input"),
                    value: "Jason",
                    placeholder: "Name",
                    style: &style,
                    disabled: false,
                    tab_index: Some(1),
                    change: Some("name_changed"),
                },
                view_cx,
            );

            let second = upsert_text_input_entity(
                &mut pass,
                "name_input",
                &TextInputSpec {
                    path: "root.0",
                    id: Some("name_input"),
                    value: "Jason Stiebs",
                    placeholder: "Full name",
                    style: &style,
                    disabled: true,
                    tab_index: Some(3),
                    change: Some("person_changed"),
                },
                view_cx,
            );

            let state = pass.finish();

            assert_eq!(first, second);
            assert_eq!(view.retained.text_inputs.len(), 1);
            assert!(state.live_text_input_ids.contains("name_input"));

            second.read_with(view_cx, |input, _| {
                assert_eq!(input.value.as_ref(), "Jason Stiebs");
                assert_eq!(input.placeholder.as_ref(), "Full name");
                assert_eq!(input.change.as_deref(), Some("person_changed"));
                assert!(input.disabled);
                assert_eq!(input.tab_index, Some(3));
            });
        });
    }
}
