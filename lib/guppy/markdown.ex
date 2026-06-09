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
  prop(:render, :selected_heading_id, :string)
  prop(:render, :scroll_target_id, :string)
  prop(:render, :heading_id_prefix, :string)

  @heading_tags [:h1, :h2, :h3, :h4, :h5, :h6]

  @doc """
  Renders Markdown source to a Guppy IR tree.
  """
  def render(%{source: source} = assigns) do
    opts =
      []
      |> maybe_put(:id, Map.get(assigns, :id))
      |> Keyword.put(:style, Map.get(assigns, :style, [:flex, :flex_col, :gap_2]))

    heading_id_prefix =
      Map.get(assigns, :heading_id_prefix) || Map.get(assigns, :id) || "markdown_heading"

    scroll_target_id =
      Map.get(assigns, :scroll_target_id) || Map.get(assigns, :selected_heading_id)

    Guppy.IR.div(
      parse_blocks(source, scroll_target_id, heading_id_prefix),
      opts
    )
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_blocks(source, selected_heading_id, heading_id_prefix) do
    {nodes, _heading_index} =
      source
      |> :shell_docs_markdown.parse_md()
      |> blocks_to_nodes(0, selected_heading_id, heading_id_prefix)

    nodes
  end

  defp blocks_to_nodes(blocks, heading_index, selected_heading_id, heading_id_prefix) do
    {nested_nodes, next_heading_index} =
      Enum.map_reduce(blocks, heading_index, fn block, index ->
        block_to_nodes(block, index, selected_heading_id, heading_id_prefix)
      end)

    {List.flatten(nested_nodes), next_heading_index}
  end

  defp block_to_nodes(
         {tag, _attrs, children},
         heading_index,
         selected_heading_id,
         heading_id_prefix
       )
       when tag in @heading_tags do
    next_heading_index = heading_index + 1
    heading_id = "#{heading_id_prefix}_#{next_heading_index}"

    nodes =
      Enum.concat(
        heading_anchor(heading_id, selected_heading_id),
        [inline_text(children, heading_style(tag))]
      )

    {nodes, next_heading_index}
  end

  defp block_to_nodes({:p, _attrs, children}, heading_index, _selected_heading_id, _prefix),
    do: {[inline_text(children, [:text_base])], heading_index}

  defp block_to_nodes({:ul, _attrs, items}, heading_index, _selected_heading_id, _prefix),
    do: {[list_block(items, :unordered)], heading_index}

  defp block_to_nodes({:ol, _attrs, items}, heading_index, _selected_heading_id, _prefix),
    do: {[list_block(items, :ordered)], heading_index}

  defp block_to_nodes({:pre, _attrs, children}, heading_index, _selected_heading_id, _prefix) do
    nodes = [
      inline_text(children, [
        :text_sm,
        :p_2,
        :rounded_md,
        :border_1,
        {:bg_hex, "#F2F0E5"},
        {:border_color_hex, "#DAD8CE"},
        {:text_color_hex, "#403E3C"}
      ])
    ]

    {nodes, heading_index}
  end

  defp block_to_nodes(text, heading_index, _selected_heading_id, _prefix) when is_binary(text),
    do: {[Guppy.IR.text(text)], heading_index}

  defp block_to_nodes(
         {_tag, _attrs, children},
         heading_index,
         selected_heading_id,
         heading_id_prefix
       )
       when is_list(children),
       do: blocks_to_nodes(children, heading_index, selected_heading_id, heading_id_prefix)

  defp block_to_nodes(_other, heading_index, _selected_heading_id, _prefix),
    do: {[], heading_index}

  defp block_to_nodes(block),
    do: block |> block_to_nodes(0, nil, "markdown_heading") |> elem(0)

  defp heading_anchor(heading_id, selected_heading_id) do
    [
      Guppy.IR.div([],
        id: "#{heading_id}_anchor",
        style: [:w_full, {:h_px, 1}],
        anchor_scroll: true,
        scroll_to: heading_id == selected_heading_id
      )
    ]
  end

  defp heading_style(:h1), do: [:text_2xl, :font_bold]
  defp heading_style(:h2), do: [:text_xl, :font_bold]
  defp heading_style(:h3), do: [:text_lg, :font_bold]
  defp heading_style(:h4), do: [:text_base, :font_bold]
  defp heading_style(:h5), do: [:text_sm, :font_bold]
  defp heading_style(:h6), do: [:text_xs, :font_bold]

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

  defp inline_style(:code, _attrs),
    do: [{:bg_hex, "#F2F0E5"}, {:text_color_hex, "#403E3C"}, :font_semibold]

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
