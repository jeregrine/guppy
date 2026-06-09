defmodule Guppy.Examples.NativeAppShellDemo.MainWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(
       titlebar: [title: "Native app shell demo"],
       window_bounds: [width: 860, height: 680],
       focus: true,
       show: true
     )
     |> assign(:badge_count, 0)
     |> assign(:status, "Ready")
     |> assign(:events, ["Started native app shell demo"])}
  end

  @impl Guppy.Window
  def render(window) do
    command_bindings = Guppy.App.command_bindings(Guppy.App.current_app())
    command_actions = Keyword.fetch!(command_bindings, :actions)
    command_shortcuts = Keyword.fetch!(command_bindings, :shortcuts)

    ~GUI"""
    <div id="shell_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]" actions={command_actions} shortcuts={command_shortcuts}>
      <div id="header" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="title" class="text-3xl font-black">Native app shell APIs</text>
        <text id="subtitle" class="text-base text-[#94a3b8] leading-snug">
          Test app badges, file dialogs with filters/defaults/owner view ids, app-window focus, lifecycle events, and context-menu focus return.
        </text>
        <text id="status" class="text-sm text-[#bfdbfe]">Status: {@status}</text>
      </div>

      <div id="button_grid" class="grid grid-cols-2 gap-3">
        <button id="badge_inc" click="badge_inc" class="p-3 rounded-lg border-1 border-[#2563eb] bg-[#1d4ed8] text-[#ffffff]">Increment app badge</button>
        <button id="badge_clear" click="badge_clear" class="p-3 rounded-lg border-1 border-[#334155] bg-[#1e293b]">Clear app badge</button>
        <button id="open_file" click="open_file" class="p-3 rounded-lg border-1 border-[#334155] bg-[#111827]">Open .ex/.exs file...</button>
        <button id="choose_dir" click="choose_dir" class="p-3 rounded-lg border-1 border-[#334155] bg-[#111827]">Choose directory...</button>
        <button id="save_file" click="save_file" class="p-3 rounded-lg border-1 border-[#334155] bg-[#111827]">Save .txt path...</button>
        <button id="open_secondary" click="open_secondary" class="p-3 rounded-lg border-1 border-[#334155] bg-[#111827]">Open/focus secondary window</button>
      </div>

      <div id="context_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#7c3aed] bg-[#1e1b4b]">
        <text id="context_title" class="text-lg font-bold">Context menu + focus return</text>
        <text class="text-sm text-[#c4b5fd]">Right-click this panel or focus it and press Shift-F10. Selecting an item dispatches an app command, closes the popup, and focuses this main window again.</text>
        <div id="context_target" context_menu="open_context_menu" focusable="true" tab_index="1" class="p-4 rounded-lg border-1 border-[#a78bfa] bg-[#312e81] cursor-context-menu">
          <text>Context target - right-click / Shift-F10 here</text>
        </div>
        <button id="context_button" click="open_context_menu" class="p-2 rounded-lg border-1 border-[#a78bfa] bg-[#4c1d95] text-[#ffffff]">Open same context menu from button</button>
      </div>

      <div id="lifecycle_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] flex-1">
        <text id="events_title" class="text-lg font-bold">Recent shell/lifecycle events</text>
        <div :for={{event, index} <- Enum.with_index(@events)} id={"event_#{index}"} class="p-2 rounded-md bg-[#0b1220]">
          <text class="text-sm text-[#e2e8f0]">{event}</text>
        </div>
      </div>
    </div>
    """
  end

  @impl Guppy.Window
  def handle_event("badge_inc", _event, window), do: increment_badge(window)
  def handle_event("badge_clear", _event, window), do: set_badge(window, nil, "Cleared app badge")
  def handle_event("open_file", _event, window), do: open_file(window)
  def handle_event("choose_dir", _event, window), do: choose_directory(window)
  def handle_event("save_file", _event, window), do: save_file(window)
  def handle_event("open_secondary", _event, window), do: open_or_focus_secondary(window)
  def handle_event("open_context_menu", event, window), do: open_context_menu(window, event)

  def handle_event("window_focused", _event, window) do
    {:noreply, log(window, "Main window focused")}
  end

  def handle_event("window_blurred", _event, window) do
    {:noreply, log(window, "Main window blurred")}
  end

  def handle_event("window_moved", event, window) do
    {:noreply, log(window, "Main window moved: #{inspect(event)}")}
  end

  def handle_event("window_resized", event, window) do
    {:noreply, log(window, "Main window resized: #{inspect(event)}")}
  end

  def handle_info({:native_shell_command, command_id, _payload}, window) do
    case command_id do
      "increment_badge" -> increment_badge(window)
      "clear_badge" -> set_badge(window, nil, "Cleared app badge from context menu")
      "open_file" -> open_file(window)
      "focus_secondary" -> open_or_focus_secondary(window)
      other -> {:noreply, log(window, "Unhandled app command: #{other}")}
    end
  end

  defp increment_badge(window) do
    count = window.assigns.badge_count + 1

    set_badge(
      %{window | assigns: Map.put(window.assigns, :badge_count, count)},
      Integer.to_string(count),
      "Set app badge to #{count}"
    )
  end

  defp set_badge(window, label, message) do
    result = Guppy.App.set_app_badge(Guppy.App.current_app(), label)

    window =
      window
      |> assign(:badge_count, if(is_nil(label), do: 0, else: String.to_integer(label)))
      |> log("#{message} -> #{inspect(result)}")

    {:noreply, window}
  end

  defp open_file(window) do
    result =
      Guppy.open_file_dialog(
        [
          multiple: true,
          prompt: "Open Elixir source",
          directory: File.cwd!(),
          filters: ["ex", "exs"],
          owner_view_id: window.view_id
        ],
        120_000
      )

    {:noreply, log(window, "Open file dialog returned #{format_dialog_result(result)}")}
  end

  defp choose_directory(window) do
    result =
      Guppy.choose_directory_dialog(
        [prompt: "Choose a directory", directory: File.cwd!(), owner_view_id: window.view_id],
        120_000
      )

    {:noreply, log(window, "Choose directory dialog returned #{format_dialog_result(result)}")}
  end

  defp save_file(window) do
    result =
      Guppy.save_file_dialog(
        [
          directory: File.cwd!(),
          default_name: "guppy-native-shell-demo.txt",
          filters: ["txt"],
          owner_view_id: window.view_id
        ],
        120_000
      )

    {:noreply, log(window, "Save file dialog returned #{format_dialog_result(result)}")}
  end

  defp open_or_focus_secondary(window) do
    app = Guppy.App.current_app()

    result =
      case Guppy.App.open_window(app, "secondary") do
        {:ok, _pid} = ok -> ok
        {:error, {:duplicate_window_id, "secondary"}} -> Guppy.App.focus_window(app, "secondary")
        other -> other
      end

    {:noreply, log(window, "Open/focus secondary -> #{inspect(result)}")}
  end

  defp open_context_menu(window, event) do
    app = Guppy.App.current_app()
    window_id = Guppy.App.current_window_id()

    result =
      Guppy.App.open_context_menu(
        app,
        [
          %{command: "increment_badge"},
          %{command: "clear_badge"},
          :separator,
          %{command: "open_file"},
          %{command: "focus_secondary"}
        ],
        id: "native_shell_context_menu",
        payload: %{source_pid: self(), source_event: inspect(event)},
        return_focus_to: window_id,
        window_bounds: [width: 260, height: 220]
      )

    {:noreply, log(window, "Opened context menu -> #{inspect(result)}")}
  end

  defp log(window, message) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second) |> Calendar.strftime("%H:%M:%S")

    window
    |> assign(:status, message)
    |> assign(:events, ["#{timestamp}  #{message}" | window.assigns.events] |> Enum.take(8))
  end

  defp format_dialog_result({:ok, nil}), do: "cancel"
  defp format_dialog_result({:ok, paths}) when is_list(paths), do: Enum.join(paths, ", ")
  defp format_dialog_result({:ok, path}) when is_binary(path), do: path
  defp format_dialog_result(other), do: inspect(other)
