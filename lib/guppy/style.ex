defmodule Guppy.Style do
  @moduledoc """
  Catalog-backed style helpers for canonical Guppy style tuple IR.

  `Guppy.Style` is generated from `data/gpui_style_catalog.json` at compile time.
  Helpers return primitive tuple ops that can be placed directly in IR style lists.
  """

  @catalog_path Path.expand("../../data/gpui_style_catalog.json", __DIR__)
  @external_resource @catalog_path
  @catalog @catalog_path |> File.read!() |> JSON.decode!()

  @axis_operations Enum.filter(@catalog["operations"], fn operation ->
                     operation["name"] in ["padding", "margin", "gap", "inset"]
                   end)

  @enum_operations Enum.filter(@catalog["operations"], fn operation ->
                     operation["name"] in ["position"]
                   end)

  @length_operations Enum.filter(@catalog["operations"], fn operation ->
                       operation["name"] in [
                         "width",
                         "height",
                         "size",
                         "min_width",
                         "min_height",
                         "max_width",
                         "max_height"
                       ]
                     end)

  @style_operations @axis_operations ++ @length_operations

  @position_operation Enum.find(@enum_operations, &(&1["name"] == "position"))
  @position_values @position_operation["values"] |> Enum.map(&String.to_atom/1)
  @position_class_tokens Map.new(@position_operation["class_tokens"], fn {token, value} ->
                           {token, String.to_atom(value)}
                         end)

  @operation_config Map.new(@style_operations, fn operation ->
                      length = operation["length"]

                      axes =
                        case operation["axes"] do
                          nil -> nil
                          axes -> axes |> Map.keys() |> Enum.map(&String.to_atom/1)
                        end

                      {String.to_atom(operation["name"]),
                       %{
                         axes: axes,
                         allow_auto: length["auto"],
                         allow_negative: length["negative"]
                       }}
                    end)

  @scale_helpers Enum.flat_map(@style_operations, fn operation ->
                   config = Map.fetch!(@operation_config, String.to_atom(operation["name"]))

                   operation["helpers"]
                   |> Enum.filter(&(&1["kind"] == "scale"))
                   |> Enum.reject(fn helper ->
                     is_nil(config.axes) and helper["name"] == operation["name"]
                   end)
                   |> Enum.map(fn helper ->
                     %{
                       operation: String.to_atom(operation["name"]),
                       function: String.to_atom(helper["name"]),
                       axis: helper["axis"] && String.to_atom(helper["axis"]),
                       allow_auto: config.allow_auto,
                       allow_negative: config.allow_negative
                     }
                   end)
                 end)

  @class_prefix_specs @style_operations
                      |> Enum.flat_map(fn operation ->
                        config = Map.fetch!(@operation_config, String.to_atom(operation["name"]))

                        Enum.map(operation["class_prefixes"], fn {prefix, axis} ->
                          %{
                            prefix: prefix,
                            operation: String.to_atom(operation["name"]),
                            axis: axis && String.to_atom(axis),
                            allow_auto: config.allow_auto,
                            allow_negative: config.allow_negative
                          }
                        end)
                      end)
                      |> Enum.sort_by(fn spec -> -String.length(spec.prefix) end)

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

  @doc "Returns a canonical position tuple."
  def position(value) when value in @position_values, do: {:position, value}

  def position(value), do: raise(ArgumentError, "invalid position value: #{inspect(value)}")

  for value <- @position_values do
    @doc "Returns canonical #{value} position style."
    def unquote(value)(), do: {:position, unquote(value)}
  end

  for {operation, config} <- @operation_config, is_list(config.axes) do
    axes = config.axes
    allow_auto = config.allow_auto
    allow_negative = config.allow_negative

    @doc "Returns a canonical #{operation} tuple for a concrete axis and length."
    def unquote(operation)(axis, length) when axis in unquote(axes) do
      {unquote(operation), axis,
       normalize_length!(length, unquote(allow_auto), unquote(allow_negative))}
    end

    def unquote(operation)(axis, _length) do
      raise ArgumentError, "invalid #{unquote(operation)} axis: #{inspect(axis)}"
    end
  end

  for {operation, config} <- @operation_config, is_nil(config.axes) do
    allow_auto = config.allow_auto
    allow_negative = config.allow_negative

    @doc "Returns a canonical #{operation} tuple for a concrete length."
    def unquote(operation)(length) do
      {unquote(operation),
       normalize_length_or_scale!(length, unquote(allow_auto), unquote(allow_negative))}
    end
  end

  for helper <- @scale_helpers do
    @doc "Returns a canonical #{helper.function} #{helper.operation} tuple for a GPUI/Tailwind spacing scale token."
    def unquote(helper.function)(scale) do
      length =
        spacing_scale_length!(
          scale,
          unquote(helper.allow_auto),
          unquote(helper.allow_negative)
        )

      style_tuple(unquote(helper.operation), unquote(helper.axis), length)
    end
  end

  @doc false
  def class_token_to_style(token) when is_binary(token) do
    case parse_position_class(token) do
      {:ok, style} -> {:ok, style}
      :error -> parse_box_class(token)
    end
  end

  def class_token_to_style(_token), do: :error

  defp parse_position_class(token) do
    case Map.fetch(@position_class_tokens, token) do
      {:ok, value} -> {:ok, {:position, value}}
      :error -> :error
    end
  end

  defp parse_box_class(token) do
    {negated, token} = split_negative_class_token(token)

    Enum.find_value(@class_prefix_specs, :error, fn spec ->
      cond do
        String.starts_with?(token, spec.prefix <> "-[") and String.ends_with?(token, "]") ->
          token
          |> String.slice((String.length(spec.prefix) + 2)..-2//1)
          |> arbitrary_length_to_style(spec, negated)

        String.starts_with?(token, spec.prefix <> "-") ->
          token
          |> String.replace_prefix(spec.prefix <> "-", "")
          |> scale_token_to_style(spec, negated)

        true ->
          false
      end
    end)
  end

  defp split_negative_class_token("-" <> token), do: {true, token}
  defp split_negative_class_token(token), do: {false, token}

  defp scale_token_to_style(scale_token, spec, negated) do
    case spacing_scale_length(scale_token, spec.allow_auto, spec.allow_negative) do
      {:ok, length} -> class_style_tuple(spec, maybe_negate_length!(length, negated, spec))
      :error -> false
    end
  end

  defp arbitrary_length_to_style(payload, spec, negated) do
    case parse_arbitrary_length(payload, spec.allow_auto, spec.allow_negative) do
      {:ok, length} -> class_style_tuple(spec, maybe_negate_length!(length, negated, spec))
      :error -> false
    end
  end

  defp class_style_tuple(spec, length), do: {:ok, style_tuple(spec.operation, spec.axis, length)}

  defp style_tuple(operation, nil, length), do: {operation, length}
  defp style_tuple(operation, axis, length), do: {operation, axis, length}

  defp spacing_scale_length!(scale, allow_auto, allow_negative) do
    case spacing_scale_length(scale, allow_auto, allow_negative) do
      {:ok, length} -> length
      :error -> raise ArgumentError, "unknown GPUI spacing scale token: #{inspect(scale)}"
    end
  end

  defp spacing_scale_length(scale, allow_auto, allow_negative) do
    {key, negated} = spacing_scale_key_and_sign(scale)

    cond do
      key == "auto" and allow_auto and not negated ->
        {:ok, :auto}

      key == "auto" ->
        :error

      true ->
        case Map.fetch(@spacing_lengths, key) do
          {:ok, length} -> {:ok, maybe_negate_length!(length, negated, allow_negative)}
          :error -> :error
        end
    end
  end

  defp spacing_scale_key_and_sign(value) when is_integer(value) do
    {Integer.to_string(abs(value)), value < 0}
  end

  defp spacing_scale_key_and_sign(value) when is_float(value) do
    key =
      value
      |> abs()
      |> then(fn value ->
        if value == trunc(value) do
          value |> trunc() |> Integer.to_string()
        else
          :erlang.float_to_binary(value, [:compact, decimals: 10])
        end
      end)

    {key, value < 0}
  end

  defp spacing_scale_key_and_sign(value) when is_binary(value) do
    case value do
      "-" <> key -> {key, true}
      key -> {key, false}
    end
  end

  defp spacing_scale_key_and_sign(:auto), do: {"auto", false}

  defp spacing_scale_key_and_sign(value) do
    raise ArgumentError, "invalid GPUI spacing scale token: #{inspect(value)}"
  end

  defp normalize_length_or_scale!({unit, _value} = length, allow_auto, allow_negative)
       when unit in [:px, :rem, :fraction],
       do: normalize_length!(length, allow_auto, allow_negative)

  defp normalize_length_or_scale!(:auto, allow_auto, allow_negative),
    do: normalize_length!(:auto, allow_auto, allow_negative)

  defp normalize_length_or_scale!(scale, allow_auto, allow_negative),
    do: spacing_scale_length!(scale, allow_auto, allow_negative)

  defp normalize_length!(:auto, true, _allow_negative), do: :auto

  defp normalize_length!({unit, value}, _allow_auto, allow_negative)
       when unit in [:px, :rem, :fraction] and is_number(value) do
    if allow_negative or value >= 0 do
      {unit, value}
    else
      raise ArgumentError, "invalid non-negative style length: #{inspect({unit, value})}"
    end
  end

  defp normalize_length!(other, allow_auto, _allow_negative) do
    auto_message = if allow_auto, do: ", :auto", else: ""

    raise ArgumentError,
          "invalid style length #{inspect(other)}; expected {:px, n}, {:rem, n}, {:fraction, n}#{auto_message}"
  end

  defp parse_arbitrary_length("auto", true, _allow_negative), do: {:ok, :auto}
  defp parse_arbitrary_length("auto", false, _allow_negative), do: :error

  defp parse_arbitrary_length(payload, _allow_auto, allow_negative) do
    case Regex.run(~r/^(-?[0-9]+(?:\.[0-9]+)?)(px|rem|%)$/, payload, capture: :all_but_first) do
      [number, "px"] ->
        validate_arbitrary_length({:px, parse_number!(number)}, allow_negative)

      [number, "rem"] ->
        validate_arbitrary_length({:rem, parse_number!(number)}, allow_negative)

      [number, "%"] ->
        validate_arbitrary_length({:fraction, parse_number!(number) / 100}, allow_negative)

      _ ->
        :error
    end
  end

  defp validate_arbitrary_length({unit, value} = length, allow_negative)
       when unit in [:px, :rem, :fraction] do
    if allow_negative or value >= 0, do: {:ok, length}, else: :error
  end

  defp maybe_negate_length!(length, false, _spec_or_allow_negative), do: length

  defp maybe_negate_length!(:auto, true, _spec_or_allow_negative) do
    raise ArgumentError, "cannot negate auto style length"
  end

  defp maybe_negate_length!({unit, value}, true, %{allow_negative: true}), do: {unit, -value}
  defp maybe_negate_length!({unit, value}, true, true), do: {unit, -value}

  defp maybe_negate_length!(length, true, _spec_or_allow_negative) do
    raise ArgumentError, "style length does not support negative values: #{inspect(length)}"
  end

  defp parse_number!(number) do
    case Float.parse(number) do
      {value, ""} when value == trunc(value) -> trunc(value)
      {value, ""} -> value
      _ -> raise ArgumentError, "invalid numeric style value: #{inspect(number)}"
    end
  end
end
