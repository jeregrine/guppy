defmodule Guppy.Examples.MultiWindowApp.MainWindow do
  use Guppy.Window

  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(
       titlebar: [title: "Guppy App"],
       window_bounds: [width: 760, height: 520],
       focus: true,
       show: true
     )
     |> assign(:message, "Ready")}
  end

  def render(window) do
    app_styles = Guppy.App.styles(Guppy.App.current_app(), "card hover:bg-blue")

    ~GUI"""
    <div id="main" class="flex flex-col gap-3 p-4 bg-[#0f172a] text-[#f8fafc]">
      <text id="title" class="text-3xl font-bold">Guppy.App multi-window demo</text>
      <text id="message">{@message}</text>
      <button id="palette" click="palette" class="p-2 rounded-md border-1">Open command palette</button>
      <button id="secondary" click="secondary" class="p-2 rounded-md border-1">Open secondary window</button>
      <div id="styled_card" style={Keyword.get(app_styles, :style)} hover_style={Keyword.get(app_styles, :hover_style)}>
        <text>Stylesheet class refs resolve in Elixir, including state variants.</text>
      </div>
    </div>
    """
  end

  def handle_event("palette", _event, window) do
    _ = Guppy.App.open_command_palette(Guppy.App.current_app())
    {:noreply, assign(window, :message, "Opened command palette")}
  end

  def handle_event("secondary", _event, window) do
    _ = Guppy.App.open_window(Guppy.App.current_app(), "secondary")
    {:noreply, assign(window, :message, "Opened secondary window")}
  end
end

defmodule Guppy.Examples.MultiWindowApp.SecondaryWindow do
  use Guppy.Window

  def mount(_arg, window) do
    {:ok,
     put_window_opts(window,
       titlebar: [title: "Secondary"],
       window_bounds: [width: 420, height: 260],
       focus: true,
       show: true
     )}
  end

  def render(_window) do
    ~GUI"""
    <div id="secondary" class="flex flex-col gap-2 p-4 bg-[#111827] text-[#f8fafc]">
      <text id="secondary_title" class="text-xl font-bold">Secondary app window</text>
      <text id="secondary_body">This window is opened and tracked by the app coordinator.</text>
    </div>
    """
  end
end

defmodule Guppy.Examples.MultiWindowApp do
  use Guppy.App,
    windows: [
      %{id: "main", module: Guppy.Examples.MultiWindowApp.MainWindow, start: false},
      %{id: "secondary", module: Guppy.Examples.MultiWindowApp.SecondaryWindow, start: false}
    ],
    theme: %{id: "demo-dark", name: "Demo Dark", appearance: :dark},
    stylesheet: %{
      classes: %{
        "card" => %{
          style: "p-4 rounded-lg border-1 border-white bg-[#1e293b]",
          hover_style: "bg-blue"
        }
      }
    },
    commands: [
      %{id: "open_secondary", label: "Open Secondary Window"},
      %{id: "show_palette", label: "Show Command Palette"}
    ],
    keymap: [
      %{key: "cmd-shift-p", command: "show_palette"},
      %{key: "cmd-2", command: "open_secondary"}
    ],
    menus: [
      %{
        label: "Window",
        items: [
          %{
            id: "show_palette",
            label: "Command Palette",
            callback: "show_palette",
            shortcut: "cmd-shift-p"
          },
          %{
            id: "open_secondary",
            label: "Open Secondary",
            callback: "open_secondary",
            shortcut: "cmd-2"
          }
        ]
      }
    ],
    package: %{bundle_id: "dev.guppy.examples.multi_window"},
    exit_on_last_window_closed: true

  def handle_command("open_secondary", _payload, state) do
    Task.start(fn -> Guppy.App.open_window(__MODULE__, "secondary") end)
    {:noreply, state}
  end

  def handle_command("show_palette", _payload, state) do
    Task.start(fn -> Guppy.App.open_command_palette(__MODULE__) end)
    {:noreply, state}
  end
end

{:ok, app_pid} = Guppy.Examples.MultiWindowApp.start_link([])
{:ok, _main_window} = Guppy.App.open_window(Guppy.Examples.MultiWindowApp, "main", [], 30_000)

IO.puts("Opened Guppy.Examples.MultiWindowApp main window")
IO.puts("Use the buttons/menu/command palette to open the secondary window.")
IO.puts("Close all app windows to exit the example.")

app_ref = Process.monitor(app_pid)

receive do
  {:DOWN, ^app_ref, :process, ^app_pid, _reason} -> :ok
end
