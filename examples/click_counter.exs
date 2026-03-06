Mix.Task.run("app.start")

IO.puts("Guppy click counter example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

owner = self()
{:ok, view_id} = Guppy.open_window(owner)
IO.inspect(view_id, label: "opened_view_id")

render = fn count ->
  Guppy.IR.div(
    [
      Guppy.IR.text("Click counter", id: "title"),
      Guppy.IR.div(
        [
          Guppy.IR.text("count = #{count}", id: "count_label"),
          Guppy.IR.text("Click this block to increment")
        ],
        id: "increment_button",
        style: %{p_4: true, bg: :blue, rounded_md: true, cursor_pointer: true},
        events: %{click: "increment"}
      ),
      Guppy.IR.text("Close the window to stop this script.")
    ],
    id: "click_counter_root",
    style: %{flex: true, flex_col: true, gap_2: true, p_4: true}
  )
end

:ok = Guppy.mount(view_id, render.(0))

loop = fn loop, count ->
  receive do
    {:guppy_event, ^view_id, %{type: :click, callback: "increment"}} ->
      next_count = count + 1

      case Guppy.update(view_id, render.(next_count)) do
        :ok ->
          IO.puts("incremented to #{next_count}")
          loop.(loop, next_count)

        {:error, :unknown_view_id} ->
          IO.puts("window already closed before click update")

        other ->
          IO.inspect(other, label: "unexpected_update_result")
      end

    {:guppy_event, ^view_id, %{type: :window_closed}} ->
      IO.puts("window was closed manually")

    {:guppy_event, ^view_id, event} ->
      IO.inspect(event, label: "unexpected_view_event")
      loop.(loop, count)

    other ->
      IO.inspect(other, label: "unexpected_message")
      loop.(loop, count)
  end
end

loop.(loop, 0)
