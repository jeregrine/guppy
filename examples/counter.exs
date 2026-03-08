defmodule Examples.TimerCounterWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 3, update: 3]

  @impl Guppy.Window
  def mount(initial_count, window) do
    Process.send_after(self(), :tick, 1_000)
    {:ok, assign(window, :count, initial_count)}
  end

  @impl Guppy.Window
  def render(window) do
    count = window.assigns.count

    Guppy.IR.div(
      [
        Guppy.IR.text("Counter example", id: "title"),
        Guppy.IR.text("count = #{count}", id: "count_label"),
        Guppy.IR.div(
          [
            Guppy.IR.text("This window is rerendered from Elixir state."),
            Guppy.IR.text("Each tick sends a full replacement IR tree.")
          ],
          style: [:p_2, {:bg, :gray}, :rounded_md]
        )
      ],
      id: "counter_root",
      style: [:flex, :flex_col, :gap_2, :p_4]
    )
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
