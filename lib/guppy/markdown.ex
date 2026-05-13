defmodule Guppy.Markdown do
  @moduledoc """
  Small Markdown-to-Guppy component.

  GPUI 0.2.2 does not expose a standalone markdown viewer in the dependency surface Guppy
  uses, so this component parses Markdown with Erlang/OTP's `:shell_docs_markdown` and
  renders a deliberately small subset into ordinary Guppy IR. Supported today: headings,
  paragraphs, unordered/ordered lists, and inline bold/italic/code/link-ish runs.
  """

  use Guppy.Component

  prop(:render, :source, :string, required: true)
  prop(:render, :id, :string)
  prop(:render, :style, :list, default: [:flex, :flex_col, :gap_2])

  @doc """
  Renders Markdown source to a Guppy IR tree.
  """
  def render(%{source: source} = assigns) do
    opts =
      []
      |> maybe_put(:id, Map.get(assigns, :id))
      |> Keyword.put(:style, Map.get(assigns, :style, [:flex, :flex_col, :gap_2]))

    Guppy.IR.div(parse_blocks(source), opts)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_blocks(source) do
    source
    |> :shell_docs_markdown.parse_md()
    |> Enum.flat_map(&block_to_nodes/1)
  end

  defp block_to_nodes({:h1, _attrs, children}),
    do: [inline_text(children, [:text_2xl, :font_bold])]

  defp block_to_nodes({:h2, _attrs, children}),
    do: [inline_text(children, [:text_xl, :font_bold])]

  defp block_to_nodes({:h3, _attrs, children}),
    do: [inline_text(children, [:text_lg, :font_bold])]

  defp block_to_nodes({:h4, _attrs, children}),
    do: [inline_text(children, [:text_base, :font_bold])]

  defp block_to_nodes({:p, _attrs, children}), do: [inline_text(children, [:text_base])]
  defp block_to_nodes({:ul, _attrs, items}), do: [list_block(items, :unordered)]
  defp block_to_nodes({:ol, _attrs, items}), do: [list_block(items, :ordered)]
  defp block_to_nodes({:pre, _attrs, children}), do: [inline_text(children, [{:bg, :gray}, :p_2])]
  defp block_to_nodes(text) when is_binary(text), do: [Guppy.IR.text(text)]

  defp block_to_nodes({_tag, _attrs, children}) when is_list(children),
    do: Enum.flat_map(children, &block_to_nodes/1)

  defp block_to_nodes(_other), do: []

  defp list_block(items, kind) do
    rows =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} -> list_item_row(item, list_marker(kind, index)) end)

    Guppy.IR.div(rows, style: [:flex, :flex_col, :gap_1])
  end

  defp list_marker(:unordered, _index), do: "•"
  defp list_marker(:ordered, index), do: "#{index}."

  defp list_item_row({:li, _attrs, children}, marker) do
    {inline_children, block_children} = split_leading_inline(children)

    content =
      case inline_children do
        [] ->
          Enum.flat_map(block_children, &block_to_nodes/1)

        inline ->
          [inline_text(inline, [:text_base]) | Enum.flat_map(block_children, &block_to_nodes/1)]
      end

    Guppy.IR.div(
      [Guppy.IR.text(marker, style: [:font_bold]) | content],
      style: [:flex, :flex_row, :gap_2]
    )
  end

  defp list_item_row(other, marker) do
    Guppy.IR.div(
      [Guppy.IR.text(marker, style: [:font_bold]) | block_to_nodes(other)],
      style: [:flex, :flex_row, :gap_2]
    )
  end

  defp split_leading_inline([{:p, _attrs, inline_children} | rest]), do: {inline_children, rest}
  defp split_leading_inline(children), do: {[], children}

  defp inline_text(children, style) do
    Guppy.IR.rich_text(inline_runs(children), style: style)
  end

  defp inline_runs(children) when is_list(children) do
    children
    |> Enum.flat_map(&inline_runs(&1, []))
    |> merge_plain_runs([])
  end

  defp inline_runs(child), do: inline_runs([child])

  defp inline_runs(text, style) when is_binary(text), do: [text_run(text, style)]

  defp inline_runs({tag, attrs, children}, style) when is_list(children) do
    child_style = style ++ inline_style(tag, attrs)
    Enum.flat_map(children, &inline_runs(&1, child_style))
  end

  defp inline_runs(_other, _style), do: []

  defp inline_style(tag, _attrs) when tag in [:em, :strong, :b], do: [:font_bold]
  defp inline_style(tag, _attrs) when tag in [:i], do: [:italic]
  defp inline_style(:code, _attrs), do: [{:bg, :gray}, :font_semibold]
  defp inline_style(:a, _attrs), do: [:underline, {:text_color, :blue}]
  defp inline_style(_tag, _attrs), do: []

  defp text_run(text, []), do: %{text: text}
  defp text_run(text, style), do: %{text: text, style: style}

  defp merge_plain_runs([], acc), do: Enum.reverse(acc)

  defp merge_plain_runs([%{text: text} = run | rest], [%{text: previous} = previous_run | acc])
       when map_size(run) == 1 and map_size(previous_run) == 1 do
    merge_plain_runs(rest, [%{text: previous <> text} | acc])
  end

  defp merge_plain_runs([run | rest], acc), do: merge_plain_runs(rest, [run | acc])
end
