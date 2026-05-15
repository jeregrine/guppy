defmodule Guppy.MarkdownTest do
  use ExUnit.Case

  test "renders a small markdown subset to Guppy IR" do
    ir =
      Guppy.Markdown.render(%{
        id: "doc",
        source:
          "# Title\n\nHello **bold** and `code`\n\n```elixir\nIO.puts(:ok)\n```\n\n- One\n- *Two*"
      })

    assert :ok = Guppy.IR.validate(ir)
    assert ir.kind == :div
    assert ir.id == "doc"

    [anchor, heading, paragraph, code_block, list] = ir.children

    assert anchor.id == "doc_1_anchor"
    assert anchor.anchor_scroll == true
    assert anchor.scroll_to == false

    assert heading.kind == :text
    assert heading.content == "Title"
    assert :text_2xl in heading.style
    assert :font_bold in heading.style

    assert paragraph.kind == :text
    assert paragraph.content == "Hello bold and code"

    assert paragraph.runs == [
             %{text: "Hello "},
             %{text: "bold", style: [:font_bold]},
             %{text: " and "},
             %{
               text: "code",
               style: [{:bg_hex, "#F2F0E5"}, {:text_color_hex, "#403E3C"}, :font_semibold]
             }
           ]

    assert code_block.kind == :text
    assert code_block.content == "IO.puts(:ok)\n"
    assert {:bg_hex, "#F2F0E5"} in code_block.style
    assert {:text_color_hex, "#403E3C"} in code_block.style

    assert list.kind == :div
    assert length(list.children) == 2
    [first_item, second_item] = list.children
    assert Enum.at(first_item.children, 1).content == "One"
    assert Enum.at(second_item.children, 1).runs == [%{text: "Two", style: [:italic]}]
  end

  test "can anchor-scroll to a selected heading" do
    ir =
      Guppy.Markdown.render(%{
        id: "doc",
        source: "# First\n\n## Second",
        heading_id_prefix: "heading",
        selected_heading_id: "heading_2"
      })

    assert :ok = Guppy.IR.validate(ir)

    [first_anchor, first, second_anchor, second] = ir.children
    assert first_anchor.id == "heading_1_anchor"
    assert first_anchor.anchor_scroll == true
    assert first_anchor.scroll_to == false
    assert first.content == "First"
    assert second_anchor.id == "heading_2_anchor"
    assert second_anchor.anchor_scroll == true
    assert second_anchor.scroll_to == true
    assert second.content == "Second"
  end
end
