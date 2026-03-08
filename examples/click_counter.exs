defmodule Examples.ClickCounterWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(initial_count, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 780, height: 620],
       titlebar: [title: "Guppy click counter"]
     )
     |> assign(:count, initial_count)}
  end

  @impl Guppy.Window
  def handle_event("increment", _event_data, window) do
    next_window = update(window, :count, &(&1 + 1))
    IO.puts("incremented to #{next_window.assigns.count}")
    {:noreply, next_window}
  end

  def handle_event("reset", _event_data, window) do
    IO.puts("reset counter")
    {:noreply, assign(window, :count, 0)}
  end

  @impl Guppy.Window
  def render(window) do
    count = window.assigns.count

    assigns =
      Map.merge(window.assigns, %{
        count_text: Integer.to_string(count),
        summary_text: summary_text(count),
        info_rows: [
          %{id: "info_primary", label: "Use the primary button to send click events"},
          %{id: "info_reset", label: "Reset is wired through the same window callback path"},
          %{id: "info_close", label: "Close the window when you are done"}
        ]
      })

    ~G"""
    <div id="click_counter_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="header_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="title" class="text-3xl font-black">Click counter</text>
        <text id="subtitle" class="text-base text-[#94a3b8]">
          Buttons dispatch native click events back into the window process, which updates assigns and rerenders.
        </text>
      </div>

      <div id="count_panel" class="flex flex-col items-center gap-2 p-6 rounded-xl border-1 border-[#2563eb] bg-[#172554] shadow-md text-center">
        <text id="count_heading" class="text-sm font-semibold text-[#bfdbfe]">Clicks</text>
        <text id="count_label" class="text-3xl font-black">{@count_text}</text>
        <text id="summary_text" class="text-base text-[#dbeafe]">{@summary_text}</text>
      </div>

      <div id="controls" class="flex flex-row gap-2">
        <button id="increment_button" click="increment" class="flex-1 p-4 rounded-lg border-1 border-[#2563eb] bg-[#2563eb] text-[#f8fafc] shadow-sm">
          Increment
        </button>
        <button id="reset_button" click="reset" class="flex-1 p-4 rounded-lg border-1 border-[#334155] bg-[#334155] text-[#f8fafc] shadow-sm">
          Reset
        </button>
      </div>

      <div id="info_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <div :for={row <- @info_rows} id={row.id <> "_row"} class="flex flex-row items-center gap-2">
          <div id={row.id <> "_dot"} class="w-[10px] h-[10px] rounded-full bg-[#60a5fa]"></div>
          <text id={row.id} class="flex-1 text-base">{row.label}</text>
        </div>
      </div>
    </div>
    """
  end

  defp summary_text(0), do: "No clicks yet — press the button to start."
  defp summary_text(1), do: "One click recorded."
  defp summary_text(count), do: "#{count} clicks recorded."
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy click counter example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.ClickCounterWindow.start_link(0)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