end

defmodule Guppy.Examples.NativeAppShellDemo.SecondaryWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(
       titlebar: [title: "Secondary shell window"],
       window_bounds: [width: 440, height: 260],
       focus: true,
       show: true
     )
     |> assign(:status, "Secondary ready")}
  end

  @impl Guppy.Window
  def render(window) do
    ~GUI"""
    <div id="secondary_root" class="flex flex-col gap-3 p-5 bg-[#111827] text-[#f8fafc]">
      <text id="secondary_title" class="text-xl font-bold">Secondary window</text>
      <text id="secondary_status" class="text-sm text-[#bfdbfe]">{@status}</text>
      <button id="focus_main" click="focus_main" class="p-3 rounded-lg border-1 border-[#334155] bg-[#1e293b]">Focus main window</button>
    </div>
    """
  end

  @impl Guppy.Window
  def handle_event("focus_main", _event, window) do
    result = Guppy.App.focus_window(Guppy.App.current_app(), "main")
    {:noreply, assign(window, :status, "Focus main -> #{inspect(result)}")}
  end
end

defmodule Guppy.Examples.NativeAppShellDemo do
  use Guppy.App,
    windows: [
      %{id: "main", module: Guppy.Examples.NativeAppShellDemo.MainWindow, start: false},
      %{id: "secondary", module: Guppy.Examples.NativeAppShellDemo.SecondaryWindow, start: false}
    ],
    commands: [
      %{id: "increment_badge", label: "Increment Badge"},
      %{id: "clear_badge", label: "Clear Badge"},
      %{id: "open_file", label: "Open .ex/.exs File"},
      %{id: "focus_secondary", label: "Focus Secondary Window"}
    ],
    keymap: [
      %{key: "cmd-b", command: "increment_badge"},
      %{key: "cmd-shift-b", command: "clear_badge"},
      %{key: "cmd-o", command: "open_file"},
      %{key: "cmd-2", command: "focus_secondary"}
    ],
    menus: [
      %{
        label: "Shell Demo",
        items: [
          %{
            id: "increment_badge",
            label: "Increment Badge",
            callback: "increment_badge",
            shortcut: "cmd-b"
          },
          %{
            id: "clear_badge",
            label: "Clear Badge",
            callback: "clear_badge",
            shortcut: "cmd-shift-b"
          },
          :separator,
          %{
            id: "open_file",
            label: "Open .ex/.exs File",
            callback: "open_file",
            shortcut: "cmd-o"
          },
          %{
            id: "focus_secondary",
            label: "Focus Secondary",
            callback: "focus_secondary",
            shortcut: "cmd-2"
          }
        ]
      }
    ],
    dock_menu: [
      %{id: "increment_badge", label: "Increment Badge", callback: "increment_badge"},
      %{id: "focus_secondary", label: "Focus Secondary", callback: "focus_secondary"}
    ],
    app_badge: "0",
    package: %{bundle_id: "dev.guppy.examples.native_app_shell"},
    exit_on_last_window_closed: true

  @impl Guppy.App
  def handle_command(command_id, payload, state) do
    case command_target(payload, state) do
      pid when is_pid(pid) -> send(pid, {:native_shell_command, command_id, payload})
      nil -> Task.start(fn -> fallback_command(command_id) end)
    end

    {:noreply, state}
  end

  @impl Guppy.App
  def handle_event(event_name, payload, state) do
    IO.puts("app lifecycle: #{event_name} #{inspect(payload)}")
    {:noreply, state}
  end

  defp command_target(%{source_pid: pid}, _state) when is_pid(pid), do: pid

  defp command_target(%{window_id: window_id}, state) when is_binary(window_id) do
    state.windows
    |> Map.get(window_id)
    |> case do
      %{pid: pid} -> pid
      _ -> nil
    end
  end

  defp command_target(_payload, _state), do: nil

  defp fallback_command("increment_badge"), do: Guppy.App.set_app_badge(__MODULE__, "!")
  defp fallback_command("clear_badge"), do: Guppy.App.set_app_badge(__MODULE__, nil)

  defp fallback_command("focus_secondary") do
    case Guppy.App.open_window(__MODULE__, "secondary") do
      {:error, {:duplicate_window_id, "secondary"}} ->
        Guppy.App.focus_window(__MODULE__, "secondary")

      other ->
        other
    end
  end

  defp fallback_command(_command_id), do: :ok
end

if "--validate-only" in System.argv() do
  IO.puts("native_app_shell_demo.exs loaded")
else
  {:ok, _} = Application.ensure_all_started(:guppy)

  IO.puts("Guppy native app shell demo")

  IO.puts(
    "Try file dialogs, app badge buttons, cmd-b/cmd-o/cmd-2, and right-click/Shift-F10 on the context panel."
  )

  {:ok, app_pid} = Guppy.Examples.NativeAppShellDemo.start_link([])

  {:ok, _main_window} =
    Guppy.App.open_window(Guppy.Examples.NativeAppShellDemo, "main", [], 30_000)

  app_ref = Process.monitor(app_pid)

  receive do
    {:DOWN, ^app_ref, :process, ^app_pid, _reason} -> :ok
  end
end
