use super::{
    CanvasCommand, CheckboxNode, DataTableSortDirection, DivNode, ImageObjectFit, ImageSource,
    IrNode, LinearGradientStop, StyleAxis, StyleColor, StyleLength, StyleOp,
    decode_list_row_child_term, ensure_unique_list_row_control_ids, field_key,
    get_optional_integer_field, get_optional_usize_field, parse_positive_u32, parse_style_op,
};
use crate::ir_allowed::{allowed_node_event_fields, allowed_node_fields};
use eetf::{Atom, BigInteger, Binary, FixInteger, Float, List, Map, Term, Tuple};

fn atom(name: &str) -> Term {
    Term::Atom(Atom::from(name))
}

fn binary(value: &str) -> Term {
    Term::Binary(Binary {
        bytes: value.as_bytes().to_vec(),
    })
}

fn integer(value: i32) -> Term {
    Term::FixInteger(FixInteger { value })
}

fn bigint_i32(value: i32) -> Term {
    Term::BigInteger(BigInteger::from(value))
}

fn bigint_u32(value: u32) -> Term {
    Term::BigInteger(BigInteger::from(value))
}

fn bigint_u64(value: u64) -> Term {
    Term::BigInteger(BigInteger::from(value))
}

fn float(value: f64) -> Term {
    Term::Float(Float { value })
}

fn tuple(elements: Vec<Term>) -> Term {
    Term::Tuple(Tuple { elements })
}

fn list(elements: Vec<Term>) -> Term {
    Term::List(List { elements })
}

fn map(entries: Vec<(Term, Term)>) -> Term {
    Term::Map(Map {
        map: entries.into_iter().collect(),
    })
}

fn bool_atom(value: bool) -> Term {
    atom(if value { "true" } else { "false" })
}

fn events(entries: Vec<(&str, &str)>) -> Term {
    map(entries
        .into_iter()
        .map(|(key, value)| (atom(key), binary(value)))
        .collect())
}

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

    for child in node.children.iter() {
        validate_list_row_child(child)?;
    }

    Ok(())
}

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

const NODE_KINDS: &[&str] = &[
    "text",
    "div",
    "scroll",
    "popover",
    "uniform_list",
    "list",
    "data_table",
    "tree",
    "canvas",
    "select",
    "image",
    "icon",
    "spacer",
    "checkbox",
    "radio",
    "button",
    "text_input",
    "textarea",
];

#[test]
fn cached_ir_field_keys_cover_allowed_schema() {
    let mut missing = Vec::new();

    for kind in NODE_KINDS {
        for field in allowed_node_fields(kind).expect("known node kind") {
            if field_key(field).is_none() {
                missing.push(format!("{kind}.{field}"));
            }
        }

        if let Some((event_fields, _context)) = allowed_node_event_fields(kind) {
            for field in event_fields {
                if field_key(field).is_none() {
                    missing.push(format!("{kind}.events.{field}"));
                }
            }
        }
    }

    assert!(
        missing.is_empty(),
        "missing cached IR field keys: {}",
        missing.join(", ")
    );
}

