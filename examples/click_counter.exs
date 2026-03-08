defmodule Examples.ClickCounterWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 3, update: 3]

  @impl Guppy.Window
  def mount(initial_count, window) do
    {:ok, assign(window, :count, initial_count)}
  end

  @impl Guppy.Window
  def render(window) do
    count = window.assigns.count

    Guppy.IR.div(
      [
        Guppy.IR.text("Click counter", id: "title"),
        Guppy.IR.div(
          [
            Guppy.IR.text("count = #{count}", id: "count_label"),
            Guppy.IR.text("Click this text to increment",
              id: "increment_text",
              events: %{click: "increment"}
            )
          ],
          id: "increment_button",
          style: [:p_4, {:bg, :blue}, :rounded_md, :cursor_pointer],
          events: %{click: "increment"}
        ),
        Guppy.IR.text("Close the window to stop this script.")
      ],
      id: "click_counter_root",
      style: [:flex, :flex_col, :gap_2, :p_4]
    )
  end

  @impl Guppy.Window
  def handle_event("increment", _event_data, window) do
    next_window = update(window, :count, &(&1 + 1))
    IO.puts("incremented to #{next_window.assigns.count}")
    {:noreply, next_window}
  end
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
