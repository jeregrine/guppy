defmodule Examples.MenuDemoWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(_arg, window) do
    window =
      window
      |> put_window_opts(
        window_bounds: [width: 760, height: 560],
        titlebar: [title: "Guppy menu demo"]
      )
      |> assign(:draft, "Focus this field, then use the Edit menu for Cut/Copy/Paste/Select All.")
      |> assign(:menu_events, [])
      |> assign(:menu_status, "installing")

    menu_status = Guppy.set_menus(menu_spec())
    {:ok, assign(window, :menu_status, inspect(menu_status))}
  end

  @impl Guppy.Window
  def handle_event("draft_changed", %{value: value}, window) do
    {:noreply, assign(window, :draft, value)}
  end

  def handle_info({:guppy_menu_event, %{callback: "new_note"} = event}, window) do
    window =
      window
      |> assign(:draft, "")
      |> push_menu_event(event)

    {:noreply, window}
  end

  def handle_info({:guppy_menu_event, %{callback: "insert_timestamp"} = event}, window) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    window =
      window
      |> assign(:draft, window.assigns.draft <> "\nInserted from menu at #{timestamp}")
      |> push_menu_event(event)

    {:noreply, window}
  end

  def handle_info({:guppy_menu_event, %{callback: "about"} = event}, window) do
    window =
      window
      |> assign(
        :draft,
        window.assigns.draft <>
          "\nGuppy menus route callbacks to the process that installed them."
      )
      |> push_menu_event(event)

    {:noreply, window}
  end

  def handle_info({:guppy_menu_event, event}, window) do
    {:noreply, push_menu_event(window, event)}
  end

  @impl Guppy.Window
  def render(window) do
    assigns =
      Map.merge(window.assigns, %{
        events: Enum.with_index(window.assigns.menu_events, 1)
      })

    ~GUI"""
    <div id="menu_demo_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="menu_header" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="menu_title" class="text-2xl font-black">App menu demo</text>
        <text id="menu_subtitle" class="text-base text-[#94a3b8] leading-snug">
          The File and Help menus send callbacks back to this window process. The Edit menu uses GPUI OS edit actions against the focused text input.
        </text>
        <text id="menu_status" class="text-sm text-[#bfdbfe]">Guppy.set_menus/1 returned {@menu_status}</text>
      </div>

      <div id="editor_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#1e40af] bg-[#172554] shadow-md flex-1">
        <text id="editor_label" class="text-sm font-bold text-[#bfdbfe]">Scratch note</text>
        <textarea
          id="draft_editor"
          value={@draft}
          placeholder="Type here, then try the app menu"
          change="draft_changed"
          class="flex-1 p-4 rounded-lg border-1 border-[#2563eb] bg-[#0b1220] text-[#f8fafc]"
        />
      </div>

      <div id="events_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="events_title" class="text-base font-bold">Recent menu callbacks</text>
        <div :if={@events == []} id="no_events" class="p-2 rounded-md bg-[#0b1220]">
          <text class="text-sm text-[#94a3b8]">Choose File -> New Note, File -> Insert Timestamp, or Help -> About Guppy.</text>
        </div>
        <div :for={{event, index} <- @events} id={"menu_event_#{index}"} class="p-2 rounded-md bg-[#0b1220]">
          <text class="text-sm text-[#e2e8f0]">{format_menu_event(event)}</text>
        </div>
      </div>
    </div>
    """
  end

  defp menu_spec do
    [
      %{
        label: "File",
        items: [
          %{id: "new_note", label: "New Note", callback: "new_note", shortcut: "cmd-n"},
          %{
            id: "insert_timestamp",
            label: "Insert Timestamp",
            callback: "insert_timestamp",
            shortcut: "cmd-shift-t"
          },
          :separator,
          %{
            id: "disabled_menu_item",
            label: "Disabled item",
            callback: "disabled",
            enabled: false
          }
        ]
      },
      %{
        label: "Edit",
        items: [
          %{id: "cut", label: "Cut", os_action: :cut},
          %{id: "copy", label: "Copy", os_action: :copy},
          %{id: "paste", label: "Paste", os_action: :paste},
          :separator,
          %{id: "select_all", label: "Select All", os_action: :select_all}
        ]
      },
      %{
        label: "Help",
        items: [%{id: "about", label: "About Guppy Menus", callback: "about"}]
      }
    ]
  end

  defp push_menu_event(window, event) do
    assign(window, :menu_events, [event | window.assigns.menu_events] |> Enum.take(5))
  end

  defp format_menu_event(%{id: id, callback: callback}) do
    "#{id} -> #{callback}"
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy menu demo")
IO.puts("load_status: #{inspect(Guppy.Native.Nif.load_status())}")
IO.puts("native_build_info: #{inspect(Guppy.native_build_info())}")
IO.puts("native_runtime_status: #{inspect(Guppy.native_runtime_status())}")
IO.puts("native_gui_status: #{inspect(Guppy.native_gui_status())}")

{:ok, pid} = Examples.MenuDemoWindow.start_link([])
IO.puts("opened_view_id: #{inspect(Guppy.Window.view_id(pid))}")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    _ = Guppy.set_menus([])
    :ok
end