#[test]
fn rejects_unknown_native_ir_fields() {
    let node = map(vec![
        (atom("kind"), atom("text")),
        (atom("content"), binary("hello")),
        (atom("typo"), bool_atom(true)),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(
        err.contains("unsupported text field"),
        "unexpected error: {err}"
    );

    let text_run = map(vec![
        (atom("text"), binary("hello")),
        (atom("style"), list(vec![])),
        (atom("typo"), bool_atom(true)),
    ]);
    let node = map(vec![
        (atom("kind"), atom("text")),
        (atom("content"), binary("hello")),
        (atom("runs"), list(vec![text_run])),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(
        err.contains("unsupported text run field"),
        "unexpected error: {err}"
    );

    let node = map(vec![
        (atom("kind"), atom("text")),
        (atom("content"), binary("hello")),
        (atom("events"), events(vec![("typo", "cb")])),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(
        err.contains("unsupported text events field"),
        "unexpected error: {err}"
    );

    let node = map(vec![
        (atom("kind"), atom("button")),
        (atom("label"), binary("Save")),
        (atom("tooltip"), binary("unsupported")),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(
        err.contains("unsupported button field"),
        "unexpected error: {err}"
    );

    let node = map(vec![
        (atom("kind"), atom("div")),
        (atom("children"), list(vec![])),
        (
            atom("animation"),
            map(vec![
                (atom("id"), binary("fade")),
                (atom("typo"), bool_atom(true)),
            ]),
        ),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(
        err.contains("unsupported animation field"),
        "unexpected error: {err}"
    );
}

#[test]
fn decodes_big_integer_fields() {
    let fields = match map(vec![
        (atom("tab_index"), bigint_i32(-2)),
        (atom("stack_priority"), bigint_u32(7)),
    ]) {
        Term::Map(map) => map.map,
        _ => unreachable!(),
    };

    assert_eq!(
        get_optional_integer_field(&fields, "tab_index").unwrap(),
        Some(-2)
    );
    assert_eq!(
        get_optional_usize_field(&fields, "stack_priority").unwrap(),
        Some(7)
    );
    assert_eq!(parse_positive_u32(&bigint_u32(4)).unwrap(), 4);
    assert!(parse_positive_u32(&bigint_i32(-1)).is_err());
}

#[test]
fn decodes_image_source_variants() {
    let auto = map(vec![
        (atom("kind"), atom("image")),
        (atom("source"), binary("logo.png")),
        (atom("object_fit"), atom("cover")),
        (atom("grayscale"), bool_atom(true)),
    ]);

    match IrNode::from_term(&auto).unwrap() {
        IrNode::Image {
            source,
            object_fit,
            grayscale,
            ..
        } => {
            assert_eq!(source, ImageSource::Auto("logo.png".into()));
            assert_eq!(object_fit, ImageObjectFit::Cover);
            assert!(grayscale);
        }
        other => panic!("expected image, got {other:?}"),
    }

    let uri = map(vec![
        (atom("kind"), atom("image")),
        (
            atom("source"),
            tuple(vec![atom("uri"), binary("https://example.com/logo.svg")]),
        ),
    ]);

    match IrNode::from_term(&uri).unwrap() {
        IrNode::Image {
            source,
            object_fit,
            grayscale,
            ..
        } => {
            assert_eq!(
                source,
                ImageSource::Uri("https://example.com/logo.svg".into())
            );
            assert_eq!(object_fit, ImageObjectFit::Contain);
            assert!(!grayscale);
        }
        other => panic!("expected image, got {other:?}"),
    }

    let icon = map(vec![
        (atom("kind"), atom("icon")),
        (
            atom("source"),
            tuple(vec![atom("path"), binary("/tmp/icon.png")]),
        ),
    ]);

    match IrNode::from_term(&icon).unwrap() {
        IrNode::Icon { source, .. } => {
            assert_eq!(source, ImageSource::Path("/tmp/icon.png".into()));
        }
        other => panic!("expected icon, got {other:?}"),
    }
}

#[test]
fn rejects_text_run_content_mismatches() {
    let node = map(vec![
        (atom("kind"), atom("text")),
        (atom("content"), binary("hello")),
        (
            atom("runs"),
            list(vec![map(vec![(atom("text"), binary("hell"))])]),
        ),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(err.contains("text runs content mismatch"));
    assert!(err.contains("expected \"hello\""));
    assert!(err.contains("got \"hell\""));
}

#[test]
fn decodes_data_table_node() {
    let node = map(vec![
        (atom("kind"), atom("data_table")),
        (atom("id"), binary("project_table")),
        (
            atom("columns"),
            list(vec![
                map(vec![
                    (atom("id"), binary("task")),
                    (atom("label"), binary("Task")),
                    (atom("width"), tuple(vec![atom("fr"), integer(1)])),
                    (atom("sortable"), bool_atom(true)),
                ]),
                map(vec![
                    (atom("id"), binary("status")),
                    (atom("label"), binary("Status")),
                    (atom("width"), tuple(vec![atom("px"), integer(120)])),
                ]),
            ]),
        ),
        (
            atom("rows"),
            list(vec![map(vec![
                (atom("id"), binary("row_1")),
                (
                    atom("cells"),
                    list(vec![map(vec![
                        (atom("column_id"), binary("task")),
                        (
                            atom("children"),
                            list(vec![map(vec![
                                (atom("kind"), atom("text")),
                                (atom("content"), binary("Ship menus")),
                            ])]),
                        ),
                    ])]),
                ),
            ])]),
        ),
        (atom("selected_row_id"), binary("row_1")),
        (
            atom("selected_cell"),
            tuple(vec![binary("row_1"), binary("task")]),
        ),
        (
            atom("sort"),
            map(vec![
                (atom("column_id"), binary("task")),
                (atom("direction"), atom("asc")),
            ]),
        ),
        (
            atom("events"),
            events(vec![
                ("row_click", "select_row"),
                ("cell_click", "select_cell"),
                ("sort", "sort_table"),
            ]),
        ),
    ]);

    match IrNode::from_term(&node).unwrap() {
        IrNode::DataTable(table) => {
            assert_eq!(table.id.as_deref(), Some("project_table"));
            assert_eq!(table.columns.len(), 2);
            assert_eq!(table.columns[0].id, "task");
            assert_eq!(table.rows[0].id, "row_1");
            assert_eq!(table.rows[0].cells[0].column_id, "task");
            assert_eq!(table.selected_row_id.as_deref(), Some("row_1"));
            assert_eq!(
                table
                    .selected_cell
                    .as_ref()
                    .map(|(row_id, column_id)| (row_id.as_str(), column_id.as_str())),
                Some(("row_1", "task"))
            );
            assert_eq!(
                table.sort.as_ref().unwrap().direction,
                DataTableSortDirection::Asc
            );
            assert_eq!(table.sort_callback.as_deref(), Some("sort_table"));
        }
        other => panic!("expected data table, got {other:?}"),
    }
}

#[test]
fn decodes_static_data_table_cell_div_children() {
    let node = map(vec![
        (atom("kind"), atom("data_table")),
        (
            atom("columns"),
            list(vec![map(vec![
                (atom("id"), binary("task")),
                (atom("label"), binary("Task")),
            ])]),
        ),
        (
            atom("rows"),
            list(vec![map(vec![
                (atom("id"), binary("row_1")),
                (
                    atom("cells"),
                    list(vec![map(vec![
                        (atom("column_id"), binary("task")),
                        (
                            atom("children"),
                            list(vec![map(vec![
                                (atom("kind"), atom("div")),
                                (atom("id"), binary("cell_layout")),
                                (
                                    atom("children"),
                                    list(vec![map(vec![
                                        (atom("kind"), atom("text")),
                                        (atom("content"), binary("Nested")),
                                    ])]),
                                ),
                            ])]),
                        ),
                    ])]),
                ),
            ])]),
        ),
    ]);

    match IrNode::from_term(&node).unwrap() {
        IrNode::DataTable(table) => match &table.rows[0].cells[0].children[0] {
            IrNode::Div(div) => {
                assert_eq!(div.id.as_deref(), Some("cell_layout"));
                assert!(
                    matches!(div.children.as_ref(), [IrNode::Text { content, .. }] if content == "Nested")
                );
            }
            other => panic!("expected data table cell div, got {other:?}"),
        },
        other => panic!("expected data table, got {other:?}"),
    }
}

#[test]
fn rejects_row_controls_inside_data_table_cell_divs() {
    let node = map(vec![
        (atom("kind"), atom("data_table")),
        (
            atom("columns"),
            list(vec![map(vec![
                (atom("id"), binary("task")),
                (atom("label"), binary("Task")),
            ])]),
        ),
        (
            atom("rows"),
            list(vec![map(vec![
                (atom("id"), binary("row_1")),
                (
                    atom("cells"),
                    list(vec![map(vec![
                        (atom("column_id"), binary("task")),
                        (
                            atom("children"),
                            list(vec![map(vec![
                                (atom("kind"), atom("div")),
                                (
                                    atom("children"),
                                    list(vec![map(vec![
                                        (atom("kind"), atom("button")),
                                        (atom("id"), binary("edit")),
                                        (atom("label"), binary("Edit")),
                                    ])]),
                                ),
                            ])]),
                        ),
                    ])]),
                ),
            ])]),
        ),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(err.contains("unsupported data_table cell child kind: button"));
}

#[test]
fn rejects_data_table_cell_unknown_columns() {
    let node = map(vec![
        (atom("kind"), atom("data_table")),
        (
            atom("columns"),
            list(vec![map(vec![
                (atom("id"), binary("task")),
                (atom("label"), binary("Task")),
            ])]),
        ),
        (
            atom("rows"),
            list(vec![map(vec![
                (atom("id"), binary("row_1")),
                (
                    atom("cells"),
                    list(vec![map(vec![
                        (atom("column_id"), binary("missing")),
                        (atom("children"), list(vec![])),
                    ])]),
                ),
            ])]),
        ),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(err.contains("unknown data_table cell column"));
}

#[test]
fn rejects_unsupported_data_table_cell_children() {
    let node = map(vec![
        (atom("kind"), atom("data_table")),
        (
            atom("columns"),
            list(vec![map(vec![
                (atom("id"), binary("task")),
                (atom("label"), binary("Task")),
            ])]),
        ),
        (
            atom("rows"),
            list(vec![map(vec![
                (atom("id"), binary("row_1")),
                (
                    atom("cells"),
                    list(vec![map(vec![
                        (atom("column_id"), binary("task")),
                        (
                            atom("children"),
                            list(vec![map(vec![
                                (atom("kind"), atom("button")),
                                (atom("label"), binary("Edit")),
                            ])]),
                        ),
                    ])]),
                ),
            ])]),
        ),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(err.contains("unsupported data_table cell child kind: button"));
}

#[test]
fn decodes_tree_node() {
    let node = map(vec![
        (atom("kind"), atom("tree")),
        (atom("id"), binary("project_tree")),
        (
            atom("nodes"),
            list(vec![map(vec![
                (atom("id"), binary("root")),
                (atom("label"), binary("Root")),
                (atom("expanded"), bool_atom(true)),
                (
                    atom("children"),
                    list(vec![map(vec![
                        (atom("id"), binary("child")),
                        (atom("label"), binary("Child")),
                    ])]),
                ),
            ])]),
        ),
        (atom("selected_id"), binary("child")),
        (
            atom("events"),
            events(vec![("select", "select_node"), ("toggle", "toggle_node")]),
        ),
    ]);

    match IrNode::from_term(&node).unwrap() {
        IrNode::Tree(tree) => {
            assert_eq!(tree.id.as_deref(), Some("project_tree"));
            assert_eq!(tree.nodes[0].id, "root");
            assert!(tree.nodes[0].expanded);
            assert_eq!(tree.nodes[0].children[0].id, "child");
            assert_eq!(tree.selected_id.as_deref(), Some("child"));
            assert_eq!(tree.select.as_deref(), Some("select_node"));
            assert_eq!(tree.toggle.as_deref(), Some("toggle_node"));
        }
        other => panic!("expected tree, got {other:?}"),
    }
}

#[test]
fn rejects_tree_selected_id_that_is_not_in_decoded_nodes() {
    let node = map(vec![
        (atom("kind"), atom("tree")),
        (
            atom("nodes"),
            list(vec![map(vec![
                (atom("id"), binary("root")),
                (atom("label"), binary("Root")),
            ])]),
        ),
        (atom("selected_id"), binary("missing")),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(err.contains("unknown tree selected item: missing"));
}

#[test]
fn decodes_canvas_commands() {
    let node = map(vec![
        (atom("kind"), atom("canvas")),
        (atom("id"), binary("summary_canvas")),
        (
            atom("commands"),
            list(vec![
                map(vec![
                    (atom("op"), atom("rect")),
                    (atom("x"), integer(0)),
                    (atom("y"), integer(0)),
                    (atom("width"), integer(120)),
                    (atom("height"), integer(80)),
                    (atom("fill"), binary("#0f172a")),
                ]),
                map(vec![
                    (atom("op"), atom("rounded_rect")),
                    (atom("x"), integer(12)),
                    (atom("y"), integer(12)),
                    (atom("width"), integer(96)),
                    (atom("height"), integer(24)),
                    (atom("radius"), integer(8)),
                    (atom("fill"), atom("blue")),
                ]),
                map(vec![
                    (atom("op"), atom("pattern_rect")),
                    (atom("x"), integer(12)),
                    (atom("y"), integer(48)),
                    (atom("width"), integer(96)),
                    (atom("height"), integer(20)),
                    (atom("color"), atom("yellow")),
                    (atom("line_width"), float(0.05)),
                    (atom("interval"), float(0.12)),
                ]),
            ]),
        ),
        (atom("events"), events(vec![("click", "canvas_clicked")])),
    ]);

    match IrNode::from_term(&node).unwrap() {
        IrNode::Canvas(canvas) => {
            assert_eq!(canvas.id.as_deref(), Some("summary_canvas"));
            assert_eq!(canvas.commands.len(), 3);
            assert!(matches!(
                canvas.commands[2],
                CanvasCommand::PatternRect {
                    line_width,
                    interval,
                    ..
                } if line_width == 0.05 && interval == 0.12
            ));
            assert_eq!(canvas.click.as_deref(), Some("canvas_clicked"));
        }
        other => panic!("expected canvas, got {other:?}"),
    }
}

#[test]
fn rejects_canvas_command_shape_mismatches() {
    let node = map(vec![
        (atom("kind"), atom("canvas")),
        (
            atom("commands"),
            list(vec![map(vec![(atom("op"), atom("path"))])]),
        ),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(err.contains("unsupported canvas command op: path"));

    let node = map(vec![
        (atom("kind"), atom("canvas")),
        (
            atom("commands"),
            list(vec![map(vec![
                (atom("op"), atom("pattern_rect")),
                (atom("x"), integer(0)),
                (atom("y"), integer(0)),
                (atom("width"), integer(20)),
                (atom("height"), integer(20)),
                (atom("fill"), atom("blue")),
                (atom("color"), atom("yellow")),
                (atom("line_width"), float(0.05)),
                (atom("interval"), float(0.12)),
            ])]),
        ),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(err.contains("unsupported canvas pattern_rect command field"));

    let node = map(vec![
        (atom("kind"), atom("canvas")),
        (
            atom("commands"),
            list(vec![map(vec![
                (atom("op"), atom("pattern_rect")),
                (atom("x"), integer(0)),
                (atom("y"), integer(0)),
                (atom("width"), integer(20)),
                (atom("height"), integer(20)),
                (atom("color"), atom("yellow")),
                (atom("line_width"), float(0.05)),
                (atom("interval"), float(1.5)),
            ])]),
        ),
    ]);

    let err = IrNode::from_term(&node).unwrap_err();
    assert!(err.contains("expected unit numeric field interval"));
}

#[test]
fn rejects_pathological_numeric_ir_values() {
    let cases = [
        map(vec![
            (atom("kind"), atom("canvas")),
            (
                atom("commands"),
                list(vec![map(vec![
                    (atom("op"), atom("rect")),
                    (atom("x"), bigint_u64(u64::MAX)),
                    (atom("y"), integer(0)),
                    (atom("width"), integer(20)),
                    (atom("height"), integer(20)),
                    (atom("fill"), atom("blue")),
                ])]),
            ),
        ]),
        map(vec![
            (atom("kind"), atom("canvas")),
            (
                atom("commands"),
                list(vec![map(vec![
                    (atom("op"), atom("rect")),
                    (atom("x"), float(f64::INFINITY)),
                    (atom("y"), integer(0)),
                    (atom("width"), integer(20)),
                    (atom("height"), integer(20)),
                    (atom("fill"), atom("blue")),
                ])]),
            ),
        ]),
        map(vec![
            (atom("kind"), atom("canvas")),
            (
                atom("commands"),
                list(vec![map(vec![
                    (atom("op"), atom("rect")),
                    (atom("x"), integer(0)),
                    (atom("y"), integer(0)),
                    (atom("width"), integer(20)),
                    (atom("height"), integer(20)),
                    (atom("radius"), float(f64::INFINITY)),
                    (atom("fill"), atom("blue")),
                ])]),
            ),
        ]),
        map(vec![
            (atom("kind"), atom("canvas")),
            (
                atom("commands"),
                list(vec![map(vec![
                    (atom("op"), atom("pattern_rect")),
                    (atom("x"), integer(0)),
                    (atom("y"), integer(0)),
                    (atom("width"), integer(20)),
                    (atom("height"), integer(20)),
                    (atom("color"), atom("yellow")),
                    (atom("line_width"), float(f64::INFINITY)),
                    (atom("interval"), float(0.12)),
                ])]),
            ),
        ]),
        map(vec![
            (atom("kind"), atom("popover")),
            (atom("label"), binary("Open")),
            (atom("open"), bool_atom(false)),
            (
                atom("anchor_position"),
                tuple(vec![float(f64::INFINITY), integer(0)]),
            ),
        ]),
        map(vec![
            (atom("kind"), atom("popover")),
            (atom("label"), binary("Open")),
            (atom("open"), bool_atom(false)),
            (atom("snap_margin"), float(f64::INFINITY)),
        ]),
        map(vec![
            (atom("kind"), atom("div")),
            (
                atom("animation"),
                map(vec![
                    (atom("id"), binary("fade")),
                    (atom("from"), float(f64::INFINITY)),
                ]),
            ),
        ]),
        map(vec![
            (atom("kind"), atom("data_table")),
            (
                atom("columns"),
                list(vec![map(vec![
                    (atom("id"), binary("task")),
                    (atom("label"), binary("Task")),
                    (atom("width"), tuple(vec![atom("px"), float(f64::INFINITY)])),
                ])]),
            ),
            (atom("rows"), list(vec![])),
        ]),
    ];

    for node in cases {
        let err = IrNode::from_term(&node).unwrap_err();
        assert!(
            err.contains("finite") || err.contains("numeric"),
            "unexpected error: {err}"
        );
    }
}

#[test]
fn list_row_decode_accepts_supported_controls_with_explicit_ids() {
    let button = map(vec![
        (atom("kind"), atom("button")),
        (atom("id"), binary("save")),
        (atom("label"), binary("Save")),
        (atom("events"), events(vec![("click", "save_row")])),
    ]);

    match decode_list_row_child_term(&button).unwrap() {
        IrNode::Button(node) => {
            assert_eq!(node.id.as_deref(), Some("save"));
            assert_eq!(node.click.as_deref(), Some("save_row"));
            assert!(
                matches!(node.children.as_ref(), [IrNode::Text { content, .. }] if content == "Save")
            );
        }
        other => panic!("expected button row control, got {other:?}"),
    }

    let checkbox = map(vec![
        (atom("kind"), atom("checkbox")),
        (atom("id"), binary("done")),
        (atom("label"), binary("Done")),
        (atom("checked"), bool_atom(false)),
        (atom("events"), events(vec![("change", "toggle_done")])),
    ]);

    match decode_list_row_child_term(&checkbox).unwrap() {
        IrNode::Checkbox(node) => {
            assert_eq!(node.id.as_deref(), Some("done"));
            assert_eq!(node.change.as_deref(), Some("toggle_done"));
        }
        other => panic!("expected checkbox row control, got {other:?}"),
    }

    let radio = map(vec![
        (atom("kind"), atom("radio")),
        (atom("id"), binary("priority_high")),
        (atom("label"), binary("High")),
        (atom("value"), binary("high")),
        (atom("checked"), bool_atom(true)),
        (atom("events"), events(vec![("change", "set_priority")])),
    ]);

    match decode_list_row_child_term(&radio).unwrap() {
        IrNode::Radio(node) => {
            assert_eq!(node.id.as_deref(), Some("priority_high"));
            assert_eq!(node.value, "high");
            assert!(node.checked);
            assert_eq!(node.change.as_deref(), Some("set_priority"));
        }
        other => panic!("expected radio row control, got {other:?}"),
    }
}

#[test]
fn list_row_decode_rejects_supported_controls_without_ids() {
    let checkbox = map(vec![
        (atom("kind"), atom("checkbox")),
        (atom("label"), binary("Done")),
        (atom("checked"), bool_atom(false)),
    ]);

    let err = decode_list_row_child_term(&checkbox).unwrap_err();
    assert!(err.contains("missing list row control id"));
}

#[test]
fn list_row_control_ids_are_unique_within_a_row() {
    let children = vec![
        IrNode::Checkbox(Box::new(CheckboxNode {
            id: Some("done".into()),
            label: "Done".into(),
            checked: false,
            style: Vec::new().into(),
            hover_style: Vec::new().into(),
            focus_style: Vec::new().into(),
            focus_visible_style: Vec::new().into(),
            in_focus_style: Vec::new().into(),
            active_style: Vec::new().into(),
            disabled_style: Vec::new().into(),
            disabled: false,
            tab_index: None,
            change: None,
            focus: None,
            blur: None,
        })),
        IrNode::Button(Box::new(DivNode {
            id: Some("done".into()),
            style: Vec::new().into(),
            hover_style: Vec::new().into(),
            focus_style: Vec::new().into(),
            focus_visible_style: Vec::new().into(),
            in_focus_style: Vec::new().into(),
            active_style: Vec::new().into(),
            disabled_style: Vec::new().into(),
            animation: None,
            disabled: false,
            stack_priority: None,
            occlude: false,
            focusable: true,
            tab_stop: Some(true),
            tab_index: None,
            track_scroll: false,
            anchor_scroll: false,
            scroll_to: false,
            tooltip: None,
            shortcuts: Vec::new().into(),
            children: vec![IrNode::text("Done")].into(),
            click: None,
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
        })),
    ];

    let err = ensure_unique_list_row_control_ids(&children).unwrap_err();
    assert!(err.contains("duplicate list row control id: done"));
}

#[test]
fn parses_canonical_box_spacing_style_ops() {
    assert_eq!(
        parse_style_op(&tuple(vec![
            atom("padding"),
            atom("y"),
            tuple(vec![atom("rem"), float(0.25)]),
        ]))
        .unwrap(),
        StyleOp::Padding {
            axis: StyleAxis::Y,
            length: StyleLength::Rem(0.25),
        }
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("margin"), atom("x"), atom("auto")])).unwrap(),
        StyleOp::Margin {
            axis: StyleAxis::X,
            length: StyleLength::Auto,
        }
    );

    assert_eq!(
        parse_style_op(&tuple(vec![
            atom("gap"),
            atom("all"),
            tuple(vec![atom("px"), integer(-1)]),
        ]))
        .unwrap(),
        StyleOp::Gap {
            axis: StyleAxis::All,
            length: StyleLength::Px(-1.0),
        }
    );

    assert_eq!(
        parse_style_op(&tuple(vec![
            atom("width"),
            tuple(vec![atom("fraction"), float(1.0)]),
        ]))
        .unwrap(),
        StyleOp::Width(StyleLength::Fraction(1.0))
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("height"), atom("auto")])).unwrap(),
        StyleOp::Height(StyleLength::Auto)
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("position"), atom("relative")])).unwrap(),
        StyleOp::Position(super::PositionStyle::Relative)
    );

    assert_eq!(
        parse_style_op(&tuple(vec![
            atom("inset"),
            atom("top"),
            tuple(vec![atom("rem"), float(-0.5)]),
        ]))
        .unwrap(),
        StyleOp::Inset {
            axis: StyleAxis::Top,
            length: StyleLength::Rem(-0.5),
        }
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("display"), atom("flex")])).unwrap(),
        StyleOp::Display(super::DisplayStyle::Flex)
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("visibility"), atom("hidden")])).unwrap(),
        StyleOp::Visibility(super::VisibilityStyle::Hidden)
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("overflow"), atom("x"), atom("scroll")])).unwrap(),
        StyleOp::Overflow {
            axis: StyleAxis::X,
            behavior: super::OverflowStyle::Scroll,
        }
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("cursor"), atom("not_allowed")])).unwrap(),
        StyleOp::Cursor(super::MouseCursorStyle::NotAllowed)
    );

    assert_eq!(
        parse_style_op(&tuple(vec![
            atom("border_width"),
            atom("x"),
            tuple(vec![atom("px"), integer(4)]),
        ]))
        .unwrap(),
        StyleOp::BorderWidth {
            axis: StyleAxis::X,
            length: StyleLength::Px(4.0),
        }
    );

    assert_eq!(
        parse_style_op(&tuple(vec![
            atom("border_radius"),
            atom("top_left"),
            tuple(vec![atom("rem"), float(0.25)]),
        ]))
        .unwrap(),
        StyleOp::BorderRadius {
            axis: super::BorderRadiusAxis::TopLeft,
            length: StyleLength::Rem(0.25),
        }
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("border_style"), atom("dashed")])).unwrap(),
        StyleOp::BorderStyle(super::BorderLineStyle::Dashed)
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("shadow"), atom("2xs")])).unwrap(),
        StyleOp::Shadow(super::ShadowStyle::TwoXs)
    );

    assert_eq!(
        parse_style_op(&tuple(vec![atom("flex_direction"), atom("row_reverse")])).unwrap(),
        StyleOp::FlexDirection(super::FlexDirectionStyle::RowReverse)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("flex_wrap"), atom("nowrap")])).unwrap(),
        StyleOp::FlexWrapValue(super::FlexWrapStyle::NoWrap)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("flex_item"), atom("shrink_0")])).unwrap(),
        StyleOp::FlexItem(super::FlexItemStyle::Shrink0)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![
            atom("flex_basis"),
            tuple(vec![atom("fraction"), float(0.5)]),
        ]))
        .unwrap(),
        StyleOp::FlexBasis(StyleLength::Fraction(0.5))
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("align_items"), atom("baseline")])).unwrap(),
        StyleOp::AlignItems(super::AlignItemsStyle::Baseline)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("justify_content"), atom("around")])).unwrap(),
        StyleOp::JustifyContent(super::JustifyContentStyle::Around)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("align_content"), atom("evenly")])).unwrap(),
        StyleOp::AlignContent(super::AlignContentStyle::Evenly)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("text_align"), atom("center")])).unwrap(),
        StyleOp::TextAlign(super::TextAlignStyle::Center)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("white_space"), atom("nowrap")])).unwrap(),
        StyleOp::WhiteSpace(super::WhiteSpaceStyle::NoWrap)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("text_overflow"), atom("truncate")])).unwrap(),
        StyleOp::TextOverflow(super::TextOverflowStyle::Truncate)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("font_size"), atom("2xl")])).unwrap(),
        StyleOp::FontSize(super::FontSizeStyle::TwoXl)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("line_height"), atom("relaxed")])).unwrap(),
        StyleOp::LineHeight(super::LineHeightStyle::Relaxed)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("font_weight"), atom("bold")])).unwrap(),
        StyleOp::FontWeight(super::FontWeightStyle::Bold)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("font_style"), atom("italic")])).unwrap(),
        StyleOp::FontStyle(super::FontStyleValue::Italic)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("text_decoration"), atom("none")])).unwrap(),
        StyleOp::TextDecoration(super::TextDecorationStyle::None)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("line_clamp"), integer(4)])).unwrap(),
        StyleOp::LineClamp(4)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("col_start"), integer(2)])).unwrap(),
        StyleOp::ColStart(2)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("col_end"), atom("auto")])).unwrap(),
        StyleOp::ColEndAuto
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("row_start"), integer(-1)])).unwrap(),
        StyleOp::RowStart(-1)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("row_end"), atom("auto")])).unwrap(),
        StyleOp::RowEndAuto
    );
}

