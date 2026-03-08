defmodule Guppy.Component.Compiler do
  @moduledoc false

  require Record

  Record.defrecord(:xmlElement,
    name: nil,
    expanded_name: [],
    nsinfo: [],
    namespace: nil,
    parents: [],
    pos: nil,
    attributes: [],
    content: [],
    language: "",
    xmlbase: "",
    elementdef: :undeclared
  )

  Record.defrecord(:xmlAttribute,
    name: nil,
    expanded_name: [],
    nsinfo: [],
    namespace: [],
    parents: [],
    pos: nil,
    language: [],
    value: nil,
    normalized: nil
  )

  Record.defrecord(:xmlText,
    parents: [],
    pos: nil,
    language: [],
    value: nil,
    type: :text
  )

  @div_events [
    "click",
    "hover",
    "focus",
    "blur",
    "key_down",
    "key_up",
    "context_menu",
    "drag_start",
    "drag_move",
    "drop",
    "mouse_down",
    "mouse_up",
    "mouse_move",
    "scroll_wheel"
  ]
  @text_events ["click"]
  @text_input_events ["change"]

  @style_attr_pairs [
    {"class", :style},
    {"style", :style},
    {"hover_class", :hover_style},
    {"hover_style", :hover_style},
    {"focus_class", :focus_style},
    {"focus_style", :focus_style},
    {"in_focus_class", :in_focus_style},
    {"in_focus_style", :in_focus_style},
    {"active_class", :active_style},
    {"active_style", :active_style},
    {"disabled_class", :disabled_style},
    {"disabled_style", :disabled_style}
  ]

  @common_node_attrs [
    {"id", :string},
    {"disabled", :boolean},
    {"tab_index", :integer},
    {"actions", :expr_only},
    {"shortcuts", :expr_only}
  ]

  @div_only_attrs [
    {"stack_priority", :integer},
    {"occlude", :boolean},
    {"focusable", :boolean},
    {"tab_stop", :boolean},
    {"track_scroll", :boolean},
    {"anchor_scroll", :boolean}
  ]

  def compile!(template, caller) when is_binary(template) do
    {safe_template, placeholders} = preprocess_dynamic_attributes(template)
    Process.put({__MODULE__, :placeholders}, placeholders)

    root = parse_template!(safe_template, caller)
    children = compile_children(xmlElement(root, :content), caller)

    case non_empty_root_children(children) do
      [child] -> child
      [] -> raise_compile_error!(caller, "~G requires a root element")
      _ -> raise_compile_error!(caller, "~G requires exactly one root element")
    end
  after
    Process.delete({__MODULE__, :placeholders})
  end

  defp parse_template!(template, caller) do
    wrapped = "<guppy_root>" <> template <> "</guppy_root>"

    case :xmerl_scan.string(String.to_charlist(wrapped), quiet: true) do
      {document, _rest} ->
        document
    end
  rescue
    error ->
      raise_compile_error!(caller, "failed to parse ~G template: #{Exception.message(error)}")
  end

  defp compile_children(nodes, caller) do
    Enum.map(nodes, &compile_child(&1, caller))
  end

  defp non_empty_root_children(children), do: Enum.reject(children, &(&1 == :skip))

  defp compile_child(node, caller) do
    case elem(node, 0) do
      :xmlElement -> compile_element(node, caller)
      :xmlText -> compile_node_text(node, caller)
      _ -> :skip
    end
  end

  defp compile_element(element, caller) do
    tag = element |> xmlElement(:name) |> to_string()
    attrs = attribute_map(xmlElement(element, :attributes))
    directives = extract_directives(attrs)
    attrs = Map.drop(attrs, [":if", ":for"])

    base =
      case tag do
        "div" -> compile_div(attrs, xmlElement(element, :content), caller)
        "scroll" -> compile_scroll(attrs, xmlElement(element, :content), caller)
        "button" -> compile_button(attrs, xmlElement(element, :content), caller)
        "text_input" -> compile_text_input(attrs, caller)
        "text" -> compile_text(attrs, xmlElement(element, :content), caller)
        other -> compile_component(other, attrs, xmlElement(element, :content), caller)
      end

    apply_directives(base, directives, caller)
  end

  defp compile_div(attrs, content, caller) do
    assert_allowed_attrs!(attrs, div_allowed_attrs(), "div", caller)
    children = build_children_ast(content, caller)
    opts = build_div_like_opts(attrs, @div_events, @common_node_attrs ++ @div_only_attrs, caller)

    quote do
      Guppy.IR.div(unquote(children), unquote(opts))
    end
  end

  defp compile_scroll(attrs, content, caller) do
    assert_allowed_attrs!(attrs, scroll_allowed_attrs(), "scroll", caller)
    children = build_children_ast(content, caller)
    opts = build_scroll_opts(attrs, caller)

    quote do
      Guppy.IR.scroll(unquote(children), unquote(opts))
    end
  end

  defp compile_button(attrs, content, caller) do
    assert_allowed_attrs!(attrs, button_allowed_attrs(), "button", caller)
    label = build_string_content_ast(content, caller)
    opts = build_div_like_opts(attrs, @div_events, @common_node_attrs, caller)

    quote do
      Guppy.IR.button(unquote(label), unquote(opts))
    end
  end

  defp compile_text_input(attrs, caller) do
    assert_allowed_attrs!(attrs, text_input_allowed_attrs(), "text_input", caller)
    value = fetch_required_attr!(attrs, "value", :string_or_expr, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        maybe_attr_entry(attrs, "placeholder", :string_or_expr, caller),
        style_entry(attrs, "class", "style", :style),
        maybe_attr_entry(attrs, "disabled", :boolean, caller),
        maybe_attr_entry(attrs, "tab_index", :integer, caller),
        events_entry(attrs, @text_input_events, caller)
      ])

    quote do
      Guppy.IR.text_input(unquote(value), unquote(opts))
    end
  end

  defp compile_text(attrs, content, caller) do
    assert_allowed_attrs!(attrs, text_allowed_attrs(), "text", caller)
    text_node = compile_text_node(attrs, content, caller)
    wrapper_style = merged_style_entry(attrs, "class", "style")

    if wrapper_style == nil do
      text_node
    else
      wrapper_opts = keyword_ast([style_tuple_ast(:style, wrapper_style)])

      quote do
        Guppy.IR.div([unquote(text_node)], unquote(wrapper_opts))
      end
    end
  end

  defp compile_component(tag, attrs, content, caller) do
    assert_component_attrs!(tag, attrs, caller)
    props = build_component_props_ast(attrs, content, caller)
    validated_assigns = Macro.unique_var(:component_assigns, __MODULE__)

    case component_target_ast(tag) do
      {:local, function_name} ->
        quote do
          unquote(validated_assigns) =
            Guppy.Component.validate_props!(__MODULE__, unquote(function_name), unquote(props))

          unquote({function_name, [], [validated_assigns]})
        end

      {:remote, module_ast} ->
        quote do
          unquote(validated_assigns) =
            Guppy.Component.validate_props!(unquote(module_ast), :render, unquote(props))

          unquote(module_ast).render(unquote(validated_assigns))
        end
    end
  end

  defp compile_text_node(attrs, content, caller) do
    text = build_string_content_ast(content, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        events_entry(attrs, @text_events, caller)
      ])

    quote do
      Guppy.IR.text(unquote(text), unquote(opts))
    end
  end

  defp build_children_ast(content, caller) do
    child_exprs =
      content
      |> compile_children(caller)
      |> Enum.reject(&(&1 == :skip))

    quote do
      Guppy.Component.flatten_children([unquote_splicing(child_exprs)])
    end
  end

  defp build_component_props_ast(attrs, content, caller) do
    entries =
      attrs
      |> Enum.map(fn {name, value} ->
        value_ast = parse_attribute_value(value, :string_or_expr, caller)
        key = String.to_atom(name)

        quote do
          {unquote(key), unquote(value_ast)}
        end
      end)

    children_ast = build_children_ast(content, caller)

    quote do
      Guppy.Component.build_component_assigns([
        unquote_splicing(entries),
        {:children, unquote(children_ast)}
      ])
    end
  end

  defp build_string_content_ast(content, caller) do
    case Enum.filter(content, &(elem(&1, 0) in [:xmlText])) do
      _ -> :ok
    end

    if Enum.any?(content, &(elem(&1, 0) == :xmlElement)) do
      raise_compile_error!(
        caller,
        "text and button content may only contain text and {expressions}"
      )
    end

    text =
      content
      |> Enum.map_join(fn node ->
        if elem(node, 0) == :xmlText do
          node |> xmlText(:value) |> List.to_string()
        else
          ""
        end
      end)
      |> normalize_template_text()

    build_interpolated_text_ast(text, caller)
  end

  defp compile_node_text(node, caller) do
    text = node |> xmlText(:value) |> List.to_string() |> normalize_template_text()

    cond do
      text == "" ->
        :skip

      single_expression?(text) ->
        expression = text |> extract_wrapped_expression!() |> parse_expression!(caller)

        quote do
          Guppy.Component.dynamic_child(unquote(expression))
        end

      true ->
        text_ast = build_interpolated_text_ast(text, caller)

        quote do
          Guppy.IR.text(unquote(text_ast))
        end
    end
  end

  defp apply_directives(base, directives, caller) do
    with_if =
      case directives[:if] do
        nil ->
          base

        expression ->
          quote do
            if unquote(expression) do
              [unquote(base)]
            else
              []
            end
          end
      end

    case directives[:for] do
      nil ->
        with_if

      for_expression ->
        {generator, _binding} = normalize_for_expression!(for_expression, caller)

        quote do
          for unquote(generator) do
            unquote(with_if)
          end
        end
    end
  end

  defp normalize_for_expression!({:<-, _, _} = generator, _caller), do: {generator, nil}

  defp normalize_for_expression!(other, caller) do
    raise_compile_error!(
      caller,
      ":for expects a generator expression, got: #{Macro.to_string(other)}"
    )
  end

  defp extract_directives(attrs) do
    %{}
    |> maybe_put_directive(:if, Map.get(attrs, ":if"))
    |> maybe_put_directive(:for, Map.get(attrs, ":for"))
  end

  defp maybe_put_directive(map, _key, nil), do: map

  defp maybe_put_directive(map, key, value) do
    Map.put(map, key, parse_expression!(extract_wrapped_expression!(value), nil))
  end

  defp build_div_like_opts(attrs, event_names, extra_attrs, caller) do
    scalar_entries =
      Enum.map(extra_attrs, fn {name, type} -> maybe_attr_entry(attrs, name, type, caller) end)

    style_entries =
      Enum.map(@style_attr_pairs, fn
        {"class", _} ->
          style_entry(attrs, "class", "style", :style)

        {"hover_class", _} ->
          style_entry(attrs, "hover_class", "hover_style", :hover_style)

        {"focus_class", _} ->
          style_entry(attrs, "focus_class", "focus_style", :focus_style)

        {"in_focus_class", _} ->
          style_entry(attrs, "in_focus_class", "in_focus_style", :in_focus_style)

        {"active_class", _} ->
          style_entry(attrs, "active_class", "active_style", :active_style)

        {"disabled_class", _} ->
          style_entry(attrs, "disabled_class", "disabled_style", :disabled_style)

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)

    keyword_ast(scalar_entries ++ style_entries ++ [events_entry(attrs, event_names, caller)])
  end

  defp build_scroll_opts(attrs, caller) do
    keyword_ast([
      maybe_attr_entry(attrs, "id", :string, caller),
      maybe_attr_entry(attrs, "axis", :axis, caller),
      style_entry(attrs, "class", "style", :style)
    ])
  end

  defp style_entry(attrs, class_key, style_key, target_key) do
    merged = merged_style_entry(attrs, class_key, style_key)

    if merged == nil do
      nil
    else
      style_tuple_ast(target_key, merged)
    end
  end

  defp merged_style_entry(attrs, class_key, style_key) do
    class_value = Map.get(attrs, class_key)
    style_value = Map.get(attrs, style_key)

    if is_nil(class_value) and is_nil(style_value) do
      nil
    else
      quote do
        Guppy.Component.merge_styles(
          unquote(style_value_ast(class_value)),
          unquote(raw_style_ast(style_value))
        )
      end
    end
  end

  defp style_value_ast(nil), do: nil
  defp style_value_ast(value), do: parse_attribute_value(value, :string_or_expr, nil)

  defp raw_style_ast(nil), do: nil
  defp raw_style_ast(value), do: parse_attribute_value(value, :expr_or_string, nil)

  defp style_tuple_ast(key, value_ast) do
    quote do
      Guppy.Component.maybe_entry(unquote(key), unquote(value_ast))
    end
  end

  defp component_target_ast(tag) do
    if String.contains?(tag, ".") do
      module_ast = tag |> String.split(".") |> Module.concat()
      {:remote, module_ast}
    else
      {:local, tag |> String.replace("-", "_") |> String.to_atom()}
    end
  end

  defp assert_component_attrs!(tag, attrs, caller) do
    if Map.has_key?(attrs, "children") do
      raise_compile_error!(caller, "component <#{tag}> cannot accept a children attribute")
    end

    :ok
  end

  defp events_entry(attrs, allowed_events, caller) do
    entries =
      allowed_events
      |> Enum.map(fn event_name ->
        case Map.get(attrs, event_name) do
          nil ->
            nil

          value ->
            event_ast = parse_attribute_value(value, :string_or_expr, caller)

            quote do
              Guppy.Component.maybe_entry(unquote(String.to_atom(event_name)), unquote(event_ast))
            end
        end
      end)
      |> Enum.reject(&is_nil/1)

    quote do
      Guppy.Component.maybe_entry(
        :events,
        Guppy.Component.build_events([unquote_splicing(entries)])
      )
    end
  end

  defp keyword_ast(entries) do
    quote do
      Guppy.Component.build_keyword([unquote_splicing(Enum.reject(entries, &is_nil/1))])
    end
  end

  defp maybe_attr_entry(attrs, name, type, caller) do
    case Map.get(attrs, name) do
      nil ->
        nil

      value ->
        parsed = parse_attribute_value(value, type, caller)

        quote do
          Guppy.Component.maybe_entry(unquote(String.to_atom(name)), unquote(parsed))
        end
    end
  end

  defp fetch_required_attr!(attrs, name, type, caller) do
    case Map.fetch(attrs, name) do
      {:ok, value} -> parse_attribute_value(value, type, caller)
      :error -> raise_compile_error!(caller, "missing required attribute #{name}")
    end
  end

  defp parse_attribute_value(value, type, caller) do
    if single_expression?(value) do
      value |> extract_wrapped_expression!() |> parse_expression!(caller)
    else
      parse_static_value(value, type, caller)
    end
  end

  defp parse_static_value(value, :string, _caller), do: value
  defp parse_static_value(value, :string_or_expr, _caller), do: value
  defp parse_static_value(value, :expr_or_string, _caller), do: value

  defp parse_static_value(value, :boolean, caller) do
    case value do
      "true" ->
        true

      "false" ->
        false

      _ ->
        raise_compile_error!(caller, "expected boolean attribute value, got: #{inspect(value)}")
    end
  end

  defp parse_static_value(value, :integer, caller) do
    case Integer.parse(value) do
      {integer, ""} ->
        integer

      _ ->
        raise_compile_error!(caller, "expected integer attribute value, got: #{inspect(value)}")
    end
  end

  defp parse_static_value(value, :axis, caller) do
    case value do
      "x" -> :x
      "y" -> :y
      "both" -> :both
      _ -> raise_compile_error!(caller, "expected axis to be x, y, or both")
    end
  end

  defp parse_expression!(source, nil) when is_binary(source) do
    source
    |> Code.string_to_quoted!()
    |> rewrite_assigns()
  end

  defp parse_expression!(source, caller) when is_binary(source) do
    source
    |> Code.string_to_quoted!(file: caller.file, line: caller.line)
    |> rewrite_assigns()
  rescue
    error ->
      raise_compile_error!(
        caller,
        "invalid expression in ~G template: #{Exception.message(error)}"
      )
  end

  defp rewrite_assigns(ast) do
    Macro.prewalk(ast, fn
      {:@, _meta, [{name, _, _context}]} when is_atom(name) ->
        quote do
          Guppy.Component.fetch_assign!(var!(assigns), unquote(name))
        end

      node ->
        node
    end)
  end

  defp build_interpolated_text_ast(text, caller) do
    segments = scan_interpolations(text)

    case segments do
      [literal] when is_binary(literal) ->
        literal

      parts ->
        iodata =
          Enum.map(parts, fn
            literal when is_binary(literal) ->
              literal

            {:expr, source} ->
              expression = parse_expression!(source, caller)

              quote do
                Guppy.Component.to_text(unquote(expression))
              end
          end)

        quote do
          IO.iodata_to_binary([unquote_splicing(iodata)])
        end
    end
  end

  defp scan_interpolations(text) do
    do_scan_interpolations(text, [], "")
  end

  defp do_scan_interpolations(<<>>, acc, current) do
    acc
    |> maybe_push_text(current)
    |> Enum.reverse()
  end

  defp do_scan_interpolations(<<"{", rest::binary>>, acc, current) do
    {expression, rest} = consume_expression(rest, 1, "")

    rest
    |> do_scan_interpolations(
      acc |> maybe_push_text(current) |> then(&[{:expr, expression} | &1]),
      ""
    )
  end

  defp do_scan_interpolations(<<char::utf8, rest::binary>>, acc, current) do
    do_scan_interpolations(rest, acc, current <> <<char::utf8>>)
  end

  defp consume_expression(<<>>, _depth, _current),
    do: raise("unterminated {expression} in ~G template")

  defp consume_expression(<<"{", rest::binary>>, depth, current) do
    consume_expression(rest, depth + 1, current <> "{")
  end

  defp consume_expression(<<"}", rest::binary>>, 1, current), do: {current, rest}

  defp consume_expression(<<"}", rest::binary>>, depth, current) do
    consume_expression(rest, depth - 1, current <> "}")
  end

  defp consume_expression(<<quote_char, rest::binary>>, depth, current)
       when quote_char in [?', ?"] do
    {string_content, rest} = consume_quoted(rest, <<quote_char>>, <<quote_char>>)
    consume_expression(rest, depth, current <> string_content)
  end

  defp consume_expression(<<char::utf8, rest::binary>>, depth, current) do
    consume_expression(rest, depth, current <> <<char::utf8>>)
  end

  defp consume_quoted(<<>>, _quote, _current), do: raise("unterminated string in ~G expression")

  defp consume_quoted(<<"\\", char::utf8, rest::binary>>, quote, current) do
    consume_quoted(rest, quote, current <> "\\" <> <<char::utf8>>)
  end

  defp consume_quoted(<<quote_char, rest::binary>>, <<quote_char>>, current) do
    {current <> <<quote_char>>, rest}
  end

  defp consume_quoted(<<char::utf8, rest::binary>>, quote, current) do
    consume_quoted(rest, quote, current <> <<char::utf8>>)
  end

  defp single_expression?(text) do
    text = String.trim(text)
    match?([{:expr, _}], scan_interpolations(text))
  end

  defp extract_wrapped_expression!(text) do
    case scan_interpolations(String.trim(text)) do
      [{:expr, source}] -> source
      _ -> raise("expected exactly one wrapped expression")
    end
  end

  defp normalize_template_text(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp preprocess_dynamic_attributes(template) do
    do_preprocess_dynamic_attributes(template, %{}, [], 0)
  end

  defp do_preprocess_dynamic_attributes(<<>>, placeholders, acc, _index) do
    {IO.iodata_to_binary(Enum.reverse(acc)), placeholders}
  end

  defp do_preprocess_dynamic_attributes(<<"=", rest::binary>>, placeholders, acc, index) do
    {spaces, rest} = take_leading_spaces(rest)

    case rest do
      <<"{", expression_rest::binary>> ->
        {expression, rest_after} = consume_expression(expression_rest, 1, "")
        placeholder = "__guppy_expr_#{index}__"

        do_preprocess_dynamic_attributes(
          rest_after,
          Map.put(placeholders, placeholder, "{" <> expression <> "}"),
          ["\"", placeholder, "\"", spaces, "=" | acc],
          index + 1
        )

      _ ->
        do_preprocess_dynamic_attributes(rest, placeholders, [spaces, "=" | acc], index)
    end
  end

  defp do_preprocess_dynamic_attributes(<<char::utf8, rest::binary>>, placeholders, acc, index) do
    do_preprocess_dynamic_attributes(rest, placeholders, [<<char::utf8>> | acc], index)
  end

  defp take_leading_spaces(binary), do: take_leading_spaces(binary, "")

  defp take_leading_spaces(<<char::utf8, rest::binary>>, acc) when char in [32, 9, 10, 13] do
    take_leading_spaces(rest, acc <> <<char::utf8>>)
  end

  defp take_leading_spaces(rest, acc), do: {acc, rest}

  defp maybe_push_text(acc, ""), do: acc
  defp maybe_push_text(acc, text), do: [text | acc]

  defp attribute_map(attributes) do
    placeholders = Process.get({__MODULE__, :placeholders}, %{})

    Map.new(attributes, fn attribute ->
      name = attribute |> xmlAttribute(:name) |> to_string() |> String.replace("-", "_")

      raw_value = attribute |> xmlAttribute(:value) |> List.to_string()
      value = Map.get(placeholders, raw_value, raw_value)

      {name, value}
    end)
  end

  defp assert_allowed_attrs!(attrs, allowed, tag, caller) do
    case Map.keys(attrs) -- allowed do
      [] ->
        :ok

      [unknown | _] ->
        raise_compile_error!(caller, "unsupported attribute #{inspect(unknown)} on <#{tag}>")
    end
  end

  defp div_allowed_attrs do
    base_allowed_attrs() ++
      Enum.map(@common_node_attrs ++ @div_only_attrs, &elem(&1, 0)) ++ @div_events
  end

  defp button_allowed_attrs do
    base_allowed_attrs() ++ Enum.map(@common_node_attrs, &elem(&1, 0)) ++ @div_events
  end

  defp text_allowed_attrs do
    [":if", ":for", "id", "class", "style"] ++ @text_events
  end

  defp text_input_allowed_attrs do
    [":if", ":for", "id", "value", "placeholder", "class", "style", "disabled", "tab_index"] ++
      @text_input_events
  end

  defp scroll_allowed_attrs do
    [":if", ":for", "id", "axis", "class", "style"]
  end

  defp base_allowed_attrs do
    [":if", ":for"] ++ Enum.map(@style_attr_pairs, &elem(&1, 0))
  end

  defp raise_compile_error!(nil, message), do: raise(CompileError, description: message)

  defp raise_compile_error!(caller, message) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description: message
  end
end
