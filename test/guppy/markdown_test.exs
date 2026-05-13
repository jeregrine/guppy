defmodule Guppy.MarkdownTest do
  use ExUnit.Case

  test "renders a small markdown subset to Guppy IR" do
    ir =
      Guppy.Markdown.render(%{
        id: "doc",
        source: "# Title\n\nHello **bold** and `code`\n\n- One\n- *Two*"
      })

    assert :ok = Guppy.IR.validate(ir)
    assert ir.kind == :div
    assert ir.id == "doc"

    [heading, paragraph, list] = ir.children

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
             %{text: "code", style: [{:bg, :gray}, :font_semibold]}
           ]

    assert list.kind == :div
    assert length(list.children) == 2
    [first_item, second_item] = list.children
    assert Enum.at(first_item.children, 1).content == "One"
    assert Enum.at(second_item.children, 1).runs == [%{text: "Two", style: [:italic]}]
  end
end
