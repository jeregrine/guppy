defmodule Guppy.App.CommandPalette do
  @moduledoc """
  Minimal reusable command-palette overlay window for `Guppy.App`.

  It is intentionally Elixir-owned: the palette is a small app-supervised
  `Guppy.Window` opened as a popup/floating window, renders the app command
  registry, and dispatches selected command ids back to the app coordinator.
  """

  use Guppy.Window

  @impl Guppy.Window
  def mount(app, window) do
    {:ok,
     window
     |> assign(:app, app)
     |> put_window_opts(
       kind: :popup,
       show: true,
       focus: true,
       window_bounds: [width: 420, height: 320],
       titlebar: false
     )}
  end

  @impl Guppy.Window
  def render(window) do
    commands =
      window.assigns.app
      |> Guppy.App.commands()
      |> Map.values()
      |> Enum.sort_by(&(&1.label || &1.id))

    Guppy.IR.div(
      [
        Guppy.IR.text("Command Palette",
          id: "command_palette_title",
          style: [{:font_weight, :bold}]
        ),
        Guppy.IR.div(Enum.map(commands, &command_row/1), id: "command_palette_commands")
      ],
      id: "command_palette",
      style: [
        {:padding, :all, {:px, 16.0}},
        {:gap, :all, {:px, 8.0}},
        {:flex_direction, :column},
        {:bg, :gray},
        {:text_color, :white}
      ]
    )
  end

  @impl Guppy.Window
  def handle_event("run_command", %{id: "command_palette_" <> command_id}, window) do
    :ok = Guppy.App.dispatch(window.assigns.app, command_id, %{source: :command_palette})
    {:stop, :normal, window}
  end

  def handle_event("run_command", _event, window), do: {:noreply, window, :skip_render}

  defp command_row(command) do
    Guppy.IR.button(command.label || command.id,
      id: "command_palette_" <> command.id,
      events: %{click: "run_command"},
      disabled: not command.enabled,
      style: [
        {:padding, :all, {:px, 8.0}},
        {:border_width, :all, {:px, 1.0}},
        {:border_color, :white}
      ]
    )
  end
end
