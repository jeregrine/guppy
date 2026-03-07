{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy text clicks example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, view_id} = Guppy.open_window(self())
IO.inspect(view_id, label: "opened_view_id")

render = fn status ->
  Guppy.IR.div(
    [
      Guppy.IR.text("Text click example", id: "title"),
      Guppy.IR.text("status = #{status}", id: "status"),
      Guppy.IR.text("Click this line", id: "line_one", events: %{click: "line_one"}),
      Guppy.IR.text("Or click this line", id: "line_two", events: %{click: "line_two"})
    ],
    id: "text_click_root",
    style: [:flex, :flex_col, :gap_2, :p_4]
  )
end

:ok = Guppy.mount(view_id, render.("waiting"))

loop = fn loop ->
  receive do
    {:guppy_event, ^view_id, %{type: :click, id: "line_one", callback: "line_one"}} ->
      :ok = Guppy.update(view_id, render.("clicked line one"))
      IO.puts("clicked line one")
      loop.(loop)

    {:guppy_event, ^view_id, %{type: :click, id: "line_two", callback: "line_two"}} ->
      :ok = Guppy.update(view_id, render.("clicked line two"))
      IO.puts("clicked line two")
      loop.(loop)

    {:guppy_event, ^view_id, %{type: :window_closed}} ->
      IO.puts("window was closed manually")

    other ->
      IO.inspect(other, label: "unexpected_message")
      loop.(loop)
  end
end

loop.(loop)
