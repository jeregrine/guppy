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
  @button_events [
    "click",
    "hover",
    "focus",
    "blur",
    "key_down",
    "key_up",
    "context_menu",
    "mouse_down",
    "mouse_up",
    "mouse_move"
  ]
  @checkbox_events ["change", "focus", "blur"]
  @radio_events ["change", "focus", "blur"]
  @select_events ["click", "change", "close", "focus", "blur"]
  @text_input_events ["change", "focus", "blur"]
  @input_attrs ["id", "value", "placeholder", "class", "style", "disabled", "tab_index"]

  @local_component_prefix "guppy-local-"

  @style_attr_pairs [
    {"class", :style},
    {"style", :style},
    {"hover_class", :hover_style},
    {"hover_style", :hover_style},
    {"focus_class", :focus_style},
    {"focus_style", :focus_style},
    {"focus_visible_class", :focus_visible_style},
    {"focus_visible_style", :focus_visible_style},
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
    {"animation", :expr_only},
    {"actions", :expr_only},
    {"shortcuts", :expr_only}
  ]

  @div_only_attrs [
    {"stack_priority", :integer},
    {"occlude", :boolean},
    {"focusable", :boolean},
    {"tab_stop", :boolean},
    {"track_scroll", :boolean},
    {"anchor_scroll", :boolean},
    {"scroll_to", :boolean},
    {"tooltip", :string_or_expr}
  ]

  def compile!(template, caller) when is_binary(template) do
    assigns_var = Macro.unique_var(:guppy_template_assigns, __MODULE__)

    {safe_template, placeholders} =
      template
      |> preprocess_local_component_tags()
      |> preprocess_dynamic_attributes()

    Process.put({__MODULE__, :placeholders}, placeholders)
    Process.put({__MODULE__, :assigns_var}, assigns_var)
    Process.put({__MODULE__, :uses_assigns}, false)

    root = parse_template!(safe_template, caller)
    children = compile_children(xmlElement(root, :content), caller)

    compiled =
      case non_empty_root_children(children) do
        [child] -> child
        [] -> raise_compile_error!(caller, "~GUI requires a root element")
        _ -> raise_compile_error!(caller, "~GUI requires exactly one root element")
      end

    if Process.get({__MODULE__, :uses_assigns}) do
      quote do
        unquote(assigns_var) = Guppy.Component.template_assigns!(binding())
        unquote(compiled)
      end
    else
      compiled
    end
  after
    Process.delete({__MODULE__, :placeholders})
    Process.delete({__MODULE__, :assigns_var})
    Process.delete({__MODULE__, :uses_assigns})
  end

  defp parse_template!(template, caller) do
    wrapped = "<guppy_root>" <> template <> "</guppy_root>"

    case :xmerl_scan.string(String.to_charlist(wrapped), quiet: true) do
      {document, _rest} ->
        document
    end
  rescue
    error ->
      raise_compile_error!(caller, "failed to parse ~GUI template: #{Exception.message(error)}")
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
        "uniform_list" -> compile_uniform_list(attrs, xmlElement(element, :content), caller)
        "list" -> compile_generic_list(attrs, xmlElement(element, :content), caller)
        "data_table" -> compile_data_table(attrs, xmlElement(element, :content), caller)
        "tree" -> compile_tree(attrs, xmlElement(element, :content), caller)
        "canvas" -> compile_canvas(attrs, xmlElement(element, :content), caller)
        "popover" -> compile_popover(attrs, xmlElement(element, :content), caller)
        "button" -> compile_button(attrs, xmlElement(element, :content), caller)
        "checkbox" -> compile_checkbox(attrs, xmlElement(element, :content), caller)
        "radio" -> compile_radio(attrs, xmlElement(element, :content), caller)
        "select" -> compile_select(attrs, xmlElement(element, :content), caller)
        "text_input" -> compile_text_input(attrs, caller)
        "textarea" -> compile_textarea(attrs, caller)
        "text" -> compile_text(attrs, xmlElement(element, :content), caller)
        "rich_text" -> compile_rich_text(attrs, xmlElement(element, :content), caller)
        "image" -> compile_image(attrs, xmlElement(element, :content), caller)
        "icon" -> compile_icon(attrs, xmlElement(element, :content), caller)
        "spacer" -> compile_spacer(attrs, xmlElement(element, :content), caller)
        other -> compile_unknown_tag(other, attrs, xmlElement(element, :content), caller)
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

  defp compile_uniform_list(attrs, content, caller) do
    assert_allowed_attrs!(attrs, uniform_list_allowed_attrs(), "uniform_list", caller)
    assert_empty_element!(content, "uniform_list", caller)
    items = fetch_required_attr!(attrs, "items", :expr_only, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        style_entry(attrs, "class", "style", :style),
        style_entry(attrs, "item_class", "item_style", :item_style),
        events_entry(attrs, @text_events, caller)
      ])

    quote do
      Guppy.IR.uniform_list(unquote(items), unquote(opts))
    end
  end

  defp compile_generic_list(attrs, content, caller) do
    assert_allowed_attrs!(attrs, list_allowed_attrs(), "list", caller)
    assert_empty_element!(content, "list", caller)
    items = fetch_required_attr!(attrs, "items", :expr_only, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        style_entry(attrs, "class", "style", :style),
        style_entry(attrs, "item_class", "item_style", :item_style),
        events_entry(attrs, @text_events, caller)
      ])

    quote do
      Guppy.IR.list(unquote(items), unquote(opts))
    end
  end

  defp compile_data_table(attrs, content, caller) do
    assert_allowed_attrs!(attrs, data_table_allowed_attrs(), "data_table", caller)
    assert_empty_element!(content, "data_table", caller)
    columns = fetch_required_attr!(attrs, "columns", :expr_only, caller)
    rows = fetch_required_attr!(attrs, "rows", :expr_only, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        style_entry(attrs, "class", "style", :style),
        style_entry(attrs, "header_class", "header_style", :header_style),
        style_entry(attrs, "row_class", "row_style", :row_style),
        style_entry(attrs, "cell_class", "cell_style", :cell_style),
        maybe_attr_entry(attrs, "selected_row_id", :string_or_expr, caller),
        maybe_attr_entry(attrs, "selected_cell", :expr_only, caller),
        renamed_attr_entry(attrs, "sort_state", :sort, :expr_only, caller),
        events_entry(attrs, ["row_click", "cell_click", "sort"], caller)
      ])

    quote do
      Guppy.IR.data_table(unquote(columns), unquote(rows), unquote(opts))
    end
  end

  defp compile_tree(attrs, content, caller) do
    assert_allowed_attrs!(attrs, tree_allowed_attrs(), "tree", caller)
    assert_empty_element!(content, "tree", caller)
    nodes = fetch_required_attr!(attrs, "nodes", :expr_only, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        style_entry(attrs, "class", "style", :style),
        style_entry(attrs, "row_class", "row_style", :row_style),
        maybe_attr_entry(attrs, "selected_id", :string_or_expr, caller),
        events_entry(attrs, ["select", "toggle", "context_menu"], caller)
      ])

    quote do
      Guppy.IR.tree(unquote(nodes), unquote(opts))
    end
  end

  defp compile_canvas(attrs, content, caller) do
    assert_allowed_attrs!(attrs, canvas_allowed_attrs(), "canvas", caller)
    assert_empty_element!(content, "canvas", caller)
    commands = fetch_required_attr!(attrs, "commands", :expr_only, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        style_entry(attrs, "class", "style", :style),
        events_entry(attrs, ["click", "context_menu"], caller)
      ])

    quote do
      Guppy.IR.canvas(unquote(commands), unquote(opts))
    end
  end

  defp compile_popover(attrs, content, caller) do
    assert_allowed_attrs!(attrs, popover_allowed_attrs(), "popover", caller)
    label = fetch_required_attr!(attrs, "label", :string_or_expr, caller)
    open = fetch_required_attr!(attrs, "open", :boolean, caller)
    children = build_children_ast(content, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        style_entry(attrs, "class", "style", :style),
        style_entry(attrs, "popover_class", "popover_style", :popover_style),
        maybe_attr_entry(attrs, "anchor", :popover_anchor, caller),
        maybe_attr_entry(attrs, "anchor_position", :expr_only, caller),
        maybe_attr_entry(attrs, "anchor_offset", :expr_only, caller),
        maybe_attr_entry(attrs, "anchor_position_mode", :anchor_position_mode, caller),
        maybe_attr_entry(attrs, "anchor_fit", :popover_anchor_fit, caller),
        maybe_attr_entry(attrs, "snap_margin", :number, caller),
        maybe_attr_entry(attrs, "close_on_click_outside", :boolean, caller),
        maybe_attr_entry(attrs, "stack_priority", :integer, caller),
        maybe_attr_entry(attrs, "disabled", :boolean, caller),
        events_entry(attrs, ["click", "close"], caller)
      ])

    quote do
      Guppy.IR.popover(unquote(label), unquote(open), unquote(children), unquote(opts))
    end
  end

  defp compile_button(attrs, content, caller) do
    assert_allowed_attrs!(attrs, button_allowed_attrs(), "button", caller)
    label = build_string_content_ast(content, caller)
    opts = build_div_like_opts(attrs, @button_events, @common_node_attrs, caller)

    quote do
      Guppy.IR.button(unquote(label), unquote(opts))
    end
  end

  defp compile_select(attrs, content, caller) do
    assert_allowed_attrs!(attrs, select_allowed_attrs(), "select", caller)
    assert_empty_element!(content, "select", caller)
    options = fetch_required_attr!(attrs, "options", :expr_only, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        maybe_attr_entry(attrs, "value", :string_or_expr, caller),
        maybe_attr_entry(attrs, "open", :boolean, caller),
        maybe_attr_entry(attrs, "placeholder", :string_or_expr, caller),
        style_entry(attrs, "class", "style", :style),
        style_entry(attrs, "list_class", "list_style", :list_style),
        style_entry(attrs, "option_class", "option_style", :option_style),
        maybe_attr_entry(attrs, "disabled", :boolean, caller),
        maybe_attr_entry(attrs, "tab_index", :integer, caller),
        events_entry(attrs, @select_events, caller)
      ])

    quote do
      Guppy.IR.select(unquote(options), unquote(opts))
    end
  end

  defp compile_text_input(attrs, caller) do
    compile_input(:text_input, "text_input", attrs, caller)
  end

  defp compile_textarea(attrs, caller) do
    compile_input(:textarea, "textarea", attrs, caller)
  end

  defp compile_input(function, tag, attrs, caller) do
    assert_allowed_attrs!(attrs, input_allowed_attrs(), tag, caller)
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
      Guppy.IR.unquote(function)(unquote(value), unquote(opts))
    end
  end

  defp compile_checkbox(attrs, content, caller) do
    assert_allowed_attrs!(attrs, checkbox_allowed_attrs(), "checkbox", caller)
    checked = fetch_required_attr!(attrs, "checked", :boolean, caller)
    label = build_choice_label_ast("checkbox", attrs, content, caller)
    opts = build_choice_opts(attrs, @checkbox_events, caller)

    quote do
      Guppy.IR.checkbox(unquote(label), unquote(checked), unquote(opts))
    end
  end

  defp compile_radio(attrs, content, caller) do
    assert_allowed_attrs!(attrs, radio_allowed_attrs(), "radio", caller)
    checked = fetch_required_attr!(attrs, "checked", :boolean, caller)
    value = fetch_required_attr!(attrs, "value", :string_or_expr, caller)
    label = build_choice_label_ast("radio", attrs, content, caller)
    opts = build_choice_opts(attrs, @radio_events, caller)

    quote do
      Guppy.IR.radio(unquote(label), unquote(value), unquote(checked), unquote(opts))
    end
  end

  defp build_choice_opts(attrs, events, caller) do
    keyword_ast([
      maybe_attr_entry(attrs, "id", :string, caller),
      style_entry(attrs, "class", "style", :style),
      style_entry(attrs, "hover_class", "hover_style", :hover_style),
      style_entry(attrs, "focus_class", "focus_style", :focus_style),
      style_entry(
        attrs,
        "focus_visible_class",
        "focus_visible_style",
        :focus_visible_style
      ),
      style_entry(attrs, "in_focus_class", "in_focus_style", :in_focus_style),
      style_entry(attrs, "active_class", "active_style", :active_style),
      style_entry(attrs, "disabled_class", "disabled_style", :disabled_style),
      maybe_attr_entry(attrs, "disabled", :boolean, caller),
      maybe_attr_entry(attrs, "tab_index", :integer, caller),
      events_entry(attrs, events, caller)
    ])
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

  defp compile_rich_text(attrs, content, caller) do
    assert_allowed_attrs!(attrs, rich_text_allowed_attrs(), "rich_text", caller)
    assert_empty_element!(content, "rich_text", caller)
    runs = fetch_required_attr!(attrs, "runs", :expr_only, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        style_entry(attrs, "class", "style", :style),
        events_entry(attrs, @text_events, caller)
      ])

    quote do
      Guppy.IR.rich_text(unquote(runs), unquote(opts))
    end
  end

  defp compile_image(attrs, content, caller) do
    assert_allowed_attrs!(attrs, image_allowed_attrs(), "image", caller)
    assert_empty_element!(content, "image", caller)
    source = build_image_source_ast(attrs, caller)

    id_opts = keyword_ast([maybe_attr_entry(attrs, "id", :string, caller)])

    image_opts =
      quote do
        Guppy.Component.merge_image_options(
          unquote(style_value_ast(Map.get(attrs, "class"))),
          unquote(raw_style_ast(Map.get(attrs, "style"))),
          unquote(optional_attr_value_ast(attrs, "object_fit", :object_fit, caller)),
          unquote(optional_attr_value_ast(attrs, "grayscale", :boolean, caller))
        )
      end

    quote do
      Guppy.IR.image(unquote(source), Keyword.merge(unquote(id_opts), unquote(image_opts)))
    end
  end

  defp compile_icon(attrs, content, caller) do
    assert_allowed_attrs!(attrs, icon_allowed_attrs(), "icon", caller)
    assert_empty_element!(content, "icon", caller)
    source = build_image_source_ast(attrs, caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        style_entry(attrs, "class", "style", :style)
      ])

    quote do
      Guppy.IR.icon(unquote(source), unquote(opts))
    end
  end

  defp compile_spacer(attrs, content, caller) do
    assert_allowed_attrs!(attrs, spacer_allowed_attrs(), "spacer", caller)
    assert_empty_element!(content, "spacer", caller)

    opts =
      keyword_ast([
        maybe_attr_entry(attrs, "id", :string, caller),
        style_entry(attrs, "class", "style", :style)
      ])

    quote do
      Guppy.IR.spacer(unquote(opts))
    end
  end

  defp compile_unknown_tag(tag, attrs, content, caller) do
    if local_component_tag?(tag) or remote_component_tag?(tag) do
      compile_component(tag, attrs, content, caller)
    else
      raise_compile_error!(
        caller,
        "unsupported tag <#{tag}>; use <.#{tag}> for local function components or a module tag for remote components"
      )
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

  defp build_image_source_ast(attrs, caller) do
    source_attrs = ["src", "path", "uri", "embedded"]

    present_sources =
      Enum.filter(source_attrs, fn key -> Map.has_key?(attrs, key) end)

    case present_sources do
      ["src"] ->
        parse_attribute_value(Map.fetch!(attrs, "src"), :string_or_expr, caller)

      ["path"] ->
        value_ast = parse_attribute_value(Map.fetch!(attrs, "path"), :string_or_expr, caller)

        quote do
          {:path, unquote(value_ast)}
        end

      ["uri"] ->
        value_ast = parse_attribute_value(Map.fetch!(attrs, "uri"), :string_or_expr, caller)

        quote do
          {:uri, unquote(value_ast)}
        end

      ["embedded"] ->
        value_ast = parse_attribute_value(Map.fetch!(attrs, "embedded"), :string_or_expr, caller)

        quote do
          {:embedded, unquote(value_ast)}
        end

      [] ->
        raise_compile_error!(
          caller,
          "missing required image source attribute: one of src, path, uri, or embedded"
        )

      _ ->
        raise_compile_error!(
          caller,
          "image accepts exactly one source attribute: src, path, uri, or embedded"
        )
    end
  end

  defp build_choice_label_ast(tag, attrs, content, caller) do
    has_label_attr? = Map.has_key?(attrs, "label")
    has_content? = has_non_empty_content?(content)

    cond do
      has_label_attr? and has_content? ->
        raise_compile_error!(
          caller,
          "#{tag} accepts either a label attribute or child text, not both"
        )

      has_label_attr? ->
        parse_attribute_value(Map.fetch!(attrs, "label"), :string_or_expr, caller)

      has_content? ->
        build_string_content_ast(content, caller)

      true ->
        raise_compile_error!(caller, "#{tag} requires a label attribute or child text")
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

        {"focus_visible_class", _} ->
          style_entry(
            attrs,
            "focus_visible_class",
            "focus_visible_style",
            :focus_visible_style
          )

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

  defp optional_attr_value_ast(attrs, name, type, caller) do
    case Map.get(attrs, name) do
      nil -> nil
      value -> parse_attribute_value(value, type, caller)
    end
  end

  defp style_tuple_ast(key, value_ast) do
    quote do
      Guppy.Component.maybe_entry(unquote(key), unquote(value_ast))
    end
  end

  defp component_target_ast(tag) do
    cond do
      local_component_tag?(tag) ->
        function_name =
          tag
          |> String.replace_prefix(@local_component_prefix, "")
          |> String.replace("-", "_")
          |> String.to_atom()

        {:local, function_name}

      remote_component_tag?(tag) ->
        module_ast = tag |> String.split(".") |> Module.concat()
        {:remote, module_ast}
    end
  end

  defp local_component_tag?(tag), do: String.starts_with?(tag, @local_component_prefix)
  defp remote_component_tag?(tag), do: String.contains?(tag, ".")

  defp component_display_tag(tag) do
    if local_component_tag?(tag) do
      "." <> String.replace_prefix(tag, @local_component_prefix, "")
    else
      tag
    end
  end

  defp assert_component_attrs!(tag, attrs, caller) do
    if Map.has_key?(attrs, "children") do
      raise_compile_error!(
        caller,
        "component <#{component_display_tag(tag)}> cannot accept a children attribute"
      )
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

  defp renamed_attr_entry(attrs, name, key, type, caller) do
    case Map.get(attrs, name) do
      nil ->
        nil

      value ->
        parsed = parse_attribute_value(value, type, caller)

        quote do
          Guppy.Component.maybe_entry(unquote(key), unquote(parsed))
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

  defp parse_static_value(value, :popover_anchor, caller) do
    case value do
      "top_left" ->
        :top_left

      "top_right" ->
        :top_right

      "bottom_left" ->
        :bottom_left

      "bottom_right" ->
        :bottom_right

      _ ->
        raise_compile_error!(
          caller,
          "expected anchor to be top_left, top_right, bottom_left, or bottom_right"
        )
    end
  end

  defp parse_static_value(value, :anchor_position_mode, caller) do
    case value do
      "window" -> :window
      "local" -> :local
      _ -> raise_compile_error!(caller, "expected anchor_position_mode to be window or local")
    end
  end

  defp parse_static_value(value, :popover_anchor_fit, caller) do
    case value do
      "switch_anchor" ->
        :switch_anchor

      "snap_to_window" ->
        :snap_to_window

      "snap_to_window_with_margin" ->
        :snap_to_window_with_margin

      _ ->
        raise_compile_error!(
          caller,
          "expected anchor_fit to be switch_anchor, snap_to_window, or snap_to_window_with_margin"
        )
    end
  end

  defp parse_static_value(value, :number, caller) do
    case Float.parse(value) do
      {number, ""} ->
        number

      _ ->
        raise_compile_error!(caller, "expected numeric attribute value, got: #{inspect(value)}")
    end
  end

  defp parse_static_value(value, :object_fit, caller) do
    case value do
      "fill" ->
        :fill

      "contain" ->
        :contain

      "cover" ->
        :cover

      "scale_down" ->
        :scale_down

      "none" ->
        :none

      _ ->
        raise_compile_error!(
          caller,
          "expected object_fit to be fill, contain, cover, scale_down, or none"
        )
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
        "invalid expression in ~GUI template: #{Exception.message(error)}"
      )
  end

  defp rewrite_assigns(ast) do
    assigns_var = Process.get({__MODULE__, :assigns_var})

    Macro.prewalk(ast, fn
      {:@, _meta, [{name, _, _context}]} when is_atom(name) ->
        Process.put({__MODULE__, :uses_assigns}, true)

        quote do
          Guppy.Component.fetch_assign!(unquote(assigns_var), unquote(name))
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
    do: raise("unterminated {expression} in ~GUI template")

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

  defp consume_quoted(<<>>, _quote, _current), do: raise("unterminated string in ~GUI expression")

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

  defp preprocess_local_component_tags(template) do
    do_preprocess_local_component_tags(template, [])
  end

  defp do_preprocess_local_component_tags(<<>>, acc) do
    IO.iodata_to_binary(Enum.reverse(acc))
  end

  defp do_preprocess_local_component_tags(<<"{", rest::binary>>, acc) do
    {expression, rest_after} = consume_expression(rest, 1, "")
    do_preprocess_local_component_tags(rest_after, ["}", expression, "{" | acc])
  end

  defp do_preprocess_local_component_tags(<<"</.", rest::binary>>, acc) do
    case take_local_component_name(rest) do
      {:ok, name, rest_after} ->
        do_preprocess_local_component_tags(rest_after, [name, @local_component_prefix, "</" | acc])

      :error ->
        do_preprocess_local_component_tags(rest, ["</." | acc])
    end
  end

  defp do_preprocess_local_component_tags(<<"<.", rest::binary>>, acc) do
    case take_local_component_name(rest) do
      {:ok, name, rest_after} ->
        do_preprocess_local_component_tags(rest_after, [name, @local_component_prefix, "<" | acc])

      :error ->
        do_preprocess_local_component_tags(rest, ["<." | acc])
    end
  end

  defp do_preprocess_local_component_tags(<<char::utf8, rest::binary>>, acc) do
    do_preprocess_local_component_tags(rest, [<<char::utf8>> | acc])
  end

  defp take_local_component_name(<<first::utf8, rest::binary>>) do
    if local_component_name_start?(first) do
      do_take_local_component_name(rest, <<first::utf8>>)
    else
      :error
    end
  end

  defp take_local_component_name(_), do: :error

  defp do_take_local_component_name(<<char::utf8, rest::binary>>, name)
       when (char >= ?a and char <= ?z) or (char >= ?A and char <= ?Z) or
              (char >= ?0 and char <= ?9) or char in [?_, ?-] do
    do_take_local_component_name(rest, name <> <<char::utf8>>)
  end

  defp do_take_local_component_name(rest, name) do
    if local_component_name_boundary?(rest), do: {:ok, name, rest}, else: :error
  end

  defp local_component_name_start?(char),
    do: (char >= ?a and char <= ?z) or (char >= ?A and char <= ?Z) or char == ?_

  defp local_component_name_boundary?(<<>>), do: false

  defp local_component_name_boundary?(<<char::utf8, _rest::binary>>),
    do: char in [?>, ?/, 32, 9, 10, 13]

  defp preprocess_dynamic_attributes(template) do
    do_preprocess_dynamic_attributes(template, %{}, [], 0, :text)
  end

  defp do_preprocess_dynamic_attributes(<<>>, placeholders, acc, _index, _state) do
    {IO.iodata_to_binary(Enum.reverse(acc)), placeholders}
  end

  defp do_preprocess_dynamic_attributes(<<"<", rest::binary>>, placeholders, acc, index, :text) do
    do_preprocess_dynamic_attributes(rest, placeholders, ["<" | acc], index, :tag)
  end

  defp do_preprocess_dynamic_attributes(
         <<quote_char::utf8, rest::binary>>,
         placeholders,
         acc,
         index,
         :tag
       )
       when quote_char in [?", ?'] do
    do_preprocess_dynamic_attributes(
      rest,
      placeholders,
      [<<quote_char::utf8>> | acc],
      index,
      {:quoted_attribute, quote_char}
    )
  end

  defp do_preprocess_dynamic_attributes(<<">", rest::binary>>, placeholders, acc, index, :tag) do
    do_preprocess_dynamic_attributes(rest, placeholders, [">" | acc], index, :text)
  end

  defp do_preprocess_dynamic_attributes(<<"=", rest::binary>>, placeholders, acc, index, :tag) do
    {spaces, rest} = take_leading_spaces(rest)

    case rest do
      <<"{", expression_rest::binary>> ->
        {expression, rest_after} = consume_expression(expression_rest, 1, "")
        placeholder = "__guppy_expr_#{index}__"

        do_preprocess_dynamic_attributes(
          rest_after,
          Map.put(placeholders, placeholder, "{" <> expression <> "}"),
          ["\"", placeholder, "\"", spaces, "=" | acc],
          index + 1,
          :tag
        )

      _ ->
        do_preprocess_dynamic_attributes(rest, placeholders, [spaces, "=" | acc], index, :tag)
    end
  end

  defp do_preprocess_dynamic_attributes(
         <<char::utf8, rest::binary>>,
         placeholders,
         acc,
         index,
         {:quoted_attribute, quote_char}
       )
       when char == quote_char do
    do_preprocess_dynamic_attributes(rest, placeholders, [<<char::utf8>> | acc], index, :tag)
  end

  defp do_preprocess_dynamic_attributes(
         <<char::utf8, rest::binary>>,
         placeholders,
         acc,
         index,
         state
       ) do
    do_preprocess_dynamic_attributes(rest, placeholders, [<<char::utf8>> | acc], index, state)
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

  defp assert_empty_element!(content, tag, caller) do
    if has_non_empty_content?(content) do
      raise_compile_error!(caller, "<#{tag}> cannot have child content")
    end
  end

  defp has_non_empty_content?(content) do
    Enum.any?(content, fn
      node when elem(node, 0) == :xmlElement ->
        true

      node when elem(node, 0) == :xmlText ->
        node |> xmlText(:value) |> List.to_string() |> normalize_template_text() != ""

      _ ->
        false
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
    base_allowed_attrs() ++ Enum.map(@common_node_attrs, &elem(&1, 0)) ++ @button_events
  end

  defp text_allowed_attrs do
    [":if", ":for", "id", "class", "style"] ++ @text_events
  end

  defp rich_text_allowed_attrs do
    [":if", ":for", "id", "runs", "class", "style"] ++ @text_events
  end

  defp input_allowed_attrs do
    [":if", ":for" | @input_attrs] ++ @text_input_events
  end

  defp scroll_allowed_attrs do
    [":if", ":for", "id", "axis", "class", "style"]
  end

  defp select_allowed_attrs do
    [
      ":if",
      ":for",
      "id",
      "value",
      "open",
      "options",
      "placeholder",
      "class",
      "style",
      "list_class",
      "list_style",
      "option_class",
      "option_style",
      "disabled",
      "tab_index"
    ] ++ @select_events
  end

  defp uniform_list_allowed_attrs do
    [":if", ":for", "id", "items", "class", "style", "item_class", "item_style"] ++ @text_events
  end

  defp list_allowed_attrs do
    [":if", ":for", "id", "items", "class", "style", "item_class", "item_style"] ++ @text_events
  end

  defp data_table_allowed_attrs do
    [
      ":if",
      ":for",
      "id",
      "columns",
      "rows",
      "class",
      "style",
      "header_class",
      "header_style",
      "row_class",
      "row_style",
      "cell_class",
      "cell_style",
      "selected_row_id",
      "selected_cell",
      "sort_state"
    ] ++ ["row_click", "cell_click", "sort"]
  end

  defp tree_allowed_attrs do
    [
      ":if",
      ":for",
      "id",
      "nodes",
      "class",
      "style",
      "row_class",
      "row_style",
      "selected_id",
      "select",
      "toggle",
      "context_menu"
    ]
  end

  defp canvas_allowed_attrs do
    [":if", ":for", "id", "commands", "class", "style", "click", "context_menu"]
  end

  defp popover_allowed_attrs do
    [
      ":if",
      ":for",
      "id",
      "label",
      "open",
      "class",
      "style",
      "popover_class",
      "popover_style",
      "anchor",
      "anchor_position",
      "anchor_offset",
      "anchor_position_mode",
      "anchor_fit",
      "snap_margin",
      "close_on_click_outside",
      "stack_priority",
      "disabled",
      "click",
      "close"
    ]
  end

  defp image_allowed_attrs do
    [
      ":if",
      ":for",
      "id",
      "src",
      "path",
      "uri",
      "embedded",
      "object_fit",
      "grayscale",
      "class",
      "style"
    ]
  end

  defp icon_allowed_attrs do
    [":if", ":for", "id", "src", "path", "uri", "embedded", "class", "style"]
  end

  defp checkbox_allowed_attrs do
    [":if", ":for", "id", "label", "checked", "disabled", "tab_index"] ++
      Enum.map(@style_attr_pairs, &elem(&1, 0)) ++ @checkbox_events
  end

  defp radio_allowed_attrs do
    [":if", ":for", "id", "label", "value", "checked", "disabled", "tab_index"] ++
      Enum.map(@style_attr_pairs, &elem(&1, 0)) ++ @radio_events
  end

  defp spacer_allowed_attrs do
    [":if", ":for", "id", "class", "style"]
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
