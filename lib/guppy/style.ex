defmodule Guppy.Style do
  @moduledoc """
  Catalog-backed style helpers for canonical Guppy style tuple IR.

  `Guppy.Style` is generated from `data/gpui_style_catalog.json` at compile time.
  Helpers return primitive tuple ops that can be placed directly in IR style lists,
  plus catalog-backed option tuples for image-only options such as object fit.
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
                       "text_bg",
                       "border_color",
                       "shadow",
                       "flex_direction",
                       "flex_wrap",
                       "flex_item",
                       "align_items",
                       "align_self",
                       "justify_content",
                       "align_content",
                       "text_align",
                       "white_space",
                       "text_overflow",
                       "font_size",
                       "line_height",
                       "font_weight",
                       "font_style",
                       "text_decoration",
                       "text_decoration_color",
                       "text_decoration_style",
                       "strikethrough_color"
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
                         "max_height",
                         "flex_basis"
                       ]
                     end)

  @integer_operations Enum.filter(@catalog["operations"], fn operation ->
                        operation["name"] in [
                          "line_clamp",
                          "grid_cols",
                          "grid_rows",
                          "col_span",
                          "row_span"
                        ]
                      end)

  @image_option_operations Enum.filter(@catalog["operations"], fn operation ->
                             operation["name"] in ["object_fit", "grayscale"]
                           end)

  @boolean_operations Enum.filter(@catalog["operations"], fn operation ->
                        operation["name"] in [
                          "allow_concurrent_scroll",
                          "restrict_scroll_to_axis"
                        ]
                      end)

  @hex_color_operations Enum.filter(@catalog["operations"], fn operation ->
                          operation["name"] in [
                            "bg_hex",
                            "text_color_hex",
                            "text_bg_hex",
                            "border_color_hex",
                            "text_decoration_color_hex",
                            "strikethrough_color_hex"
                          ]
                        end)

  @gradient_operations Enum.filter(@catalog["operations"], fn operation ->
                         operation["name"] in ["bg_linear_gradient"]
                       end)

  @number_operations Enum.filter(@catalog["operations"], fn operation ->
                       operation["name"] in [
                         "aspect_ratio",
                         "flex_grow",
                         "flex_shrink",
                         "font_weight_value",
                         "opacity",
                         "text_decoration_thickness",
                         "strikethrough_thickness"
                       ]
                     end)

  @unit_length_operations Enum.filter(@catalog["operations"], fn operation ->
                            operation["name"] in [
                              "line_height_length",
                              "scrollbar_width",
                              "text_size"
                            ]
                          end)

  @string_operations Enum.filter(@catalog["operations"], fn operation ->
                       operation["name"] in ["font_family"]
                     end)

  @string_list_operations Enum.filter(@catalog["operations"], fn operation ->
                            operation["name"] in ["font_fallbacks"]
                          end)

  @font_feature_operations Enum.filter(@catalog["operations"], fn operation ->
                             operation["name"] in ["font_features"]
                           end)

  @grid_line_operations Enum.filter(@catalog["operations"], fn operation ->
                          operation["name"] in ["col_start", "col_end", "row_start", "row_end"]
                        end)

  @named_color_tokens @catalog["color_tokens"] |> Enum.map(&String.to_atom/1)

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

  @image_option_config Map.new(@image_option_operations, fn operation ->
                         normalize_value = fn
                           value when is_binary(value) -> String.to_atom(value)
                           value when is_boolean(value) -> value
                         end

                         {String.to_atom(operation["name"]),
                          %{
                            values: Enum.map(operation["values"], normalize_value),
                            class_tokens:
                              Map.new(operation["class_tokens"], fn {token, value} ->
                                {token, normalize_value.(value)}
                              end)
                          }}
                       end)

  @image_option_class_tokens Enum.flat_map(@image_option_operations, fn operation ->
                               normalize_value = fn
                                 value when is_binary(value) -> String.to_atom(value)
                                 value when is_boolean(value) -> value
                               end

                               operation_name = String.to_atom(operation["name"])

                               Enum.map(operation["class_tokens"], fn {token, value} ->
                                 {token, {operation_name, normalize_value.(value)}}
                               end)
                             end)
                             |> Map.new()

  @boolean_class_tokens Enum.flat_map(@boolean_operations, fn operation ->
                          operation_name = String.to_atom(operation["name"])

                          Enum.map(operation["class_tokens"], fn {token, value} ->
                            {token, {operation_name, value}}
                          end)
                        end)
                        |> Map.new()

  @hex_color_class_prefixes Map.new(@hex_color_operations, fn operation ->
                              {operation["class_prefix"], String.to_atom(operation["name"])}
                            end)

  @number_config Map.new(@number_operations, fn operation ->
                   number = operation["number"]

                   {String.to_atom(operation["name"]),
                    %{
                      min: number["min"],
                      max: number["max"]
                    }}
                 end)

  @number_class_tokens Enum.flat_map(@number_operations, fn operation ->
                         operation_name = String.to_atom(operation["name"])

                         Enum.map(operation["class_tokens"], fn {token, value} ->
                           {token, {operation_name, value}}
                         end)
                       end)
                       |> Map.new()

  @number_class_prefix_specs @number_operations
                             |> Enum.map(fn operation ->
                               config =
                                 Map.fetch!(@number_config, String.to_atom(operation["name"]))

                               {prefix, nil} = Enum.at(operation["class_prefixes"], 0)

                               %{
                                 prefix: prefix,
                                 operation: String.to_atom(operation["name"]),
                                 min: config.min,
                                 max: config.max
                               }
                             end)
                             |> Enum.sort_by(fn spec -> -String.length(spec.prefix) end)

  @unit_length_config Map.new(@unit_length_operations, fn operation ->
                        length = operation["length"]

                        {String.to_atom(operation["name"]),
                         %{
                           allow_auto: length["auto"],
                           allow_negative: length["negative"],
                           length_units: length["allowed_units"] |> Enum.map(&String.to_atom/1)
                         }}
                      end)

  @unit_length_class_prefix_specs @unit_length_operations
                                  |> Enum.map(fn operation ->
                                    config =
                                      Map.fetch!(
                                        @unit_length_config,
                                        String.to_atom(operation["name"])
                                      )

                                    {prefix, nil} = Enum.at(operation["class_prefixes"], 0)

                                    %{
                                      prefix: prefix,
                                      operation: String.to_atom(operation["name"]),
                                      allow_auto: config.allow_auto,
                                      allow_negative: config.allow_negative,
                                      length_units: config.length_units
                                    }
                                  end)
                                  |> Enum.sort_by(fn spec -> -String.length(spec.prefix) end)

  @grid_line_config Map.new(@grid_line_operations, fn operation ->
                      integer = operation["integer"]

                      {String.to_atom(operation["name"]),
                       %{
                         min: integer["min"],
                         max: integer["max"],
                         allow_auto: integer["auto"]
                       }}
                    end)

  @grid_line_class_tokens Enum.flat_map(@grid_line_operations, fn operation ->
                            operation_name = String.to_atom(operation["name"])

                            Enum.map(operation["class_tokens"], fn {token, value} ->
                              value = if value == "auto", do: :auto, else: value
                              {token, {operation_name, value}}
                            end)
                          end)
                          |> Map.new()

  @grid_line_class_prefix_specs @grid_line_operations
                                |> Enum.map(fn operation ->
                                  config =
                                    Map.fetch!(
                                      @grid_line_config,
                                      String.to_atom(operation["name"])
                                    )

                                  {prefix, nil} = Enum.at(operation["class_prefixes"], 0)

                                  %{
                                    prefix: prefix,
                                    operation: String.to_atom(operation["name"]),
                                    min: config.min,
                                    max: config.max
                                  }
                                end)
                                |> Enum.sort_by(fn spec -> -String.length(spec.prefix) end)

  @string_config Map.new(@string_operations, fn operation ->
                   string = operation["string"]

                   {String.to_atom(operation["name"]),
                    %{
                      min_length: string["min_length"]
                    }}
                 end)

  @string_class_prefix_specs @string_operations
                             |> Enum.map(fn operation ->
                               config =
                                 Map.fetch!(@string_config, String.to_atom(operation["name"]))

                               {prefix, nil} = Enum.at(operation["class_prefixes"], 0)

                               %{
                                 prefix: prefix,
                                 operation: String.to_atom(operation["name"]),
                                 min_length: config.min_length
                               }
                             end)
                             |> Enum.sort_by(fn spec -> -String.length(spec.prefix) end)

  @string_list_config Map.new(@string_list_operations, fn operation ->
                        string_list = operation["string_list"]

                        {String.to_atom(operation["name"]),
                         %{
                           min_items: string_list["min_items"],
                           min_length: string_list["min_length"]
                         }}
                      end)

  @string_list_class_prefix_specs @string_list_operations
                                  |> Enum.map(fn operation ->
                                    config =
                                      Map.fetch!(
                                        @string_list_config,
                                        String.to_atom(operation["name"])
                                      )

                                    {prefix, nil} = Enum.at(operation["class_prefixes"], 0)

                                    %{
                                      prefix: prefix,
                                      operation: String.to_atom(operation["name"]),
                                      min_items: config.min_items,
                                      min_length: config.min_length
                                    }
                                  end)
                                  |> Enum.sort_by(fn spec -> -String.length(spec.prefix) end)

  @font_feature_config Map.new(@font_feature_operations, fn operation ->
                         font_features = operation["font_features"]

                         {String.to_atom(operation["name"]),
                          %{
                            min_items: font_features["min_items"],
                            tag_pattern: Regex.compile!(font_features["tag_pattern"]),
                            min_value: font_features["min_value"],
                            max_value: font_features["max_value"]
                          }}
                       end)

  @font_feature_class_tokens Enum.flat_map(@font_feature_operations, fn operation ->
                               operation_name = String.to_atom(operation["name"])

                               Enum.map(operation["class_tokens"], fn {token, value} ->
                                 {token, {operation_name, Enum.map(value, &List.to_tuple/1)}}
                               end)
                             end)
                             |> Map.new()

  @font_feature_class_prefix_specs @font_feature_operations
                                   |> Enum.map(fn operation ->
                                     config =
                                       Map.fetch!(
                                         @font_feature_config,
                                         String.to_atom(operation["name"])
                                       )

                                     {prefix, nil} = Enum.at(operation["class_prefixes"], 0)

                                     %{
                                       prefix: prefix,
                                       operation: String.to_atom(operation["name"]),
                                       min_items: config.min_items,
                                       tag_pattern: config.tag_pattern,
                                       min_value: config.min_value,
                                       max_value: config.max_value
                                     }
                                   end)
                                   |> Enum.sort_by(fn spec -> -String.length(spec.prefix) end)

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

  @integer_config Map.new(@integer_operations, fn operation ->
                    integer = operation["integer"]

                    {String.to_atom(operation["name"]),
                     %{
                       min: integer["min"],
                       max: integer["max"]
                     }}
                  end)

  @integer_class_tokens Enum.flat_map(@integer_operations, fn operation ->
                          operation_name = String.to_atom(operation["name"])

                          operation
                          |> Map.get("class_tokens", %{})
                          |> Enum.map(fn {token, value} ->
                            value = if is_binary(value), do: String.to_atom(value), else: value
                            {token, {operation_name, value}}
                          end)
                        end)
                        |> Map.new()

  @integer_class_prefix_specs @integer_operations
                              |> Enum.map(fn operation ->
                                config =
                                  Map.fetch!(@integer_config, String.to_atom(operation["name"]))

                                {prefix, nil} = Enum.at(operation["class_prefixes"], 0)

                                %{
                                  prefix: prefix,
                                  operation: String.to_atom(operation["name"]),
                                  min: config.min,
                                  max: config.max
                                }
                              end)
                              |> Enum.sort_by(fn spec -> -String.length(spec.prefix) end)

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

  for {operation, config} <- @image_option_config do
    values = Macro.escape(config.values)

    @doc "Returns a canonical image-only #{operation} option tuple."
    def unquote(operation)(value) when value in unquote(values), do: {unquote(operation), value}

    def unquote(operation)(value),
      do: raise(ArgumentError, "invalid #{unquote(operation)} value: #{inspect(value)}")
  end

  for operation <- @boolean_operations,
      %{"kind" => "exact", "name" => name} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)

    @doc "Returns a canonical #{operation_name} boolean tuple."
    def unquote(function)(value) when is_boolean(value), do: {unquote(operation_name), value}

    def unquote(function)(value),
      do: raise(ArgumentError, "invalid #{unquote(operation_name)} value: #{inspect(value)}")
  end

  for operation <- @boolean_operations,
      %{"kind" => "value", "name" => name, "value" => value} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)

    @doc "Returns canonical #{inspect(value)} #{operation_name} style."
    def unquote(function)(), do: {unquote(operation_name), unquote(value)}
  end

  for operation <- @image_option_operations,
      %{"kind" => "value", "name" => name, "value" => value} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)

    value =
      case value do
        value when is_binary(value) -> String.to_atom(value)
        value when is_boolean(value) -> value
      end

    @doc "Returns canonical #{inspect(value)} #{operation_name} image option."
    def unquote(function)(), do: {unquote(operation_name), unquote(value)}
  end

  for operation <- @hex_color_operations do
    operation_name = String.to_atom(operation["name"])

    @doc "Returns a canonical #{operation_name} hex color tuple."
    def unquote(operation_name)(value), do: {unquote(operation_name), normalize_hex_color!(value)}
  end

  for operation <- @gradient_operations do
    operation_name = String.to_atom(operation["name"])

    @doc "Returns a canonical #{operation_name} tuple."
    def unquote(operation_name)(options),
      do: {unquote(operation_name), normalize_linear_gradient_options!(options)}
  end

  for operation <- @number_operations,
      %{"kind" => "number", "name" => name} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)

    @doc "Returns a canonical #{operation_name} number tuple."
    def unquote(function)(value),
      do: {unquote(operation_name), normalize_number!(unquote(operation_name), value)}
  end

  for operation <- @unit_length_operations,
      %{"kind" => "unit_length", "name" => name} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)

    @doc "Returns a canonical #{operation_name} unit length tuple."
    def unquote(function)(length),
      do:
        unit_length_style_tuple(
          unquote(operation_name),
          normalize_unit_length!(unquote(operation_name), length)
        )
  end

  for operation <- @string_operations,
      %{"kind" => "string", "name" => name} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)

    @doc "Returns a canonical #{operation_name} string tuple."
    def unquote(function)(value),
      do: {unquote(operation_name), normalize_string!(unquote(operation_name), value)}
  end

  for operation <- @string_list_operations,
      %{"kind" => "string_list", "name" => name} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)

    @doc "Returns a canonical #{operation_name} string-list tuple."
    def unquote(function)(value),
      do: {unquote(operation_name), normalize_string_list!(unquote(operation_name), value)}
  end

  for operation <- @font_feature_operations,
      %{"kind" => "font_features", "name" => name} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)

    @doc "Returns a canonical #{operation_name} OpenType feature tuple."
    def unquote(function)(value),
      do: {unquote(operation_name), normalize_font_features!(unquote(operation_name), value)}
  end

  for operation <- @font_feature_operations,
      %{"kind" => "value", "name" => name, "value" => value} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)
    value = Enum.map(value, &List.to_tuple/1)

    @doc "Returns canonical #{operation_name} OpenType feature style."
    def unquote(function)(), do: {unquote(operation_name), unquote(Macro.escape(value))}
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

  for {operation, config} <- @integer_config do
    @doc "Returns a canonical #{operation} integer style tuple."
    def unquote(operation)(value)
        when is_integer(value) and value >= unquote(config.min) and value <= unquote(config.max),
        do: {unquote(operation), value}

    def unquote(operation)(value) do
      raise ArgumentError,
            "invalid #{unquote(operation)} value: #{inspect(value)}; expected integer #{unquote(config.min)}..#{unquote(config.max)}"
    end
  end

  for operation <- @integer_operations,
      %{"kind" => "value", "name" => name, "value" => value} <- operation["helpers"] do
    operation_name = String.to_atom(operation["name"])
    function = String.to_atom(name)
    value = if is_binary(value), do: String.to_atom(value), else: value

    @doc "Returns canonical #{inspect(value)} #{operation_name} style."
    def unquote(function)(), do: {unquote(operation_name), unquote(value)}
  end

  for {operation, config} <- @grid_line_config do
    @doc "Returns a canonical #{operation} grid line placement style tuple."
    def unquote(operation)(:auto) when unquote(config.allow_auto), do: {unquote(operation), :auto}

    def unquote(operation)(value)
        when is_integer(value) and value >= unquote(config.min) and value <= unquote(config.max),
        do: {unquote(operation), value}

    def unquote(operation)(value) do
      raise ArgumentError,
            "invalid #{unquote(operation)} value: #{inspect(value)}; expected :auto or integer #{unquote(config.min)}..#{unquote(config.max)}"
    end
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
         :error <- parse_overflow_class(token),
         :error <- parse_boolean_class(token),
         :error <- parse_integer_class(token),
         :error <- parse_grid_line_class(token),
         :error <- parse_hex_color_class(token),
         :error <- parse_linear_gradient_class(token),
         :error <- parse_number_class(token),
         :error <- parse_unit_length_class(token),
         :error <- parse_string_class(token),
         :error <- parse_string_list_class(token),
         :error <- parse_font_feature_class(token) do
      parse_box_class(token)
    end
  end

  def class_token_to_style(_token), do: :error

  @doc false
  def class_token_to_image_option(token) when is_binary(token) do
    case Map.fetch(@image_option_class_tokens, token) do
      {:ok, {operation, value}} -> {:ok, {operation, value}}
      :error -> :error
    end
  end

  def class_token_to_image_option(_token), do: :error

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

  defp parse_boolean_class(token) do
    case Map.fetch(@boolean_class_tokens, token) do
      {:ok, {operation, value}} -> {:ok, {operation, value}}
      :error -> :error
    end
  end

  defp parse_integer_class(token) do
    case Map.fetch(@integer_class_tokens, token) do
      {:ok, {operation, value}} ->
        {:ok, {operation, value}}

      :error ->
        parse_integer_prefixed_class(token)
    end
  end

  defp parse_integer_prefixed_class(token) do
    Enum.find_value(@integer_class_prefix_specs, :error, fn spec ->
      cond do
        String.starts_with?(token, spec.prefix <> "-[") and String.ends_with?(token, "]") ->
          token
          |> String.slice((String.length(spec.prefix) + 2)..-2//1)
          |> integer_token_to_style(spec)

        String.starts_with?(token, spec.prefix <> "-") ->
          token
          |> String.replace_prefix(spec.prefix <> "-", "")
          |> integer_token_to_style(spec)

        true ->
          false
      end
    end)
  end

  defp parse_grid_line_class(token) do
    case Map.fetch(@grid_line_class_tokens, token) do
      {:ok, {operation, value}} ->
        {:ok, {operation, value}}

      :error ->
        parse_grid_line_integer_class(token)
    end
  end

  defp parse_grid_line_integer_class(token) do
    {negated, token} = split_negative_class_token(token)

    Enum.find_value(@grid_line_class_prefix_specs, :error, fn spec ->
      cond do
        String.starts_with?(token, spec.prefix <> "-[") and String.ends_with?(token, "]") ->
          token
          |> String.slice((String.length(spec.prefix) + 2)..-2//1)
          |> grid_line_token_to_style(spec, negated)

        String.starts_with?(token, spec.prefix <> "-") ->
          token
          |> String.replace_prefix(spec.prefix <> "-", "")
          |> grid_line_token_to_style(spec, negated)

        true ->
          false
      end
    end)
  end

  defp parse_hex_color_class(token) do
    with [prefix, hex] <-
           Regex.run(~r/^([a-z-]+)-\[(#[0-9A-Fa-f]{6})\]$/, token, capture: :all_but_first),
         {:ok, operation} <- Map.fetch(@hex_color_class_prefixes, prefix) do
      {:ok, {operation, hex}}
    else
      _ -> :error
    end
  end

  defp parse_linear_gradient_class(token) do
    with [payload] <-
           Regex.run(~r/^bg-linear-gradient-\[(.+)\]$/, token, capture: :all_but_first),
         [angle, from, to] <- String.split(payload, ",", parts: 3),
         {:ok, angle} <- parse_number(angle),
         {:ok, from} <- parse_gradient_stop(from),
         {:ok, to} <- parse_gradient_stop(to),
         options <- [angle: angle, from: from, to: to],
         {:ok, options} <- normalize_linear_gradient_options(options) do
      {:ok, {:bg_linear_gradient, options}}
    else
      _ -> :error
    end
  end

  defp parse_number_class(token) do
    case Map.fetch(@number_class_tokens, token) do
      {:ok, {operation, value}} ->
        {:ok, {operation, value}}

      :error ->
        parse_arbitrary_number_class(token)
    end
  end

  defp parse_arbitrary_number_class(token) do
    Enum.find_value(@number_class_prefix_specs, :error, fn spec ->
      with true <-
             String.starts_with?(token, spec.prefix <> "-[") and String.ends_with?(token, "]"),
           payload <- String.slice(token, (String.length(spec.prefix) + 2)..-2//1),
           {:ok, value} <- parse_number(payload),
           {:ok, value} <- normalize_number(spec.operation, value) do
        {:ok, {spec.operation, value}}
      else
        _ -> false
      end
    end)
  end

  defp parse_unit_length_class(token) do
    Enum.find_value(@unit_length_class_prefix_specs, :error, fn spec ->
      with true <-
             String.starts_with?(token, spec.prefix <> "-[") and String.ends_with?(token, "]"),
           payload <- String.slice(token, (String.length(spec.prefix) + 2)..-2//1),
           {:ok, length} <-
             parse_arbitrary_length(
               payload,
               spec.allow_auto,
               spec.allow_negative,
               spec.length_units
             ) do
        {:ok, unit_length_style_tuple(spec.operation, length)}
      else
        _ -> false
      end
    end)
  end

  defp parse_string_class(token) do
    Enum.find_value(@string_class_prefix_specs, :error, fn spec ->
      with true <-
             String.starts_with?(token, spec.prefix <> "-[") and String.ends_with?(token, "]"),
           payload <- String.slice(token, (String.length(spec.prefix) + 2)..-2//1),
           {:ok, value} <- normalize_string(spec.operation, payload) do
        {:ok, {spec.operation, value}}
      else
        _ -> false
      end
    end)
  end

  defp parse_string_list_class(token) do
    Enum.find_value(@string_list_class_prefix_specs, :error, fn spec ->
      with true <-
             String.starts_with?(token, spec.prefix <> "-[") and String.ends_with?(token, "]"),
           payload <- String.slice(token, (String.length(spec.prefix) + 2)..-2//1),
           {:ok, value} <- normalize_string_list(spec.operation, String.split(payload, ",")) do
        {:ok, {spec.operation, value}}
      else
        _ -> false
      end
    end)
  end

  defp parse_font_feature_class(token) do
    case Map.fetch(@font_feature_class_tokens, token) do
      {:ok, {operation, value}} ->
        {:ok, {operation, value}}

      :error ->
        parse_arbitrary_font_feature_class(token)
    end
  end

  defp parse_arbitrary_font_feature_class(token) do
    Enum.find_value(@font_feature_class_prefix_specs, :error, fn spec ->
      with true <-
             String.starts_with?(token, spec.prefix <> "-[") and String.ends_with?(token, "]"),
           payload <- String.slice(token, (String.length(spec.prefix) + 2)..-2//1),
           {:ok, value} <- parse_font_feature_payload(spec, payload) do
        {:ok, {spec.operation, value}}
      else
        _ -> false
      end
    end)
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

  defp integer_token_to_style(token, spec) do
    case Integer.parse(token) do
      {value, ""} when value >= spec.min and value <= spec.max ->
        {:ok, {spec.operation, value}}

      _ ->
        false
    end
  end

  defp grid_line_token_to_style(token, spec, negated) do
    case Integer.parse(token) do
      {value, ""} ->
        value = if negated, do: -value, else: value

        if value >= spec.min and value <= spec.max do
          {:ok, {spec.operation, value}}
        else
          false
        end

      _ ->
        false
    end
  end

  defp scale_token_to_style(_scale_token, %{allow_negative: false}, true), do: false

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

  defp arbitrary_length_to_style(_payload, %{allow_negative: false}, true), do: false

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

  defp normalize_hex_color!(value) when is_binary(value) do
    if Regex.match?(~r/^#?[0-9A-Fa-f]{6}$/, value) do
      value
    else
      raise ArgumentError, "invalid hex color: #{inspect(value)}"
    end
  end

  defp normalize_hex_color!(value),
    do: raise(ArgumentError, "invalid hex color: #{inspect(value)}")

  defp normalize_number!(operation, value) do
    case normalize_number(operation, value) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "invalid #{operation} value: #{inspect(value)}"
    end
  end

  defp normalize_number(operation, value) when is_number(value) do
    config = Map.fetch!(@number_config, operation)

    if value >= config.min and value <= config.max do
      {:ok, value}
    else
      :error
    end
  end

  defp normalize_number(_operation, _value), do: :error

  defp normalize_unit_length!(operation, length) do
    config = Map.fetch!(@unit_length_config, operation)

    normalize_length!(
      length,
      config.allow_auto,
      config.allow_negative,
      config.length_units
    )
  end

  defp normalize_string!(operation, value) do
    case normalize_string(operation, value) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "invalid #{operation} value: #{inspect(value)}"
    end
  end

  defp normalize_string(operation, value) when is_binary(value) do
    config = Map.fetch!(@string_config, operation)

    if String.length(value) >= config.min_length do
      {:ok, value}
    else
      :error
    end
  end

  defp normalize_string(_operation, _value), do: :error

  defp normalize_string_list!(operation, value) do
    case normalize_string_list(operation, value) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "invalid #{operation} value: #{inspect(value)}"
    end
  end

  defp normalize_string_list(operation, values) when is_list(values) do
    config = Map.fetch!(@string_list_config, operation)

    cond do
      length(values) < config.min_items ->
        :error

      Enum.all?(values, &(is_binary(&1) and String.length(&1) >= config.min_length)) ->
        {:ok, values}

      true ->
        :error
    end
  end

  defp normalize_string_list(_operation, _value), do: :error

  defp normalize_font_features!(operation, value) do
    case normalize_font_features(operation, value) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "invalid #{operation} value: #{inspect(value)}"
    end
  end

  defp normalize_font_features(operation, values) when is_list(values) do
    config = Map.fetch!(@font_feature_config, operation)

    cond do
      length(values) < config.min_items ->
        :error

      Enum.all?(values, &valid_font_feature?(&1, config)) ->
        {:ok, values}

      true ->
        :error
    end
  end

  defp normalize_font_features(_operation, _value), do: :error

  defp valid_font_feature?({tag, value}, config) when is_binary(tag) and is_integer(value) do
    Regex.match?(config.tag_pattern, tag) and value >= config.min_value and
      value <= config.max_value
  end

  defp valid_font_feature?(_feature, _config), do: false

  defp parse_font_feature_payload(_spec, ""), do: :error

  defp parse_font_feature_payload(spec, payload) do
    payload
    |> String.split(",")
    |> Enum.map(&parse_font_feature_entry(&1, spec))
    |> collect_results()
  end

  defp parse_font_feature_entry(entry, spec) do
    with [tag, value] <- String.split(entry, "=", parts: 2),
         true <- Regex.match?(spec.tag_pattern, tag),
         {:ok, value} <- parse_font_feature_value(value, spec) do
      {:ok, {tag, value}}
    else
      _ -> :error
    end
  end

  defp parse_font_feature_value("true", spec), do: parse_font_feature_value("1", spec)
  defp parse_font_feature_value("false", spec), do: parse_font_feature_value("0", spec)

  defp parse_font_feature_value(value, spec) do
    with {parsed, ""} <- Integer.parse(value),
         true <- parsed >= spec.min_value and parsed <= spec.max_value do
      {:ok, parsed}
    else
      _ -> :error
    end
  end

  defp collect_results(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, value}, {:ok, values} -> {:cont, {:ok, [value | values]}}
      :error, _acc -> {:halt, :error}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      :error -> :error
    end
  end

  defp unit_length_style_tuple(:scrollbar_width, {:px, value}), do: {:scrollbar_width_px, value}
  defp unit_length_style_tuple(:scrollbar_width, {:rem, value}), do: {:scrollbar_width_rem, value}
  defp unit_length_style_tuple(:text_size, length), do: {:text_size, length}
  defp unit_length_style_tuple(:line_height_length, length), do: {:line_height_length, length}

  defp unit_length_style_tuple(operation, length),
    do: raise(ArgumentError, "invalid #{operation} length: #{inspect(length)}")

  defp normalize_linear_gradient_options!(options) do
    case normalize_linear_gradient_options(options) do
      {:ok, options} -> options
      :error -> raise ArgumentError, "invalid linear gradient options: #{inspect(options)}"
    end
  end

  defp normalize_linear_gradient_options(options) when is_list(options) do
    if Keyword.keyword?(options) do
      keys = Keyword.keys(options)

      if length(options) == 3 and MapSet.size(MapSet.new(keys)) == 3 and
           Enum.sort(keys) == [:angle, :from, :to] and
           valid_gradient_angle?(Keyword.fetch!(options, :angle)) and
           valid_gradient_stop?(Keyword.fetch!(options, :from)) and
           valid_gradient_stop?(Keyword.fetch!(options, :to)) do
        {:ok, options}
      else
        :error
      end
    else
      :error
    end
  end

  defp normalize_linear_gradient_options(_options), do: :error

  defp parse_gradient_stop(stop) do
    with [color, percentage] <- String.split(stop, ":", parts: 2),
         {:ok, color} <- parse_gradient_color(color),
         {:ok, percentage} <- parse_number(percentage) do
      {:ok, {color, percentage}}
    else
      _ -> :error
    end
  end

  defp parse_gradient_color(color) do
    color = String.trim(color)

    cond do
      Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, color) ->
        {:ok, color}

      color_atom = named_gradient_color(color) ->
        {:ok, color_atom}

      true ->
        :error
    end
  end

  defp named_gradient_color(color) do
    color_atom = String.to_existing_atom(color)
    if color_atom in @named_color_tokens, do: color_atom, else: nil
  rescue
    ArgumentError -> nil
  end

  defp valid_gradient_angle?(angle), do: is_number(angle) and angle >= 0 and angle <= 360

  defp valid_gradient_stop?({color, percentage}),
    do:
      valid_gradient_color?(color) and is_number(percentage) and percentage >= 0 and
        percentage <= 1

  defp valid_gradient_stop?(_stop), do: false

  defp valid_gradient_color?(color) when color in @named_color_tokens, do: true

  defp valid_gradient_color?(color) when is_binary(color),
    do: Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, color)

  defp valid_gradient_color?(_color), do: false

  defp maybe_negate_length!(length, false, _spec_or_allow_negative), do: length

  defp maybe_negate_length!(:auto, true, _spec_or_allow_negative) do
    raise ArgumentError, "cannot negate auto style length"
  end

  defp maybe_negate_length!({unit, value}, true, %{allow_negative: true}), do: {unit, -value}
  defp maybe_negate_length!({unit, value}, true, true), do: {unit, -value}

  defp maybe_negate_length!(length, true, _spec_or_allow_negative) do
    raise ArgumentError, "style length does not support negative values: #{inspect(length)}"
  end

  defp parse_number(number) do
    number = String.trim(number)

    case Float.parse(number) do
      {value, ""} when value == trunc(value) -> {:ok, trunc(value)}
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  defp parse_number!(number) do
    case parse_number(number) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "invalid numeric style value: #{inspect(number)}"
    end
  end
end
