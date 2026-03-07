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
          optional(:mouse_down) => String.t(),
          optional(:mouse_up) => String.t(),
          optional(:mouse_move) => String.t(),
          optional(:scroll_wheel) => String.t()
        }

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
          optional(:track_scroll) => boolean(),
          optional(:anchor_scroll) => boolean(),
          optional(:events) => div_events()
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
    track_scroll = Keyword.get(opts, :track_scroll)
    anchor_scroll = Keyword.get(opts, :anchor_scroll)

    %{kind: :div, children: children}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:hover_style, hover_style)
    |> maybe_put(:track_scroll, track_scroll)
    |> maybe_put(:anchor_scroll, anchor_scroll)
    |> maybe_put(:events, events)
  end

  @spec validate(ir_node()) :: :ok | {:error, term()}
  def validate(%{kind: :text, content: content} = node) when is_binary(content) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_events(Map.get(node, :events), [:click]) do
      :ok
    end
  end

  def validate(%{kind: :div, children: children} = node) when is_list(children) do
    with :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :hover_style)),
         :ok <- validate_optional_boolean(Map.get(node, :track_scroll), :track_scroll),
         :ok <- validate_optional_boolean(Map.get(node, :anchor_scroll), :anchor_scroll),
         :ok <-
           validate_events(Map.get(node, :events), [
             :click,
             :hover,
             :mouse_down,
             :mouse_up,
             :mouse_move,
             :scroll_wheel
           ]),
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

  defp validate_optional_boolean(nil, _field), do: :ok
  defp validate_optional_boolean(value, _field) when is_boolean(value), do: :ok
  defp validate_optional_boolean(value, field), do: {:error, {field, value}}

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
