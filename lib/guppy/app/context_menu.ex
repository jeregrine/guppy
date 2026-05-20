defmodule Guppy.App.ContextMenu do
  @moduledoc """
  Minimal app-owned context-menu popup window.

  The menu is intentionally Elixir-owned. Native elements emit `:context_menu`
  events, the owning app opens this transient `Guppy.Window`, and item clicks
  dispatch registered app commands through `c:Guppy.App.handle_command/3`.
  """

  use Guppy.Window

  @callback_id "run_context_menu_command"

  @impl Guppy.Window
  def mount(arg, window) when is_map(arg) do
    {:ok,
     window
     |> assign(:app, Map.fetch!(arg, :app))
     |> assign(:id, Map.get(arg, :id, "context_menu"))
     |> assign(:items, Map.fetch!(arg, :items))
     |> assign(:style, Map.get(arg, :style))
     |> assign(:item_style, Map.get(arg, :item_style))
     |> assign(:disabled_item_style, Map.get(arg, :disabled_item_style))
     |> assign(:separator_style, Map.get(arg, :separator_style))
     |> assign(:payload, Map.get(arg, :payload, %{}))
     |> put_window_opts(Map.get(arg, :window_options, default_window_options()))}
  end

  @impl Guppy.Window
  def render(window) do
    Guppy.ContextMenu.render(resolve_items(window.assigns.items, window.assigns.app),
      id: window.assigns.id,
      style: Map.get(window.assigns, :style),
      item_style: Map.get(window.assigns, :item_style),
      disabled_item_style: Map.get(window.assigns, :disabled_item_style),
      separator_style: Map.get(window.assigns, :separator_style)
    )
  end

  @impl Guppy.Window
  def handle_event(@callback_id, %{id: item_id}, window) when is_binary(item_id) do
    case command_id_from_item_id(item_id, window.assigns.id) do
      {:ok, command_id} ->
        payload =
          window.assigns
          |> Map.get(:payload, %{})
          |> Map.put_new(:source, :context_menu)
          |> Map.put(:menu_id, window.assigns.id)

        :ok = Guppy.App.dispatch(window.assigns.app, command_id, payload)
        {:stop, :normal, window}

      :error ->
        {:noreply, window, :skip_render}
    end
  end

  def handle_event(@callback_id, _event, window), do: {:noreply, window, :skip_render}

  defp default_window_options do
    [
      kind: :popup,
      focus: true,
      show: true,
      titlebar: false,
      window_bounds: [width: 220, height: 240]
    ]
  end

  defp resolve_items(items, app) do
    commands = Guppy.App.commands(app)
    Enum.map(items, &resolve_item(&1, commands))
  end

  defp resolve_item(:separator, _commands), do: :separator
  defp resolve_item(%{separator: true}, _commands), do: %{separator: true}

  defp resolve_item(%{command: command_id} = item, commands) when is_binary(command_id) do
    command =
      Map.get(commands, command_id) ||
        raise ArgumentError, "unknown context menu command: #{inspect(command_id)}"

    %{
      id: command_id,
      label: Map.get(item, :label) || command.label || command.id,
      callback: @callback_id,
      disabled: not command.enabled
    }
  end

  defp resolve_item(item, _commands) do
    raise ArgumentError, "invalid app context menu item: #{inspect(item)}"
  end

  defp command_id_from_item_id(item_id, menu_id) do
    prefix = menu_id <> "."

    if String.starts_with?(item_id, prefix) do
      {:ok, binary_part(item_id, byte_size(prefix), byte_size(item_id) - byte_size(prefix))}
    else
      :error
    end
  end
end
