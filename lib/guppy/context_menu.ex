defmodule Guppy.ContextMenu do
  @moduledoc """
  Data-first helpers for rendering element-local context menus.

  This module intentionally stays in Elixir: native code emits `:context_menu`
  events for pointer and keyboard invocation, while the owning process decides
  whether and where to render a menu. Menu items are plain data and render to
  ordinary Guppy IR button/div nodes, so row/tree/canvas/editor owners keep UI
  state and action routing.
  """

  defmodule Item do
    @moduledoc false
    @enforce_keys []
    defstruct id: nil, label: nil, callback: nil, disabled: false, separator: false
  end

  @type item :: %Item{
          id: String.t() | nil,
          label: String.t() | nil,
          callback: String.t() | nil,
          disabled: boolean(),
          separator: boolean()
        }

  @supported_item_keys [:id, :label, :callback, :disabled]
  @supported_separator_keys [:separator]

  @doc "Validates context menu item data."
  def validate(items) when is_list(items) do
    items
    |> Enum.reduce_while({:ok, [], MapSet.new()}, fn item, {:ok, acc, ids} ->
      case validate_item(item, ids) do
        {:ok, item, ids} -> {:cont, {:ok, [item | acc], ids}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items, _ids} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  def validate(items), do: {:error, {:invalid_context_menu, items}}

  @doc "Validates context menu item data or raises `ArgumentError`."
  def validate!(items) do
    case validate(items) do
      {:ok, items} -> items
      {:error, reason} -> raise ArgumentError, "invalid context menu: #{inspect(reason)}"
    end
  end

  @doc "Renders a context menu as Guppy IR."
  def render(items, opts \\ []) when is_list(opts) do
    items = validate!(items)
    id = Keyword.get(opts, :id, "context_menu")
    style = Keyword.get(opts, :style)
    item_style = Keyword.get(opts, :item_style)
    disabled_item_style = Keyword.get(opts, :disabled_item_style)
    separator_style = Keyword.get(opts, :separator_style)

    children =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        render_item(item, index, id, item_style, disabled_item_style, separator_style)
      end)

    Guppy.IR.div(children, id: id, style: style)
  end

  defp validate_item(:separator, ids), do: {:ok, %Item{separator: true}, ids}

  defp validate_item(%{separator: true} = item, ids) do
    with :ok <- validate_keys(item, @supported_separator_keys, {:invalid_context_menu_item, item}) do
      {:ok, %Item{separator: true}, ids}
    end
  end

  defp validate_item(%{id: id, label: label, callback: callback} = item, ids)
       when is_binary(id) and id != "" and is_binary(label) and label != "" and
              is_binary(callback) and callback != "" do
    with :ok <- validate_keys(item, @supported_item_keys, {:invalid_context_menu_item, item}),
         :ok <- validate_disabled(Map.get(item, :disabled, false), item),
         {:ok, ids} <- track_id(id, ids) do
      {:ok,
       %Item{
         id: id,
         label: label,
         callback: callback,
         disabled: Map.get(item, :disabled, false)
       }, ids}
    end
  end

  defp validate_item(item, _ids), do: {:error, {:invalid_context_menu_item, item}}

  defp validate_keys(map, allowed_keys, error) do
    case Map.keys(map) -- allowed_keys do
      [] -> :ok
      _ -> {:error, error}
    end
  end

  defp validate_disabled(disabled, _item) when is_boolean(disabled), do: :ok
  defp validate_disabled(_disabled, item), do: {:error, {:invalid_context_menu_item, item}}

  defp track_id(id, ids) do
    if MapSet.member?(ids, id) do
      {:error, {:duplicate_context_menu_item_id, id}}
    else
      {:ok, MapSet.put(ids, id)}
    end
  end

  defp render_item(%Item{separator: true}, index, menu_id, _item_style, _disabled_style, style) do
    Guppy.IR.div([], id: "#{menu_id}.separator.#{index}", style: style)
  end

  defp render_item(%Item{} = item, _index, menu_id, item_style, disabled_style, _separator_style) do
    style = if item.disabled, do: disabled_style || item_style, else: item_style

    Guppy.IR.button(item.label,
      id: "#{menu_id}.#{item.id}",
      events: %{click: item.callback},
      disabled: item.disabled,
      style: style
    )
  end
end
