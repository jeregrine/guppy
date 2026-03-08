defmodule Guppy.Component do
  @moduledoc """
  Compile-time Guppy template support.

  `use Guppy.Component` imports the `~G` sigil, which compiles a restricted,
  HEEx-style template syntax directly to Guppy IR.

  The current template vocabulary intentionally matches Guppy's real IR surface:

  - `<div>`
  - `<text>`
  - `<button>`
  - `<scroll>`
  - `<text_input />`

  Expressions use `{...}` syntax. Assign lookups use `@name`, which expects an
  `assigns` variable to be available in scope, similar to HEEx.
  """

  defmacro __using__(_opts) do
    quote do
      import Guppy.Component, only: [sigil_G: 2]
    end
  end

  defmacro sigil_G({:<<>>, _meta, [template]}, _modifiers) when is_binary(template) do
    Guppy.Component.Compiler.compile!(template, __CALLER__)
  end

  def fetch_assign!(assigns, key) when is_map(assigns) and is_atom(key) do
    Map.fetch!(assigns, key)
  end

  def maybe_entry(_key, nil), do: nil
  def maybe_entry(key, value), do: {key, value}

  def build_keyword(entries) do
    entries
    |> Enum.reject(&is_nil/1)
  end

  def build_events(entries) do
    case Enum.reject(entries, &is_nil/1) do
      [] -> nil
      pairs -> Map.new(pairs)
    end
  end

  def merge_styles(class_value, style_value) do
    merged = normalize_style_value(class_value) ++ normalize_style_value(style_value)
    if merged == [], do: nil, else: merged
  end

  def flatten_children(children) do
    children
    |> List.flatten()
    |> Enum.flat_map(&normalize_child/1)
  end

  def dynamic_child(value), do: normalize_child(value)

  def normalize_child(nil), do: []
  def normalize_child(false), do: []
  def normalize_child(children) when is_list(children), do: flatten_children(children)
  def normalize_child(%{} = node), do: [node]
  def normalize_child(value), do: [Guppy.IR.text(to_text(value))]

  def to_text(nil), do: ""
  def to_text(false), do: ""
  def to_text(value) when is_binary(value), do: value
  def to_text(value), do: to_string(value)

  def class_to_style!(nil), do: []

  def class_to_style!(value) when is_list(value) do
    value
    |> Enum.flat_map(fn
      nil ->
        []

      false ->
        []

      item when is_binary(item) ->
        class_to_style!(item)

      other ->
        raise ArgumentError, "expected class list entries to be strings, got: #{inspect(other)}"
    end)
  end

  def class_to_style!(value) when is_binary(value) do
    value
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&class_token_to_style!/1)
  end

  def class_to_style!(other) do
    raise ArgumentError,
          "expected class to be a string or list of strings, got: #{inspect(other)}"
  end

  defp normalize_style_value(nil), do: []
  defp normalize_style_value(false), do: []
  defp normalize_style_value(value) when is_binary(value), do: class_to_style!(value)
  defp normalize_style_value(value) when is_list(value), do: value

  defp normalize_style_value(other),
    do:
      raise(
        ArgumentError,
        "expected style to be nil, string, or style list, got: #{inspect(other)}"
      )

  defp class_token_to_style!(token) do
    cond do
      color_style = parse_named_color_style(token) ->
        color_style

      hex_style = parse_hex_color_style(token) ->
        hex_style

      size_style = parse_size_style(token) ->
        size_style

      opacity_style = parse_opacity_style(token) ->
        opacity_style

      flag_style = parse_flag_style(token) ->
        flag_style

      true ->
        raise ArgumentError, "unsupported Guppy class token: #{inspect(token)}"
    end
  end

  defp parse_named_color_style(token) do
    with [prefix, color] <- String.split(token, "-", parts: 2),
         {:ok, key} <- color_key(prefix),
         {:ok, color_atom} <- named_color(color) do
      {key, color_atom}
    else
      _ -> nil
    end
  end

  defp parse_hex_color_style(token) do
    case Regex.run(~r/^(bg|text|border)-\[(#[0-9A-Fa-f]{6})\]$/, token, capture: :all_but_first) do
      ["bg", hex] -> {:bg_hex, hex}
      ["text", hex] -> {:text_color_hex, hex}
      ["border", hex] -> {:border_color_hex, hex}
      _ -> nil
    end
  end

  defp parse_size_style(token) do
    case Regex.run(~r/^(w|h|scrollbar-w)-\[([0-9]+(?:\.[0-9]+)?)(px|rem)\]$/, token,
           capture: :all_but_first
         ) do
      ["w", number, "px"] -> {:w_px, parse_number!(number)}
      ["w", number, "rem"] -> {:w_rem, parse_number!(number)}
      ["h", number, "px"] -> {:h_px, parse_number!(number)}
      ["h", number, "rem"] -> {:h_rem, parse_number!(number)}
      ["scrollbar-w", number, "px"] -> {:scrollbar_width_px, parse_number!(number)}
      ["scrollbar-w", number, "rem"] -> {:scrollbar_width_rem, parse_number!(number)}
      _ -> nil
    end
  end

  defp parse_opacity_style(token) do
    case Regex.run(~r/^opacity-\[([0-9]+(?:\.[0-9]+)?)\]$/, token, capture: :all_but_first) do
      [number] -> {:opacity, parse_number!(number)}
      _ -> nil
    end
  end

  defp parse_flag_style(token) do
    atom_name = token |> String.replace("-", "_")

    try do
      atom = String.to_existing_atom(atom_name)

      case Guppy.IR.validate(Guppy.IR.div([], style: [atom])) do
        :ok -> atom
        _ -> nil
      end
    rescue
      ArgumentError -> nil
    end
  end

  defp color_key("bg"), do: {:ok, :bg}
  defp color_key("text"), do: {:ok, :text_color}
  defp color_key("border"), do: {:ok, :border_color}
  defp color_key(_), do: :error

  defp named_color("red"), do: {:ok, :red}
  defp named_color("green"), do: {:ok, :green}
  defp named_color("blue"), do: {:ok, :blue}
  defp named_color("yellow"), do: {:ok, :yellow}
  defp named_color("black"), do: {:ok, :black}
  defp named_color("white"), do: {:ok, :white}
  defp named_color("gray"), do: {:ok, :gray}
  defp named_color(_), do: :error

  defp parse_number!(number) do
    case Float.parse(number) do
      {value, ""} when value == trunc(value) -> trunc(value)
      {value, ""} -> value
    end
  end
end
