defmodule Examples.TimerCounterWindow do
  use Guppy.Window
  use Guppy.Component

  import Guppy.Window, only: [assign: 3, update: 3, put_window_opts: 2]

  @impl Guppy.Window
  def mount(initial_count, window) do
    Process.send_after(self(), :tick, 1_000)

    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 760, height: 560],
       titlebar: [title: "Guppy timer counter"]
     )
     |> assign(:count, initial_count)}
  end

  @impl Guppy.Window
  def render(window) do
    count = window.assigns.count

    assigns =
      Map.merge(window.assigns, %{
        count_text: Integer.to_string(count),
        progress_text: progress_text(count),
        info_rows: [
          %{id: "info_state", label: "State lives in the window process"},
          %{id: "info_tick", label: "Each tick updates assigns and triggers a fresh render"},
          %{id: "info_stop", label: "The example exits once the count reaches five"}
        ]
      })

    ~G"""
    <div id="counter_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="header_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="title" class="text-3xl font-black">Timer counter</text>
        <text id="subtitle" class="text-base text-[#94a3b8]">
          This window rerenders from Elixir state once per second and stops after five updates.
        </text>
      </div>

      <div id="count_panel" class="flex flex-col items-center gap-2 p-6 rounded-xl border-1 border-[#2563eb] bg-[#172554] shadow-md text-center">
        <text id="count_heading" class="text-sm font-semibold text-[#bfdbfe]">Current count</text>
        <text id="count_label" class="text-3xl font-black">{@count_text}</text>
        <text id="progress_text" class="text-base text-[#dbeafe]">{@progress_text}</text>
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

  @impl Guppy.Window
  def handle_info(:tick, window) when window.assigns.count < 5 do
    next_window = update(window, :count, &(&1 + 1))
    IO.puts("updated count to #{next_window.assigns.count}")
    Process.send_after(self(), :tick, 1_000)
    {:noreply, next_window}
  end

  @impl Guppy.Window
  def handle_info(:tick, window) do
    IO.puts("stopping window process after 5 updates")
    {:stop, :normal, window}
  end

  defp progress_text(count) when count < 5, do: "Waiting for the next timer tick..."
  defp progress_text(_count), do: "Done. The process will shut down now."
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy counter example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.TimerCounterWindow.start_link(0)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
