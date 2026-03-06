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

  @type events :: %{optional(:click) => String.t()}
  @type text_node :: %{required(:kind) => :text, required(:content) => String.t()}
  @type div_node :: %{
          required(:kind) => :div,
          required(:children) => [ir_node()],
          optional(:events) => events()
        }
  @type ir_node :: text_node() | div_node()

  @spec text(String.t()) :: text_node()
  def text(content) when is_binary(content) do
    %{kind: :text, content: content}
  end

  @spec div([ir_node()], keyword()) :: div_node()
  def div(children, opts \\ []) when is_list(children) and is_list(opts) do
    events = Keyword.get(opts, :events)

    %{kind: :div, children: children}
    |> maybe_put(:events, events)
  end

  @spec validate(ir_node()) :: :ok | {:error, term()}
  def validate(%{kind: :text, content: content}) when is_binary(content), do: :ok

  def validate(%{kind: :div, children: children} = node) when is_list(children) do
    with :ok <- validate_events(Map.get(node, :events)),
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
