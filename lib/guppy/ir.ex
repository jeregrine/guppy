defmodule Guppy.IR do
  @moduledoc """
  Minimal IR helpers for the Phase 1 tracer shot.

  This starts with just enough structure to prove:

  - Elixir owns UI state
  - Elixir sends a tree description
  - native GPUI renders that description
  - Elixir sends full-tree replacement updates
  - native click events can roundtrip back to Elixir

  Style tokens are represented as an ordered list.
  That order is preserved across the bridge so later tokens can override earlier ones.
  """

  @type node_id :: String.t()
  @type color_token :: :red | :green | :blue | :yellow | :black | :white | :gray

  @type style_flag ::
          :flex
          | :flex_col
          | :flex_row
          | :flex_wrap
          | :flex_nowrap
          | :flex_none
          | :flex_auto
          | :flex_grow
          | :flex_shrink
          | :flex_shrink_0
          | :flex_1
          | :size_full
          | :w_full
          | :h_full
          | :w_32
          | :w_64
          | :w_96
          | :h_32
          | :min_w_32
          | :min_h_0
          | :min_h_full
          | :max_w_64
          | :max_w_96
          | :max_w_full
          | :max_h_32
          | :max_h_96
          | :max_h_full
          | :gap_1
          | :gap_2
          | :gap_4
          | :p_1
          | :p_2
          | :p_4
          | :p_6
          | :p_8
          | :px_2
          | :py_2
          | :pt_2
          | :pr_2
          | :pb_2
          | :pl_2
          | :m_2
          | :mx_2
          | :my_2
          | :mt_2
          | :mr_2
          | :mb_2
          | :ml_2
          | :relative
          | :absolute
          | :top_0
          | :right_0
          | :bottom_0
          | :left_0
          | :inset_0
          | :top_1
          | :right_1
          | :top_2
          | :right_2
          | :bottom_2
          | :left_2
          | :text_left
          | :text_center
          | :text_right
          | :whitespace_normal
          | :whitespace_nowrap
          | :truncate
          | :text_ellipsis
          | :line_clamp_2
          | :line_clamp_3
          | :text_xs
          | :text_sm
          | :text_base
          | :text_lg
          | :text_xl
          | :text_2xl
          | :text_3xl
          | :leading_none
          | :leading_tight
          | :leading_snug
          | :leading_normal
          | :leading_relaxed
          | :leading_loose
          | :font_thin
          | :font_extralight
          | :font_light
          | :font_normal
          | :font_medium
          | :font_semibold
          | :font_bold
          | :font_extrabold
          | :font_black
          | :italic
          | :not_italic
          | :underline
          | :line_through
          | :items_start
          | :items_center
          | :items_end
          | :justify_start
          | :justify_center
          | :justify_end
          | :justify_between
          | :justify_around
          | :cursor_pointer
          | :rounded_sm
          | :rounded_md
          | :rounded_lg
          | :rounded_xl
          | :rounded_2xl
          | :rounded_full
          | :border_1
          | :border_2
          | :border_dashed
          | :border_t_1
          | :border_r_1
          | :border_b_1
          | :border_l_1
          | :shadow_sm
          | :shadow_md
          | :shadow_lg
          | :overflow_scroll
          | :overflow_x_scroll
          | :overflow_y_scroll
          | :overflow_hidden
          | :overflow_x_hidden
          | :overflow_y_hidden

  @type style_value ::
          {:bg, color_token()}
          | {:text_color, color_token()}
          | {:border_color, color_token()}
          | {:bg_hex, String.t()}
          | {:text_color_hex, String.t()}
          | {:border_color_hex, String.t()}
          | {:opacity, number()}
          | {:w_px, number()}
          | {:w_rem, number()}
          | {:w_frac, number()}
          | {:h_px, number()}
          | {:h_rem, number()}
          | {:h_frac, number()}
          | {:scrollbar_width_px, number()}
          | {:scrollbar_width_rem, number()}

  @type style_op :: style_flag() | style_value()
  @type style :: [style_op()]

  @type text_events :: %{optional(:click) => String.t()}

  @type div_events :: %{
          optional(:click) => String.t(),
          optional(:hover) => String.t(),
          optional(:focus) => String.t(),
          optional(:blur) => String.t(),
          optional(:key_down) => String.t(),
          optional(:key_up) => String.t(),
          optional(:context_menu) => String.t(),
          optional(:drag_start) => String.t(),
          optional(:drag_move) => String.t(),
          optional(:drop) => String.t(),
          optional(:mouse_down) => String.t(),
          optional(:mouse_up) => String.t(),
          optional(:mouse_move) => String.t(),
          optional(:scroll_wheel) => String.t()
        }

  @type action_name :: String.t()
  @type callback_id :: String.t()
  @type action_bindings :: %{optional(action_name()) => callback_id()}
  @type shortcut_binding :: {String.t(), action_name()}

  @type text_node :: %{
          required(:kind) => :text,
          required(:content) => String.t(),
          optional(:id) => node_id(),
          optional(:events) => text_events()
        }

  @type div_node :: %{
          required(:kind) => :div,
          required(:children) => [ir_node()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:hover_style) => style(),
          optional(:focus_style) => style(),
          optional(:in_focus_style) => style(),
          optional(:active_style) => style(),
          optional(:disabled_style) => style(),
          optional(:disabled) => boolean(),
          optional(:stack_priority) => non_neg_integer(),
          optional(:occlude) => boolean(),
          optional(:focusable) => boolean(),
          optional(:tab_stop) => boolean(),
          optional(:tab_index) => integer(),
          optional(:track_scroll) => boolean(),
          optional(:anchor_scroll) => boolean(),
          optional(:actions) => action_bindings(),
          optional(:shortcuts) => [shortcut_binding()],
          optional(:events) => div_events()
        }

  @type scroll_axis :: :x | :y | :both

  @type scroll_node :: %{
          required(:kind) => :scroll,
          required(:children) => [ir_node()],
          optional(:id) => node_id(),
          optional(:axis) => scroll_axis(),
          optional(:style) => style()
        }

  @type image_source ::
          String.t()
          | {:uri, String.t()}
          | {:path, String.t()}
          | {:embedded, String.t()}

  @type image_object_fit :: :fill | :contain | :cover | :scale_down | :none

  @type image_node :: %{
          required(:kind) => :image,
          required(:source) => image_source(),
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:object_fit) => image_object_fit(),
          optional(:grayscale) => boolean()
        }

  @type button_node :: %{
          required(:kind) => :button,
          required(:label) => String.t(),
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:hover_style) => style(),
          optional(:focus_style) => style(),
          optional(:in_focus_style) => style(),
          optional(:active_style) => style(),
          optional(:disabled_style) => style(),
          optional(:disabled) => boolean(),
          optional(:tab_index) => integer(),
          optional(:actions) => action_bindings(),
          optional(:shortcuts) => [shortcut_binding()],
          optional(:events) => div_events()
        }

  @type spacer_node :: %{
          required(:kind) => :spacer,
          optional(:id) => node_id(),
          optional(:style) => style()
        }

  @type text_input_events :: %{optional(:change) => String.t()}

  @type text_input_node :: %{
          required(:kind) => :text_input,
          required(:value) => String.t(),
          optional(:id) => node_id(),
          optional(:placeholder) => String.t(),
          optional(:style) => style(),
          optional(:disabled) => boolean(),
          optional(:tab_index) => integer(),
          optional(:events) => text_input_events()
        }

  @type ir_node ::
          text_node()
          | div_node()
          | scroll_node()
          | image_node()
          | button_node()
          | spacer_node()
          | text_input_node()

  @style_flag_tokens [
    :flex,
    :flex_col,
    :flex_row,
    :flex_wrap,
    :flex_nowrap,
    :flex_none,
    :flex_auto,
    :flex_grow,
    :flex_shrink,
    :flex_shrink_0,
    :flex_1,
    :size_full,
    :w_full,
    :h_full,
    :w_32,
    :w_64,
    :w_96,
    :h_32,
    :min_w_32,
    :min_h_0,
    :min_h_full,
    :max_w_64,
    :max_w_96,
    :max_w_full,
    :max_h_32,
    :max_h_96,
    :max_h_full,
    :gap_1,
    :gap_2,
    :gap_4,
    :p_1,
    :p_2,
    :p_4,
    :p_6,
    :p_8,
    :px_2,
    :py_2,
    :pt_2,
    :pr_2,
    :pb_2,
    :pl_2,
    :m_2,
    :mx_2,
    :my_2,
    :mt_2,
    :mr_2,
    :mb_2,
    :ml_2,
    :relative,
    :absolute,
    :top_0,
    :right_0,
    :bottom_0,
    :left_0,
    :inset_0,
    :top_1,
    :right_1,
    :top_2,
    :right_2,
    :bottom_2,
    :left_2,
    :text_left,
    :text_center,
    :text_right,
    :whitespace_normal,
    :whitespace_nowrap,
    :truncate,
    :text_ellipsis,
    :line_clamp_2,
    :line_clamp_3,
    :text_xs,
    :text_sm,
    :text_base,
    :text_lg,
    :text_xl,
    :text_2xl,
    :text_3xl,
    :leading_none,
    :leading_tight,
    :leading_snug,
    :leading_normal,
    :leading_relaxed,
    :leading_loose,
    :font_thin,
    :font_extralight,
    :font_light,
    :font_normal,
    :font_medium,
    :font_semibold,
    :font_bold,
    :font_extrabold,
    :font_black,
    :italic,
    :not_italic,
    :underline,
    :line_through,
    :items_start,
    :items_center,
    :items_end,
    :justify_start,
    :justify_center,
    :justify_end,
    :justify_between,
    :justify_around,
    :cursor_pointer,
    :rounded_sm,
    :rounded_md,
    :rounded_lg,
    :rounded_xl,
    :rounded_2xl,
    :rounded_full,
    :border_1,
    :border_2,
    :border_dashed,
    :border_t_1,
    :border_r_1,
    :border_b_1,
    :border_l_1,
    :shadow_sm,
    :shadow_md,
    :shadow_lg,
    :overflow_scroll,
    :overflow_x_scroll,
    :overflow_y_scroll,
    :overflow_hidden,
    :overflow_x_hidden,
    :overflow_y_hidden
  ]

  @color_style_value_tokens [:bg, :text_color, :border_color]
  @hex_color_style_value_tokens [:bg_hex, :text_color_hex, :border_color_hex]
  @size_value_tokens [:w_px, :w_rem, :h_px, :h_rem]
  @fraction_value_tokens [:w_frac, :h_frac]
  @scrollbar_value_tokens [:scrollbar_width_px, :scrollbar_width_rem]
  @color_tokens [:red, :green, :blue, :yellow, :black, :white, :gray]

  @spec text(String.t(), keyword()) :: text_node()
  def text(content, opts \\ []) when is_binary(content) and is_list(opts) do
    id = Keyword.get(opts, :id)
    events = Keyword.get(opts, :events)

    %{kind: :text, content: content}
    |> maybe_put(:id, id)
    |> maybe_put(:events, events)
  end

  @spec div([ir_node()], keyword()) :: div_node()
  def div(children, opts \\ []) when is_list(children) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    events = Keyword.get(opts, :events)
    hover_style = Keyword.get(opts, :hover_style)
    focus_style = Keyword.get(opts, :focus_style)
    in_focus_style = Keyword.get(opts, :in_focus_style)
    active_style = Keyword.get(opts, :active_style)
    disabled_style = Keyword.get(opts, :disabled_style)
    disabled = Keyword.get(opts, :disabled)
    stack_priority = Keyword.get(opts, :stack_priority)
    occlude = Keyword.get(opts, :occlude)
    focusable = Keyword.get(opts, :focusable)
    tab_stop = Keyword.get(opts, :tab_stop)
    tab_index = Keyword.get(opts, :tab_index)
    track_scroll = Keyword.get(opts, :track_scroll)
    anchor_scroll = Keyword.get(opts, :anchor_scroll)
    actions = Keyword.get(opts, :actions)
    shortcuts = Keyword.get(opts, :shortcuts)

    %{kind: :div, children: children}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:hover_style, hover_style)
    |> maybe_put(:focus_style, focus_style)
    |> maybe_put(:in_focus_style, in_focus_style)
    |> maybe_put(:active_style, active_style)
    |> maybe_put(:disabled_style, disabled_style)
    |> maybe_put(:disabled, disabled)
    |> maybe_put(:stack_priority, stack_priority)
    |> maybe_put(:occlude, occlude)
    |> maybe_put(:focusable, focusable)
    |> maybe_put(:tab_stop, tab_stop)
    |> maybe_put(:tab_index, tab_index)
    |> maybe_put(:track_scroll, track_scroll)
    |> maybe_put(:anchor_scroll, anchor_scroll)
    |> maybe_put(:actions, actions)
    |> maybe_put(:shortcuts, shortcuts)
    |> maybe_put(:events, events)
  end

  @spec scroll([ir_node()], keyword()) :: scroll_node()
  def scroll(children, opts \\ []) when is_list(children) and is_list(opts) do
    id = Keyword.get(opts, :id)
    axis = Keyword.get(opts, :axis)
    style = Keyword.get(opts, :style)

    %{kind: :scroll, children: children}
    |> maybe_put(:id, id)
    |> maybe_put(:axis, axis)
    |> maybe_put(:style, style)
  end

  @spec image(image_source(), keyword()) :: image_node()
  def image(source, opts \\ []) when is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    object_fit = Keyword.get(opts, :object_fit)
    grayscale = Keyword.get(opts, :grayscale)

    %{kind: :image, source: source}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:object_fit, object_fit)
    |> maybe_put(:grayscale, grayscale)
  end

  @spec spacer(keyword()) :: spacer_node()
  def spacer(opts \\ []) when is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)

    %{kind: :spacer}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
  end

  @spec button(String.t(), keyword()) :: button_node()
  def button(label, opts \\ []) when is_binary(label) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    events = Keyword.get(opts, :events)
    hover_style = Keyword.get(opts, :hover_style)
    focus_style = Keyword.get(opts, :focus_style)
    in_focus_style = Keyword.get(opts, :in_focus_style)
    active_style = Keyword.get(opts, :active_style)
    disabled_style = Keyword.get(opts, :disabled_style)
    disabled = Keyword.get(opts, :disabled)
    tab_index = Keyword.get(opts, :tab_index)
    actions = Keyword.get(opts, :actions)
    shortcuts = Keyword.get(opts, :shortcuts)

    %{kind: :button, label: label}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:hover_style, hover_style)
    |> maybe_put(:focus_style, focus_style)
    |> maybe_put(:in_focus_style, in_focus_style)
    |> maybe_put(:active_style, active_style)
    |> maybe_put(:disabled_style, disabled_style)
    |> maybe_put(:disabled, disabled)
    |> maybe_put(:tab_index, tab_index)
    |> maybe_put(:actions, actions)
    |> maybe_put(:shortcuts, shortcuts)
    |> maybe_put(:events, events)
  end

  @spec text_input(String.t(), keyword()) :: text_input_node()
  def text_input(value, opts \\ []) when is_binary(value) and is_list(opts) do
    id = Keyword.get(opts, :id)
    placeholder = Keyword.get(opts, :placeholder)
    style = Keyword.get(opts, :style)
    disabled = Keyword.get(opts, :disabled)
    tab_index = Keyword.get(opts, :tab_index)
    events = Keyword.get(opts, :events)

    %{kind: :text_input, value: value}
    |> maybe_put(:id, id)
    |> maybe_put(:placeholder, placeholder)
    |> maybe_put(:style, style)
    |> maybe_put(:disabled, disabled)
    |> maybe_put(:tab_index, tab_index)
    |> maybe_put(:events, events)
  end

  @spec validate(ir_node()) :: :ok | {:error, term()}
  def validate(ir) do
    with :ok <- validate_node(ir),
         :ok <- validate_unique_ids(ir) do
      :ok
    end
  end

  defp validate_node(%{kind: :text, content: content} = node) when is_binary(content) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_events(Map.get(node, :events), [:click]) do
      :ok
    end
  end

  defp validate_node(%{kind: :div, children: children} = node) when is_list(children) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :hover_style)),
         :ok <- validate_style(Map.get(node, :focus_style)),
         :ok <- validate_style(Map.get(node, :in_focus_style)),
         :ok <- validate_style(Map.get(node, :active_style)),
         :ok <- validate_style(Map.get(node, :disabled_style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_optional_non_neg_integer(Map.get(node, :stack_priority), :stack_priority),
         :ok <- validate_optional_boolean(Map.get(node, :occlude), :occlude),
         :ok <- validate_optional_boolean(Map.get(node, :focusable), :focusable),
         :ok <- validate_optional_boolean(Map.get(node, :tab_stop), :tab_stop),
         :ok <- validate_optional_integer(Map.get(node, :tab_index), :tab_index),
         :ok <- validate_optional_boolean(Map.get(node, :track_scroll), :track_scroll),
         :ok <- validate_optional_boolean(Map.get(node, :anchor_scroll), :anchor_scroll),
         :ok <- validate_actions(Map.get(node, :actions)),
         :ok <- validate_shortcuts(Map.get(node, :shortcuts), Map.get(node, :actions)),
         :ok <-
           validate_events(Map.get(node, :events), [
             :click,
             :hover,
             :focus,
             :blur,
             :key_down,
             :key_up,
             :context_menu,
             :drag_start,
             :drag_move,
             :drop,
             :mouse_down,
             :mouse_up,
             :mouse_move,
             :scroll_wheel
           ]),
         :ok <- validate_children(children) do
      :ok
    end
  end

  defp validate_node(%{kind: :scroll, children: children} = node) when is_list(children) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_scroll_axis(Map.get(node, :axis)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_children(children) do
      :ok
    end
  end

  defp validate_node(%{kind: :image, source: source} = node) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_image_source(source),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_image_object_fit(Map.get(node, :object_fit)),
         :ok <- validate_optional_boolean(Map.get(node, :grayscale), :grayscale) do
      :ok
    end
  end

  defp validate_node(%{kind: :spacer} = node) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)) do
      :ok
    end
  end

  defp validate_node(%{kind: :button, label: label} = node) when is_binary(label) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :hover_style)),
         :ok <- validate_style(Map.get(node, :focus_style)),
         :ok <- validate_style(Map.get(node, :in_focus_style)),
         :ok <- validate_style(Map.get(node, :active_style)),
         :ok <- validate_style(Map.get(node, :disabled_style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_optional_integer(Map.get(node, :tab_index), :tab_index),
         :ok <- validate_actions(Map.get(node, :actions)),
         :ok <- validate_shortcuts(Map.get(node, :shortcuts), Map.get(node, :actions)),
         :ok <-
           validate_events(Map.get(node, :events), [
             :click,
             :hover,
             :focus,
             :blur,
             :key_down,
             :key_up,
             :context_menu,
             :mouse_down,
             :mouse_up,
             :mouse_move
           ]) do
      :ok
    end
  end

  defp validate_node(%{kind: :text_input, value: value} = node) when is_binary(value) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_optional_string(Map.get(node, :placeholder), :placeholder),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_optional_integer(Map.get(node, :tab_index), :tab_index),
         :ok <- validate_events(Map.get(node, :events), [:change]) do
      :ok
    end
  end

  defp validate_node(other), do: {:error, {:invalid_ir, other}}

  defp validate_children(children) do
    Enum.reduce_while(children, :ok, fn child, :ok ->
      case validate_node(child) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_unique_ids(ir) do
    case collect_ids(ir, MapSet.new()) do
      {:ok, _ids} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp collect_ids(%{id: id} = node, ids) when is_binary(id) do
    if MapSet.member?(ids, id) do
      {:error, {:duplicate_id, id}}
    else
      collect_child_ids(node, MapSet.put(ids, id))
    end
  end

  defp collect_ids(node, ids), do: collect_child_ids(node, ids)

  defp collect_child_ids(%{kind: kind, children: children}, ids)
       when kind in [:div, :scroll] and is_list(children) do
    Enum.reduce_while(children, {:ok, ids}, fn child, {:ok, acc_ids} ->
      case collect_ids(child, acc_ids) do
        {:ok, next_ids} -> {:cont, {:ok, next_ids}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp collect_child_ids(_node, ids), do: {:ok, ids}

  defp validate_id(nil), do: :ok
  defp validate_id(id) when is_binary(id), do: :ok
  defp validate_id(other), do: {:error, {:invalid_id, other}}

  defp validate_optional_boolean(nil, _field), do: :ok
  defp validate_optional_boolean(value, _field) when is_boolean(value), do: :ok
  defp validate_optional_boolean(value, field), do: {:error, {field, value}}

  defp validate_optional_integer(nil, _field), do: :ok
  defp validate_optional_integer(value, _field) when is_integer(value), do: :ok
  defp validate_optional_integer(value, field), do: {:error, {field, value}}

  defp validate_optional_string(nil, _field), do: :ok
  defp validate_optional_string(value, _field) when is_binary(value), do: :ok
  defp validate_optional_string(value, field), do: {:error, {field, value}}

  defp validate_optional_non_neg_integer(nil, _field), do: :ok

  defp validate_optional_non_neg_integer(value, _field) when is_integer(value) and value >= 0,
    do: :ok

  defp validate_optional_non_neg_integer(value, field), do: {:error, {field, value}}

  defp validate_scroll_axis(nil), do: :ok
  defp validate_scroll_axis(axis) when axis in [:x, :y, :both], do: :ok
  defp validate_scroll_axis(axis), do: {:error, {:invalid_scroll_axis, axis}}

  defp validate_image_source(source) when is_binary(source), do: :ok

  defp validate_image_source({kind, value})
       when kind in [:uri, :path, :embedded] and is_binary(value), do: :ok

  defp validate_image_source(source), do: {:error, {:invalid_image_source, source}}

  defp validate_image_object_fit(nil), do: :ok

  defp validate_image_object_fit(fit) when fit in [:fill, :contain, :cover, :scale_down, :none],
    do: :ok

  defp validate_image_object_fit(fit), do: {:error, {:invalid_image_object_fit, fit}}

  defp validate_style(nil), do: :ok

  defp validate_style(style) when is_list(style) do
    Enum.reduce_while(style, :ok, fn op, :ok ->
      case validate_style_op(op) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_style(other), do: {:error, {:invalid_style_list, other}}

  defp validate_style_op(op) when op in @style_flag_tokens, do: :ok

  defp validate_style_op({key, value})
       when key in @color_style_value_tokens and value in @color_tokens,
       do: :ok

  defp validate_style_op({key, value})
       when key in @hex_color_style_value_tokens and is_binary(value) do
    if Regex.match?(~r/^#?[0-9a-fA-F]{6}$/, value) do
      :ok
    else
      {:error, {:invalid_style_op, {key, value}}}
    end
  end

  defp validate_style_op({:opacity, value})
       when is_number(value) and value >= 0.0 and value <= 1.0,
       do: :ok

  defp validate_style_op({key, value})
       when key in @size_value_tokens and is_number(value) and value >= 0.0,
       do: :ok

  defp validate_style_op({key, value})
       when key in @fraction_value_tokens and is_number(value) and value >= 0.0 and value <= 1.0,
       do: :ok

  defp validate_style_op({key, value})
       when key in @scrollbar_value_tokens and is_number(value) and value >= 0.0,
       do: :ok

  defp validate_style_op(other), do: {:error, {:invalid_style_op, other}}

  defp validate_actions(nil), do: :ok

  defp validate_actions(actions) when is_map(actions) do
    Enum.reduce_while(actions, :ok, fn
      {action_name, callback_id}, :ok when is_binary(action_name) and is_binary(callback_id) ->
        {:cont, :ok}

      {action_name, callback_id}, :ok ->
        {:halt, {:error, {:invalid_action_binding, action_name, callback_id}}}
    end)
  end

  defp validate_actions(other), do: {:error, {:invalid_actions, other}}

  defp validate_shortcuts(nil, _actions), do: :ok

  defp validate_shortcuts(shortcuts, actions) when is_list(shortcuts) do
    action_names =
      case actions do
        nil -> MapSet.new()
        %{} -> Map.keys(actions) |> MapSet.new()
      end

    Enum.reduce_while(shortcuts, :ok, fn
      {shortcut, action_name}, :ok
      when is_binary(shortcut) and is_binary(action_name) and shortcut != "" ->
        if MapSet.member?(action_names, action_name) do
          {:cont, :ok}
        else
          {:halt, {:error, {:unknown_shortcut_action, shortcut, action_name}}}
        end

      other, :ok ->
        {:halt, {:error, {:invalid_shortcut_binding, other}}}
    end)
  end

  defp validate_shortcuts(other, _actions), do: {:error, {:invalid_shortcuts, other}}

  defp validate_events(nil, _allowed), do: :ok

  defp validate_events(events, allowed) when is_map(events) do
    Enum.reduce_while(events, :ok, fn
      {event_name, callback_id}, :ok ->
        if event_name in allowed and is_binary(callback_id) do
          {:cont, :ok}
        else
          {:halt, {:error, {:invalid_event, event_name, callback_id}}}
        end
    end)
  end

  defp validate_events(other, _allowed), do: {:error, {:invalid_events, other}}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