#[test]
fn rejects_invalid_canonical_length_style_ops() {
    for term in [
        tuple(vec![
            atom("padding"),
            atom("inline"),
            tuple(vec![atom("rem"), float(0.25)]),
        ]),
        tuple(vec![
            atom("padding"),
            atom("all"),
            tuple(vec![atom("px"), integer(-1)]),
        ]),
        tuple(vec![
            atom("gap"),
            atom("top"),
            tuple(vec![atom("px"), integer(1)]),
        ]),
        tuple(vec![atom("width"), tuple(vec![atom("bad"), integer(1)])]),
        tuple(vec![atom("position"), atom("fixed")]),
        tuple(vec![
            atom("inset"),
            atom("center"),
            tuple(vec![atom("px"), integer(1)]),
        ]),
        tuple(vec![atom("display"), atom("inline")]),
        tuple(vec![atom("visibility"), atom("collapsed")]),
        tuple(vec![atom("overflow"), atom("x"), atom("clip")]),
        tuple(vec![atom("cursor"), atom("bad")]),
        tuple(vec![
            atom("border_width"),
            atom("center"),
            tuple(vec![atom("px"), integer(1)]),
        ]),
        tuple(vec![
            atom("border_width"),
            atom("all"),
            tuple(vec![atom("fraction"), integer(1)]),
        ]),
        tuple(vec![
            atom("border_radius"),
            atom("x"),
            tuple(vec![atom("px"), integer(1)]),
        ]),
        tuple(vec![atom("border_style"), atom("double")]),
        tuple(vec![atom("shadow"), atom("huge")]),
        tuple(vec![atom("flex_direction"), atom("sideways")]),
        tuple(vec![atom("flex_wrap"), atom("maybe")]),
        tuple(vec![atom("flex_item"), atom("bad")]),
        tuple(vec![atom("align_items"), atom("left")]),
        tuple(vec![atom("justify_content"), atom("stretch")]),
        tuple(vec![atom("align_content"), atom("bad")]),
        tuple(vec![atom("text_align"), atom("justify")]),
        tuple(vec![atom("white_space"), atom("pre")]),
        tuple(vec![atom("text_overflow"), atom("clip")]),
        tuple(vec![atom("font_size"), atom("huge")]),
        tuple(vec![atom("line_height"), atom("bad")]),
        tuple(vec![atom("font_weight"), atom("heavy")]),
        tuple(vec![atom("font_style"), atom("oblique")]),
        tuple(vec![atom("text_decoration"), atom("blink")]),
    ] {
        let err = parse_style_op(&term).unwrap_err();
        assert!(
            err.contains("padding")
                || err.contains("gap")
                || err.contains("position")
                || err.contains("inset")
                || err.contains("display")
                || err.contains("visibility")
                || err.contains("overflow")
                || err.contains("cursor")
                || err.contains("border")
                || err.contains("shadow")
                || err.contains("flex")
                || err.contains("align")
                || err.contains("justify")
                || err.contains("text")
                || err.contains("white")
                || err.contains("font")
                || err.contains("line")
                || err.contains("length"),
            "unexpected error: {err}"
        );
    }
}

