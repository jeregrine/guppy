defmodule Guppy.Markdown do
  @moduledoc """
  Small Markdown-to-Guppy component.

  GPUI 0.2.2 does not expose a standalone markdown viewer in the dependency surface Guppy
  uses, so this component renders a deliberately small Markdown subset into ordinary Guppy IR.
  Supported today: headings, paragraphs, unordered lists, and inline `**bold**`, `*italic*`,
  and `` `code` `` runs.
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
    |> String.split("\n")
    |> parse_lines([])
    |> Enum.reverse()
  end

  defp parse_lines([], acc), do: acc

  defp parse_lines([line | rest], acc) do
    cond do
      blank?(line) ->
        parse_lines(rest, acc)

      heading = parse_heading(line) ->
        parse_lines(rest, [heading | acc])

      list_item?(line) ->
        {items, remaining} = Enum.split_while([line | rest], &list_item?/1)
        parse_lines(remaining, [render_list(items) | acc])

      true ->
        {paragraph_lines, remaining} =
          Enum.split_while([line | rest], fn candidate ->
            not blank?(candidate) and is_nil(parse_heading(candidate)) and
              not list_item?(candidate)
          end)

        text = Enum.map_join(paragraph_lines, " ", &String.trim/1)
        parse_lines(remaining, [rich_text(text, [:text_base]) | acc])
    end
  end

  defp blank?(line), do: String.trim(line) == ""

  defp parse_heading(line) do
    cond do
      String.starts_with?(line, "### ") ->
        rich_text(String.trim_leading(line, "### "), [:text_lg, :font_bold])

      String.starts_with?(line, "## ") ->
        rich_text(String.trim_leading(line, "## "), [:text_xl, :font_bold])

      String.starts_with?(line, "# ") ->
        rich_text(String.trim_leading(line, "# "), [:text_2xl, :font_bold])

      true ->
        nil
    end
  end

  defp list_item?(line), do: line |> String.trim_leading() |> String.starts_with?("- ")

  defp render_list(items) do
    children =
      Enum.map(items, fn item ->
        text = item |> String.trim_leading() |> String.trim_leading("- ")

        Guppy.IR.div(
          [
            Guppy.IR.text("•", style: [:font_bold]),
            rich_text(text, [:text_base])
          ],
          style: [:flex, :flex_row, :gap_2]
        )
      end)

    Guppy.IR.div(children, style: [:flex, :flex_col, :gap_1])
  end

  defp rich_text(text, style) do
    Guppy.IR.rich_text(inline_runs(text), style: style)
  end

  defp inline_runs(text), do: inline_runs(text, []) |> Enum.reverse() |> merge_plain_runs([])

  defp inline_runs("", acc), do: acc

  defp inline_runs("**" <> rest, acc), do: delimited_run(rest, "**", [:font_bold], acc)
  defp inline_runs("*" <> rest, acc), do: delimited_run(rest, "*", [:italic], acc)

  defp inline_runs("`" <> rest, acc),
    do: delimited_run(rest, "`", [{:bg, :gray}, :font_semibold], acc)

  defp inline_runs(text, acc) do
    {plain, rest} = take_until_marker(text)
    inline_runs(rest, [%{text: plain} | acc])
  end

  defp delimited_run(rest, delimiter, style, acc) do
    case String.split(rest, delimiter, parts: 2) do
      [content, remaining] -> inline_runs(remaining, [%{text: content, style: style} | acc])
      [_] -> inline_runs(rest, [%{text: delimiter} | acc])
    end
  end

  defp take_until_marker(text) do
    markers = ["**", "*", "`"]

    index =
      markers
      |> Enum.flat_map(fn marker ->
        case :binary.match(text, marker) do
          {index, _length} -> [index]
          :nomatch -> []
        end
      end)
      |> Enum.min(fn -> byte_size(text) end)

    <<plain::binary-size(index), rest::binary>> = text
    {plain, rest}
  end

  defp merge_plain_runs([], acc), do: Enum.reverse(acc)

  defp merge_plain_runs([%{text: text} = run | rest], [%{text: previous} = previous_run | acc])
       when map_size(run) == 1 and map_size(previous_run) == 1 do
    merge_plain_runs(rest, [%{text: previous <> text} | acc])
  end

  defp merge_plain_runs([run | rest], acc), do: merge_plain_runs(rest, [run | acc])
end
