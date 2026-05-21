use super::{
    events,
    identity::NodeIdentity,
    render_pass::RenderPass,
    render_text,
    style::{apply_div_style, apply_semantic_focus_visible_affordance},
};
use crate::{
    bridge_view::BridgeView,
    ir::{
        DataTableCell, DataTableColumn, DataTableColumnWidth, DataTableNode, DataTableRow,
        DivStyle, IrNode,
    },
};
use gpui::{
    AnyElement, Context, FocusHandle, InteractiveElement, IntoElement, KeyDownEvent, MouseButton,
    ParentElement, SharedString, StatefulInteractiveElement, Styled, Window, div, list, px,
};
use std::collections::HashMap;
const ROW_CLICK_EVENT: i32 = 1;
const CELL_CLICK_EVENT: i32 = 2;
const SORT_EVENT: i32 = 3;

#[derive(Clone, Default)]
struct DataTableFocusHandles {
    rows: HashMap<String, FocusHandle>,
    cells: HashMap<(String, String), FocusHandle>,
}

#[derive(Clone, Default)]
struct RowFocusNeighbors {
    previous: Option<FocusHandle>,
    next: Option<FocusHandle>,
    first: Option<FocusHandle>,
    last: Option<FocusHandle>,
    first_cell: Option<FocusHandle>,
}

#[derive(Clone, Default)]
struct CellFocusNeighbors {
    left: Option<FocusHandle>,
    right: Option<FocusHandle>,
    up: Option<FocusHandle>,
    down: Option<FocusHandle>,
    first: Option<FocusHandle>,
    last: Option<FocusHandle>,
}