#[test]
fn native_style_catalog_loads() {
    let catalog: serde_json::Value =
        serde_json::from_str(include_str!("../../../data/gpui_style_catalog.json")).unwrap();

    assert_eq!(catalog["gpui_version"], "0.2.2");
    let operations = catalog["operations"].as_array().unwrap();
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "padding")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "margin")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "width")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "position")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "display")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "cursor")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "border_width")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "border_radius")
    );
    assert!(operations.iter().any(|operation| operation["name"] == "bg"));
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "text_color")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "bg_hex")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "bg_linear_gradient")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "opacity")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "scrollbar_width")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "shadow")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "flex_direction")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "flex_basis")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "align_content")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "font_weight")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "text_bg")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "text_decoration")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "line_clamp")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "grid_cols")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "col_start")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "object_fit")
    );
    assert!(
        operations
            .iter()
            .any(|operation| operation["name"] == "grayscale")
    );
}

#[test]
fn parses_named_text_background_style_op() {
    assert_eq!(
        parse_style_op(&tuple(vec![atom("text_bg"), atom("blue")])).unwrap(),
        StyleOp::TextBg(super::ColorToken::Blue)
    );
}

#[test]
fn parses_bg_linear_gradient_style_op() {
    let term = tuple(vec![
        atom("bg_linear_gradient"),
        list(vec![
            tuple(vec![atom("angle"), integer(90)]),
            tuple(vec![
                atom("from"),
                tuple(vec![binary("#0f172a"), float(0.0)]),
            ]),
            tuple(vec![atom("to"), tuple(vec![atom("blue"), float(1.0)])]),
        ]),
    ]);

    assert_eq!(
        parse_style_op(&term).unwrap(),
        StyleOp::BgLinearGradient {
            angle: 90.0,
            from: LinearGradientStop {
                color: StyleColor::Hex(0x0f172a),
                percentage: 0.0,
            },
            to: LinearGradientStop {
                color: StyleColor::Token(super::ColorToken::Blue),
                percentage: 1.0,
            },
        }
    );
}

