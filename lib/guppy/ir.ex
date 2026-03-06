defmodule Guppy.IR do
  @moduledoc """
  Minimal IR helpers for the Phase 1 tracer shot.

  This starts with just enough structure to prove:

  - Elixir owns UI state
  - Elixir sends a tree description
  - native GPUI renders that description
  - Elixir sends full-tree replacement updates
  - native click events can roundtrip back to Elixir
  """

  @type node_id :: String.t()
  @type color_token :: :red | :green | :blue | :yellow | :black | :white | :gray

  @type style :: %{
          optional(:flex) => boolean(),
          optional(:flex_col) => boolean(),
          optional(:gap_2) => boolean(),
          optional(:p_2) => boolean(),
          optional(:p_4) => boolean(),
          optional(:p_6) => boolean(),
          optional(:items_center) => boolean(),
          optional(:justify_center) => boolean(),
          optional(:cursor_pointer) => boolean(),
          optional(:rounded_md) => boolean(),
          optional(:bg) => color_token(),
          optional(:text_color) => color_token()
        }

  @type events :: %{optional(:click) => String.t()}

  @type text_node :: %{
          required(:kind) => :text,
          required(:content) => String.t(),
          optional(:id) => node_id()
        }

  @type div_node :: %{
          required(:kind) => :div,
          required(:children) => [ir_node()],
          optional(:id) => node_id(),
          optional(:style) => style(),
          optional(:events) => events()
        }

  @type ir_node :: text_node() | div_node()

  @style_boolean_keys [
    :flex,
    :flex_col,
    :gap_2,
    :p_2,
    :p_4,
    :p_6,
    :items_center,
    :justify_center,
    :cursor_pointer,
    :rounded_md
  ]

  @style_color_keys [:bg, :text_color]
  @color_tokens [:red, :green, :blue, :yellow, :black, :white, :gray]

  @spec text(String.t(), keyword()) :: text_node()
  def text(content, opts \\ []) when is_binary(content) and is_list(opts) do
    id = Keyword.get(opts, :id)

    %{kind: :text, content: content}
    |> maybe_put(:id, id)
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
    validate_id(Map.get(node, :id))
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

  defp validate_style(style) when is_map(style) do
    Enum.reduce_while(style, :ok, fn
      {key, value}, :ok when key in @style_boolean_keys and is_boolean(value) ->
        {:cont, :ok}

      {key, value}, :ok when key in @style_color_keys and value in @color_tokens ->
        {:cont, :ok}

      {key, value}, :ok ->
        {:halt, {:error, {:invalid_style, key, value}}}
    end)
  end

  defp validate_style(other), do: {:error, {:invalid_style_map, other}}

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
