Code.require_file("support/ui.exs", __DIR__)

defmodule Guppy.Examples.OverlayDemoWindow do
  use Guppy.Window

  alias Examples.UI

  @statuses [
    %{value: "todo", label: "Todo"},
    %{value: "blocked", label: "Blocked", disabled: true},
    %{value: "doing", label: "Doing"},
    %{value: "done", label: "Done"}
  ]

  @impl Guppy.Window
  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(
       titlebar: [title: "Overlays"],
       window_bounds: [width: 560, height: 620],
       focus: true,
       show: true
     )
     |> assign(initial_assigns())}
  end

  @impl Guppy.Window
  def render(window) do
    ~GUI"""
    <div id="overlay_root" class={UI.window_class()}>
      <div id="form_panel" class="flex flex-col gap-2">
        <text id="form_title" class="text-sm font-semibold">Status</text>
        <select
          id="status_select"
          value={@status}
          open={@select_open}
          options={@statuses}
          placeholder="Pick status"
          click="toggle_select"
          change="status_changed"
          close="close_select"
          class={"w-[260px] rounded-md border-1 border-[" <> UI.border() <> "] bg-[" <> UI.surface() <> "]"}
          list_class={"p-1 rounded-md border-1 border-[" <> UI.border() <> "] bg-[" <> UI.surface() <> "]"}
          option_class="p-2 text-sm"
          anchor="bottom_left"
          anchor_offset={{0, 10}}
          anchor_fit="snap_to_window_with_margin"
          snap_margin="12"
        />
        <text id="selected_status" class={UI.caption_class()}>
          Selected: {@status}. Arrows, Home/End, typeahead, Enter/Space, and Escape all work; the disabled Blocked option is skipped.
        </text>
      </div>

      <div id="popover_panel" class="flex flex-col gap-2">
        <text id="popover_title" class="text-sm font-semibold">Popover</text>
        <popover
          id="details_popover"
          label="Show details"
          open={@popover_open}
          click="toggle_popover"
          close="close_popover"
          anchor="bottom_left"
          anchor_position_mode="local"
          anchor_fit="snap_to_window_with_margin"
          anchor_offset={{0, 8}}
          snap_margin="12"
          close_on_click_outside="true"
          stack_priority="3"
          class={"w-[160px] " <> UI.button_class()}
          popover_class={"w-[320px] p-3 rounded-md border-1 border-[" <> UI.border() <> "] bg-[" <> UI.surface() <> "] text-[" <> UI.text() <> "]"}
        >
          <div id="popover_inner_panel" class="flex flex-col gap-2">
            <text class="text-sm">Ordinary content is supported inside a popover, including nested panels.</text>
            <div id="popover_nested_panel" class={"p-2 rounded-md bg-[" <> UI.window_bg() <> "]"}>
              <text class="text-sm">Nested overlay nodes are rejected by validation and native decode.</text>
            </div>
          </div>
        </popover>
        <text class={UI.caption_class()}>
          Snaps to the window with a margin; closes on outside click or Escape.
        </text>
      </div>

      <div id="context_panel" class="flex flex-col gap-2">
        <text id="context_title" class="text-sm font-semibold">Context menu</text>
        <div id="context_target" context_menu="open_context_menu" focusable="true" tab_index="1" class={"p-3 rounded-md border-1 border-[" <> UI.border() <> "] bg-[" <> UI.surface() <> "] cursor-context-menu"}>
          <text class="text-sm">Right-click here, or focus this box and press Shift-F10.</text>
        </div>
        {context_menu_ir(@context_menu_open)}
      </div>

      <div id="event_log" class="flex flex-col gap-1 flex-1">
        <text id="event_title" class="text-sm font-semibold">Recent events</text>
        <text :for={{event, index} <- Enum.with_index(@events)} id={"event_#{index}"} class={UI.caption_class()}>
          {event}
        </text>
      </div>
    </div>
    """
  end

  @impl Guppy.Window
  def handle_event("toggle_select", _event, window) do
    {:noreply,
     window
     |> assign(:select_open, !window.assigns.select_open)
     |> log("Toggled select")}
  end

  def handle_event("status_changed", %{value: value}, window) do
    {:noreply,
     window
     |> assign(:status, value)
     |> assign(:select_open, false)
     |> log("Changed select to #{value}")}
  end

  def handle_event("close_select", _event, window) do
    {:noreply, window |> assign(:select_open, false) |> log("Closed select")}
  end

  def handle_event("toggle_popover", _event, window) do
    {:noreply,
     window
     |> assign(:popover_open, !window.assigns.popover_open)
     |> log("Toggled popover")}
  end

  def handle_event("close_popover", _event, window) do
    {:noreply, window |> assign(:popover_open, false) |> log("Closed popover")}
  end

  def handle_event("open_context_menu", event, window) do
    {:noreply,
     window
     |> assign(:context_menu_open, true)
     |> log("Opened context menu from #{Map.get(event, :id, "unknown")}")}
  end

  def handle_event("context_action", %{id: id}, window) do
    action = String.replace_prefix(id, "overlay_context.", "")

    {:noreply,
     window
     |> assign(:context_menu_open, false)
     |> log("Context menu action: #{action}")}
  end

  def sample_ir do
    %Guppy.Window{assigns: initial_assigns()}
    |> render()
  end

  defp initial_assigns do
    %{
      status: "todo",
      statuses: @statuses,
      select_open: false,
      popover_open: false,
      context_menu_open: false,
      status_message: "Ready",
      events: ["Ready"]
    }
  end

  defp context_menu_ir(false), do: Guppy.IR.div([], id: "context_menu_placeholder")

  defp context_menu_ir(true) do
    Guppy.ContextMenu.render(
      [
        %{id: "copy", label: "Copy", callback: "context_action"},
        %{id: "rename", label: "Rename", callback: "context_action"},
        :separator,
        %{id: "disabled", label: "Disabled item", callback: "context_action", disabled: true}
      ],
      id: "overlay_context",
      style: [
        {:width, {:px, 240}},
        {:padding, :all, {:rem, 0.25}},
        {:bg_hex, UI.surface()},
        {:text_color_hex, UI.text()},
        {:border_width, :all, {:px, 1}},
        {:border_color_hex, UI.border()}
      ],
      item_style: [{:padding, :all, {:rem, 0.5}}],
      disabled_item_style: [{:padding, :all, {:rem, 0.5}}, {:text_color, :gray}],
      separator_style: [{:height, {:px, 1}}, {:bg_hex, UI.border()}]
    )
  end

  defp log(window, message) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second) |> Calendar.strftime("%H:%M:%S")

    window
    |> assign(:status_message, message)
    |> assign(:events, ["#{timestamp}  #{message}" | window.assigns.events] |> Enum.take(8))
  end
end

if "--validate-only" in System.argv() do
  :ok = Guppy.IR.validate(Guppy.Examples.OverlayDemoWindow.sample_ir())
  IO.puts("overlay_demo.exs validates")
else
  {:ok, _} = Application.ensure_all_started(:guppy)

  IO.puts("Guppy overlay demo")

  IO.puts(
    "Try select keyboard controls, popover Escape/outside close, and right-click/Shift-F10 context menu."
  )

  {:ok, pid} = Guppy.Examples.OverlayDemoWindow.start_link([])
  ref = Process.monitor(pid)

  receive do
    {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
  end
end
