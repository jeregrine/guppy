defmodule Guppy.Examples.OverlayDemoWindow do
  use Guppy.Window

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
       titlebar: [title: "Guppy overlay demo"],
       window_bounds: [width: 840, height: 680],
       focus: true,
       show: true
     )
     |> assign(initial_assigns())}
  end

  @impl Guppy.Window
  def render(window) do
    ~GUI"""
    <div id="overlay_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="intro" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827]">
        <text id="title" class="text-3xl font-black">Overlay, popover, and select hardening</text>
        <text id="summary" class="text-base text-[#94a3b8] leading-snug">
          Exercises select keyboard behavior, popover positioning/close semantics, element-local context menus, and nested non-overlay panels.
        </text>
        <text id="status" class="text-sm text-[#bfdbfe]">{@status_message}</text>
      </div>

      <div id="form_panel" class="flex flex-col gap-3 p-4 rounded-xl border-1 border-[#2563eb] bg-[#172554]">
        <text id="form_title" class="text-lg font-bold">Form-like select</text>
        <text class="text-sm text-[#bfdbfe]">Focus the select and use arrows, Home/End, typeahead, Enter/Space, and Escape. The disabled Blocked option is skipped.</text>
        <select
          id="status_select"
          value={@status}
          open={@select_open}
          options={@statuses}
          placeholder="Pick status"
          click="toggle_select"
          change="status_changed"
          close="close_select"
          class="w-[260px] border-1 border-[#60a5fa] bg-[#0b1220]"
          list_class="p-1 shadow-lg"
          option_class="p-2"
          anchor="bottom_left"
          anchor_offset={{0, 10}}
          anchor_fit="snap_to_window_with_margin"
          snap_margin="12"
        />
        <text id="selected_status" class="text-sm text-[#bfdbfe]">Selected: {@status}</text>
      </div>

      <div id="popover_panel" class="flex flex-col gap-3 p-4 rounded-xl border-1 border-[#7c3aed] bg-[#1e1b4b]">
        <text id="popover_title" class="text-lg font-bold">Popover with nested panels</text>
        <text class="text-sm text-[#c4b5fd]">The popover snaps to the window with a margin, closes on outside click or Escape, and intentionally contains nested panels but no nested overlays.</text>
        <popover
          id="details_popover"
          label="Toggle details popover"
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
          class="w-[240px] bg-[#5b21b6] border-1 border-[#a78bfa]"
          popover_class="w-[320px] p-4 bg-[#ffffff] text-[#111827] border-1 border-[#7c3aed]"
        >
          <div id="popover_inner_panel" class="flex flex-col gap-2 p-3 rounded-lg border-1 border-[#ddd6fe] bg-[#f5f3ff]">
            <text class="text-sm">Nested panel one: ordinary content is supported inside a popover.</text>
            <div id="popover_nested_panel" class="p-2 rounded-md border-1 border-[#c4b5fd] bg-[#ede9fe]">
              <text class="text-sm">Nested panel two: nested overlay nodes are rejected by validation and native decode.</text>
            </div>
          </div>
        </popover>
      </div>

      <div id="context_panel" class="flex flex-col gap-3 p-4 rounded-xl border-1 border-[#059669] bg-[#064e3b]">
        <text id="context_title" class="text-lg font-bold">Element-local context menu</text>
        <div id="context_target" context_menu="open_context_menu" focusable="true" tab_index="1" class="p-4 rounded-lg border-1 border-[#34d399] bg-[#065f46] cursor-context-menu">
          <text>Right-click here, or focus this box and press Shift-F10/context-menu key.</text>
        </div>
        {context_menu_ir(@context_menu_open)}
      </div>

      <div id="event_log" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] flex-1">
        <text id="event_title" class="text-lg font-bold">Recent overlay events</text>
        <div :for={{event, index} <- Enum.with_index(@events)} id={"event_#{index}"} class="p-2 rounded-md bg-[#0b1220]">
          <text class="text-sm text-[#e2e8f0]">{event}</text>
        </div>
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
        {:bg_hex, "#ffffff"},
        {:text_color, :black},
        {:border_width, :all, {:px, 1}},
        {:border_color_hex, "#34d399"}
      ],
      item_style: [{:padding, :all, {:rem, 0.5}}],
      disabled_item_style: [{:padding, :all, {:rem, 0.5}}, {:text_color, :gray}],
      separator_style: [{:height, {:px, 1}}, {:bg_hex, "#d1fae5"}]
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