#[test]
fn rejects_invalid_bg_linear_gradient_style_op() {
    let term = tuple(vec![
        atom("bg_linear_gradient"),
        list(vec![
            tuple(vec![atom("angle"), integer(90)]),
            tuple(vec![
                atom("from"),
                tuple(vec![binary("0f172a"), float(0.0)]),
            ]),
            tuple(vec![atom("to"), tuple(vec![binary("#2563eb"), float(1.5)])]),
        ]),
    ]);

    let err = parse_style_op(&term).unwrap_err();
    assert!(err.contains("gradient"));
}

#[test]
fn parses_style_hex_color_ops_with_optional_hash() {
    assert_eq!(
        parse_style_op(&tuple(vec![atom("bg_hex"), binary("#0f172a")])).unwrap(),
        StyleOp::BgHex(0x0f172a)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("text_color_hex"), binary("445566")])).unwrap(),
        StyleOp::TextColorHex(0x445566)
    );
    assert_eq!(
        parse_style_op(&tuple(vec![atom("text_bg_hex"), binary("778899")])).unwrap(),
        StyleOp::TextBgHex(0x778899)
    );
}

#[test]
fn rejects_invalid_hex_style_color_ops() {
    let term = tuple(vec![atom("bg_hex"), binary("#12")]);

    let err = parse_style_op(&term).unwrap_err();
    assert!(err.contains("invalid style hex color"));
}

#[test]
fn rejects_invalid_numeric_style_ops() {
    for term in [
        tuple(vec![atom("opacity"), float(1.5)]),
        tuple(vec![atom("line_clamp"), integer(0)]),
        tuple(vec![atom("col_start"), integer(40_000)]),
        tuple(vec![
            atom("flex_basis"),
            tuple(vec![atom("px"), integer(-1)]),
        ]),
        tuple(vec![atom("w_px"), integer(-1)]),
        tuple(vec![atom("w_frac"), float(1.2)]),
        tuple(vec![atom("scrollbar_width_px"), integer(-1)]),
    ] {
        let err = parse_style_op(&term).unwrap_err();
        assert!(err.contains("invalid"), "unexpected error: {err}");
    }
}

#[test]
fn list_row_validation_rejects_stateful_controls() {
    let err = validate_list_row_child(&IrNode::TextInput {
        id: Some("row_input".into()),
        value: "nope".into(),
        placeholder: String::new(),
        style: Vec::new().into(),
        disabled: false,
        tab_index: None,
        change: None,
        focus: None,
        blur: None,
    })
    .unwrap_err();

    assert!(err.contains("text_input"));
}
