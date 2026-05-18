defmodule Guppy.Style do
  @moduledoc """
  Catalog-backed style helpers for canonical Guppy style tuple IR.

  `Guppy.Style` is generated from `data/gpui_style_catalog.json` at compile time.
  Helpers return primitive tuple ops that can be placed directly in IR style lists.
  """

  @catalog_path Path.expand("../../data/gpui_style_catalog.json", __DIR__)
  @external_resource @catalog_path
  @catalog @catalog_path |> File.read!() |> JSON.decode!()

  @padding_operation Enum.find(@catalog["operations"], &(&1["name"] == "padding"))
  @padding_axes @padding_operation["axes"] |> Map.keys() |> Enum.map(&String.to_atom/1)
  @padding_class_prefixes @padding_operation["class_prefixes"]
                          |> Enum.map(fn {prefix, axis} -> {prefix, String.to_atom(axis)} end)
                          |> Enum.sort_by(fn {prefix, _axis} -> -String.length(prefix) end)
  @padding_scale_helpers Enum.filter(@padding_operation["helpers"], &(&1["kind"] == "scale"))

  @spacing_lengths @catalog["spacing_scale"]
                   |> Enum.flat_map(fn entry ->
                     length =
                       case entry["length"] do
                         %{"unit" => "px", "value" => value} ->
                           {:px, value}

                         %{"unit" => "rem", "value" => value} ->
                           {:rem, value}

                         %{"unit" => "fraction", "value" => value} ->
                           {:fraction, value}

                         other ->
                           raise ArgumentError, "unsupported catalog length: #{inspect(other)}"
                       end

                     tokens = [entry["token"] | Map.get(entry, "aliases", [])]
                     Enum.map(tokens, &{&1, length})
                   end)
                   |> Map.new()

  @doc "Returns the decoded style catalog used to generate this module."
  def catalog, do: @catalog

  @doc "Returns a canonical padding tuple for a concrete axis and definite length."
  def padding(axis, length) when axis in @padding_axes do
    {:padding, axis, normalize_definite_length!(length)}
  end

  def padding(axis, _length) do
    raise ArgumentError, "invalid padding axis: #{inspect(axis)}"
  end

  for %{"name" => name, "axis" => axis} <- @padding_scale_helpers do
    function = String.to_atom(name)
    axis = String.to_atom(axis)

    @doc "Returns a canonical #{name} padding tuple for a GPUI/Tailwind spacing scale token."
    def unquote(function)(scale) do
      {:padding, unquote(axis), spacing_scale_length!(scale)}
    end
  end

  @doc false
  def class_token_to_style(token) when is_binary(token) do
    parse_padding_class(token)
  end

  def class_token_to_style(_token), do: :error

  defp parse_padding_class(token) do
    Enum.find_value(@padding_class_prefixes, :error, fn {prefix, axis} ->
      cond do
        String.starts_with?(token, prefix <> "-[") and String.ends_with?(token, "]") ->
          token
          |> String.slice((String.length(prefix) + 2)..-2//1)
          |> arbitrary_length_to_padding(axis)

        String.starts_with?(token, prefix <> "-") ->
          token
          |> String.replace_prefix(prefix <> "-", "")
          |> scale_token_to_padding(axis)

        true ->
          false
      end
    end)
  end

  defp scale_token_to_padding(scale_token, axis) do
    case Map.fetch(@spacing_lengths, scale_token) do
      {:ok, length} -> {:ok, {:padding, axis, length}}
      :error -> false
    end
  end

  defp arbitrary_length_to_padding(payload, axis) do
    case parse_arbitrary_definite_length(payload) do
      {:ok, length} -> {:ok, {:padding, axis, length}}
      :error -> false
    end
  end

  defp spacing_scale_length!(scale) do
    key = spacing_scale_key(scale)

    case Map.fetch(@spacing_lengths, key) do
      {:ok, length} -> length
      :error -> raise ArgumentError, "unknown GPUI spacing scale token: #{inspect(scale)}"
    end
  end

  defp spacing_scale_key(value) when is_integer(value), do: Integer.to_string(value)

  defp spacing_scale_key(value) when is_float(value) do
    if value == trunc(value) do
      value |> trunc() |> Integer.to_string()
    else
      :erlang.float_to_binary(value, [:compact, decimals: 10])
    end
  end

  defp spacing_scale_key(value) when is_binary(value), do: value

  defp spacing_scale_key(value) do
    raise ArgumentError, "invalid GPUI spacing scale token: #{inspect(value)}"
  end

  defp normalize_definite_length!({unit, value}) when unit in [:px, :rem, :fraction] do
    if is_number(value) and value >= 0 do
      {unit, value}
    else
      raise ArgumentError, "invalid non-negative style length: #{inspect({unit, value})}"
    end
  end

  defp normalize_definite_length!(other) do
    raise ArgumentError,
          "invalid definite style length #{inspect(other)}; expected {:px, n}, {:rem, n}, or {:fraction, n}"
  end

  defp parse_arbitrary_definite_length(payload) do
    case Regex.run(~r/^([0-9]+(?:\.[0-9]+)?)(px|rem|%)$/, payload, capture: :all_but_first) do
      [number, "px"] -> {:ok, {:px, parse_number!(number)}}
      [number, "rem"] -> {:ok, {:rem, parse_number!(number)}}
      [number, "%"] -> {:ok, {:fraction, parse_number!(number) / 100}}
      _ -> :error
    end
  end

  defp parse_number!(number) do
    case Float.parse(number) do
      {value, ""} when value == trunc(value) -> trunc(value)
      {value, ""} -> value
      _ -> raise ArgumentError, "invalid numeric style value: #{inspect(number)}"
    end
  end
end
