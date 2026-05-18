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
                     operation["name"] in [
                       "padding",
                       "margin",
                       "gap",
                       "inset",
                       "border_width",
                       "border_radius"
                     ]
                   end)

  @enum_operations Enum.filter(@catalog["operations"], fn operation ->
                     operation["name"] in [
                       "position",
                       "display",
                       "visibility",
                       "cursor",
                       "border_style",
                       "bg",
                       "text_color",
                       "border_color"
                     ]
                   end)

  @overflow_operation Enum.find(@catalog["operations"], &(&1["name"] == "overflow"))

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

  @enum_config Map.new(@enum_operations, fn operation ->
                 {String.to_atom(operation["name"]),
                  %{
                    values: Enum.map(operation["values"], &String.to_atom/1),
                    class_tokens:
                      Map.new(operation["class_tokens"], fn {token, value} ->
                        {token, String.to_atom(value)}
                      end)
                  }}
               end)

  @enum_class_tokens Enum.flat_map(@enum_operations, fn operation ->
                       operation_name = String.to_atom(operation["name"])

                       Enum.map(operation["class_tokens"], fn {token, value} ->
                         {token, {operation_name, String.to_atom(value)}}
                       end)
                     end)
                     |> Map.new()

  @overflow_axes @overflow_operation["axes"] |> Map.keys() |> Enum.map(&String.to_atom/1)
  @overflow_values @overflow_operation["values"] |> Enum.map(&String.to_atom/1)
  @overflow_class_tokens Map.new(@overflow_operation["class_tokens"], fn {token, [axis, value]} ->
                           {token, {String.to_atom(axis), String.to_atom(value)}}
                         end)
  @overflow_value_helpers @overflow_operation["helpers"]
                          |> Enum.filter(&(&1["kind"] == "value"))
                          |> Enum.map(fn helper ->
                            %{
                              function: String.to_atom(helper["name"]),
                              axis: String.to_atom(helper["axis"]),
                              value: String.to_atom(helper["value"])
                            }
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
                         allow_negative: length["negative"],
                         length_units: length["allowed_units"] |> Enum.map(&String.to_atom/1)
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
                       allow_negative: config.allow_negative,
                       length_units: config.length_units
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
                            allow_negative: config.allow_negative,
                            length_units: config.length_units
                          }
                        end)
                      end)
                      |> Enum.sort_by(fn spec -> -String.length(spec.prefix) end)

  @operation_scales Map.new(@style_operations, fn operation ->
                      scale_name = Map.get(operation, "scale", "spacing_scale")
                      scale_entries = Map.fetch!(@catalog, scale_name)

                      scale_lengths =
                        scale_entries
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
                                raise ArgumentError,
                                      "unsupported catalog length: #{inspect(other)}"
                            end

                          tokens = [entry["token"] | Map.get(entry, "aliases", [])]
                          Enum.map(tokens, &{&1, length})
                        end)
                        |> Map.new()

                      {String.to_atom(operation["name"]), scale_lengths}
                    end)

  @doc "Returns the decoded style catalog used to generate this module."
  def catalog, do: @catalog

  for {operation, config} <- @enum_config do
    values = config.values

    @doc "Returns a canonical #{operation} tuple."
    def unquote(operation)(value) when value in unquote(values), do: {unquote(operation), value}

    def unquote(operation)(value),
      do: raise(ArgumentError, "invalid #{unquote(operation)} value: #{inspect(value)}")
  end

  for operation <- @enum_operations,
      %{"kind" => "value", "name" => name, "value" => value} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)
    value = String.to_atom(value)

    @doc "Returns canonical #{value} #{operation_name} style."
    def unquote(function)(), do: {unquote(operation_name), unquote(value)}
  end

  @doc "Returns a canonical overflow tuple."
  def overflow(axis, value) when axis in @overflow_axes and value in @overflow_values,
    do: {:overflow, axis, value}

  def overflow(axis, value),
    do: raise(ArgumentError, "invalid overflow axis/value: #{inspect({axis, value})}")

  for helper <- @overflow_value_helpers do
    @doc "Returns canonical #{helper.value} overflow style for #{helper.axis}."
    def unquote(helper.function)(), do: {:overflow, unquote(helper.axis), unquote(helper.value)}
  end

  for {operation, config} <- @operation_config, is_list(config.axes) do
    axes = config.axes
    allow_auto = config.allow_auto
    allow_negative = config.allow_negative

    @doc "Returns a canonical #{operation} tuple for a concrete axis and length."
    def unquote(operation)(axis, length) when axis in unquote(axes) do
      {unquote(operation), axis,
       normalize_length!(
         length,
         unquote(allow_auto),
         unquote(allow_negative),
         unquote(config.length_units)
       )}
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
       normalize_length_or_scale!(
         unquote(operation),
         length,
         unquote(allow_auto),
         unquote(allow_negative),
         unquote(config.length_units)
       )}
    end
  end

  for helper <- @scale_helpers do
    @doc "Returns a canonical #{helper.function} #{helper.operation} tuple for a GPUI/Tailwind spacing scale token."
    def unquote(helper.function)(scale) do
      length =
        spacing_scale_length!(
          unquote(helper.operation),
          scale,
          unquote(helper.allow_auto),
          unquote(helper.allow_negative),
          unquote(helper.length_units)
        )

      style_tuple(unquote(helper.operation), unquote(helper.axis), length)
    end
  end

  @doc false
  def class_token_to_style(token) when is_binary(token) do
    with :error <- parse_enum_class(token),
         :error <- parse_overflow_class(token) do
      parse_box_class(token)
    end
  end

  def class_token_to_style(_token), do: :error

  defp parse_enum_class(token) do
    case Map.fetch(@enum_class_tokens, token) do
      {:ok, {operation, value}} -> {:ok, {operation, value}}
      :error -> :error
    end
  end

  defp parse_overflow_class(token) do
    case Map.fetch(@overflow_class_tokens, token) do
      {:ok, {axis, value}} -> {:ok, {:overflow, axis, value}}
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
    case catalog_scale_length(
           spec.operation,
           scale_token,
           spec.allow_auto,
           spec.allow_negative,
           spec.length_units
         ) do
      {:ok, length} -> class_style_tuple(spec, maybe_negate_length!(length, negated, spec))
      :error -> false
    end
  end

  defp arbitrary_length_to_style(payload, spec, negated) do
    case parse_arbitrary_length(payload, spec.allow_auto, spec.allow_negative, spec.length_units) do
      {:ok, length} -> class_style_tuple(spec, maybe_negate_length!(length, negated, spec))
      :error -> false
    end
  end

  defp class_style_tuple(spec, length), do: {:ok, style_tuple(spec.operation, spec.axis, length)}

  defp style_tuple(operation, nil, length), do: {operation, length}
  defp style_tuple(operation, axis, length), do: {operation, axis, length}

  defp spacing_scale_length!(operation, scale, allow_auto, allow_negative, length_units) do
    case catalog_scale_length(operation, scale, allow_auto, allow_negative, length_units) do
      {:ok, length} -> length
      :error -> raise ArgumentError, "unknown GPUI spacing scale token: #{inspect(scale)}"
    end
  end

  defp catalog_scale_length(operation, scale, allow_auto, allow_negative, length_units) do
    {key, negated} = spacing_scale_key_and_sign(scale)

    cond do
      key == "auto" and allow_auto and not negated ->
        {:ok, :auto}

      key == "auto" ->
        :error

      true ->
        case @operation_scales |> Map.fetch!(operation) |> Map.fetch(key) do
          {:ok, length} ->
            length
            |> validate_length_units!(length_units)
            |> then(&{:ok, maybe_negate_length!(&1, negated, allow_negative)})

          :error ->
            :error
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

  defp normalize_length_or_scale!(
         _operation,
         {unit, _value} = length,
         allow_auto,
         allow_negative,
         length_units
       )
       when unit in [:px, :rem, :fraction],
       do: normalize_length!(length, allow_auto, allow_negative, length_units)

  defp normalize_length_or_scale!(_operation, :auto, allow_auto, allow_negative, length_units),
    do: normalize_length!(:auto, allow_auto, allow_negative, length_units)

  defp normalize_length_or_scale!(operation, scale, allow_auto, allow_negative, length_units),
    do: spacing_scale_length!(operation, scale, allow_auto, allow_negative, length_units)

  defp normalize_length!(:auto, true, _allow_negative, _length_units), do: :auto

  defp normalize_length!({unit, value} = length, _allow_auto, allow_negative, length_units)
       when unit in [:px, :rem, :fraction] and is_number(value) do
    cond do
      unit not in length_units ->
        raise ArgumentError, "style length unit is not allowed here: #{inspect(length)}"

      allow_negative or value >= 0 ->
        {unit, value}

      true ->
        raise ArgumentError, "invalid non-negative style length: #{inspect(length)}"
    end
  end

  defp normalize_length!(other, allow_auto, _allow_negative, _length_units) do
    auto_message = if allow_auto, do: ", :auto", else: ""

    raise ArgumentError,
          "invalid style length #{inspect(other)}; expected {:px, n}, {:rem, n}, {:fraction, n}#{auto_message}"
  end

  defp parse_arbitrary_length("auto", true, _allow_negative, _length_units), do: {:ok, :auto}
  defp parse_arbitrary_length("auto", false, _allow_negative, _length_units), do: :error

  defp parse_arbitrary_length(payload, _allow_auto, allow_negative, length_units) do
    case Regex.run(~r/^(-?[0-9]+(?:\.[0-9]+)?)(px|rem|%)$/, payload, capture: :all_but_first) do
      [number, "px"] ->
        validate_arbitrary_length({:px, parse_number!(number)}, allow_negative, length_units)

      [number, "rem"] ->
        validate_arbitrary_length({:rem, parse_number!(number)}, allow_negative, length_units)

      [number, "%"] ->
        validate_arbitrary_length(
          {:fraction, parse_number!(number) / 100},
          allow_negative,
          length_units
        )

      _ ->
        :error
    end
  end

  defp validate_arbitrary_length({unit, value} = length, allow_negative, length_units)
       when unit in [:px, :rem, :fraction] do
    cond do
      unit not in length_units -> :error
      allow_negative or value >= 0 -> {:ok, length}
      true -> :error
    end
  end

  defp validate_length_units!(:auto, _length_units), do: :auto

  defp validate_length_units!({unit, _value} = length, length_units) do
    if unit in length_units do
      length
    else
      raise ArgumentError, "style length unit is not allowed here: #{inspect(length)}"
    end
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
