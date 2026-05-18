defmodule Guppy.ComponentTest do
  use ExUnit.Case

  test "Guppy.Component imports ~GUI and does not expose the legacy template sigil" do
    macros = Guppy.Component.__info__(:macros)

    assert {:sigil_GUI, 2} in macros
    refute {:sigil_G, 2} in macros
  end

  test "Guppy.Component parses background linear gradient class tokens" do
    assert Guppy.Component.class_to_style!(
             "bg-linear-gradient-[90,#0f172a:0,#2563eb:1] text-white"
           ) == [
             {:bg_linear_gradient, [angle: 90, from: {"#0f172a", 0}, to: {"#2563eb", 1}]},
             {:text_color, :white}
           ]

    ir = Guppy.GradientTemplateExample.render(%{})

    assert :ok = Guppy.IR.validate(ir)

    assert {:bg_linear_gradient, [angle: 90, from: {"#0f172a", 0}, to: {"#2563eb", 1}]} in ir.style
  end

  test "Guppy.Component normalizes dynamic list-valued class attributes" do
    ir =
      Guppy.DynamicClassTemplateExample.render(%{
        classes: ["p-2", nil, false, "text-white", "bg-[#0f172a]"],
        style: [{:w_px, 10}]
      })

    assert ir.style == [
             {:padding, :all, {:rem, 0.5}},
             {:text_color, :white},
             {:bg_hex, "#0f172a"},
             {:w_px, 10}
           ]

    assert :ok = Guppy.IR.validate(ir)

    assert_raise ArgumentError, ~r/use class for class tokens/, fn ->
      Guppy.Component.merge_styles(nil, "p-2 text-white")
    end
  end

  test "Guppy.Component rejects raw string style attributes" do
    source = """
    defmodule Guppy.BadStringStyleTemplate do
      use Guppy.Component

      def render(assigns) do
        ~GUI\"\"\"
        <div style=\"p-2 text-white\">
          <text>Bad style</text>
        </div>
        \"\"\"
      end
    end
    """

    [{module, _bytecode}] = Code.compile_string(source)

    assert_raise ArgumentError, ~r/use class for class tokens/, fn ->
      module.render(%{})
    end
  end

  test "Guppy.Component parses image-only catalog classes into image options" do
    assert Guppy.Component.merge_image_options(
             "object-contain grayscale w-[10px] h-[20px]",
             nil,
             nil,
             nil
           ) == [
             style: [{:width, {:px, 10}}, {:height, {:px, 20}}],
             object_fit: :contain,
             grayscale: true
           ]

    assert Guppy.Component.merge_image_options("object-cover grayscale", nil, :fill, false) == [
             object_fit: :fill,
             grayscale: false
           ]
  end

  test "Guppy.Component parses catalog-backed box spacing classes into canonical tuple styles" do
    assert Guppy.Component.class_to_style!(
             "py-1 px-1 p-0.5 p-0p5 p-[6px] m-auto -mx-2 mt-[-4px] gap-1 gap-x-px w-full h-[120px] min-h-0 max-w-1/2 size-4 relative inset-0 -top-2 right-auto flex hidden invisible visible overflow-hidden overflow-x-scroll cursor-pointer cursor-not-allowed border-1 border-x-4 border-t-px border-dashed border-solid rounded-sm rounded-t-lg rounded-br-full bg-red text-blue text-bg-yellow text-bg-[#112233] border-gray opacity-50 scrollbar-w-[12px] shadow-md shadow-none flex-col flex-row-reverse flex-wrap flex-nowrap flex-1 flex-auto flex-initial items-baseline justify-around content-evenly text-center whitespace-nowrap text-ellipsis truncate text-xl leading-tight font-bold italic not-italic underline line-through no-underline line-clamp-2 grid-cols-3 grid-rows-2 col-start-2 col-end-auto row-start-1 row-end-[-1] col-span-4 row-span-5"
           ) == [
             {:padding, :y, {:rem, 0.25}},
             {:padding, :x, {:rem, 0.25}},
             {:padding, :all, {:rem, 0.125}},
             {:padding, :all, {:rem, 0.125}},
             {:padding, :all, {:px, 6}},
             {:margin, :all, :auto},
             {:margin, :x, {:rem, -0.5}},
             {:margin, :top, {:px, -4}},
             {:gap, :all, {:rem, 0.25}},
             {:gap, :x, {:px, 1}},
             {:width, {:fraction, 1}},
             {:height, {:px, 120}},
             {:min_height, {:px, 0}},
             {:max_width, {:fraction, 0.5}},
             {:size, {:rem, 1}},
             {:position, :relative},
             {:inset, :all, {:px, 0}},
             {:inset, :top, {:rem, -0.5}},
             {:inset, :right, :auto},
             {:display, :flex},
             {:display, :none},
             {:visibility, :hidden},
             {:visibility, :visible},
             {:overflow, :all, :hidden},
             {:overflow, :x, :scroll},
             {:cursor, :pointer},
             {:cursor, :not_allowed},
             {:border_width, :all, {:px, 1}},
             {:border_width, :x, {:px, 4}},
             {:border_width, :top, {:px, 1}},
             {:border_style, :dashed},
             {:border_style, :solid},
             {:border_radius, :all, {:rem, 0.25}},
             {:border_radius, :top, {:rem, 0.5}},
             {:border_radius, :bottom_right, {:px, 9999}},
             {:bg, :red},
             {:text_color, :blue},
             {:text_bg, :yellow},
             {:text_bg_hex, "#112233"},
             {:border_color, :gray},
             {:opacity, 0.5},
             {:scrollbar_width_px, 12},
             {:shadow, :md},
             {:shadow, :none},
             {:flex_direction, :column},
             {:flex_direction, :row_reverse},
             {:flex_wrap, :wrap},
             {:flex_wrap, :nowrap},
             {:flex_item, :one},
             {:flex_item, :auto},
             {:flex_item, :initial},
             {:align_items, :baseline},
             {:justify_content, :around},
             {:align_content, :evenly},
             {:text_align, :center},
             {:white_space, :nowrap},
             {:text_overflow, :ellipsis},
             {:text_overflow, :truncate},
             {:font_size, :xl},
             {:line_height, :tight},
             {:font_weight, :bold},
             {:font_style, :italic},
             {:font_style, :normal},
             {:text_decoration, :underline},
             {:text_decoration, :line_through},
             {:text_decoration, :none},
             {:line_clamp, 2},
             {:grid_cols, 3},
             {:grid_rows, 2},
             {:col_start, 2},
             {:col_end, :auto},
             {:row_start, 1},
             {:row_end, -1},
             {:col_span, 4},
             {:row_span, 5}
           ]

    assert :ok =
             Guppy.IR.validate(
               Guppy.IR.div([],
                 style:
                   Guppy.Component.class_to_style!(
                     "py-1 px-[2rem] m-[auto] gap-y-[4px] w-[50%] h-auto absolute left-[2px]"
                   )
               )
             )
  end

  test "Guppy.Component compiles ~GUI templates into valid IR" do
    ir =
      Guppy.TemplateExample.render(%{
        title: "Template demo",
        root_animation: %{id: "root_fade", duration_ms: 500, repeat: true, from: 0.85, to: 1.0},
        items: [%{id: 1, label: "One"}, %{id: 2, label: "Two"}],
        uniform_items: [
          %{id: "uniform_1", label: "Uniform one"},
          %{id: "uniform_2", label: "Uniform two"}
        ],
        generic_items: [
          %{id: "generic_1", children: [Guppy.IR.text("Generic one")]},
          %{
            id: "generic_2",
            children: [Guppy.IR.div([Guppy.IR.text("Generic two detail")])]
          }
        ],
        table_columns: [
          %{id: "task", label: "Task", width: {:fr, 1}, sortable: true},
          %{id: "status", label: "Status", width: {:px, 96}}
        ],
        table_rows: [
          %{
            id: "row_1",
            cells: [
              %{column_id: "task", children: [Guppy.IR.text("Template table row")]},
              %{column_id: "status", children: [Guppy.IR.text("Ready")]}
            ]
          }
        ],
        selected_row_id: "row_1",
        selected_cell: {"row_1", "status"},
        table_sort: %{column_id: "task", direction: :asc},
        tree_nodes: [
          %{
            id: "tree_root",
            label: "Root",
            expanded: true,
            children: [%{id: "tree_child", label: "Child"}]
          }
        ],
        selected_tree_id: "tree_child",
        canvas_commands: [
          %{op: :rect, x: 0, y: 0, width: 120, height: 80, fill: "#0f172a"},
          %{op: :rounded_rect, x: 12, y: 12, width: 96, height: 24, radius: 8, fill: :blue}
        ],
        rich_runs: [
          %{text: "Rich ", style: [:font_bold]},
          %{text: "intro", style: [{:text_color, :yellow}]}
        ],
        value: "Jason",
        notes: "Line one\nLine two",
        priority: "high",
        status: "todo",
        status_open: true,
        status_options: [
          %{value: "todo", label: "Todo"},
          %{value: "done", label: "Done"}
        ],
        popover_open: true,
        show_footer: true
      })

    assert :ok = Guppy.IR.validate(ir)
    assert ir.kind == :div
    assert ir.id == "root"
    assert ir.tooltip == "Template root"
    assert ir.animation.id == "root_fade"
    assert {:display, :flex} in ir.style
    assert {:bg_hex, "#0f172a"} in ir.style

    [
      title_wrapper,
      rich_intro,
      button,
      checkbox,
      radio,
      icon,
      image,
      scroll,
      uniform_list,
      list,
      data_table,
      tree,
      canvas,
      popover,
      select,
      text_input,
      textarea,
      footer
    ] =
      ir.children

    assert title_wrapper.kind == :div
    assert title_wrapper.children == [%{kind: :text, content: "Template demo", id: "title"}]
    assert {:font_size, :"3xl"} in title_wrapper.style
    assert {:font_weight, :black} in title_wrapper.style

    assert rich_intro.kind == :text
    assert rich_intro.id == "rich_intro"
    assert rich_intro.content == "Rich intro"

    assert rich_intro.runs == [
             %{text: "Rich ", style: [:font_bold]},
             %{text: "intro", style: [{:text_color, :yellow}]}
           ]

    assert {:col_span, 3} in rich_intro.style
    assert {:row_span, 2} in rich_intro.style

    assert button.kind == :button
    assert button.id == "save_button"
    assert button.label == "Save"
    assert :col_span_full in button.style
    assert button.focus_visible_style == [{:border_color, :yellow}, {:shadow, :lg}]
    assert button.events == %{click: "save"}

    assert checkbox.kind == :checkbox
    assert checkbox.id == "tos_checkbox"
    assert checkbox.label == "Accept terms"
    assert checkbox.checked == true
    assert checkbox.events == %{change: "toggle_tos"}

    assert radio.kind == :radio
    assert radio.id == "priority_high"
    assert radio.label == "High priority"
    assert radio.value == "high"
    assert radio.checked == true
    assert radio.events == %{change: "priority_changed"}

    assert icon.kind == :icon
    assert icon.id == "release_icon"
    assert icon.source == {:embedded, "icons/release.svg"}
    assert {:width, {:px, 24}} in icon.style
    assert {:height, {:px, 24}} in icon.style

    assert image.kind == :image
    assert image.id == "hero_image"
    assert image.source == {:uri, "https://example.com/demo.png"}
    assert image.object_fit == :cover
    assert image.grayscale == true
    assert {:width, {:px, 240}} in image.style
    assert {:height, {:px, 120}} in image.style

    assert scroll.kind == :scroll
    assert scroll.id == "items"
    assert scroll.axis == :y
    assert length(scroll.children) == 2

    assert Enum.map(scroll.children, & &1.id) == ["item_1", "item_2"]

    assert uniform_list.kind == :uniform_list
    assert uniform_list.id == "virtual_items"
    assert Enum.map(uniform_list.items, & &1.id) == ["uniform_1", "uniform_2"]
    assert {:height, {:px, 120}} in uniform_list.style
    assert {:padding, :all, {:rem, 0.5}} in uniform_list.item_style
    assert uniform_list.events == %{click: "uniform_item_clicked"}

    assert list.kind == :list
    assert list.id == "generic_items"
    assert Enum.map(list.items, & &1.id) == ["generic_1", "generic_2"]
    assert {:height, {:px, 140}} in list.style
    assert {:padding, :all, {:rem, 0.5}} in list.item_style
    assert list.events == %{click: "generic_item_clicked"}

    assert data_table.kind == :data_table
    assert data_table.id == "task_table"
    assert Enum.map(data_table.columns, & &1.id) == ["task", "status"]
    assert Enum.map(data_table.rows, & &1.id) == ["row_1"]
    assert data_table.selected_row_id == "row_1"
    assert data_table.selected_cell == {"row_1", "status"}
    assert data_table.sort == %{column_id: "task", direction: :asc}

    assert data_table.events == %{
             row_click: "table_row_clicked",
             cell_click: "table_cell_clicked",
             sort: "table_sorted"
           }

    assert tree.kind == :tree
    assert tree.id == "task_tree"
    assert Enum.map(tree.nodes, & &1.id) == ["tree_root"]
    assert tree.selected_id == "tree_child"
    assert tree.events == %{select: "tree_selected", toggle: "tree_toggled"}

    assert canvas.kind == :canvas
    assert canvas.id == "summary_canvas"
    assert length(canvas.commands) == 2
    assert canvas.events == %{click: "canvas_clicked"}
    assert {:width, {:px, 120}} in canvas.style
    assert {:height, {:px, 80}} in canvas.style

    assert popover.kind == :popover
    assert popover.id == "help_popover"
    assert popover.label == "Help"
    assert popover.open == true
    assert popover.events == %{click: "open_help", close: "close_help"}
    assert popover.anchor == :bottom_right
    assert popover.anchor_position_mode == :local
    assert popover.anchor_fit == :snap_to_window_with_margin
    assert popover.anchor_offset == {0, 12}
    assert popover.snap_margin == 12
    assert popover.close_on_click_outside == false
    assert popover.stack_priority == 2
    assert {:padding, :all, {:rem, 1}} in popover.popover_style
    assert [%{kind: :text, content: "Popover content"}] = popover.children

    assert select.kind == :select
    assert select.id == "status_select"
    assert select.value == "todo"
    assert select.open == true
    assert select.placeholder == "Pick status"
    assert Enum.map(select.options, & &1.value) == ["todo", "done"]

    assert select.events == %{
             click: "toggle_status",
             change: "status_changed",
             close: "close_status"
           }

    assert {:width, {:px, 240}} in select.style
    assert {:padding, :all, {:rem, 0.25}} in select.list_style
    assert {:padding, :all, {:rem, 0.5}} in select.option_style

    assert text_input.kind == :text_input
    assert text_input.id == "name_input"
    assert text_input.value == "Jason"
    assert text_input.placeholder == "Type here"

    assert text_input.events == %{
             change: "name_changed",
             focus: "name_focused",
             blur: "name_blurred"
           }

    assert textarea.kind == :textarea
    assert textarea.id == "notes_input"
    assert textarea.value == "Line one\nLine two"
    assert textarea.placeholder == "Notes"

    assert textarea.events == %{
             change: "notes_changed",
             focus: "notes_focused",
             blur: "notes_blurred"
           }

    assert {:height, {:px, 120}} in textarea.style

    assert footer == %{kind: :text, content: "Footer ready", id: "footer"}
  end

  test "Guppy.Component resolves @assigns from a Guppy.Window render context" do
    ir =
      Guppy.WindowAssignsTemplateExample.render(%Guppy.Window{assigns: %{title: "Window title"}})

    assert :ok = Guppy.IR.validate(ir)
    assert [%{kind: :text, content: "Window title", id: "window_assigns_title"}] = ir.children
  end

  test "Guppy.Component keeps equals signs in text expressions out of attribute preprocessing" do
    ir = Guppy.TemplateTextExpressionExample.render(%{count: 7, x: 3})

    assert :ok = Guppy.IR.validate(ir)

    assert [equals_spaced, equals_tight] = ir.children
    assert equals_spaced.content == "count = 7"
    assert equals_tight.content == "x=3"
  end

  test "Guppy.Component supports local and remote function components with props and children" do
    ir =
      Guppy.FunctionComponentExample.render(%{
        items: [
          %{id: 1, title: "Open", value: "12"},
          %{id: 2, title: "Blocked", value: "3"}
        ]
      })

    assert :ok = Guppy.IR.validate(ir)
    assert ir.id == "component_root"

    [first_stat, second_stat, panel, badge] = ir.children

    assert first_stat.id == "stat_1"
    [first_title_wrapper, first_value] = first_stat.children
    assert first_title_wrapper.kind == :div
    assert first_title_wrapper.children == [%{kind: :text, id: "stat_1_title", content: "Open"}]
    assert first_value == %{kind: :text, id: "stat_1_value", content: "12"}

    assert second_stat.id == "stat_2"
    [second_title_wrapper, second_value] = second_stat.children

    assert second_title_wrapper.children == [
             %{kind: :text, id: "stat_2_title", content: "Blocked"}
           ]

    assert second_value == %{kind: :text, id: "stat_2_value", content: "3"}

    assert panel.id == "activity_panel"
    assert panel.children == [%{kind: :text, id: "activity_text", content: "Inner activity feed"}]

    assert badge.id == "release_badge"
    assert badge.children == [%{kind: :text, id: "release_badge_label", content: "Beta ready"}]
  end

  test "Guppy.Component rejects bare local function component tags" do
    source = """
    defmodule Guppy.BareLocalComponentExample do
      use Guppy.Component

      def render(assigns) do
        ~GUI\"\"\"
        <div>
          <stat_card />
        </div>
        \"\"\"
      end

      defp stat_card(assigns), do: Guppy.IR.text(assigns[:label] || "bad")
    end
    """

    assert_raise CompileError, ~r/use <\.stat_card> for local function components/, fn ->
      Code.compile_string(source)
    end
  end

  test "Guppy.Component rejects unsupported button event attributes" do
    source = """
    defmodule Guppy.BadButtonEventTemplate do
      use Guppy.Component

      def render(assigns) do
        ~GUI\"\"\"
        <button drag_start=\"start_drag\">Save</button>
        \"\"\"
      end
    end
    """

    assert_raise CompileError, ~r/unsupported attribute \"drag_start\" on <button>/, fn ->
      Code.compile_string(source)
    end
  end

  test "Guppy.Component prop declarations apply defaults and validate required and typed props" do
    assigns =
      Guppy.Component.validate_props!(Guppy.ComponentPropsExample, :render, %{
        title: "Release board"
      })

    ir = Guppy.ComponentPropsExample.render(assigns)

    assert :ok = Guppy.IR.validate(ir)
    assert ir.id == "props_root"
    assert Enum.map(ir.children, & &1.content) == ["Release board", "info"]

    tag_ir = Guppy.ComponentPropsTagCaller.render(%{title: "Roadmap"})
    assert :ok = Guppy.IR.validate(tag_ir)
    assert Enum.map(tag_ir.children, & &1.content) == ["Roadmap", "info"]

    assert_raise ArgumentError, ~r/missing required props/, fn ->
      Guppy.Component.validate_props!(Guppy.ComponentPropsExample, :render, %{})
    end

    assert_raise ArgumentError, ~r/unknown props/, fn ->
      Guppy.Component.validate_props!(Guppy.ComponentPropsExample, :render, %{
        title: "Release board",
        extra: true
      })
    end

    assert_raise ArgumentError, ~r/invalid value for prop :tone/, fn ->
      Guppy.Component.validate_props!(Guppy.ComponentPropsExample, :render, %{
        title: "Release board",
        tone: :bad
      })
    end
  end
end
