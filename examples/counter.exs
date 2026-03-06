Mix.Task.run("app.start")

IO.puts("Guppy counter example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, view_id} = Guppy.open_window()
IO.inspect(view_id, label: "opened_view_id")

render_counter = fn count ->
  Guppy.IR.div(
    [
      Guppy.IR.text("Counter example", id: "title"),
      Guppy.IR.text("count = #{count}", id: "count_label"),
      Guppy.IR.div(
        [
          Guppy.IR.text("This window is rerendered from Elixir state."),
          Guppy.IR.text("Each tick sends a full replacement IR tree.")
        ],
        style: %{p_2: true, bg: :gray, rounded_md: true}
      )
    ],
    id: "counter_root",
    style: %{flex: true, flex_col: true, gap_2: true, p_4: true}
  )
end

:ok = Guppy.mount(view_id, render_counter.(0))

Process.send_after(self(), :tick, 1_000)

loop = fn loop, count ->
  receive do
    :tick when count < 5 ->
      next_count = count + 1

      case Guppy.update(view_id, render_counter.(next_count)) do
        :ok ->
          IO.puts("updated count to #{next_count}")
          Process.send_after(self(), :tick, 1_000)
          loop.(loop, next_count)

        {:error, :unknown_view_id} ->
          IO.puts("window already closed before next tick")

        other ->
          IO.inspect(other, label: "unexpected_update_result")
      end

    :tick ->
      case Guppy.close_window(view_id) do
        :ok -> IO.puts("closed window after 5 updates")
        {:error, :unknown_view_id} -> IO.puts("window already closed")
        other -> IO.inspect(other, label: "unexpected_close_result")
      end

    {:guppy_event, ^view_id, %{type: :window_closed}} ->
      IO.puts("window was closed manually")

    other ->
      IO.inspect(other, label: "unexpected_message")
      loop.(loop, count)
  end
end

loop.(loop, 0)
