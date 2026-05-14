use super::{events, identity::NodeIdentity, render_pass::RenderPass, style::apply_div_style};
use crate::{
    bridge_view::BridgeView,
    ir::{
        DataTableCell, DataTableColumn, DataTableColumnWidth, DataTableNode, DataTableRow,
        DivStyle, IrNode, TextRunSegment,
    },
};
use gpui::{
    AnyElement, Context, InteractiveElement, InteractiveText, IntoElement, ParentElement,
    SharedString, StatefulInteractiveElement, Styled, Window, div, list, px,
};
use std::sync::Arc;

const ROW_CLICK_EVENT: i32 = 1;
const CELL_CLICK_EVENT: i32 = 2;
const SORT_EVENT: i32 = 3;

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    table: &DataTableNode,
    _window: &mut Window,
    _cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, table.id.as_deref());
    let table_id = node_id.to_string();
    let list_id = format!("{table_id}.rows");
    let state = pass.retain_list_state(&list_id, table.rows.len());
    let columns: Arc<[DataTableColumn]> = table.columns.clone().into();
    let rows: Arc<[DataTableRow]> = table.rows.clone().into();
    let row_style = table.row_style.clone();
    let cell_style = table.cell_style.clone();
    let row_click = table.row_click.clone();
    let cell_click = table.cell_click.clone();
    let table_id_for_rows = table_id.clone();

    let body = list(state, move |index, _window, _cx| {
        rows.get(index)
            .map(|row| {
                render_row(
                    view_id,
                    &table_id_for_rows,
                    row,
                    &columns,
                    &row_style,
                    &cell_style,
                    row_click.as_deref(),
                    cell_click.as_deref(),
                )
            })
            .unwrap_or_else(|| div().into_any_element())
    })
    .size_full();

    let header = render_header(
        view_id,
        &table_id,
        &table.columns,
        &table.header_style,
        table.sort_callback.as_deref(),
    );

    apply_div_style(
        div()
            .id(node_id.to_shared_string())
            .flex()
            .flex_col()
            .size_full()
            .child(header)
            .child(body),
        &table.style,
    )
    .into_any_element()
}

fn render_header(
    view_id: u64,
    table_id: &str,
    columns: &[DataTableColumn],
    header_style: &DivStyle,
    sort_callback: Option<&str>,
) -> AnyElement {
    let children = columns.iter().map(|column| {
        let header_id = format!("{table_id}.header.{}", column.id);
        let mut cell = apply_column_width(
            apply_div_style(
                div()
                    .id(SharedString::from(header_id.clone()))
                    .p_2()
                    .child(column.label.clone()),
                &column.style,
            ),
            &column.width,
        );

        if column.sortable
            && let Some(callback_id) = sort_callback
        {
            let callback_id = callback_id.to_owned();
            let table_id = table_id.to_owned();
            let column_id = column.id.clone();
            cell = cell.on_click(move |_, _, _| {
                events::emit_data_table_event(
                    view_id,
                    SORT_EVENT,
                    &header_id,
                    &callback_id,
                    &table_id,
                    None,
                    Some(&column_id),
                );
            });
        }

        cell.into_any_element()
    });

    apply_div_style(
        div()
            .id(SharedString::from(format!("{table_id}.header")))
            .flex()
            .flex_row()
            .children(children),
        header_style,
    )
    .into_any_element()
}

#[allow(clippy::too_many_arguments)]
fn render_row(
    view_id: u64,
    table_id: &str,
    row: &DataTableRow,
    columns: &[DataTableColumn],
    row_style: &DivStyle,
    cell_style: &DivStyle,
    row_click: Option<&str>,
    cell_click: Option<&str>,
) -> AnyElement {
    let row_id = format!("{table_id}.row.{}", row.id);
    let cells = columns.iter().map(|column| {
        let cell = row.cells.iter().find(|cell| cell.column_id == column.id);
        render_cell(
            view_id, table_id, &row.id, column, cell, cell_style, cell_click,
        )
    });

    let mut element = apply_div_style(
        div()
            .id(SharedString::from(row_id.clone()))
            .flex()
            .flex_row()
            .children(cells),
        row_style,
    );
    element = apply_div_style(element, &row.style);

    if let Some(callback_id) = row_click {
        let callback_id = callback_id.to_owned();
        let table_id = table_id.to_owned();
        let row_value = row.id.clone();
        element = element.on_click(move |_, _, _| {
            events::emit_data_table_event(
                view_id,
                ROW_CLICK_EVENT,
                &row_id,
                &callback_id,
                &table_id,
                Some(&row_value),
                None,
            );
        });
    }

    element.into_any_element()
}

