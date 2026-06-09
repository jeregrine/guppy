Code.require_file("support/ui.exs", __DIR__)

defmodule Examples.MenuDemoWindow do
  use Guppy.Window

  alias Examples.UI

  @impl Guppy.Window
  def mount(_arg, window) do
    window =
      window
      |> put_window_opts(
        window_bounds: [width: 560, height: 420],
        titlebar: [title: "Notes"]
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
    <div id="menu_demo_root" class={UI.window_class()}>
      <textarea
        id="draft_editor"
        value={@draft}
        placeholder="Type here, then try the app menu"
        change="draft_changed"
        class={"flex-1 p-2 rounded-md border-1 border-[" <> UI.border() <> "] bg-[" <> UI.surface() <> "] text-sm text-[" <> UI.text() <> "]"}
      />

      <div id="events_panel" class="flex flex-col gap-1">
        <text id="events_title" class="text-sm font-semibold">Recent menu callbacks</text>
        <text :if={@events == []} id="no_events" class={UI.caption_class()}>
          Choose File -> New Note, File -> Insert Timestamp, or Help -> About Guppy. The Edit menu drives the focused field.
        </text>
        <text :for={{event, index} <- @events} id={"menu_event_#{index}"} class={UI.caption_class()}>
          {format_menu_event(event)}
        </text>
      </div>

      <text id="menu_status" class={UI.caption_class()}>Guppy.set_menus/1 returned {@menu_status}</text>
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

{:ok, pid} = Examples.MenuDemoWindow.start_link([])

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    _ = Guppy.set_menus([])
    :ok
end