pub(crate) fn render(
    pass: &mut RenderPass<'_>,
    path: &str,
    table: &DataTableNode,
    window: &mut Window,
    cx: &mut Context<BridgeView>,
) -> AnyElement {
    let view_id = pass.view_id();
    let node_id = NodeIdentity::new(view_id, path, table.id.as_deref());
    let table_id = node_id.to_string();
    let list_id = format!("{table_id}.rows");
    let state = pass.retain_list_state(&list_id, table.rows.len());
    let columns = table.columns.clone();
    let rows = prepare_rows(table.columns.as_ref(), table.rows.as_ref());
    let header_focus_handles = prepare_header_focus_handles(
        pass,
        &table_id,
        table.columns.as_ref(),
        table.sort_callback.is_some(),
        cx,
    );
    let body_focus_handles = prepare_body_focus_handles(pass, &table_id, table, cx);
    let focus_visible = pass.focus_visible();
    let row_style = table.row_style.clone();
    let cell_style = table.cell_style.clone();
    let row_click = table.row_click.clone();
    let cell_click = table.cell_click.clone();
    let row_context_menu = table.row_context_menu.clone();
    let cell_context_menu = table.cell_context_menu.clone();
    let table_id_for_rows = table_id.clone();
    let body_focus_handles_for_rows = body_focus_handles.clone();
    let header_focus_handles_for_rows = header_focus_handles.clone();
    let first_row_id = rows.first().map(|row| row.id.clone());

    let body = list(state, move |index, window, _cx| {
        rows.get(index)
            .map(|row| {
                let previous_row = index
                    .checked_sub(1)
                    .and_then(|previous_index| rows.get(previous_index));
                let next_row = rows.get(index + 1);
                let row_focus_neighbors = RowFocusNeighbors {
                    previous: previous_row
                        .and_then(|row| body_focus_handles_for_rows.rows.get(&row.id))
                        .cloned(),
                    next: next_row
                        .and_then(|row| body_focus_handles_for_rows.rows.get(&row.id))
                        .cloned(),
                    first: rows
                        .first()
                        .and_then(|row| body_focus_handles_for_rows.rows.get(&row.id))
                        .cloned(),
                    last: rows
                        .last()
                        .and_then(|row| body_focus_handles_for_rows.rows.get(&row.id))
                        .cloned(),
                    first_cell: columns.first().and_then(|column| {
                        body_focus_handles_for_rows
                            .cells
                            .get(&(row.id.clone(), column.id.clone()))
                            .cloned()
                    }),
                };

                render_row(
                    view_id,
                    &table_id_for_rows,
                    row,
                    previous_row.map(|row| row.id.as_str()),
                    next_row.map(|row| row.id.as_str()),
                    &columns,
                    &row_style,
                    &cell_style,
                    row_click.as_deref(),
                    cell_click.as_deref(),
                    row_context_menu.as_deref(),
                    cell_context_menu.as_deref(),
                    &body_focus_handles_for_rows,
                    &header_focus_handles_for_rows,
                    row_focus_neighbors,
                    focus_visible,
                    window,
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
        &header_focus_handles,
        &body_focus_handles,
        first_row_id.as_deref(),
        focus_visible,
        window,
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

fn prepare_header_focus_handles(
    pass: &mut RenderPass<'_>,
    table_id: &str,
    columns: &[DataTableColumn],
    sort_enabled: bool,
    cx: &mut Context<BridgeView>,
) -> HashMap<String, FocusHandle> {
    if !sort_enabled {
        return HashMap::new();
    }

    columns
        .iter()
        .filter(|column| column.sortable)
        .map(|column| {
            let header_id = format!("{table_id}.header.{}", column.id);
            let focus_handle = pass.ensure_focus_handle(&header_id, cx, Some(true), None);
            (column.id.clone(), focus_handle)
        })
        .collect()
}

fn prepare_body_focus_handles(
    pass: &mut RenderPass<'_>,
    table_id: &str,
    table: &DataTableNode,
    cx: &mut Context<BridgeView>,
) -> DataTableFocusHandles {
    let mut handles = DataTableFocusHandles::default();

    if table.row_click.is_some() || table.row_context_menu.is_some() {
        for row in table.rows.iter() {
            let row_id = data_table_row_id(table_id, &row.id);
            handles.rows.insert(
                row.id.clone(),
                pass.ensure_focus_handle(&row_id, cx, Some(true), None),
            );
        }
    }

    if table.cell_click.is_some() || table.cell_context_menu.is_some() {
        for row in table.rows.iter() {
            for column in table.columns.iter() {
                let cell_id = data_table_cell_id(table_id, &row.id, &column.id);
                handles.cells.insert(
                    (row.id.clone(), column.id.clone()),
                    pass.ensure_focus_handle(&cell_id, cx, Some(true), None),
                );
            }
        }
    }

    handles
}

fn header_focus_neighbors(
    columns: &[DataTableColumn],
    focus_handles: &HashMap<String, FocusHandle>,
    column_index: usize,
) -> (Option<FocusHandle>, Option<FocusHandle>) {
    let previous = columns
        .get(..column_index)
        .into_iter()
        .flatten()
        .rev()
        .find(|column| column.sortable)
        .and_then(|column| focus_handles.get(&column.id))
        .cloned();
    let next = columns
        .get(column_index + 1..)
        .into_iter()
        .flatten()
        .find(|column| column.sortable)
        .and_then(|column| focus_handles.get(&column.id))
        .cloned();

    (previous, next)
}

fn render_header(
    view_id: u64,
    table_id: &str,
    columns: &[DataTableColumn],
    header_style: &DivStyle,
    sort_callback: Option<&str>,
    focus_handles: &HashMap<String, FocusHandle>,
    body_focus_handles: &DataTableFocusHandles,
    first_row_id: Option<&str>,
    focus_visible: bool,
    window: &Window,
) -> AnyElement {
    let children = columns.iter().enumerate().map(|(column_index, column)| {
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
        let show_focus_visible = focus_visible
            && focus_handles
                .get(&column.id)
                .is_some_and(|handle| handle.is_focused(window));

        if column.sortable
            && let Some(callback_id) = sort_callback
        {
            if let Some(handle) = focus_handles.get(&column.id) {
                let focus_handle = handle.clone();
                cell = cell
                    .track_focus(&focus_handle)
                    .focusable()
                    .on_any_mouse_down(move |_, window, _| {
                        focus_handle.focus(window);
                    });
            }

            let click_callback_id = callback_id.to_owned();
            let click_table_id = table_id.to_owned();
            let click_column_id = column.id.clone();
            let click_header_id = header_id.clone();
            cell = cell.on_click(move |_, _, _| {
                events::emit_data_table_event(
                    view_id,
                    SORT_EVENT,
                    &click_header_id,
                    &click_callback_id,
                    &click_table_id,
                    None,
                    Some(&click_column_id),
                );
            });

            let key_callback_id = callback_id.to_owned();
            let key_table_id = table_id.to_owned();
            let key_column_id = column.id.clone();
            let key_header_id = header_id.clone();
            let down_focus = first_row_id
                .and_then(|row_id| {
                    body_focus_handles
                        .cells
                        .get(&(row_id.to_owned(), column.id.clone()))
                })
                .cloned();
            let (left_focus, right_focus) =
                header_focus_neighbors(columns, focus_handles, column_index);
            cell = cell.on_key_down(move |event: &KeyDownEvent, window, cx| {
                match event.keystroke.key.as_str() {
                    "left" => {
                        if let Some(handle) = left_focus.as_ref() {
                            handle.focus(window);
                            cx.stop_propagation();
                            return;
                        }
                    }
                    "right" => {
                        if let Some(handle) = right_focus.as_ref() {
                            handle.focus(window);
                            cx.stop_propagation();
                            return;
                        }
                    }
                    "down" => {
                        if let Some(handle) = down_focus.as_ref() {
                            handle.focus(window);
                            cx.stop_propagation();
                            return;
                        }
                    }
                    _ => {}
                }

                if is_header_activation_key(event) {
                    events::emit_data_table_event(
                        view_id,
                        SORT_EVENT,
                        &key_header_id,
                        &key_callback_id,
                        &key_table_id,
                        None,
                        Some(&key_column_id),
                    );
                    cx.stop_propagation();
                }
            });
        }

        apply_semantic_focus_visible_affordance(cell, show_focus_visible).into_any_element()
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
    previous_row_id: Option<&str>,
    next_row_id: Option<&str>,
    columns: &[DataTableColumn],
    row_style: &DivStyle,
    cell_style: &DivStyle,
    row_click: Option<&str>,
    cell_click: Option<&str>,
    row_context_menu: Option<&str>,
    cell_context_menu: Option<&str>,
    focus_handles: &DataTableFocusHandles,
    header_focus_handles: &HashMap<String, FocusHandle>,
    row_focus_neighbors: RowFocusNeighbors,
    focus_visible: bool,
    window: &Window,
) -> AnyElement {
    let row_id = data_table_row_id(table_id, &row.id);
    let cells =
        columns
            .iter()
            .enumerate()
            .zip(row.cells.iter())
            .map(|((column_index, column), cell)| {
                let cell_focus_neighbors = cell_focus_neighbors(
                    focus_handles,
                    columns,
                    &row.id,
                    previous_row_id,
                    next_row_id,
                    column_index,
                    header_focus_handles,
                );

                render_cell(
                    view_id,
                    table_id,
                    &row.id,
                    column,
                    cell.as_ref(),
                    cell_style,
                    cell_click,
                    cell_context_menu,
                    focus_handles
                        .cells
                        .get(&(row.id.clone(), column.id.clone())),
                    cell_focus_neighbors,
                    focus_visible,
                    window,
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
    let show_focus_visible = focus_visible
        && focus_handles
            .rows
            .get(&row.id)
            .is_some_and(|handle| handle.is_focused(window));

    if let Some(handle) = focus_handles.rows.get(&row.id) {
        let focus_handle = handle.clone();
        element = element
            .track_focus(&focus_handle)
            .focusable()
            .on_any_mouse_down(move |_, window, _| {
                focus_handle.focus(window);
            });
    }

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

    if row_click.is_some() || row_context_menu.is_some() {
        let click_callback = row_click.map(str::to_owned);
        let context_menu_callback = row_context_menu.map(str::to_owned);
        let key_table_id = table_id.to_owned();
        let key_row_value = row.id.clone();
        let key_row_id = row_id.clone();
        let row_focus_neighbors = row_focus_neighbors.clone();
        element = element.on_key_down(move |event: &KeyDownEvent, window, cx| {
            match event.keystroke.key.as_str() {
                "up" => {
                    if let Some(handle) = row_focus_neighbors.previous.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "down" => {
                    if let Some(handle) = row_focus_neighbors.next.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "home" => {
                    if let Some(handle) = row_focus_neighbors.first.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "end" => {
                    if let Some(handle) = row_focus_neighbors.last.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "right" => {
                    if let Some(handle) = row_focus_neighbors.first_cell.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                _ => {}
            }

            if let Some(callback_id) = context_menu_callback.as_deref()
                && events::is_context_menu_key(event)
            {
                events::emit_data_table_keyboard_context_menu(
                    view_id,
                    &key_row_id,
                    callback_id,
                    &key_table_id,
                    &key_row_value,
                    None,
                    event,
                );
                cx.stop_propagation();
                return;
            }

            if let Some(callback_id) = click_callback.as_deref()
                && is_activation_key(event)
            {
                events::emit_data_table_event(
                    view_id,
                    ROW_CLICK_EVENT,
                    &key_row_id,
                    callback_id,
                    &key_table_id,
                    Some(&key_row_value),
                    None,
                );
                cx.stop_propagation();
            }
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

    apply_semantic_focus_visible_affordance(element, show_focus_visible).into_any_element()
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

fn cell_focus_neighbors(
    focus_handles: &DataTableFocusHandles,
    columns: &[DataTableColumn],
    row_id: &str,
    previous_row_id: Option<&str>,
    next_row_id: Option<&str>,
    column_index: usize,
    header_focus_handles: &HashMap<String, FocusHandle>,
) -> CellFocusNeighbors {
    let Some(column) = columns.get(column_index) else {
        return CellFocusNeighbors::default();
    };

    CellFocusNeighbors {
        left: column_index
            .checked_sub(1)
            .and_then(|index| columns.get(index))
            .and_then(|column| {
                focus_handles
                    .cells
                    .get(&(row_id.to_owned(), column.id.clone()))
            })
            .cloned()
            .or_else(|| focus_handles.rows.get(row_id).cloned()),
        right: columns
            .get(column_index + 1)
            .and_then(|column| {
                focus_handles
                    .cells
                    .get(&(row_id.to_owned(), column.id.clone()))
            })
            .cloned(),
        up: previous_row_id
            .and_then(|row_id| {
                focus_handles
                    .cells
                    .get(&(row_id.to_owned(), column.id.clone()))
            })
            .cloned()
            .or_else(|| header_focus_handles.get(&column.id).cloned()),
        down: next_row_id
            .and_then(|row_id| {
                focus_handles
                    .cells
                    .get(&(row_id.to_owned(), column.id.clone()))
            })
            .cloned(),
        first: columns.first().and_then(|column| {
            focus_handles
                .cells
                .get(&(row_id.to_owned(), column.id.clone()))
                .cloned()
        }),
        last: columns.last().and_then(|column| {
            focus_handles
                .cells
                .get(&(row_id.to_owned(), column.id.clone()))
                .cloned()
        }),
    }
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
    focus_handle: Option<&FocusHandle>,
    focus_neighbors: CellFocusNeighbors,
    focus_visible: bool,
    window: &Window,
) -> AnyElement {
    let cell_id = data_table_cell_id(table_id, row_id, &column.id);
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
    let show_focus_visible =
        focus_visible && focus_handle.is_some_and(|handle| handle.is_focused(window));

    if let Some(handle) = focus_handle {
        let focus_handle = handle.clone();
        element = element
            .track_focus(&focus_handle)
            .focusable()
            .on_any_mouse_down(move |_, window, _| {
                focus_handle.focus(window);
            });
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

    if cell_click.is_some() || cell_context_menu.is_some() {
        let click_callback = cell_click.map(str::to_owned);
        let context_menu_callback = cell_context_menu.map(str::to_owned);
        let key_table_id = table_id.to_owned();
        let key_row_id = row_id.to_owned();
        let key_column_id = column.id.clone();
        let key_cell_id = cell_id.clone();
        let focus_neighbors = focus_neighbors.clone();
        element = element.on_key_down(move |event: &KeyDownEvent, window, cx| {
            match event.keystroke.key.as_str() {
                "left" => {
                    if let Some(handle) = focus_neighbors.left.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "right" => {
                    if let Some(handle) = focus_neighbors.right.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "up" => {
                    if let Some(handle) = focus_neighbors.up.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "down" => {
                    if let Some(handle) = focus_neighbors.down.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "home" => {
                    if let Some(handle) = focus_neighbors.first.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                "end" => {
                    if let Some(handle) = focus_neighbors.last.as_ref() {
                        handle.focus(window);
                        cx.stop_propagation();
                        return;
                    }
                }
                _ => {}
            }

            if let Some(callback_id) = context_menu_callback.as_deref()
                && events::is_context_menu_key(event)
            {
                events::emit_data_table_keyboard_context_menu(
                    view_id,
                    &key_cell_id,
                    callback_id,
                    &key_table_id,
                    &key_row_id,
                    Some(&key_column_id),
                    event,
                );
                cx.stop_propagation();
                return;
            }

            if let Some(callback_id) = click_callback.as_deref()
                && is_activation_key(event)
            {
                events::emit_data_table_event(
                    view_id,
                    CELL_CLICK_EVENT,
                    &key_cell_id,
                    callback_id,
                    &key_table_id,
                    Some(&key_row_id),
                    Some(&key_column_id),
                );
                cx.stop_propagation();
            }
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

    apply_semantic_focus_visible_affordance(element, show_focus_visible).into_any_element()
}

fn data_table_row_id(table_id: &str, row_id: &str) -> String {
    format!("{table_id}.row.{row_id}")
}

fn data_table_cell_id(table_id: &str, row_id: &str, column_id: &str) -> String {
    format!("{table_id}.cell.{row_id}.{column_id}")
}

fn is_header_activation_key(event: &KeyDownEvent) -> bool {
    is_activation_key(event)
}

fn is_activation_key(event: &KeyDownEvent) -> bool {
    matches!(event.keystroke.key.as_str(), "space" | "enter")
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
