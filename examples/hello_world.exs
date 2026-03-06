Mix.Task.run("app.start")

IO.puts("Guppy hello world")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")
IO.inspect(Guppy.ping(), label: "ping")

{:ok, view_id} = Guppy.open_window()
IO.inspect(view_id, label: "opened_view_id")
IO.inspect(Guppy.native_view_count(), label: "native_view_count")
IO.puts("opened and asked GPUI to activate/focus the window")

:ok =
  Guppy.mount(
    view_id,
    Guppy.IR.div([
      Guppy.IR.text("Hello from examples/hello_world.exs"),
      Guppy.IR.text("Rendered through BridgeView IR")
    ])
  )

IO.puts("mounted IR tree")

Process.send_after(self(), :update_text, 1_000)
Process.send_after(self(), :close_window, 5_000)

receive_loop = fn receive_loop ->
  receive do
    :update_text ->
      :ok =
        Guppy.update(
          view_id,
          Guppy.IR.div([
            Guppy.IR.text("Hello from examples/hello_world.exs (updated)"),
            Guppy.IR.text("Full-tree replacement rerender worked")
          ])
        )

      IO.puts("updated window via IR")
      receive_loop.(receive_loop)

    :close_window ->
      :ok = Guppy.close_window(view_id)
      IO.puts("closed window")
      IO.inspect(Guppy.native_view_count(), label: "native_view_count")

    other ->
      IO.inspect(other, label: "unexpected_message")
      receive_loop.(receive_loop)
  end
end

receive_loop.(receive_loop)
