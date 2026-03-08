defmodule Examples.HelloWorldWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 3]

  @impl Guppy.Window
  def mount(:ok, window) do
    Process.send_after(self(), :update_text, 1_000)
    Process.send_after(self(), :shutdown, 5_000)
    {:ok, assign(window, :phase, :initial)}
  end

  @impl Guppy.Window
  def render(window) do
    case window.assigns.phase do
      :initial ->
        Guppy.IR.div(
          [
            Guppy.IR.text("Hello from examples/hello_world.exs", id: "title"),
            Guppy.IR.text("Rendered through BridgeView IR")
          ],
          id: "hello_root",
          style: [:flex, :flex_col, :gap_2, :p_4, {:bg, :gray}, :rounded_md]
        )

      :updated ->
        Guppy.IR.div(
          [
            Guppy.IR.text("Hello from examples/hello_world.exs (updated)", id: "title"),
            Guppy.IR.text("Full-tree replacement rerender worked")
          ],
          id: "hello_root",
          style: [:flex, :flex_col, :gap_2, :p_4, {:bg, :blue}, :rounded_md]
        )
    end
  end

  @impl Guppy.Window
  def handle_info(:update_text, window) do
    IO.puts("updated window via IR")
    {:noreply, assign(window, :phase, :updated)}
  end

  @impl Guppy.Window
  def handle_info(:shutdown, window) do
    IO.puts("stopping window process")
    {:stop, :normal, window}
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy hello world")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")
IO.inspect(Guppy.ping(), label: "ping")

{:ok, pid} = Examples.HelloWorldWindow.start_link(:ok)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")
IO.inspect(Guppy.native_view_count(), label: "native_view_count")
IO.puts("opened and asked GPUI to activate/focus the window")
IO.puts("rendered IR tree")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    IO.inspect(Guppy.native_view_count(), label: "native_view_count")
end
