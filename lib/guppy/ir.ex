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

  @type style_op :: style_flag() | style_value()
  @type style :: [style_op()]

  @type events :: %{optional(:click) => String.t()}

  @type text_node :: %{
          required(:kind) => :text,
          required(:content) => String.t(),
          optional(:id) => node_id(),
          optional(:events) => events()
        }

  @type div_node :: %{
          required(:kind) => :div,
          required(:children) => [ir_node()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:events) => events()
        }

  @type ir_node :: text_node() | div_node()

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

  @style_value_tokens [:bg, :text_color, :border_color]
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

    %{kind: :div, children: children}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:events, events)
  end

  @spec validate(ir_node()) :: :ok | {:error, term()}
  def validate(%{kind: :text, content: content} = node) when is_binary(content) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_events(Map.get(node, :events)) do
      :ok
    end
  end

  def validate(%{kind: :div, children: children} = node) when is_list(children) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_events(Map.get(node, :events)),
         :ok <- validate_children(children) do
      :ok
    end
  end

  def validate(other), do: {:error, {:invalid_ir, other}}

  defp validate_children(children) do
    Enum.reduce_while(children, :ok, fn child, :ok ->
      case validate(child) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_id(nil), do: :ok
  defp validate_id(id) when is_binary(id), do: :ok
  defp validate_id(other), do: {:error, {:invalid_id, other}}

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

  defp validate_style_op({key, value}) when key in @style_value_tokens and value in @color_tokens,
    do: :ok

  defp validate_style_op(other), do: {:error, {:invalid_style_op, other}}

  defp validate_events(nil), do: :ok

  defp validate_events(events) when is_map(events) do
    Enum.reduce_while(events, :ok, fn
      {:click, callback_id}, :ok when is_binary(callback_id) ->
        {:cont, :ok}

      {event_name, callback_id}, :ok ->
        {:halt, {:error, {:invalid_event, event_name, callback_id}}}
    end)
  end

  defp validate_events(other), do: {:error, {:invalid_events, other}}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
