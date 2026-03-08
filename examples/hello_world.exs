{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy hello world")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")
IO.inspect(Guppy.ping(), label: "ping")

{:ok, view_id} =
  Guppy.open_window(
    Guppy.IR.div(
      [
        Guppy.IR.text("Hello from examples/hello_world.exs", id: "title"),
        Guppy.IR.text("Rendered through BridgeView IR")
      ],
      id: "hello_root",
      style: [:flex, :flex_col, :gap_2, :p_4, {:bg, :gray}, :rounded_md]
    )
  )

IO.inspect(view_id, label: "opened_view_id")
IO.inspect(Guppy.native_view_count(), label: "native_view_count")
IO.puts("opened and asked GPUI to activate/focus the window")

IO.puts("rendered IR tree")

Process.send_after(self(), :update_text, 1_000)
Process.send_after(self(), :close_window, 5_000)

receive_loop = fn receive_loop ->
  receive do
    :update_text ->
      case Guppy.render(
             view_id,
             Guppy.IR.div(
               [
                 Guppy.IR.text("Hello from examples/hello_world.exs (updated)", id: "title"),
                 Guppy.IR.text("Full-tree replacement rerender worked")
               ],
               id: "hello_root",
               style: [:flex, :flex_col, :gap_2, :p_4, {:bg, :blue}, :rounded_md]
             )
           ) do
        :ok ->
          IO.puts("updated window via IR")
          receive_loop.(receive_loop)

        {:error, :unknown_view_id} ->
          IO.puts("window already closed before update")

        other ->
          IO.inspect(other, label: "unexpected_update_result")
      end

    :close_window ->
      case Guppy.close_window(view_id) do
        :ok ->
          IO.puts("closed window")
          IO.inspect(Guppy.native_view_count(), label: "native_view_count")

        {:error, :unknown_view_id} ->
          IO.puts("window already closed")
          IO.inspect(Guppy.native_view_count(), label: "native_view_count")

        other ->
          IO.inspect(other, label: "unexpected_close_result")
      end

    {:guppy_event, ^view_id, %{type: :window_closed}} ->
      IO.puts("window was closed manually")
      IO.inspect(Guppy.native_view_count(), label: "native_view_count")

    other ->
      IO.inspect(other, label: "unexpected_message")
      receive_loop.(receive_loop)
  end
end

receive_loop.(receive_loop)
