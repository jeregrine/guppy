use super::{
    events, identity::NodeIdentity, render_pass::RenderPass, render_text, style::apply_div_style,
};
use crate::{
    bridge_view::BridgeView,
    ir::{
        DataTableCell, DataTableColumn, DataTableColumnWidth, DataTableNode, DataTableRow,
        DivStyle, IrNode,
    },
};
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, MouseButton, ParentElement, SharedString,
    StatefulInteractiveElement, Styled, Window, div, list, px,
};
use std::collections::HashMap;
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
    let columns = table.columns.clone();
    let rows = prepare_rows(table.columns.as_ref(), table.rows.as_ref());
    let row_style = table.row_style.clone();
    let cell_style = table.cell_style.clone();
    let row_click = table.row_click.clone();
    let cell_click = table.cell_click.clone();
    let row_context_menu = table.row_context_menu.clone();
    let cell_context_menu = table.cell_context_menu.clone();
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
                    row_context_menu.as_deref(),
                    cell_context_menu.as_deref(),
                )
            })
            .unwrap_or_else(|| div().into_any_element())
    })
    .size_full();

    let header = render_header(
        view_id,
        &table_id,
        table.columns.as_ref(),
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
    row: &PreparedDataTableRow,
    columns: &[DataTableColumn],
    row_style: &DivStyle,
    cell_style: &DivStyle,
    row_click: Option<&str>,
    cell_click: Option<&str>,
    row_context_menu: Option<&str>,
    cell_context_menu: Option<&str>,
) -> AnyElement {
    let row_id = format!("{table_id}.row.{}", row.id);
    let cells = columns.iter().zip(row.cells.iter()).map(|(column, cell)| {
        render_cell(
            view_id,
            table_id,
            &row.id,
            column,
            cell.as_ref(),
            cell_style,
            cell_click,
            cell_context_menu,
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
        let click_row_id = row_id.clone();
        element = element.on_click(move |_, _, _| {
            events::emit_data_table_event(
                view_id,
                ROW_CLICK_EVENT,
                &click_row_id,
                &callback_id,
                &table_id,
                Some(&row_value),
                None,
            );
        });
    }

    if let Some(callback_id) = row_context_menu {
        let callback_id = callback_id.to_owned();
        let table_id = table_id.to_owned();
        let row_value = row.id.clone();
        element = element.on_mouse_down(MouseButton::Right, move |event, _, _| {
            events::emit_data_table_context_menu(
                view_id,
                &row_id,
                &callback_id,
                &table_id,
                &row_value,
                None,
                event,
            );
        });
    }

    element.into_any_element()
}

#[derive(Debug)]
struct PreparedDataTableRow {
    id: String,
    cells: Vec<Option<DataTableCell>>,
    style: DivStyle,
}

fn prepare_rows(columns: &[DataTableColumn], rows: &[DataTableRow]) -> Vec<PreparedDataTableRow> {
    let column_indices = columns
        .iter()
        .enumerate()
        .map(|(index, column)| (column.id.as_str(), index))
        .collect::<HashMap<_, _>>();

    rows.iter()
        .map(|row| PreparedDataTableRow {
            id: row.id.clone(),
            cells: ordered_row_cells(columns.len(), &column_indices, row),
            style: row.style.clone(),
        })
        .collect()
}

fn ordered_row_cells(
    column_count: usize,
    column_indices: &HashMap<&str, usize>,
    row: &DataTableRow,
) -> Vec<Option<DataTableCell>> {
    let mut ordered_cells = vec![None; column_count];

    for cell in row.cells.iter() {
        if let Some(index) = column_indices.get(cell.column_id.as_str()) {
            ordered_cells[*index] = Some(cell.clone());
        }
    }

    ordered_cells
}

#[allow(clippy::too_many_arguments)]
fn render_cell(
    view_id: u64,
    table_id: &str,
    row_id: &str,
    column: &DataTableColumn,
    cell: Option<&DataTableCell>,
    cell_style: &DivStyle,
    cell_click: Option<&str>,
    cell_context_menu: Option<&str>,
) -> AnyElement {
    let cell_id = format!("{table_id}.cell.{row_id}.{}", column.id);
    let mut cell_div = div().id(SharedString::from(cell_id.clone())).p_2();
    if let Some(cell) = cell {
        let children = cell.children.iter().enumerate().map(|(index, child)| {
            render_static_node(view_id, &format!("{cell_id}.{index}"), child)
        });
        cell_div = cell_div.children(children);
    }

    let mut element = apply_column_width(apply_div_style(cell_div, cell_style), &column.width);

    if let Some(cell) = cell {
        element = apply_div_style(element, &cell.style);
    }

    if let Some(callback_id) = cell_click {
        let callback_id = callback_id.to_owned();
        let table_id = table_id.to_owned();
        let row_id = row_id.to_owned();
        let column_id = column.id.clone();
        let click_cell_id = cell_id.clone();
        element = element.on_click(move |_, _, _| {
            events::emit_data_table_event(
                view_id,
                CELL_CLICK_EVENT,
                &click_cell_id,
                &callback_id,
                &table_id,
                Some(&row_id),
                Some(&column_id),
            );
        });
    }

    if let Some(callback_id) = cell_context_menu {
        let callback_id = callback_id.to_owned();
        let table_id = table_id.to_owned();
        let row_id = row_id.to_owned();
        let column_id = column.id.clone();
        element = element.on_mouse_down(MouseButton::Right, move |event, _, _| {
            events::emit_data_table_context_menu(
                view_id,
                &cell_id,
                &callback_id,
                &table_id,
                &row_id,
                Some(&column_id),
                event,
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
        DataTableColumnWidth::Fr(value) => {
            let mut element = element.flex_1();
            element.style().flex_grow = Some(*value as f32);
            element
        }
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
        } => render_text::render_with_view_id(
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

#[cfg(test)]
mod tests {
    use super::{CELL_CLICK_EVENT, ROW_CLICK_EVENT, SORT_EVENT, apply_column_width, prepare_rows};
    use crate::{
        bridge_view::events,
        ir::{DataTableCell, DataTableColumn, DataTableColumnWidth, DataTableRow},
    };
    use gpui::{InteractiveElement, SharedString, Styled, div, relative};

    #[test]
    fn fractional_column_widths_apply_weighted_flex_grow() {
        let mut one_fr = apply_column_width(
            div().id(SharedString::from("one_fr")),
            &DataTableColumnWidth::Fr(1),
        );
        let mut two_fr = apply_column_width(
            div().id(SharedString::from("two_fr")),
            &DataTableColumnWidth::Fr(2),
        );

        assert_eq!(one_fr.style().flex_grow, Some(1.0));
        assert_eq!(two_fr.style().flex_grow, Some(2.0));
        assert_eq!(one_fr.style().flex_shrink, Some(1.0));
        assert_eq!(two_fr.style().flex_shrink, Some(1.0));
        assert_eq!(one_fr.style().flex_basis, Some(relative(0.).into()));
        assert_eq!(two_fr.style().flex_basis, Some(relative(0.).into()));
    }

    #[test]
    fn prepared_rows_follow_column_order_and_preserve_missing_cells() {
        let columns = vec![
            DataTableColumn {
                id: "task".into(),
                label: "Task".into(),
                width: DataTableColumnWidth::Auto,
                sortable: false,
                style: Vec::new().into(),
            },
            DataTableColumn {
                id: "owner".into(),
                label: "Owner".into(),
                width: DataTableColumnWidth::Auto,
                sortable: false,
                style: Vec::new().into(),
            },
            DataTableColumn {
                id: "status".into(),
                label: "Status".into(),
                width: DataTableColumnWidth::Auto,
                sortable: false,
                style: Vec::new().into(),
            },
        ];
        let rows = vec![DataTableRow {
            id: "row_1".into(),
            cells: vec![
                DataTableCell {
                    column_id: "status".into(),
                    children: Vec::new().into(),
                    style: Vec::new().into(),
                },
                DataTableCell {
                    column_id: "task".into(),
                    children: Vec::new().into(),
                    style: Vec::new().into(),
                },
            ]
            .into(),
            style: Vec::new().into(),
        }];

        let prepared = prepare_rows(&columns, &rows);

        assert_eq!(prepared[0].id, "row_1");
        assert_eq!(
            prepared[0]
                .cells
                .iter()
                .map(|cell| cell.as_ref().map(|cell| cell.column_id.as_str()))
                .collect::<Vec<_>>(),
            [Some("task"), None, Some("status")]
        );
    }

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

        use gpui::{Modifiers, MouseButton, MouseDownEvent, point, px};

        events::emit_data_table_context_menu(
            7,
            "table.cell.row_1.status",
            "cell_context",
            "table",
            "row_1",
            Some("status"),
            &MouseDownEvent {
                position: point(px(12.0), px(8.0)),
                modifiers: Modifiers::none(),
                button: MouseButton::Right,
                click_count: 1,
                first_mouse: false,
            },
        );
        let event = crate::take_semantic_event_snapshot_for_test().unwrap();
        assert_eq!(event.event, "context_menu");
        assert_eq!(event.table_id.as_deref(), Some("table"));
        assert_eq!(event.row_id.as_deref(), Some("row_1"));
        assert_eq!(event.column_id.as_deref(), Some("status"));
    }
}
