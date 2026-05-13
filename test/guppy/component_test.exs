defmodule Guppy.ComponentTest do
  use ExUnit.Case

  test "Guppy.Component compiles ~G templates into valid IR" do
    ir =
      Guppy.TemplateExample.render(%{
        title: "Template demo",
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
    assert :flex in ir.style
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
      popover,
      select,
      text_input,
      textarea,
      footer
    ] =
      ir.children

    assert title_wrapper.kind == :div
    assert title_wrapper.children == [%{kind: :text, content: "Template demo", id: "title"}]
    assert :text_3xl in title_wrapper.style
    assert :font_black in title_wrapper.style

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
    assert button.focus_visible_style == [{:border_color, :yellow}, :shadow_lg]
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
    assert {:w_px, 24} in icon.style
    assert {:h_px, 24} in icon.style

    assert image.kind == :image
    assert image.id == "hero_image"
    assert image.source == {:uri, "https://example.com/demo.png"}
    assert image.object_fit == :cover
    assert image.grayscale == true
    assert {:w_px, 240} in image.style
    assert {:h_px, 120} in image.style

    assert scroll.kind == :scroll
    assert scroll.id == "items"
    assert scroll.axis == :y
    assert length(scroll.children) == 2

    assert Enum.map(scroll.children, & &1.id) == ["item_1", "item_2"]

    assert uniform_list.kind == :uniform_list
    assert uniform_list.id == "virtual_items"
    assert Enum.map(uniform_list.items, & &1.id) == ["uniform_1", "uniform_2"]
    assert {:h_px, 120} in uniform_list.style
    assert :p_2 in uniform_list.item_style
    assert uniform_list.events == %{click: "uniform_item_clicked"}

    assert list.kind == :list
    assert list.id == "generic_items"
    assert Enum.map(list.items, & &1.id) == ["generic_1", "generic_2"]
    assert {:h_px, 140} in list.style
    assert :p_2 in list.item_style
    assert list.events == %{click: "generic_item_clicked"}

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
    assert :p_4 in popover.popover_style
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

    assert {:w_px, 240} in select.style
    assert :p_1 in select.list_style
    assert :p_2 in select.option_style

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

    assert {:h_px, 120} in textarea.style

    assert footer == %{kind: :text, content: "Footer ready", id: "footer"}
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
