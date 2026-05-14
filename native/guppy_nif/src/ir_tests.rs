use super::{
    CanvasCommand, CheckboxNode, DataTableSortDirection, DivNode, IrNode, LinearGradientStop,
    StyleColor, StyleOp, decode_list_row_child_term, ensure_unique_list_row_control_ids,
    parse_style_op, validate_list_row_child,
};
use eetf::{Atom, Binary, FixInteger, Float, List, Map, Term, Tuple};

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
