defmodule Guppy.IR.Validated do
  @moduledoc """
  Wrapper for an IR tree that has already passed Elixir-side validation.
  """

  @type t :: %__MODULE__{ir: term()}

  @enforce_keys [:ir]
  defstruct [:ir]
end

defmodule Guppy.IR do
  @moduledoc """
  Helpers and validation for Guppy's Elixir-owned UI IR.

  Elixir processes build full-tree IR values, Guppy validates the supported
  schema, and the native runtime renders those trees through GPUI while routing
  events back to the owning process.

  Style tokens are represented as ordered lists. That order is preserved across
  the bridge so later tokens can override earlier ones.
  """

  @type node_id :: String.t()
  @type color_token :: :red | :green | :blue | :yellow | :black | :white | :gray
  @type gradient_color :: color_token() | String.t()
  @type linear_gradient_stop :: {gradient_color(), number()}

  @type style_flag ::
          :grid
          | :flex
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
          | :col_span_full
          | :row_span_full
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

  @type style_length :: {:px, number()} | {:rem, number()} | {:fraction, number()}
  @type style_axis :: :all | :x | :y | :top | :right | :bottom | :left

  @type style_value ::
          {:padding, style_axis(), style_length()}
          | {:margin, style_axis(), style_length() | :auto}
          | {:gap, :all | :x | :y, style_length()}
          | {:width, style_length() | :auto}
          | {:height, style_length() | :auto}
          | {:size, style_length() | :auto}
          | {:min_width, style_length() | :auto}
          | {:min_height, style_length() | :auto}
          | {:max_width, style_length() | :auto}
          | {:max_height, style_length() | :auto}
          | {:position, :relative | :absolute}
          | {:inset, :all | :top | :right | :bottom | :left, style_length() | :auto}
          | {:display, :block | :flex | :grid | :none}
          | {:visibility, :visible | :hidden}
          | {:overflow, :all | :x | :y, :hidden | :scroll}
          | {:bg, color_token()}
          | {:text_color, color_token()}
          | {:border_color, color_token()}
          | {:bg_hex, String.t()}
          | {:text_color_hex, String.t()}
          | {:border_color_hex, String.t()}
          | {:bg_linear_gradient,
             [angle: number(), from: linear_gradient_stop(), to: linear_gradient_stop()]}
          | {:opacity, number()}
          | {:grid_cols, pos_integer()}
          | {:grid_rows, pos_integer()}
          | {:col_span, pos_integer()}
          | {:row_span, pos_integer()}
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
  @type text_run :: %{required(:text) => String.t(), optional(:style) => style()}

  @type animation :: %{
          required(:id) => String.t(),
          optional(:duration_ms) => pos_integer(),
          optional(:repeat) => boolean(),
          optional(:from) => number(),
          optional(:to) => number()
        }

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
          optional(:style) => style(),
          optional(:runs) => [text_run()],
          optional(:events) => text_events()
        }

  @type div_node :: %{
          required(:kind) => :div,
          required(:children) => [ir_node()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:hover_style) => style(),
          optional(:focus_style) => style(),
          optional(:focus_visible_style) => style(),
          optional(:in_focus_style) => style(),
          optional(:active_style) => style(),
          optional(:disabled_style) => style(),
          optional(:animation) => animation(),
          optional(:disabled) => boolean(),
          optional(:stack_priority) => non_neg_integer(),
          optional(:occlude) => boolean(),
          optional(:focusable) => boolean(),
          optional(:tab_stop) => boolean(),
          optional(:tab_index) => integer(),
          optional(:track_scroll) => boolean(),
          optional(:anchor_scroll) => boolean(),
          optional(:scroll_to) => boolean(),
          optional(:tooltip) => String.t(),
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

  @type icon_node :: %{
          required(:kind) => :icon,
          required(:source) => image_source(),
          optional(:id) => node_id(),
          optional(:style) => style()
        }

  @type button_events :: %{
          optional(:click) => String.t(),
          optional(:hover) => String.t(),
          optional(:focus) => String.t(),
          optional(:blur) => String.t(),
          optional(:key_down) => String.t(),
          optional(:key_up) => String.t(),
          optional(:context_menu) => String.t(),
          optional(:mouse_down) => String.t(),
          optional(:mouse_up) => String.t(),
          optional(:mouse_move) => String.t()
        }

  @type button_node :: %{
          required(:kind) => :button,
          required(:label) => String.t(),
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:hover_style) => style(),
          optional(:focus_style) => style(),
          optional(:focus_visible_style) => style(),
          optional(:in_focus_style) => style(),
          optional(:active_style) => style(),
          optional(:disabled_style) => style(),
          optional(:animation) => animation(),
          optional(:disabled) => boolean(),
          optional(:tab_index) => integer(),
          optional(:actions) => action_bindings(),
          optional(:shortcuts) => [shortcut_binding()],
          optional(:events) => button_events()
        }

  @type checkbox_events :: %{
          optional(:change) => String.t(),
          optional(:focus) => String.t(),
          optional(:blur) => String.t()
        }

  @type checkbox_node :: %{
          required(:kind) => :checkbox,
          required(:label) => String.t(),
          required(:checked) => boolean(),
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:hover_style) => style(),
          optional(:focus_style) => style(),
          optional(:focus_visible_style) => style(),
          optional(:in_focus_style) => style(),
          optional(:active_style) => style(),
          optional(:disabled_style) => style(),
          optional(:disabled) => boolean(),
          optional(:tab_index) => integer(),
          optional(:events) => checkbox_events()
        }

  @type radio_node :: %{
          required(:kind) => :radio,
          required(:label) => String.t(),
          required(:value) => String.t(),
          required(:checked) => boolean(),
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:hover_style) => style(),
          optional(:focus_style) => style(),
          optional(:focus_visible_style) => style(),
          optional(:in_focus_style) => style(),
          optional(:active_style) => style(),
          optional(:disabled_style) => style(),
          optional(:disabled) => boolean(),
          optional(:tab_index) => integer(),
          optional(:events) => checkbox_events()
        }

  @type select_option :: %{
          required(:value) => String.t(),
          required(:label) => String.t(),
          optional(:disabled) => boolean()
        }

  @type select_events :: %{
          optional(:click) => String.t(),
          optional(:change) => String.t(),
          optional(:close) => String.t(),
          optional(:focus) => String.t(),
          optional(:blur) => String.t()
        }

  @type select_node :: %{
          required(:kind) => :select,
          required(:options) => [select_option()],
          optional(:id) => node_id(),
          optional(:value) => String.t(),
          optional(:open) => boolean(),
          optional(:placeholder) => String.t(),
          optional(:style) => style(),
          optional(:list_style) => style(),
          optional(:option_style) => style(),
          optional(:disabled) => boolean(),
          optional(:tab_index) => integer(),
          optional(:events) => select_events()
        }

  @type uniform_list_item :: %{required(:id) => node_id(), required(:label) => String.t()}

  @type uniform_list_node :: %{
          required(:kind) => :uniform_list,
          required(:items) => [uniform_list_item()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:item_style) => style(),
          optional(:events) => text_events()
        }

  @type list_row_click_events :: %{optional(:click) => String.t()}
  @type list_row_change_events :: %{optional(:change) => String.t()}

  @type list_row_div_node :: %{
          required(:kind) => :div,
          required(:children) => [list_row_node()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:disabled) => boolean(),
          optional(:events) => list_row_click_events()
        }

  @type list_row_button_node :: %{
          required(:kind) => :button,
          required(:label) => String.t(),
          required(:id) => node_id(),
          optional(:style) => style(),
          optional(:hover_style) => style(),
          optional(:focus_style) => style(),
          optional(:focus_visible_style) => style(),
          optional(:in_focus_style) => style(),
          optional(:active_style) => style(),
          optional(:disabled_style) => style(),
          optional(:disabled) => boolean(),
          optional(:tab_index) => integer(),
          optional(:events) => list_row_click_events()
        }

  @type list_row_checkbox_node :: %{
          required(:kind) => :checkbox,
          required(:label) => String.t(),
          required(:checked) => boolean(),
          required(:id) => node_id(),
          optional(:style) => style(),
          optional(:hover_style) => style(),
          optional(:focus_style) => style(),
          optional(:focus_visible_style) => style(),
          optional(:in_focus_style) => style(),
          optional(:active_style) => style(),
          optional(:disabled_style) => style(),
          optional(:disabled) => boolean(),
          optional(:tab_index) => integer(),
          optional(:events) => list_row_change_events()
        }

  @type list_row_radio_node :: %{
          required(:kind) => :radio,
          required(:label) => String.t(),
          required(:value) => String.t(),
          required(:checked) => boolean(),
          required(:id) => node_id(),
          optional(:style) => style(),
          optional(:hover_style) => style(),
          optional(:focus_style) => style(),
          optional(:focus_visible_style) => style(),
          optional(:in_focus_style) => style(),
          optional(:active_style) => style(),
          optional(:disabled_style) => style(),
          optional(:disabled) => boolean(),
          optional(:tab_index) => integer(),
          optional(:events) => list_row_change_events()
        }

  @type list_row_node ::
          text_node()
          | spacer_node()
          | list_row_div_node()
          | list_row_button_node()
          | list_row_checkbox_node()
          | list_row_radio_node()

  @type list_item :: %{required(:id) => node_id(), required(:children) => [list_row_node()]}

  @type data_table_cell_div_node :: %{
          required(:kind) => :div,
          required(:children) => [data_table_cell_node()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:disabled) => boolean(),
          optional(:events) => list_row_click_events()
        }

  @type data_table_cell_node :: text_node() | spacer_node() | data_table_cell_div_node()

  @type list_node :: %{
          required(:kind) => :list,
          required(:items) => [list_item()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:item_style) => style(),
          optional(:events) => text_events()
        }

  @type data_table_column_width :: :auto | {:px, number()} | {:fr, pos_integer()}

  @type data_table_column :: %{
          required(:id) => node_id(),
          required(:label) => String.t(),
          optional(:width) => data_table_column_width(),
          optional(:sortable) => boolean(),
          optional(:style) => style()
        }

  @type data_table_cell :: %{
          required(:column_id) => node_id(),
          required(:children) => [data_table_cell_node()],
          optional(:style) => style()
        }

  @type data_table_row :: %{
          required(:id) => node_id(),
          required(:cells) => [data_table_cell()],
          optional(:style) => style()
        }

  @type data_table_events :: %{
          optional(:row_click) => String.t(),
          optional(:cell_click) => String.t(),
          optional(:sort) => String.t()
        }

  @type data_table_sort :: %{
          required(:column_id) => node_id(),
          required(:direction) => :asc | :desc
        }

  @type data_table_node :: %{
          required(:kind) => :data_table,
          required(:columns) => [data_table_column()],
          required(:rows) => [data_table_row()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:header_style) => style(),
          optional(:row_style) => style(),
          optional(:cell_style) => style(),
          optional(:selected_row_id) => node_id(),
          optional(:selected_cell) => {node_id(), node_id()},
          optional(:sort) => data_table_sort(),
          optional(:events) => data_table_events()
        }

  @type tree_item :: %{
          required(:id) => node_id(),
          required(:label) => String.t(),
          optional(:expanded) => boolean(),
          optional(:children) => [tree_item()],
          optional(:style) => style()
        }

  @type tree_events :: %{optional(:select) => String.t(), optional(:toggle) => String.t()}

  @type tree_node :: %{
          required(:kind) => :tree,
          required(:nodes) => [tree_item()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:row_style) => style(),
          optional(:selected_id) => node_id(),
          optional(:events) => tree_events()
        }

  @type canvas_color :: gradient_color()

  @type canvas_rect_command :: %{
          required(:op) => :rect,
          required(:x) => number(),
          required(:y) => number(),
          required(:width) => number(),
          required(:height) => number(),
          required(:fill) => canvas_color(),
          optional(:radius) => number()
        }

  @type canvas_rounded_rect_command :: %{
          required(:op) => :rounded_rect,
          required(:x) => number(),
          required(:y) => number(),
          required(:width) => number(),
          required(:height) => number(),
          required(:fill) => canvas_color(),
          required(:radius) => number()
        }

  @type canvas_pattern_rect_command :: %{
          required(:op) => :pattern_rect,
          required(:x) => number(),
          required(:y) => number(),
          required(:width) => number(),
          required(:height) => number(),
          required(:color) => canvas_color(),
          required(:line_width) => number(),
          required(:interval) => number(),
          optional(:radius) => number()
        }

  @type canvas_command ::
          canvas_rect_command() | canvas_rounded_rect_command() | canvas_pattern_rect_command()

  @type canvas_events :: %{optional(:click) => String.t()}

  @type canvas_node :: %{
          required(:kind) => :canvas,
          required(:commands) => [canvas_command()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:events) => canvas_events()
        }

  @type popover_events :: %{optional(:click) => String.t(), optional(:close) => String.t()}
  @type popover_anchor :: :top_left | :top_right | :bottom_left | :bottom_right
  @type popover_anchor_position_mode :: :window | :local
  @type popover_anchor_fit :: :switch_anchor | :snap_to_window | :snap_to_window_with_margin
  @type point :: {number(), number()}

  @type popover_node :: %{
          required(:kind) => :popover,
          required(:label) => String.t(),
          required(:open) => boolean(),
          required(:children) => [ir_node()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:popover_style) => style(),
          optional(:anchor) => popover_anchor(),
          optional(:anchor_position) => point(),
          optional(:anchor_offset) => point(),
          optional(:anchor_position_mode) => popover_anchor_position_mode(),
          optional(:anchor_fit) => popover_anchor_fit(),
          optional(:snap_margin) => number(),
          optional(:close_on_click_outside) => boolean(),
          optional(:stack_priority) => non_neg_integer(),
          optional(:disabled) => boolean(),
          optional(:events) => popover_events()
        }

  @type spacer_node :: %{
          required(:kind) => :spacer,
          optional(:id) => node_id(),
          optional(:style) => style()
        }

  @type text_input_events :: %{
          optional(:change) => String.t(),
          optional(:focus) => String.t(),
          optional(:blur) => String.t()
        }

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

  @type textarea_node :: %{
          required(:kind) => :textarea,
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
          | icon_node()
          | button_node()
          | checkbox_node()
          | radio_node()
          | select_node()
          | uniform_list_node()
          | list_node()
          | data_table_node()
          | tree_node()
          | canvas_node()
          | popover_node()
          | spacer_node()
          | text_input_node()
          | textarea_node()

  @style_flag_tokens [
    :grid,
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
    :col_span_full,
    :row_span_full,
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

  @style_axis_tokens [:all, :x, :y, :top, :right, :bottom, :left]
  @gap_axis_tokens [:all, :x, :y]
  @inset_axis_tokens [:all, :top, :right, :bottom, :left]
  @position_value_tokens [:relative, :absolute]
  @display_value_tokens [:block, :flex, :grid, :none]
  @visibility_value_tokens [:visible, :hidden]
  @overflow_value_tokens [:hidden, :scroll]
  @color_style_value_tokens [:bg, :text_color, :border_color]
  @hex_color_style_value_tokens [:bg_hex, :text_color_hex, :border_color_hex]
  @size_value_tokens [:w_px, :w_rem, :h_px, :h_rem]
  @fraction_value_tokens [:w_frac, :h_frac]
  @scrollbar_value_tokens [:scrollbar_width_px, :scrollbar_width_rem]
  @length_style_value_tokens [
    :width,
    :height,
    :size,
    :min_width,
    :min_height,
    :max_width,
    :max_height
  ]
  @grid_value_tokens [:grid_cols, :grid_rows, :col_span, :row_span]
  @color_tokens [:red, :green, :blue, :yellow, :black, :white, :gray]
  @native_f32_integer_min -9_223_372_036_854_775_808
  @native_f32_integer_max 9_223_372_036_854_775_807
  @native_f32_max 3.402_823_466_385_288_6e38

  defguardp is_native_f32_number(value)
            when (is_float(value) and value >= -@native_f32_max and value <= @native_f32_max) or
                   (is_integer(value) and value >= @native_f32_integer_min and
                      value <= @native_f32_integer_max)

  defguardp is_positive_native_f32_number(value)
            when is_native_f32_number(value) and value > 0

  defguardp is_non_neg_native_f32_number(value)
            when is_native_f32_number(value) and value >= 0

  defguardp is_unit_native_f32_number(value)
            when is_native_f32_number(value) and value >= 0 and value <= 1

  defguardp is_positive_unit_native_f32_number(value)
            when is_native_f32_number(value) and value > 0 and value <= 1

  @uniform_list_item_keys [:id, :label]
  @list_item_keys [:id, :children]
  @data_table_column_keys [:id, :label, :width, :sortable, :style]
  @data_table_row_keys [:id, :cells, :style]
  @data_table_cell_keys [:column_id, :children, :style]
  @data_table_sort_keys [:column_id, :direction]
  @tree_item_keys [:id, :label, :expanded, :children, :style]
  @canvas_command_keys [
    :op,
    :x,
    :y,
    :width,
    :height,
    :fill,
    :color,
    :line_width,
    :interval,
    :radius
  ]
  @select_option_keys [:value, :label, :disabled]
  @list_row_div_keys [:kind, :children, :id, :style, :disabled, :events]
  @list_row_control_kinds [:button, :checkbox, :radio]
  @list_row_button_keys [
    :kind,
    :label,
    :id,
    :style,
    :hover_style,
    :focus_style,
    :focus_visible_style,
    :in_focus_style,
    :active_style,
    :disabled_style,
    :disabled,
    :tab_index,
    :events
  ]
  @list_row_checkbox_keys [
    :kind,
    :label,
    :checked,
    :id,
    :style,
    :hover_style,
    :focus_style,
    :focus_visible_style,
    :in_focus_style,
    :active_style,
    :disabled_style,
    :disabled,
    :tab_index,
    :events
  ]
  @list_row_radio_keys [:value | @list_row_checkbox_keys]

  @spec text(String.t(), keyword()) :: text_node()
  def text(content, opts \\ []) when is_binary(content) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    events = Keyword.get(opts, :events)

    %{kind: :text, content: content}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:events, events)
  end

  @spec rich_text([text_run() | String.t() | {String.t(), style()}], keyword()) :: text_node()
  def rich_text(runs, opts \\ []) when is_list(runs) and is_list(opts) do
    normalized_runs = Enum.map(runs, &normalize_text_run!/1)
    content = Enum.map_join(normalized_runs, & &1.text)

    text(content, opts)
    |> Map.put(:runs, normalized_runs)
  end

  defp normalize_text_run!(text) when is_binary(text), do: %{text: text}

  defp normalize_text_run!(%{text: text} = run) when is_binary(text) do
    %{text: text}
    |> maybe_put(:style, Map.get(run, :style))
  end

  defp normalize_text_run!({text, style}) when is_binary(text) do
    %{text: text, style: style}
  end

  defp normalize_text_run!(other) do
    raise ArgumentError, "invalid rich text run: #{inspect(other)}"
  end

  @spec div([ir_node()], keyword()) :: div_node()
  def div(children, opts \\ []) when is_list(children) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    events = Keyword.get(opts, :events)
    hover_style = Keyword.get(opts, :hover_style)
    focus_style = Keyword.get(opts, :focus_style)
    focus_visible_style = Keyword.get(opts, :focus_visible_style)
    in_focus_style = Keyword.get(opts, :in_focus_style)
    active_style = Keyword.get(opts, :active_style)
    disabled_style = Keyword.get(opts, :disabled_style)
    animation = Keyword.get(opts, :animation)
    disabled = Keyword.get(opts, :disabled)
    stack_priority = Keyword.get(opts, :stack_priority)
    occlude = Keyword.get(opts, :occlude)
    focusable = Keyword.get(opts, :focusable)
    tab_stop = Keyword.get(opts, :tab_stop)
    tab_index = Keyword.get(opts, :tab_index)
    track_scroll = Keyword.get(opts, :track_scroll)
    anchor_scroll = Keyword.get(opts, :anchor_scroll)
    scroll_to = Keyword.get(opts, :scroll_to)
    tooltip = Keyword.get(opts, :tooltip)
    actions = Keyword.get(opts, :actions)
    shortcuts = Keyword.get(opts, :shortcuts)

    %{kind: :div, children: children}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:hover_style, hover_style)
    |> maybe_put(:focus_style, focus_style)
    |> maybe_put(:focus_visible_style, focus_visible_style)
    |> maybe_put(:in_focus_style, in_focus_style)
    |> maybe_put(:active_style, active_style)
    |> maybe_put(:disabled_style, disabled_style)
    |> maybe_put(:animation, animation)
    |> maybe_put(:disabled, disabled)
    |> maybe_put(:stack_priority, stack_priority)
    |> maybe_put(:occlude, occlude)
    |> maybe_put(:focusable, focusable)
    |> maybe_put(:tab_stop, tab_stop)
    |> maybe_put(:tab_index, tab_index)
    |> maybe_put(:track_scroll, track_scroll)
    |> maybe_put(:anchor_scroll, anchor_scroll)
    |> maybe_put(:scroll_to, scroll_to)
    |> maybe_put(:tooltip, tooltip)
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

  @spec popover(String.t(), boolean(), [ir_node()], keyword()) :: popover_node()
  def popover(label, open, children, opts \\ [])
      when is_binary(label) and is_boolean(open) and is_list(children) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    popover_style = Keyword.get(opts, :popover_style)
    anchor = Keyword.get(opts, :anchor)
    anchor_position = Keyword.get(opts, :anchor_position)
    anchor_offset = Keyword.get(opts, :anchor_offset)
    anchor_position_mode = Keyword.get(opts, :anchor_position_mode)
    anchor_fit = Keyword.get(opts, :anchor_fit)
    snap_margin = Keyword.get(opts, :snap_margin)
    close_on_click_outside = Keyword.get(opts, :close_on_click_outside)
    stack_priority = Keyword.get(opts, :stack_priority)
    disabled = Keyword.get(opts, :disabled)
    events = Keyword.get(opts, :events)

    %{kind: :popover, label: label, open: open, children: children}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:popover_style, popover_style)
    |> maybe_put(:anchor, anchor)
    |> maybe_put(:anchor_position, anchor_position)
    |> maybe_put(:anchor_offset, anchor_offset)
    |> maybe_put(:anchor_position_mode, anchor_position_mode)
    |> maybe_put(:anchor_fit, anchor_fit)
    |> maybe_put(:snap_margin, snap_margin)
    |> maybe_put(:close_on_click_outside, close_on_click_outside)
    |> maybe_put(:stack_priority, stack_priority)
    |> maybe_put(:disabled, disabled)
    |> maybe_put(:events, events)
  end

  @spec uniform_list([uniform_list_item()], keyword()) :: uniform_list_node()
  def uniform_list(items, opts \\ []) when is_list(items) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    item_style = Keyword.get(opts, :item_style)
    events = Keyword.get(opts, :events)

    %{kind: :uniform_list, items: items}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:item_style, item_style)
    |> maybe_put(:events, events)
  end

  @spec list([list_item()], keyword()) :: list_node()
  def list(items, opts \\ []) when is_list(items) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    item_style = Keyword.get(opts, :item_style)
    events = Keyword.get(opts, :events)

    %{kind: :list, items: items}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:item_style, item_style)
    |> maybe_put(:events, events)
  end

  @spec data_table([data_table_column()], [data_table_row()], keyword()) :: data_table_node()
  def data_table(columns, rows, opts \\ [])
      when is_list(columns) and is_list(rows) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    header_style = Keyword.get(opts, :header_style)
    row_style = Keyword.get(opts, :row_style)
    cell_style = Keyword.get(opts, :cell_style)
    selected_row_id = Keyword.get(opts, :selected_row_id)
    selected_cell = Keyword.get(opts, :selected_cell)
    sort = Keyword.get(opts, :sort)
    events = Keyword.get(opts, :events)

    %{kind: :data_table, columns: columns, rows: rows}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:header_style, header_style)
    |> maybe_put(:row_style, row_style)
    |> maybe_put(:cell_style, cell_style)
    |> maybe_put(:selected_row_id, selected_row_id)
    |> maybe_put(:selected_cell, selected_cell)
    |> maybe_put(:sort, sort)
    |> maybe_put(:events, events)
  end

  @spec tree([tree_item()], keyword()) :: tree_node()
  def tree(nodes, opts \\ []) when is_list(nodes) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    row_style = Keyword.get(opts, :row_style)
    selected_id = Keyword.get(opts, :selected_id)
    events = Keyword.get(opts, :events)

    %{kind: :tree, nodes: nodes}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:row_style, row_style)
    |> maybe_put(:selected_id, selected_id)
    |> maybe_put(:events, events)
  end

  @spec canvas([canvas_command()], keyword()) :: canvas_node()
  def canvas(commands, opts \\ []) when is_list(commands) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    events = Keyword.get(opts, :events)

    %{kind: :canvas, commands: commands}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:events, events)
  end

  @spec select([select_option()], keyword()) :: select_node()
  def select(options, opts \\ []) when is_list(options) and is_list(opts) do
    id = Keyword.get(opts, :id)
    value = Keyword.get(opts, :value)
    open = Keyword.get(opts, :open)
    placeholder = Keyword.get(opts, :placeholder)
    style = Keyword.get(opts, :style)
    list_style = Keyword.get(opts, :list_style)
    option_style = Keyword.get(opts, :option_style)
    disabled = Keyword.get(opts, :disabled)
    tab_index = Keyword.get(opts, :tab_index)
    events = Keyword.get(opts, :events)

    %{kind: :select, options: options}
    |> maybe_put(:id, id)
    |> maybe_put(:value, value)
    |> maybe_put(:open, open)
    |> maybe_put(:placeholder, placeholder)
    |> maybe_put(:style, style)
    |> maybe_put(:list_style, list_style)
    |> maybe_put(:option_style, option_style)
    |> maybe_put(:disabled, disabled)
    |> maybe_put(:tab_index, tab_index)
    |> maybe_put(:events, events)
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

  @spec icon(image_source(), keyword()) :: icon_node()
  def icon(source, opts \\ []) when is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)

    %{kind: :icon, source: source}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
  end

  @spec checkbox(String.t(), boolean(), keyword()) :: checkbox_node()
  def checkbox(label, checked, opts \\ [])
      when is_binary(label) and is_boolean(checked) and is_list(opts) do
    choice_node(:checkbox, label, checked, opts)
  end

  @spec radio(String.t(), String.t(), boolean(), keyword()) :: radio_node()
  def radio(label, value, checked, opts \\ [])
      when is_binary(label) and is_binary(value) and is_boolean(checked) and is_list(opts) do
    choice_node(:radio, label, checked, Keyword.put(opts, :value, value))
  end

  defp choice_node(kind, label, checked, opts) do
    id = Keyword.get(opts, :id)
    value = Keyword.get(opts, :value)
    style = Keyword.get(opts, :style)
    events = Keyword.get(opts, :events)
    hover_style = Keyword.get(opts, :hover_style)
    focus_style = Keyword.get(opts, :focus_style)
    focus_visible_style = Keyword.get(opts, :focus_visible_style)
    in_focus_style = Keyword.get(opts, :in_focus_style)
    active_style = Keyword.get(opts, :active_style)
    disabled_style = Keyword.get(opts, :disabled_style)
    disabled = Keyword.get(opts, :disabled)
    tab_index = Keyword.get(opts, :tab_index)

    %{kind: kind, label: label, checked: checked}
    |> maybe_put(:value, value)
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:hover_style, hover_style)
    |> maybe_put(:focus_style, focus_style)
    |> maybe_put(:focus_visible_style, focus_visible_style)
    |> maybe_put(:in_focus_style, in_focus_style)
    |> maybe_put(:active_style, active_style)
    |> maybe_put(:disabled_style, disabled_style)
    |> maybe_put(:disabled, disabled)
    |> maybe_put(:tab_index, tab_index)
    |> maybe_put(:events, events)
  end

  @spec button(String.t(), keyword()) :: button_node()
  def button(label, opts \\ []) when is_binary(label) and is_list(opts) do
    id = Keyword.get(opts, :id)
    style = Keyword.get(opts, :style)
    events = Keyword.get(opts, :events)
    hover_style = Keyword.get(opts, :hover_style)
    focus_style = Keyword.get(opts, :focus_style)
    focus_visible_style = Keyword.get(opts, :focus_visible_style)
    in_focus_style = Keyword.get(opts, :in_focus_style)
    active_style = Keyword.get(opts, :active_style)
    disabled_style = Keyword.get(opts, :disabled_style)
    animation = Keyword.get(opts, :animation)
    disabled = Keyword.get(opts, :disabled)
    tab_index = Keyword.get(opts, :tab_index)
    actions = Keyword.get(opts, :actions)
    shortcuts = Keyword.get(opts, :shortcuts)

    %{kind: :button, label: label}
    |> maybe_put(:id, id)
    |> maybe_put(:style, style)
    |> maybe_put(:hover_style, hover_style)
    |> maybe_put(:focus_style, focus_style)
    |> maybe_put(:focus_visible_style, focus_visible_style)
    |> maybe_put(:in_focus_style, in_focus_style)
    |> maybe_put(:active_style, active_style)
    |> maybe_put(:disabled_style, disabled_style)
    |> maybe_put(:animation, animation)
    |> maybe_put(:disabled, disabled)
    |> maybe_put(:tab_index, tab_index)
    |> maybe_put(:actions, actions)
    |> maybe_put(:shortcuts, shortcuts)
    |> maybe_put(:events, events)
  end

  @spec text_input(String.t(), keyword()) :: text_input_node()
  def text_input(value, opts \\ []) when is_binary(value) and is_list(opts) do
    input_node(:text_input, value, opts)
  end

  @spec textarea(String.t(), keyword()) :: textarea_node()
  def textarea(value, opts \\ []) when is_binary(value) and is_list(opts) do
    input_node(:textarea, value, opts)
  end

  defp input_node(kind, value, opts) do
    id = Keyword.get(opts, :id)
    placeholder = Keyword.get(opts, :placeholder)
    style = Keyword.get(opts, :style)
    disabled = Keyword.get(opts, :disabled)
    tab_index = Keyword.get(opts, :tab_index)
    events = Keyword.get(opts, :events)

    %{kind: kind, value: value}
    |> maybe_put(:id, id)
    |> maybe_put(:placeholder, placeholder)
    |> maybe_put(:style, style)
    |> maybe_put(:disabled, disabled)
    |> maybe_put(:tab_index, tab_index)
    |> maybe_put(:events, events)
  end

  @spec validated(ir_node()) :: {:ok, Guppy.IR.Validated.t()} | {:error, term()}
  def validated(%Guppy.IR.Validated{} = validated), do: {:ok, validated}

  def validated(ir) do
    with :ok <- validate(ir) do
      {:ok, %Guppy.IR.Validated{ir: ir}}
    end
  end

  @spec validated!(ir_node()) :: Guppy.IR.Validated.t()
  def validated!(ir) do
    case validated(ir) do
      {:ok, validated} -> validated
      {:error, reason} -> raise ArgumentError, "invalid IR: #{inspect(reason)}"
    end
  end

  def unwrap(%Guppy.IR.Validated{ir: ir}), do: ir
  def unwrap(ir), do: ir

  @spec validate(ir_node() | Guppy.IR.Validated.t()) :: :ok | {:error, term()}
  def validate(%Guppy.IR.Validated{}), do: :ok

  def validate(ir) do
    with :ok <- validate_node(ir),
         :ok <- validate_unique_ids(ir) do
      :ok
    end
  end

  @allowed_node_keys %{
    text: [:kind, :content, :id, :style, :runs, :events],
    div: [
      :kind,
      :children,
      :id,
      :style,
      :hover_style,
      :focus_style,
      :focus_visible_style,
      :in_focus_style,
      :active_style,
      :disabled_style,
      :animation,
      :disabled,
      :stack_priority,
      :occlude,
      :focusable,
      :tab_stop,
      :tab_index,
      :track_scroll,
      :anchor_scroll,
      :scroll_to,
      :tooltip,
      :actions,
      :shortcuts,
      :events
    ],
    scroll: [:kind, :children, :id, :axis, :style],
    popover: [
      :kind,
      :label,
      :open,
      :children,
      :id,
      :style,
      :popover_style,
      :anchor,
      :anchor_position,
      :anchor_offset,
      :anchor_position_mode,
      :anchor_fit,
      :snap_margin,
      :close_on_click_outside,
      :stack_priority,
      :disabled,
      :events
    ],
    uniform_list: [:kind, :items, :id, :style, :item_style, :events],
    list: [:kind, :items, :id, :style, :item_style, :events],
    data_table: [
      :kind,
      :columns,
      :rows,
      :id,
      :style,
      :header_style,
      :row_style,
      :cell_style,
      :selected_row_id,
      :selected_cell,
      :sort,
      :events
    ],
    tree: [:kind, :nodes, :id, :style, :row_style, :selected_id, :events],
    canvas: [:kind, :commands, :id, :style, :events],
    select: [
      :kind,
      :options,
      :id,
      :value,
      :open,
      :placeholder,
      :style,
      :list_style,
      :option_style,
      :disabled,
      :tab_index,
      :events
    ],
    image: [:kind, :source, :id, :style, :object_fit, :grayscale],
    icon: [:kind, :source, :id, :style],
    spacer: [:kind, :id, :style],
    checkbox: [
      :kind,
      :label,
      :checked,
      :id,
      :style,
      :hover_style,
      :focus_style,
      :focus_visible_style,
      :in_focus_style,
      :active_style,
      :disabled_style,
      :disabled,
      :tab_index,
      :events
    ],
    radio: [
      :kind,
      :label,
      :value,
      :checked,
      :id,
      :style,
      :hover_style,
      :focus_style,
      :focus_visible_style,
      :in_focus_style,
      :active_style,
      :disabled_style,
      :disabled,
      :tab_index,
      :events
    ],
    button: [
      :kind,
      :label,
      :id,
      :style,
      :hover_style,
      :focus_style,
      :focus_visible_style,
      :in_focus_style,
      :active_style,
      :disabled_style,
      :animation,
      :disabled,
      :tab_index,
      :actions,
      :shortcuts,
      :events
    ],
    text_input: [:kind, :value, :id, :placeholder, :style, :disabled, :tab_index, :events],
    textarea: [:kind, :value, :id, :placeholder, :style, :disabled, :tab_index, :events]
  }

  defp validate_node(%{kind: :text, content: content} = node) when is_binary(content) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_text_runs(content, Map.get(node, :runs)),
         :ok <- validate_events(Map.get(node, :events), [:click]) do
      :ok
    end
  end

  defp validate_node(%{kind: :div, children: children} = node) when is_list(children) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :hover_style)),
         :ok <- validate_style(Map.get(node, :focus_style)),
         :ok <- validate_style(Map.get(node, :focus_visible_style)),
         :ok <- validate_style(Map.get(node, :in_focus_style)),
         :ok <- validate_style(Map.get(node, :active_style)),
         :ok <- validate_style(Map.get(node, :disabled_style)),
         :ok <- validate_animation(Map.get(node, :animation)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_optional_non_neg_integer(Map.get(node, :stack_priority), :stack_priority),
         :ok <- validate_optional_boolean(Map.get(node, :occlude), :occlude),
         :ok <- validate_optional_boolean(Map.get(node, :focusable), :focusable),
         :ok <- validate_optional_boolean(Map.get(node, :tab_stop), :tab_stop),
         :ok <- validate_optional_integer(Map.get(node, :tab_index), :tab_index),
         :ok <- validate_optional_boolean(Map.get(node, :track_scroll), :track_scroll),
         :ok <- validate_optional_boolean(Map.get(node, :anchor_scroll), :anchor_scroll),
         :ok <- validate_optional_boolean(Map.get(node, :scroll_to), :scroll_to),
         :ok <- validate_optional_string(Map.get(node, :tooltip), :tooltip),
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
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_scroll_axis(Map.get(node, :axis)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_children(children) do
      :ok
    end
  end

  defp validate_node(%{kind: :popover, label: label, open: open, children: children} = node)
       when is_binary(label) and is_boolean(open) and is_list(children) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :popover_style)),
         :ok <- validate_popover_anchor(Map.get(node, :anchor)),
         :ok <- validate_optional_point(Map.get(node, :anchor_position), :anchor_position),
         :ok <- validate_optional_point(Map.get(node, :anchor_offset), :anchor_offset),
         :ok <- validate_popover_anchor_position_mode(Map.get(node, :anchor_position_mode)),
         :ok <- validate_popover_anchor_fit(Map.get(node, :anchor_fit)),
         :ok <- validate_optional_non_neg_number(Map.get(node, :snap_margin), :snap_margin),
         :ok <-
           validate_optional_boolean(
             Map.get(node, :close_on_click_outside),
             :close_on_click_outside
           ),
         :ok <- validate_optional_non_neg_integer(Map.get(node, :stack_priority), :stack_priority),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_events(Map.get(node, :events), [:click, :close]),
         :ok <- validate_children(children) do
      :ok
    end
  end

  defp validate_node(%{kind: :uniform_list, items: items} = node) when is_list(items) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :item_style)),
         :ok <- validate_events(Map.get(node, :events), [:click]),
         :ok <- validate_uniform_list_items(items) do
      :ok
    end
  end

  defp validate_node(%{kind: :list, items: items} = node) when is_list(items) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :item_style)),
         :ok <- validate_events(Map.get(node, :events), [:click]),
         :ok <- validate_list_items(items) do
      :ok
    end
  end

  defp validate_node(%{kind: :data_table, columns: columns, rows: rows} = node)
       when is_list(columns) and is_list(rows) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :header_style)),
         :ok <- validate_style(Map.get(node, :row_style)),
         :ok <- validate_style(Map.get(node, :cell_style)),
         :ok <- validate_events(Map.get(node, :events), [:row_click, :cell_click, :sort]),
         {:ok, column_ids} <- validate_data_table_columns(columns),
         {:ok, row_ids} <- validate_data_table_rows(rows, column_ids),
         :ok <- validate_data_table_selected_row(Map.get(node, :selected_row_id), row_ids),
         :ok <-
           validate_data_table_selected_cell(Map.get(node, :selected_cell), row_ids, column_ids),
         :ok <- validate_data_table_sort(Map.get(node, :sort), column_ids) do
      :ok
    end
  end

  defp validate_node(%{kind: :tree, nodes: nodes} = node) when is_list(nodes) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :row_style)),
         :ok <- validate_events(Map.get(node, :events), [:select, :toggle]),
         {:ok, node_ids} <- validate_tree_nodes(nodes),
         :ok <- validate_tree_selected_id(Map.get(node, :selected_id), node_ids) do
      :ok
    end
  end

  defp validate_node(%{kind: :canvas, commands: commands} = node) when is_list(commands) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_events(Map.get(node, :events), [:click]),
         :ok <- validate_canvas_commands(commands) do
      :ok
    end
  end

  defp validate_node(%{kind: :select, options: options} = node) when is_list(options) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_optional_string(Map.get(node, :value), :value),
         :ok <- validate_optional_boolean(Map.get(node, :open), :open),
         :ok <- validate_optional_string(Map.get(node, :placeholder), :placeholder),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :list_style)),
         :ok <- validate_style(Map.get(node, :option_style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_optional_integer(Map.get(node, :tab_index), :tab_index),
         :ok <- validate_events(Map.get(node, :events), [:click, :change, :close, :focus, :blur]),
         :ok <- validate_select_options(options) do
      :ok
    end
  end

  defp validate_node(%{kind: :image, source: source} = node) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_image_source(source),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_image_object_fit(Map.get(node, :object_fit)),
         :ok <- validate_optional_boolean(Map.get(node, :grayscale), :grayscale) do
      :ok
    end
  end

  defp validate_node(%{kind: :icon, source: source} = node) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_image_source(source),
         :ok <- validate_style(Map.get(node, :style)) do
      :ok
    end
  end

  defp validate_node(%{kind: :spacer} = node) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)) do
      :ok
    end
  end

  defp validate_node(%{kind: :checkbox, label: label, checked: checked} = node)
       when is_binary(label) and is_boolean(checked) do
    validate_choice_node(node)
  end

  defp validate_node(%{kind: :radio, label: label, value: value, checked: checked} = node)
       when is_binary(label) and is_binary(value) and is_boolean(checked) do
    validate_choice_node(node)
  end

  defp validate_node(%{kind: :button, label: label} = node) when is_binary(label) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :hover_style)),
         :ok <- validate_style(Map.get(node, :focus_style)),
         :ok <- validate_style(Map.get(node, :focus_visible_style)),
         :ok <- validate_style(Map.get(node, :in_focus_style)),
         :ok <- validate_style(Map.get(node, :active_style)),
         :ok <- validate_style(Map.get(node, :disabled_style)),
         :ok <- validate_animation(Map.get(node, :animation)),
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

  defp validate_node(%{kind: kind, value: value} = node)
       when kind in [:text_input, :textarea] and is_binary(value) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_optional_string(Map.get(node, :placeholder), :placeholder),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_optional_integer(Map.get(node, :tab_index), :tab_index),
         :ok <- validate_events(Map.get(node, :events), [:change, :focus, :blur]) do
      :ok
    end
  end

  defp validate_node(other), do: {:error, {:invalid_ir, other}}

  defp validate_animation(nil), do: :ok

  defp validate_animation(%{id: id} = animation) when is_binary(id) do
    allowed_keys = [:id, :duration_ms, :repeat, :from, :to]
    duration_ms = Map.get(animation, :duration_ms, 1_000)
    repeat = Map.get(animation, :repeat, false)
    from = Map.get(animation, :from, 0.0)
    to = Map.get(animation, :to, 1.0)

    cond do
      Map.keys(animation) -- allowed_keys != [] ->
        {:error, {:invalid_animation, animation}}

      not (is_integer(duration_ms) and duration_ms >= 1) ->
        {:error, {:invalid_animation, animation}}

      not is_boolean(repeat) ->
        {:error, {:invalid_animation, animation}}

      not unit_native_f32_number?(from) ->
        {:error, {:invalid_animation, animation}}

      not unit_native_f32_number?(to) ->
        {:error, {:invalid_animation, animation}}

      true ->
        :ok
    end
  end

  defp validate_animation(animation), do: {:error, {:invalid_animation, animation}}

  defp validate_text_runs(_content, nil), do: :ok

  defp validate_text_runs(content, runs) when is_list(runs) do
    with {:ok, texts} <- validate_text_run_list(runs) do
      joined = Enum.join(texts)

      if joined == content do
        :ok
      else
        {:error, {:text_runs_content_mismatch, content, joined}}
      end
    end
  end

  defp validate_text_runs(_content, runs), do: {:error, {:invalid_text_runs, runs}}

  defp validate_text_run_list(runs) do
    Enum.reduce_while(runs, {:ok, []}, fn run, {:ok, texts} ->
      case validate_text_run(run) do
        {:ok, text} -> {:cont, {:ok, [text | texts]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, texts} -> {:ok, Enum.reverse(texts)}
      error -> error
    end
  end

  defp validate_text_run(%{text: text} = run) when is_binary(text) do
    case Map.keys(run) -- [:text, :style] do
      [] ->
        with :ok <- validate_style(Map.get(run, :style)) do
          {:ok, text}
        end

      unknown ->
        {:error, {:unknown_text_run_keys, Enum.sort(unknown)}}
    end
  end

  defp validate_text_run(run), do: {:error, {:invalid_text_run, run}}

  defp validate_node_keys(%{kind: kind} = node) do
    validate_known_keys(node, Map.fetch!(@allowed_node_keys, kind), kind)
  end

  defp validate_known_keys(map, allowed, context) do
    case Map.keys(map) -- allowed do
      [] -> :ok
      unknown -> {:error, {:unknown_ir_keys, context, Enum.sort(unknown)}}
    end
  end

  defp validate_choice_node(node) do
    with :ok <- validate_node_keys(node),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :hover_style)),
         :ok <- validate_style(Map.get(node, :focus_style)),
         :ok <- validate_style(Map.get(node, :focus_visible_style)),
         :ok <- validate_style(Map.get(node, :in_focus_style)),
         :ok <- validate_style(Map.get(node, :active_style)),
         :ok <- validate_style(Map.get(node, :disabled_style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_optional_integer(Map.get(node, :tab_index), :tab_index),
         :ok <- validate_events(Map.get(node, :events), [:change, :focus, :blur]) do
      :ok
    end
  end

  defp validate_uniform_list_items(items) do
    Enum.reduce_while(items, :ok, fn
      %{id: id, label: label} = item, :ok when is_binary(id) and is_binary(label) ->
        case validate_known_keys(item, @uniform_list_item_keys, :uniform_list_item) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end

      item, :ok ->
        {:halt, {:error, {:invalid_uniform_list_item, item}}}
    end)
  end

  defp validate_list_items(items) do
    Enum.reduce_while(items, :ok, fn
      %{id: id, children: children} = item, :ok when is_binary(id) and is_list(children) ->
        with :ok <- validate_known_keys(item, @list_item_keys, :list_item),
             :ok <- validate_list_item_children(children) do
          {:cont, :ok}
        else
          error -> {:halt, error}
        end

      item, :ok ->
        {:halt, {:error, {:invalid_list_item, item}}}
    end)
  end

  defp validate_list_item_children(children) do
    case validate_list_item_children(children, MapSet.new()) do
      {:ok, _seen_control_ids} -> :ok
      error -> error
    end
  end

  defp validate_list_item_children(children, seen_control_ids) do
    Enum.reduce_while(children, {:ok, seen_control_ids}, fn child, {:ok, seen} ->
      case validate_list_row_node(child, seen) do
        {:ok, next_seen} -> {:cont, {:ok, next_seen}}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_list_row_node(%{kind: kind} = node, seen_control_ids)
       when kind in [:text, :spacer] do
    case validate_node(node) do
      :ok -> {:ok, seen_control_ids}
      error -> error
    end
  end

  defp validate_list_row_node(%{kind: :div, children: children} = node, seen_control_ids)
       when is_list(children) do
    with :ok <- validate_known_keys(node, @list_row_div_keys, :list_row_div),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_events(Map.get(node, :events), [:click]) do
      validate_list_item_children(children, seen_control_ids)
    end
  end

  defp validate_list_row_node(%{kind: kind} = node, seen_control_ids)
       when kind in @list_row_control_kinds do
    with :ok <- validate_list_row_control_node(node),
         {:ok, next_seen} <- track_list_row_control_id(kind, Map.get(node, :id), seen_control_ids) do
      {:ok, next_seen}
    end
  end

  defp validate_list_row_node(other, _seen_control_ids),
    do: {:error, {:unsupported_list_item_child, other}}

  defp validate_list_row_control_node(%{kind: :button, label: label} = node)
       when is_binary(label) do
    with :ok <- validate_known_keys(node, @list_row_button_keys, :list_row_button),
         :ok <- validate_required_id(Map.get(node, :id), :button),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :hover_style)),
         :ok <- validate_style(Map.get(node, :focus_style)),
         :ok <- validate_style(Map.get(node, :focus_visible_style)),
         :ok <- validate_style(Map.get(node, :in_focus_style)),
         :ok <- validate_style(Map.get(node, :active_style)),
         :ok <- validate_style(Map.get(node, :disabled_style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_optional_integer(Map.get(node, :tab_index), :tab_index),
         :ok <- validate_events(Map.get(node, :events), [:click]) do
      :ok
    end
  end

  defp validate_list_row_control_node(%{kind: :checkbox, label: label, checked: checked} = node)
       when is_binary(label) and is_boolean(checked) do
    validate_list_row_choice_node(node, :checkbox, :list_row_checkbox, @list_row_checkbox_keys, [
      :change
    ])
  end

  defp validate_list_row_control_node(
         %{kind: :radio, label: label, value: value, checked: checked} = node
       )
       when is_binary(label) and is_binary(value) and is_boolean(checked) do
    validate_list_row_choice_node(node, :radio, :list_row_radio, @list_row_radio_keys, [:change])
  end

  defp validate_list_row_control_node(node), do: {:error, {:invalid_list_row_control, node}}

  defp validate_list_row_choice_node(node, kind, error_kind, allowed_keys, allowed_events) do
    with :ok <- validate_known_keys(node, allowed_keys, error_kind),
         :ok <- validate_required_id(Map.get(node, :id), kind),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_style(Map.get(node, :hover_style)),
         :ok <- validate_style(Map.get(node, :focus_style)),
         :ok <- validate_style(Map.get(node, :focus_visible_style)),
         :ok <- validate_style(Map.get(node, :in_focus_style)),
         :ok <- validate_style(Map.get(node, :active_style)),
         :ok <- validate_style(Map.get(node, :disabled_style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_optional_integer(Map.get(node, :tab_index), :tab_index),
         :ok <- validate_events(Map.get(node, :events), allowed_events) do
      :ok
    end
  end

  defp validate_required_id(id, _kind) when is_binary(id), do: :ok
  defp validate_required_id(_id, kind), do: {:error, {:missing_list_row_control_id, kind}}

  defp track_list_row_control_id(_kind, id, seen_control_ids) do
    if MapSet.member?(seen_control_ids, id) do
      {:error, {:duplicate_list_row_control_id, id}}
    else
      {:ok, MapSet.put(seen_control_ids, id)}
    end
  end

  defp validate_data_table_columns(columns) do
    Enum.reduce_while(columns, {:ok, MapSet.new()}, fn
      %{id: id, label: label} = column, {:ok, seen} when is_binary(id) and is_binary(label) ->
        if MapSet.member?(seen, id) do
          {:halt, {:error, {:duplicate_data_table_column_id, id}}}
        else
          with :ok <- validate_known_keys(column, @data_table_column_keys, :data_table_column),
               :ok <- validate_data_table_column_width(Map.get(column, :width)),
               :ok <- validate_optional_boolean(Map.get(column, :sortable), :sortable),
               :ok <- validate_style(Map.get(column, :style)) do
            {:cont, {:ok, MapSet.put(seen, id)}}
          else
            error -> {:halt, error}
          end
        end

      column, {:ok, _seen} ->
        {:halt, {:error, {:invalid_data_table_column, column}}}
    end)
  end

  defp validate_data_table_column_width(nil), do: :ok
  defp validate_data_table_column_width(:auto), do: :ok

  defp validate_data_table_column_width({:px, value})
       when is_positive_native_f32_number(value),
       do: :ok

  defp validate_data_table_column_width({:fr, value}) when is_integer(value) and value > 0,
    do: :ok

  defp validate_data_table_column_width(width),
    do: {:error, {:invalid_data_table_column_width, width}}

  defp validate_data_table_rows(rows, column_ids) do
    Enum.reduce_while(rows, {:ok, MapSet.new()}, fn
      %{id: id, cells: cells} = row, {:ok, seen} when is_binary(id) and is_list(cells) ->
        if MapSet.member?(seen, id) do
          {:halt, {:error, {:duplicate_data_table_row_id, id}}}
        else
          with :ok <- validate_known_keys(row, @data_table_row_keys, :data_table_row),
               :ok <- validate_style(Map.get(row, :style)),
               :ok <- validate_data_table_cells(cells, column_ids) do
            {:cont, {:ok, MapSet.put(seen, id)}}
          else
            error -> {:halt, error}
          end
        end

      row, {:ok, _seen} ->
        {:halt, {:error, {:invalid_data_table_row, row}}}
    end)
  end

  defp validate_data_table_cells(cells, column_ids) do
    Enum.reduce_while(cells, {:ok, MapSet.new()}, fn
      %{column_id: column_id, children: children} = cell, {:ok, seen}
      when is_binary(column_id) and is_list(children) ->
        cond do
          not MapSet.member?(column_ids, column_id) ->
            {:halt, {:error, {:unknown_data_table_cell_column, column_id}}}

          MapSet.member?(seen, column_id) ->
            {:halt, {:error, {:duplicate_data_table_cell_column, column_id}}}

          true ->
            with :ok <- validate_known_keys(cell, @data_table_cell_keys, :data_table_cell),
                 :ok <- validate_style(Map.get(cell, :style)),
                 :ok <- validate_data_table_cell_children(children) do
              {:cont, {:ok, MapSet.put(seen, column_id)}}
            else
              error -> {:halt, error}
            end
        end

      cell, {:ok, _seen} ->
        {:halt, {:error, {:invalid_data_table_cell, cell}}}
    end)
    |> case do
      {:ok, _seen} -> :ok
      error -> error
    end
  end

  defp validate_data_table_cell_children(children) do
    Enum.reduce_while(children, :ok, fn child, :ok ->
      case validate_data_table_cell_child(child) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_data_table_cell_child(%{kind: kind} = node) when kind in [:text, :spacer],
    do: validate_node(node)

  defp validate_data_table_cell_child(%{kind: :div, children: children} = node)
       when is_list(children) do
    with :ok <- validate_known_keys(node, @list_row_div_keys, :data_table_cell_div),
         :ok <- validate_id(Map.get(node, :id)),
         :ok <- validate_style(Map.get(node, :style)),
         :ok <- validate_optional_boolean(Map.get(node, :disabled), :disabled),
         :ok <- validate_events(Map.get(node, :events), [:click]) do
      validate_data_table_cell_children(children)
    end
  end

  defp validate_data_table_cell_child(child),
    do: {:error, {:unsupported_data_table_cell_child, child}}

  defp validate_data_table_selected_row(nil, _row_ids), do: :ok

  defp validate_data_table_selected_row(row_id, row_ids) when is_binary(row_id) do
    if MapSet.member?(row_ids, row_id) do
      :ok
    else
      {:error, {:unknown_data_table_selected_row, row_id}}
    end
  end

  defp validate_data_table_selected_row(row_id, _row_ids),
    do: {:error, {:invalid_data_table_selected_row, row_id}}

  defp validate_data_table_selected_cell(nil, _row_ids, _column_ids), do: :ok

  defp validate_data_table_selected_cell({row_id, column_id}, row_ids, column_ids)
       when is_binary(row_id) and is_binary(column_id) do
    cond do
      not MapSet.member?(row_ids, row_id) ->
        {:error, {:unknown_data_table_selected_row, row_id}}

      not MapSet.member?(column_ids, column_id) ->
        {:error, {:unknown_data_table_selected_column, column_id}}

      true ->
        :ok
    end
  end

  defp validate_data_table_selected_cell(cell, _row_ids, _column_ids),
    do: {:error, {:invalid_data_table_selected_cell, cell}}

  defp validate_data_table_sort(nil, _column_ids), do: :ok

  defp validate_data_table_sort(%{column_id: column_id, direction: direction} = sort, column_ids)
       when is_binary(column_id) and direction in [:asc, :desc] do
    with :ok <- validate_known_keys(sort, @data_table_sort_keys, :data_table_sort) do
      if MapSet.member?(column_ids, column_id) do
        :ok
      else
        {:error, {:unknown_data_table_sort_column, column_id}}
      end
    end
  end

  defp validate_data_table_sort(sort, _column_ids), do: {:error, {:invalid_data_table_sort, sort}}

  defp validate_tree_nodes(nodes) do
    case validate_tree_nodes(nodes, MapSet.new()) do
      {:ok, ids} -> {:ok, ids}
      error -> error
    end
  end

  defp validate_tree_nodes(nodes, seen) do
    Enum.reduce_while(nodes, {:ok, seen}, fn node, {:ok, acc_seen} ->
      case validate_tree_node(node, acc_seen) do
        {:ok, next_seen} -> {:cont, {:ok, next_seen}}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_tree_node(%{id: id, label: label} = node, seen)
       when is_binary(id) and is_binary(label) do
    cond do
      MapSet.member?(seen, id) ->
        {:error, {:duplicate_tree_node_id, id}}

      not valid_tree_node_shape?(node) ->
        {:error, {:invalid_tree_node, node}}

      true ->
        children = Map.get(node, :children, [])

        with :ok <- validate_known_keys(node, @tree_item_keys, :tree_item),
             :ok <- validate_style(Map.get(node, :style)),
             {:ok, next_seen} <- validate_tree_nodes(children, MapSet.put(seen, id)) do
          {:ok, next_seen}
        end
    end
  end

  defp validate_tree_node(node, _seen), do: {:error, {:invalid_tree_node, node}}

  defp valid_tree_node_shape?(node) do
    valid_tree_expanded?(node) and valid_tree_children?(node)
  end

  defp valid_tree_expanded?(%{expanded: expanded}), do: is_boolean(expanded)
  defp valid_tree_expanded?(_node), do: true

  defp valid_tree_children?(%{children: children}), do: is_list(children)
  defp valid_tree_children?(_node), do: true

  defp validate_tree_selected_id(nil, _node_ids), do: :ok

  defp validate_tree_selected_id(id, node_ids) when is_binary(id) do
    if MapSet.member?(node_ids, id) do
      :ok
    else
      {:error, {:unknown_tree_selected_id, id}}
    end
  end

  defp validate_tree_selected_id(id, _node_ids), do: {:error, {:invalid_tree_selected_id, id}}

  defp validate_canvas_commands(commands) do
    Enum.reduce_while(commands, :ok, fn command, :ok ->
      case validate_canvas_command(command) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_canvas_command(%{op: op, x: x, y: y, width: width, height: height} = command)
       when op in [:rect, :rounded_rect, :pattern_rect] and is_native_f32_number(x) and
              is_native_f32_number(y) and is_positive_native_f32_number(width) and
              is_positive_native_f32_number(height) do
    with :ok <- validate_known_keys(command, @canvas_command_keys, :canvas_command),
         :ok <- validate_canvas_command_fields(op, command),
         :ok <- validate_canvas_radius(op, Map.get(command, :radius)) do
      :ok
    end
  end

  defp validate_canvas_command(command), do: {:error, {:invalid_canvas_command, command}}

  defp validate_canvas_command_fields(op, command) when op in [:rect, :rounded_rect] do
    allowed = [:op, :x, :y, :width, :height, :fill, :radius]

    cond do
      Map.has_key?(command, :color) or Map.has_key?(command, :line_width) or
          Map.has_key?(command, :interval) ->
        {:error, {:invalid_canvas_command, command}}

      not Map.has_key?(command, :fill) ->
        {:error, {:invalid_canvas_command, command}}

      Map.keys(command) -- allowed != [] ->
        {:error, {:invalid_canvas_command, command}}

      true ->
        validate_canvas_color(command.fill)
    end
  end

  defp validate_canvas_command_fields(:pattern_rect, command) do
    allowed = [:op, :x, :y, :width, :height, :color, :line_width, :interval, :radius]

    cond do
      Map.has_key?(command, :fill) ->
        {:error, {:invalid_canvas_command, command}}

      not (Map.has_key?(command, :color) and Map.has_key?(command, :line_width) and
               Map.has_key?(command, :interval)) ->
        {:error, {:invalid_canvas_command, command}}

      Map.keys(command) -- allowed != [] ->
        {:error, {:invalid_canvas_command, command}}

      true ->
        with :ok <- validate_canvas_color(command.color),
             :ok <- validate_unit_canvas_number(:line_width, command.line_width),
             :ok <- validate_unit_canvas_number(:interval, command.interval) do
          :ok
        end
    end
  end

  defp validate_unit_canvas_number(_field, value)
       when is_positive_unit_native_f32_number(value),
       do: :ok

  defp validate_unit_canvas_number(field, value),
    do: {:error, {:invalid_canvas_number, field, value}}

  defp validate_canvas_color(color) when color in @color_tokens, do: :ok

  defp validate_canvas_color(color) when is_binary(color) do
    if valid_gradient_color?(color) do
      :ok
    else
      {:error, {:invalid_canvas_color, color}}
    end
  end

  defp validate_canvas_color(color), do: {:error, {:invalid_canvas_color, color}}

  defp validate_canvas_radius(:rect, nil), do: :ok
  defp validate_canvas_radius(:rect, radius) when is_non_neg_native_f32_number(radius), do: :ok

  defp validate_canvas_radius(:rounded_rect, radius) when is_non_neg_native_f32_number(radius),
    do: :ok

  defp validate_canvas_radius(:rounded_rect, nil), do: {:error, {:invalid_canvas_radius, nil}}
  defp validate_canvas_radius(:pattern_rect, nil), do: :ok

  defp validate_canvas_radius(:pattern_rect, radius) when is_non_neg_native_f32_number(radius),
    do: :ok

  defp validate_canvas_radius(_op, radius), do: {:error, {:invalid_canvas_radius, radius}}

  defp validate_select_options(options) do
    Enum.reduce_while(options, {:ok, MapSet.new()}, fn
      %{value: value, label: label} = option, {:ok, seen}
      when is_binary(value) and is_binary(label) ->
        case validate_known_keys(option, @select_option_keys, :select_option) do
          :ok ->
            cond do
              MapSet.member?(seen, value) ->
                {:halt, {:error, {:duplicate_select_value, value}}}

              not valid_select_option_disabled?(option) ->
                {:halt, {:error, {:invalid_select_option, option}}}

              true ->
                {:cont, {:ok, MapSet.put(seen, value)}}
            end

          error ->
            {:halt, error}
        end

      option, {:ok, _seen} ->
        {:halt, {:error, {:invalid_select_option, option}}}
    end)
    |> case do
      {:ok, _seen} -> :ok
      error -> error
    end
  end

  defp valid_select_option_disabled?(%{disabled: disabled}), do: is_boolean(disabled)
  defp valid_select_option_disabled?(_option), do: true

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
       when kind in [:div, :scroll, :popover] and is_list(children) do
    Enum.reduce_while(children, {:ok, ids}, fn child, {:ok, acc_ids} ->
      case collect_ids(child, acc_ids) do
        {:ok, next_ids} -> {:cont, {:ok, next_ids}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp collect_child_ids(%{kind: :uniform_list, items: items}, ids) when is_list(items) do
    Enum.reduce_while(items, {:ok, ids}, fn %{id: id}, {:ok, acc_ids} ->
      if MapSet.member?(acc_ids, id) do
        {:halt, {:error, {:duplicate_id, id}}}
      else
        {:cont, {:ok, MapSet.put(acc_ids, id)}}
      end
    end)
  end

  defp collect_child_ids(%{kind: :list, items: items}, ids) when is_list(items) do
    Enum.reduce_while(items, {:ok, ids}, fn %{id: id, children: children}, {:ok, acc_ids} ->
      if MapSet.member?(acc_ids, id) do
        {:halt, {:error, {:duplicate_id, id}}}
      else
        case collect_list_item_child_ids(children, MapSet.put(acc_ids, id)) do
          {:ok, next_ids} -> {:cont, {:ok, next_ids}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end
    end)
  end

  defp collect_child_ids(%{kind: :data_table, rows: rows}, ids) when is_list(rows) do
    Enum.reduce_while(rows, {:ok, ids}, fn %{id: id, cells: cells}, {:ok, acc_ids} ->
      if MapSet.member?(acc_ids, id) do
        {:halt, {:error, {:duplicate_id, id}}}
      else
        case collect_data_table_cell_child_ids(cells, MapSet.put(acc_ids, id)) do
          {:ok, next_ids} -> {:cont, {:ok, next_ids}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end
    end)
  end

  defp collect_child_ids(%{kind: :tree, nodes: nodes}, ids) when is_list(nodes) do
    collect_tree_item_ids(nodes, ids)
  end

  defp collect_child_ids(_node, ids), do: {:ok, ids}

  defp collect_list_item_child_ids(children, ids) do
    Enum.reduce_while(children, {:ok, ids}, fn child, {:ok, acc_ids} ->
      case collect_list_row_ids(child, acc_ids) do
        {:ok, next_ids} -> {:cont, {:ok, next_ids}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp collect_list_row_ids(%{kind: kind}, ids) when kind in @list_row_control_kinds,
    do: {:ok, ids}

  defp collect_list_row_ids(%{kind: :div, id: id, children: children}, ids)
       when is_binary(id) and is_list(children) do
    if MapSet.member?(ids, id) do
      {:error, {:duplicate_id, id}}
    else
      collect_list_item_child_ids(children, MapSet.put(ids, id))
    end
  end

  defp collect_list_row_ids(%{kind: :div, children: children}, ids) when is_list(children),
    do: collect_list_item_child_ids(children, ids)

  defp collect_list_row_ids(node, ids), do: collect_ids(node, ids)

  defp collect_data_table_cell_child_ids(cells, ids) do
    Enum.reduce_while(cells, {:ok, ids}, fn %{children: children}, {:ok, acc_ids} ->
      case collect_list_item_child_ids(children, acc_ids) do
        {:ok, next_ids} -> {:cont, {:ok, next_ids}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp collect_tree_item_ids(nodes, ids) do
    Enum.reduce_while(nodes, {:ok, ids}, fn %{id: id} = node, {:ok, acc_ids} ->
      if MapSet.member?(acc_ids, id) do
        {:halt, {:error, {:duplicate_id, id}}}
      else
        case collect_tree_item_ids(Map.get(node, :children, []), MapSet.put(acc_ids, id)) do
          {:ok, next_ids} -> {:cont, {:ok, next_ids}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end
    end)
  end

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

  defp validate_optional_non_neg_number(nil, _field), do: :ok

  defp validate_optional_non_neg_number(value, _field) when is_non_neg_native_f32_number(value),
    do: :ok

  defp validate_optional_non_neg_number(value, field), do: {:error, {field, value}}

  defp native_f32_number?(value) when is_native_f32_number(value), do: true
  defp native_f32_number?(_value), do: false

  defp unit_native_f32_number?(value) when is_unit_native_f32_number(value), do: true
  defp unit_native_f32_number?(_value), do: false

  defp validate_scroll_axis(nil), do: :ok
  defp validate_scroll_axis(axis) when axis in [:x, :y, :both], do: :ok
  defp validate_scroll_axis(axis), do: {:error, {:invalid_scroll_axis, axis}}

  defp validate_popover_anchor(nil), do: :ok

  defp validate_popover_anchor(anchor)
       when anchor in [:top_left, :top_right, :bottom_left, :bottom_right],
       do: :ok

  defp validate_popover_anchor(anchor), do: {:error, {:invalid_popover_anchor, anchor}}

  defp validate_popover_anchor_position_mode(nil), do: :ok
  defp validate_popover_anchor_position_mode(mode) when mode in [:window, :local], do: :ok

  defp validate_popover_anchor_position_mode(mode),
    do: {:error, {:invalid_popover_anchor_position_mode, mode}}

  defp validate_popover_anchor_fit(nil), do: :ok

  defp validate_popover_anchor_fit(fit)
       when fit in [:switch_anchor, :snap_to_window, :snap_to_window_with_margin],
       do: :ok

  defp validate_popover_anchor_fit(fit), do: {:error, {:invalid_popover_anchor_fit, fit}}

  defp validate_optional_point(nil, _field), do: :ok

  defp validate_optional_point({x, y}, _field)
       when is_native_f32_number(x) and is_native_f32_number(y),
       do: :ok

  defp validate_optional_point(value, field), do: {:error, {:invalid_point, field, value}}

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

  defp validate_style_op({:padding, axis, length} = op) when axis in @style_axis_tokens do
    if valid_definite_length?(length, false) do
      :ok
    else
      {:error, {:invalid_style_op, op}}
    end
  end

  defp validate_style_op({:margin, axis, length} = op) when axis in @style_axis_tokens do
    if valid_length?(length, true) do
      :ok
    else
      {:error, {:invalid_style_op, op}}
    end
  end

  defp validate_style_op({:gap, axis, length} = op) when axis in @gap_axis_tokens do
    if valid_definite_length?(length, true) do
      :ok
    else
      {:error, {:invalid_style_op, op}}
    end
  end

  defp validate_style_op({key, length} = op) when key in @length_style_value_tokens do
    if valid_length?(length, true) do
      :ok
    else
      {:error, {:invalid_style_op, op}}
    end
  end

  defp validate_style_op({:position, value}) when value in @position_value_tokens, do: :ok

  defp validate_style_op({:inset, axis, length} = op) when axis in @inset_axis_tokens do
    if valid_length?(length, true) do
      :ok
    else
      {:error, {:invalid_style_op, op}}
    end
  end

  defp validate_style_op({:display, value}) when value in @display_value_tokens, do: :ok
  defp validate_style_op({:visibility, value}) when value in @visibility_value_tokens, do: :ok

  defp validate_style_op({:overflow, axis, value})
       when axis in @gap_axis_tokens and value in @overflow_value_tokens,
       do: :ok

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

  defp validate_style_op({:bg_linear_gradient, options} = op) do
    if valid_linear_gradient_options?(options) do
      :ok
    else
      {:error, {:invalid_style_op, op}}
    end
  end

  defp validate_style_op({:opacity, value}) when is_unit_native_f32_number(value), do: :ok

  defp validate_style_op({key, value})
       when key in @grid_value_tokens and is_integer(value) and value >= 1 and value <= 65_535,
       do: :ok

  defp validate_style_op({key, value})
       when key in @size_value_tokens and is_non_neg_native_f32_number(value),
       do: :ok

  defp validate_style_op({key, value})
       when key in @fraction_value_tokens and is_unit_native_f32_number(value),
       do: :ok

  defp validate_style_op({key, value})
       when key in @scrollbar_value_tokens and is_non_neg_native_f32_number(value),
       do: :ok

  defp validate_style_op(other), do: {:error, {:invalid_style_op, other}}

  defp valid_length?(:auto, true), do: true
  defp valid_length?(length, allow_negative), do: valid_definite_length?(length, allow_negative)

  defp valid_definite_length?({unit, value}, true)
       when unit in [:px, :rem, :fraction] and is_native_f32_number(value),
       do: true

  defp valid_definite_length?({unit, value}, false)
       when unit in [:px, :rem, :fraction] and is_non_neg_native_f32_number(value),
       do: true

  defp valid_definite_length?(_length, _allow_negative), do: false

  defp valid_linear_gradient_options?(options) when is_list(options) do
    if Keyword.keyword?(options) do
      keys = Keyword.keys(options)

      length(options) == 3 and MapSet.size(MapSet.new(keys)) == 3 and
        Enum.sort(keys) == [:angle, :from, :to] and
        valid_gradient_angle?(Keyword.fetch!(options, :angle)) and
        valid_gradient_stop?(Keyword.fetch!(options, :from)) and
        valid_gradient_stop?(Keyword.fetch!(options, :to))
    else
      false
    end
  end

  defp valid_linear_gradient_options?(_options), do: false

  defp valid_gradient_angle?(angle),
    do: native_f32_number?(angle) and angle >= 0.0 and angle <= 360.0

  defp valid_gradient_stop?({color, percentage}),
    do: valid_gradient_color?(color) and unit_native_f32_number?(percentage)

  defp valid_gradient_stop?(_stop), do: false

  defp valid_gradient_color?(color) when color in @color_tokens, do: true

  defp valid_gradient_color?(color) when is_binary(color),
    do: Regex.match?(~r/^#[0-9a-fA-F]{6}$/, color)

  defp valid_gradient_color?(_color), do: false

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