fn render_cell(
    view_id: u64,
    table_id: &str,
    row_id: &str,
    column: &DataTableColumn,
    cell: Option<&DataTableCell>,
    cell_style: &DivStyle,
    cell_click: Option<&str>,
) -> AnyElement {
    let cell_id = format!("{table_id}.cell.{row_id}.{}", column.id);
    let children = cell
        .map(|cell| {
            cell.children
                .iter()
                .enumerate()
                .map(|(index, child)| {
                    render_static_node(view_id, &format!("{cell_id}.{index}"), child)
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    let mut element = apply_column_width(
        apply_div_style(
            div()
                .id(SharedString::from(cell_id.clone()))
                .p_2()
                .children(children),
            cell_style,
        ),
        &column.width,
    );

    if let Some(cell) = cell {
        element = apply_div_style(element, &cell.style);
    }

    if let Some(callback_id) = cell_click {
        let callback_id = callback_id.to_owned();
        let table_id = table_id.to_owned();
        let row_id = row_id.to_owned();
        let column_id = column.id.clone();
        element = element.on_click(move |_, _, _| {
            events::emit_data_table_event(
                view_id,
                CELL_CLICK_EVENT,
                &cell_id,
                &callback_id,
                &table_id,
                Some(&row_id),
                Some(&column_id),
            );
        });
    }

    element.into_any_element()
}

fn apply_column_width<E>(element: E, width: &DataTableColumnWidth) -> E
where
    E: Styled + StatefulInteractiveElement,
{
    match width {
        DataTableColumnWidth::Auto => element.flex_1(),
        DataTableColumnWidth::Px(value) => element.w(px(*value)),
        DataTableColumnWidth::Fr(_value) => element.flex_1(),
    }
}

fn render_static_node(view_id: u64, path: &str, ir: &IrNode) -> AnyElement {
    match ir {
        IrNode::Text {
            id,
            content,
            runs,
            style,
            click,
        } => render_static_text(
            view_id,
            path,
            id.as_deref(),
            content,
            runs,
            style,
            click.as_deref(),
        ),
        IrNode::Spacer { id, style } => {
            let node_id = NodeIdentity::new(view_id, path, id.as_deref());
            apply_div_style(div().id(node_id.to_shared_string()), style).into_any_element()
        }
        IrNode::Div(node) => {
            let node_id = NodeIdentity::new(view_id, path, node.id.as_deref());
            let children = node.children.iter().enumerate().map(|(index, child)| {
                render_static_node(view_id, &format!("{path}.{index}"), child)
            });
            apply_div_style(
                div().id(node_id.to_shared_string()).children(children),
                &node.style,
            )
            .into_any_element()
        }
        _ => div()
            .child("Unsupported data-table cell child")
            .into_any_element(),
    }
}

fn render_static_text(
    view_id: u64,
    path: &str,
    id: Option<&str>,
    content: &str,
    runs: &[TextRunSegment],
    style: &DivStyle,
    click: Option<&str>,
) -> AnyElement {
    let node_id = NodeIdentity::new(view_id, path, id);
    let interactive_text = InteractiveText::new(
        node_id.to_shared_string(),
        super::render_text::styled_text(content, runs),
    );

    let element = match click {
        Some(callback_id) if !content.is_empty() => {
            let callback_id = callback_id.to_owned();
            let click_node_id = node_id.to_string();
            let clickable_ranges = std::iter::once(0..content.len()).collect::<Vec<_>>();

            interactive_text
                .on_click(clickable_ranges, move |_, _, _| {
                    events::emit_click(view_id, &click_node_id, &callback_id);
                })
                .into_any_element()
        }
        _ => interactive_text.into_any_element(),
    };

    if style.is_empty() {
        element
    } else {
        apply_div_style(
            div().id(SharedString::from(format!("{}::text_style", node_id))),
            style,
        )
        .child(element)
        .into_any_element()
    }
}

#[cfg(test)]
mod tests {
    use super::{CELL_CLICK_EVENT, ROW_CLICK_EVENT, SORT_EVENT};
    use crate::bridge_view::events;

    #[test]
    fn data_table_events_include_semantic_identity() {
        events::emit_data_table_event(
            7,
            ROW_CLICK_EVENT,
            "table.row.row_1",
            "select_row",
            "table",
            Some("row_1"),
            None,
        );
        let event = crate::take_semantic_event_snapshot_for_test().unwrap();
        assert_eq!(event.event, "data_table_row_click");
        assert_eq!(event.view_id, 7);
        assert_eq!(event.table_id.as_deref(), Some("table"));
        assert_eq!(event.row_id.as_deref(), Some("row_1"));
        assert_eq!(event.column_id, None);

        events::emit_data_table_event(
            7,
            CELL_CLICK_EVENT,
            "table.cell.row_1.status",
            "select_cell",
            "table",
            Some("row_1"),
            Some("status"),
        );
        let event = crate::take_semantic_event_snapshot_for_test().unwrap();
        assert_eq!(event.event, "data_table_cell_click");
        assert_eq!(event.row_id.as_deref(), Some("row_1"));
        assert_eq!(event.column_id.as_deref(), Some("status"));

        events::emit_data_table_event(
            7,
            SORT_EVENT,
            "table.header.status",
            "sort_table",
            "table",
            None,
            Some("status"),
        );
        let event = crate::take_semantic_event_snapshot_for_test().unwrap();
        assert_eq!(event.event, "data_table_sort");
        assert_eq!(event.row_id, None);
        assert_eq!(event.column_id.as_deref(), Some("status"));
    }
}
