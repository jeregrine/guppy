defmodule Guppy.IRTest do
  use ExUnit.Case

  test "ir validation rejects unknown node keys" do
    assert {:error, {:unknown_ir_keys, :text, [:typo]}} =
             Guppy.IR.validate(Map.put(Guppy.IR.text("hello"), :typo, true))

    assert {:error, {:unknown_ir_keys, :div, [:bogus]}} =
             Guppy.IR.validate(Map.put(Guppy.IR.div([], id: "root"), :bogus, "nope"))
  end

  test "ir validation accepts ordered style lists and rejects invalid values" do
    assert :ok = Guppy.IR.validate(Guppy.IR.text("hello", id: "greeting"))
    assert :ok = Guppy.IR.validate(Guppy.IR.text("hello", events: %{click: "open"}))

    assert {:error, {:invalid_style_op, :not_a_style}} =
             Guppy.IR.validate(Guppy.IR.text("hello", style: [:not_a_style]))

    scroll_ir =
      Guppy.IR.scroll(
        [Guppy.IR.text("inside scroll")],
        id: "scroll_root",
        axis: :both,
        style: [{:h_px, 180}, {:scrollbar_width_px, 12}, :p_2, :rounded_md]
      )

    assert :ok = Guppy.IR.validate(scroll_ir)
    assert scroll_ir.axis == :both

    image_ir =
      Guppy.IR.image(
        {:path, "/tmp/logo.png"},
        id: "logo_image",
        style: [{:w_px, 96}, {:h_px, 96}, :rounded_md],
        object_fit: :cover,
        grayscale: true
      )

    assert :ok = Guppy.IR.validate(image_ir)
    assert image_ir.object_fit == :cover
    assert image_ir.grayscale == true

    checkbox_ir =
      Guppy.IR.checkbox(
        "Ship release notes",
        true,
        id: "ship_checkbox",
        style: [:gap_2],
        hover_style: [{:opacity, 0.9}],
        focus_style: [{:border_color, :yellow}],
        in_focus_style: [:shadow_md],
        active_style: [{:opacity, 0.7}],
        disabled_style: [{:opacity, 0.3}],
        disabled: false,
        tab_index: 5,
        events: %{change: "toggle_ship", focus: "focus_ship", blur: "blur_ship"}
      )

    assert :ok = Guppy.IR.validate(checkbox_ir)
    assert checkbox_ir.checked == true
    assert checkbox_ir.tab_index == 5
    assert checkbox_ir.events == %{change: "toggle_ship", focus: "focus_ship", blur: "blur_ship"}

    uniform_list_ir =
      Guppy.IR.uniform_list(
        [%{id: "item_1", label: "Item one"}, %{id: "item_2", label: "Item two"}],
        id: "uniform_items",
        style: [{:h_px, 160}, :overflow_y_scroll],
        item_style: [:p_2, :border_b_1],
        events: %{click: "item_clicked"}
      )

    assert :ok = Guppy.IR.validate(uniform_list_ir)
    assert uniform_list_ir.kind == :uniform_list
    assert length(uniform_list_ir.items) == 2
    assert uniform_list_ir.events == %{click: "item_clicked"}

    list_ir =
      Guppy.IR.list(
        [
          %{
            id: "row_1",
            children: [
              Guppy.IR.text("Row one", id: "row_1_label"),
              Guppy.IR.div([Guppy.IR.text("variable height")], id: "row_1_detail")
            ]
          },
          %{id: "row_2", children: [Guppy.IR.text("Row two")]}
        ],
        id: "generic_items",
        style: [{:h_px, 180}, :overflow_y_scroll],
        item_style: [:p_2, :border_b_1],
        events: %{click: "generic_item_clicked"}
      )

    assert :ok = Guppy.IR.validate(list_ir)
    assert list_ir.kind == :list
    assert Enum.map(list_ir.items, & &1.id) == ["row_1", "row_2"]
    assert list_ir.events == %{click: "generic_item_clicked"}

    popover_ir =
      Guppy.IR.popover(
        "Help",
        true,
        [Guppy.IR.text("Popover content", id: "popover_text")],
        id: "help_popover",
        style: [:p_2],
        popover_style: [:p_4, :shadow_lg],
        anchor: :bottom_right,
        anchor_position: {4, 8},
        anchor_offset: {0, 12},
        anchor_position_mode: :local,
        anchor_fit: :snap_to_window_with_margin,
        snap_margin: 12,
        close_on_click_outside: false,
        stack_priority: 2,
        events: %{click: "open_help", close: "close_help"}
      )

    assert :ok = Guppy.IR.validate(popover_ir)
    assert popover_ir.kind == :popover
    assert popover_ir.open == true
    assert popover_ir.anchor == :bottom_right
    assert popover_ir.anchor_position == {4, 8}
    assert popover_ir.anchor_offset == {0, 12}
    assert popover_ir.anchor_position_mode == :local
    assert popover_ir.anchor_fit == :snap_to_window_with_margin
    assert popover_ir.snap_margin == 12
    assert popover_ir.close_on_click_outside == false
    assert popover_ir.stack_priority == 2
    assert popover_ir.events == %{click: "open_help", close: "close_help"}

    radio_ir =
      Guppy.IR.radio(
        "High priority",
        "high",
        true,
        id: "priority_high",
        style: [:gap_2],
        disabled: false,
        tab_index: 2,
        events: %{change: "priority_changed", focus: "focus_priority", blur: "blur_priority"}
      )

    assert :ok = Guppy.IR.validate(radio_ir)
    assert radio_ir.kind == :radio
    assert radio_ir.label == "High priority"
    assert radio_ir.value == "high"
    assert radio_ir.checked == true
    assert radio_ir.tab_index == 2

    assert radio_ir.events == %{
             change: "priority_changed",
             focus: "focus_priority",
             blur: "blur_priority"
           }

    select_ir =
      Guppy.IR.select(
        [
          %{value: "todo", label: "Todo"},
          %{value: "done", label: "Done", disabled: true}
        ],
        id: "status_select",
        value: "todo",
        open: true,
        placeholder: "Pick status",
        style: [:p_2, :border_1],
        list_style: [:p_1, :shadow_lg],
        option_style: [:p_2],
        disabled: false,
        tab_index: 6,
        events: %{
          click: "toggle_status",
          change: "status_changed",
          close: "close_status",
          focus: "focus_status",
          blur: "blur_status"
        }
      )

    assert :ok = Guppy.IR.validate(select_ir)
    assert select_ir.kind == :select
    assert select_ir.value == "todo"
    assert select_ir.open == true
    assert select_ir.placeholder == "Pick status"
    assert Enum.map(select_ir.options, & &1.value) == ["todo", "done"]
    assert select_ir.tab_index == 6

    icon_ir =
      Guppy.IR.icon({:path, "/tmp/release.svg"},
        id: "release_icon",
        style: [{:w_px, 18}, {:h_px, 18}]
      )

    assert :ok = Guppy.IR.validate(icon_ir)
    assert icon_ir.source == {:path, "/tmp/release.svg"}

    button_ir =
      Guppy.IR.button(
        "Save changes",
        id: "save_button",
        style: [{:bg, :blue}, {:text_color, :white}],
        focus_style: [{:border_color, :yellow}],
        active_style: [{:opacity, 0.7}],
        disabled_style: [{:opacity, 0.3}],
        disabled: false,
        tab_index: 2,
        actions: %{"save" => "save_action"},
        shortcuts: [{"ctrl-s", "save"}],
        events: %{
          click: "save_click",
          focus: "save_focus",
          blur: "save_blur",
          key_down: "save_key_down",
          key_up: "save_key_up",
          context_menu: "save_context",
          mouse_down: "save_mouse_down",
          mouse_up: "save_mouse_up",
          mouse_move: "save_mouse_move"
        }
      )

    assert :ok = Guppy.IR.validate(button_ir)
    assert button_ir.tab_index == 2
    assert button_ir.actions == %{"save" => "save_action"}
    assert button_ir.shortcuts == [{"ctrl-s", "save"}]

    text_input_ir =
      Guppy.IR.text_input(
        "Jason",
        id: "name_input",
        placeholder: "Type a name",
        style: [{:w_px, 240}],
        disabled: false,
        tab_index: 4,
        events: %{change: "name_changed"}
      )

    assert :ok = Guppy.IR.validate(text_input_ir)
    assert text_input_ir.placeholder == "Type a name"
    assert text_input_ir.tab_index == 4

    textarea_ir =
      Guppy.IR.textarea(
        "Line one\nLine two",
        id: "notes_input",
        placeholder: "Notes",
        style: [{:w_px, 320}, {:h_px, 120}],
        disabled: false,
        tab_index: 5,
        events: %{change: "notes_changed"}
      )

    assert :ok = Guppy.IR.validate(textarea_ir)
    assert textarea_ir.kind == :textarea
    assert textarea_ir.value == "Line one\nLine two"
    assert textarea_ir.placeholder == "Notes"
    assert textarea_ir.tab_index == 5

    styled_ir =
      Guppy.IR.div(
        [Guppy.IR.text("hello")],
        id: "root",
        tooltip: "Helpful root tooltip",
        hover_style: [{:bg_hex, "#101010"}, {:opacity, 0.9}, :cursor_pointer],
        focus_style: [{:bg_hex, "#202020"}, {:text_color, :yellow}],
        in_focus_style: [{:border_color, :yellow}, :shadow_md],
        active_style: [{:opacity, 0.6}, {:bg_hex, "#303030"}],
        disabled_style: [{:opacity, 0.4}, {:bg, :black}],
        disabled: false,
        stack_priority: 7,
        occlude: true,
        focusable: true,
        tab_stop: true,
        tab_index: 3,
        track_scroll: true,
        anchor_scroll: true,
        actions: %{"save" => "save_action", "open" => "open_action"},
        shortcuts: [{"ctrl-s", "save"}, {"ctrl-o", "open"}],
        events: %{
          hover: "hovered",
          click: "clicked",
          focus: "focused",
          blur: "blurred",
          key_down: "keyed_down",
          key_up: "keyed_up",
          context_menu: "contexted",
          drag_start: "dragged_start",
          drag_move: "dragged_move",
          drop: "dropped",
          mouse_down: "down",
          mouse_up: "up",
          mouse_move: "move",
          scroll_wheel: "wheel"
        },
        style: [
          :flex,
          :flex_col,
          :flex_row,
          :flex_wrap,
          :flex_nowrap,
          :flex_none,
          :flex_auto,
          :flex_grow,
          :flex_shrink,
          :flex_shrink_0,
          :flex_1,
          :size_full,
          :w_full,
          :h_full,
          :w_32,
          :w_96,
          :h_32,
          :min_w_32,
          :min_h_0,
          :min_h_full,
          :max_w_64,
          :max_w_96,
          :max_w_full,
          :max_h_32,
          :max_h_96,
          :max_h_full,
          :gap_1,
          :gap_2,
          :gap_4,
          :p_1,
          :p_2,
          :p_4,
          :p_6,
          :p_8,
          :px_2,
          :py_2,
          :pt_2,
          :pr_2,
          :pb_2,
          :pl_2,
          :m_2,
          :mx_2,
          :my_2,
          :mt_2,
          :mr_2,
          :mb_2,
          :ml_2,
          :relative,
          :absolute,
          :top_0,
          :right_0,
          :bottom_0,
          :left_0,
          :inset_0,
          :top_1,
          :right_1,
          :top_2,
          :right_2,
          :bottom_2,
          :left_2,
          :text_left,
          :text_center,
          :text_right,
          :whitespace_normal,
          :whitespace_nowrap,
          :truncate,
          :text_ellipsis,
          :line_clamp_2,
          :line_clamp_3,
          :text_xs,
          :text_sm,
          :text_base,
          :text_lg,
          :text_xl,
          :text_2xl,
          :text_3xl,
          :leading_none,
          :leading_tight,
          :leading_snug,
          :leading_normal,
          :leading_relaxed,
          :leading_loose,
          :font_thin,
          :font_extralight,
          :font_light,
          :font_normal,
          :font_medium,
          :font_semibold,
          :font_bold,
          :font_extrabold,
          :font_black,
          :italic,
          :not_italic,
          :underline,
          :line_through,
          :items_start,
          :items_end,
          :justify_start,
          :justify_center,
          :justify_end,
          :justify_between,
          :justify_around,
          {:bg, :gray},
          :rounded_sm,
          :rounded_md,
          :rounded_lg,
          :rounded_xl,
          :rounded_2xl,
          :rounded_full,
          :border_1,
          :border_2,
          :border_dashed,
          :border_t_1,
          :border_r_1,
          :border_b_1,
          :border_l_1,
          :shadow_sm,
          :shadow_md,
          :shadow_lg,
          {:border_color, :white},
          {:bg_hex, "#112233"},
          {:text_color_hex, "445566"},
          {:border_color_hex, "#abcdef"},
          {:opacity, 0.75},
          {:w_px, 320},
          {:w_rem, 24.0},
          {:w_frac, 0.5},
          {:h_px, 180},
          {:h_rem, 12.0},
          {:h_frac, 1.0},
          {:scrollbar_width_px, 12},
          {:scrollbar_width_rem, 1.0},
          :overflow_y_scroll,
          {:bg, :blue}
        ]
      )

    assert :ok = Guppy.IR.validate(styled_ir)

    assert styled_ir.focus_style == [{:bg_hex, "#202020"}, {:text_color, :yellow}]
    assert styled_ir.in_focus_style == [{:border_color, :yellow}, :shadow_md]
    assert styled_ir.active_style == [{:opacity, 0.6}, {:bg_hex, "#303030"}]
    assert styled_ir.disabled_style == [{:opacity, 0.4}, {:bg, :black}]
    assert styled_ir.actions == %{"save" => "save_action", "open" => "open_action"}
    assert styled_ir.shortcuts == [{"ctrl-s", "save"}, {"ctrl-o", "open"}]
    assert styled_ir.disabled == false
    assert styled_ir.stack_priority == 7
    assert styled_ir.occlude == true
    assert styled_ir.focusable == true
    assert styled_ir.tooltip == "Helpful root tooltip"
    assert styled_ir.tab_stop == true
    assert styled_ir.tab_index == 3

    assert styled_ir.style == [
             :flex,
             :flex_col,
             :flex_row,
             :flex_wrap,
             :flex_nowrap,
             :flex_none,
             :flex_auto,
             :flex_grow,
             :flex_shrink,
             :flex_shrink_0,
             :flex_1,
             :size_full,
             :w_full,
             :h_full,
             :w_32,
             :w_96,
             :h_32,
             :min_w_32,
             :min_h_0,
             :min_h_full,
             :max_w_64,
             :max_w_96,
             :max_w_full,
             :max_h_32,
             :max_h_96,
             :max_h_full,
             :gap_1,
             :gap_2,
             :gap_4,
             :p_1,
             :p_2,
             :p_4,
             :p_6,
             :p_8,
             :px_2,
             :py_2,
             :pt_2,
             :pr_2,
             :pb_2,
             :pl_2,
             :m_2,
             :mx_2,
             :my_2,
             :mt_2,
             :mr_2,
             :mb_2,
             :ml_2,
             :relative,
             :absolute,
             :top_0,
             :right_0,
             :bottom_0,
             :left_0,
             :inset_0,
             :top_1,
             :right_1,
             :top_2,
             :right_2,
             :bottom_2,
             :left_2,
             :text_left,
             :text_center,
             :text_right,
             :whitespace_normal,
             :whitespace_nowrap,
             :truncate,
             :text_ellipsis,
             :line_clamp_2,
             :line_clamp_3,
             :text_xs,
             :text_sm,
             :text_base,
             :text_lg,
             :text_xl,
             :text_2xl,
             :text_3xl,
             :leading_none,
             :leading_tight,
             :leading_snug,
             :leading_normal,
             :leading_relaxed,
             :leading_loose,
             :font_thin,
             :font_extralight,
             :font_light,
             :font_normal,
             :font_medium,
             :font_semibold,
             :font_bold,
             :font_extrabold,
             :font_black,
             :italic,
             :not_italic,
             :underline,
             :line_through,
             :items_start,
             :items_end,
             :justify_start,
             :justify_center,
             :justify_end,
             :justify_between,
             :justify_around,
             {:bg, :gray},
             :rounded_sm,
             :rounded_md,
             :rounded_lg,
             :rounded_xl,
             :rounded_2xl,
             :rounded_full,
             :border_1,
             :border_2,
             :border_dashed,
             :border_t_1,
             :border_r_1,
             :border_b_1,
             :border_l_1,
             :shadow_sm,
             :shadow_md,
             :shadow_lg,
             {:border_color, :white},
             {:bg_hex, "#112233"},
             {:text_color_hex, "445566"},
             {:border_color_hex, "#abcdef"},
             {:opacity, 0.75},
             {:w_px, 320},
             {:w_rem, 24.0},
             {:w_frac, 0.5},
             {:h_px, 180},
             {:h_rem, 12.0},
             {:h_frac, 1.0},
             {:scrollbar_width_px, 12},
             {:scrollbar_width_rem, 1.0},
             :overflow_y_scroll,
             {:bg, :blue}
           ]

    assert {:error, {:invalid_id, 123}} = Guppy.IR.validate(Guppy.IR.text("hello", id: 123))

    assert {:error, {:duplicate_id, "dup"}} =
             Guppy.IR.validate(
               Guppy.IR.div([
                 Guppy.IR.text("first", id: "dup"),
                 Guppy.IR.scroll([
                   Guppy.IR.div([], id: "dup")
                 ])
               ])
             )

    assert {:error, {:invalid_style_op, :bogus}} =
             Guppy.IR.validate(Guppy.IR.div([], style: [:bogus]))

    assert {:error, {:invalid_style_op, {:bg, :purple}}} =
             Guppy.IR.validate(Guppy.IR.div([], style: [{:bg, :purple}]))

    assert {:error, {:invalid_style_op, {:opacity, 1.5}}} =
             Guppy.IR.validate(Guppy.IR.div([], style: [{:opacity, 1.5}]))

    assert {:error, {:invalid_style_op, {:bg_hex, "#12"}}} =
             Guppy.IR.validate(Guppy.IR.div([], style: [{:bg_hex, "#12"}]))

    assert {:error, {:invalid_style_op, :bogus}} =
             Guppy.IR.validate(Guppy.IR.div([], active_style: [:bogus]))

    assert {:error, {:invalid_style_op, :bogus}} =
             Guppy.IR.validate(Guppy.IR.div([], in_focus_style: [:bogus]))

    assert {:error, {:invalid_style_op, :bogus}} =
             Guppy.IR.validate(Guppy.IR.div([], disabled_style: [:bogus]))

    assert {:error, {:invalid_scroll_axis, :diagonal}} =
             Guppy.IR.validate(Guppy.IR.scroll([], axis: :diagonal))

    assert {:error, {:invalid_ir, %{kind: :button, label: 123}}} =
             Guppy.IR.validate(%{kind: :button, label: 123})

    assert {:error, {:invalid_ir, %{kind: :radio, label: "High", value: 123, checked: true}}} =
             Guppy.IR.validate(%{kind: :radio, label: "High", value: 123, checked: true})

    assert {:error, {:invalid_uniform_list_item, %{id: "item", label: 123}}} =
             Guppy.IR.validate(Guppy.IR.uniform_list([%{id: "item", label: 123}]))

    assert {:error, {:invalid_list_item, %{id: "row", children: "nope"}}} =
             Guppy.IR.validate(Guppy.IR.list([%{id: "row", children: "nope"}]))

    assert {:error, {:duplicate_id, "row_1_label"}} =
             Guppy.IR.validate(
               Guppy.IR.list([
                 %{id: "row_1", children: [Guppy.IR.text("first", id: "row_1_label")]},
                 %{id: "row_2", children: [Guppy.IR.text("second", id: "row_1_label")]}
               ])
             )

    assert {:error, {:invalid_ir, %{kind: :popover, label: "Help", open: "yes", children: []}}} =
             Guppy.IR.validate(%{kind: :popover, label: "Help", open: "yes", children: []})

    assert {:error, {:invalid_popover_anchor, :middle}} =
             Guppy.IR.validate(Guppy.IR.popover("Help", true, [], anchor: :middle))

    assert {:error, {:invalid_popover_anchor_fit, :float}} =
             Guppy.IR.validate(Guppy.IR.popover("Help", true, [], anchor_fit: :float))

    assert {:error, {:invalid_point, :anchor_offset, {0, "down"}}} =
             Guppy.IR.validate(Guppy.IR.popover("Help", true, [], anchor_offset: {0, "down"}))

    assert {:error, {:snap_margin, -1}} =
             Guppy.IR.validate(Guppy.IR.popover("Help", true, [], snap_margin: -1))

    assert {:error, {:invalid_ir, %{kind: :text_input, value: 123}}} =
             Guppy.IR.validate(%{kind: :text_input, value: 123})

    assert {:error, {:invalid_ir, %{kind: :textarea, value: 123}}} =
             Guppy.IR.validate(%{kind: :textarea, value: 123})

    assert {:error, {:invalid_event, :drag_start, "nope"}} =
             Guppy.IR.validate(Guppy.IR.button("Save", events: %{drag_start: "nope"}))

    assert {:error, {:invalid_event, :click, "nope"}} =
             Guppy.IR.validate(Guppy.IR.radio("High", "high", false, events: %{click: "nope"}))

    assert {:error, {:invalid_event, :click, "nope"}} =
             Guppy.IR.validate(Guppy.IR.text_input("Jason", events: %{click: "nope"}))

    assert {:error, {:invalid_event, :click, "nope"}} =
             Guppy.IR.validate(Guppy.IR.textarea("Notes", events: %{click: "nope"}))

    assert {:error, {:invalid_select_option, %{label: "Todo", value: 1}}} =
             Guppy.IR.validate(Guppy.IR.select([%{value: 1, label: "Todo"}]))

    assert {:error, {:duplicate_select_value, "todo"}} =
             Guppy.IR.validate(
               Guppy.IR.select([
                 %{value: "todo", label: "Todo"},
                 %{value: "todo", label: "Duplicate"}
               ])
             )

    assert {:error, {:invalid_event, :hover, "hover_status"}} =
             Guppy.IR.validate(Guppy.IR.select([], events: %{hover: "hover_status"}))

    assert {:error, {:placeholder, 123}} =
             Guppy.IR.validate(Guppy.IR.text_input("Jason", placeholder: 123))

    assert {:error, {:tab_index, "first"}} =
             Guppy.IR.validate(Guppy.IR.text_input("Jason", tab_index: "first"))

    assert {:error, {:disabled, "yes"}} =
             Guppy.IR.validate(Guppy.IR.text_input("Jason", disabled: "yes"))

    assert {:error, {:tooltip, 123}} =
             Guppy.IR.validate(Guppy.IR.div([], tooltip: 123))

    assert {:error, {:invalid_actions, [:nope]}} =
             Guppy.IR.validate(Guppy.IR.div([], actions: [:nope]))

    assert {:error, {:invalid_action_binding, :save, "save_action"}} =
             Guppy.IR.validate(Guppy.IR.div([], actions: %{save: "save_action"}))

    assert {:error, {:invalid_shortcuts, %{}}} =
             Guppy.IR.validate(Guppy.IR.div([], shortcuts: %{}))

    assert {:error, {:invalid_shortcut_binding, {1, "save"}}} =
             Guppy.IR.validate(
               Guppy.IR.div([], actions: %{"save" => "save_action"}, shortcuts: [{1, "save"}])
             )

    assert {:error, {:unknown_shortcut_action, "ctrl-s", "save"}} =
             Guppy.IR.validate(Guppy.IR.div([], shortcuts: [{"ctrl-s", "save"}]))

    assert {:error, {:track_scroll, "yes"}} =
             Guppy.IR.validate(Guppy.IR.div([], track_scroll: "yes"))

    assert {:error, {:anchor_scroll, 1}} =
             Guppy.IR.validate(Guppy.IR.div([], anchor_scroll: 1))

    assert {:error, {:disabled, "yes"}} =
             Guppy.IR.validate(Guppy.IR.div([], disabled: "yes"))

    assert {:error, {:stack_priority, -1}} =
             Guppy.IR.validate(Guppy.IR.div([], stack_priority: -1))

    assert {:error, {:occlude, "yes"}} =
             Guppy.IR.validate(Guppy.IR.div([], occlude: "yes"))

    assert {:error, {:focusable, "yes"}} =
             Guppy.IR.validate(Guppy.IR.div([], focusable: "yes"))

    assert {:error, {:tab_stop, 1}} =
             Guppy.IR.validate(Guppy.IR.div([], tab_stop: 1))

    assert {:error, {:tab_index, "first"}} =
             Guppy.IR.validate(Guppy.IR.div([], tab_index: "first"))

    assert {:error, {:invalid_image_source, 123}} =
             Guppy.IR.validate(Guppy.IR.image(123))

    assert {:error, {:invalid_image_source, {:path, 123}}} =
             Guppy.IR.validate(Guppy.IR.image({:path, 123}))

    assert {:error, {:invalid_image_object_fit, :stretch}} =
             Guppy.IR.validate(Guppy.IR.image("logo.png", object_fit: :stretch))

    assert {:error, {:grayscale, "yes"}} =
             Guppy.IR.validate(Guppy.IR.image("logo.png", grayscale: "yes"))

    assert {:error, {:invalid_image_source, {:uri, 123}}} =
             Guppy.IR.validate(Guppy.IR.icon({:uri, 123}))

    assert {:error, {:disabled, "yes"}} =
             Guppy.IR.validate(Guppy.IR.checkbox("Ship", true, disabled: "yes"))

    assert {:error, {:tab_index, "fifth"}} =
             Guppy.IR.validate(Guppy.IR.checkbox("Ship", true, tab_index: "fifth"))

    assert {:error, {:invalid_event, :click, "toggle"}} =
             Guppy.IR.validate(Guppy.IR.checkbox("Ship", true, events: %{click: "toggle"}))
  end

  test "validated IR wrappers validate once and unwrap for rendering" do
    ir = Guppy.IR.div([Guppy.IR.text("trusted", id: "trusted_text")], id: "trusted_root")

    assert {:ok, validated} = Guppy.IR.validated(ir)
    assert :ok = Guppy.IR.validate(validated)
    assert Guppy.IR.unwrap(validated) == ir
    assert Guppy.IR.validated!(ir) == validated

    assert {:error, {:invalid_id, 123}} = Guppy.IR.validated(Guppy.IR.text("bad", id: 123))

    assert_raise ArgumentError, fn ->
      Guppy.IR.validated!(Guppy.IR.text("bad", id: 123))
    end
  end
end
