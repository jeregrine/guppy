defmodule Examples.HelloWorldWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(:ok, window) do
    Process.send_after(self(), :update_text, 1_000)
    Process.send_after(self(), :shutdown, 5_000)

    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 420, height: 200],
       titlebar: [title: "Hello Guppy"]
     )
     |> assign(:phase, :initial)}
  end

  @impl Guppy.Window
  def render(window) do
    {status, status_color} = phase_status(window.assigns.phase)
    assigns = Map.merge(window.assigns, %{status: status, status_color: status_color})

    ~GUI"""
    <div id="hello_root" class="flex flex-col w-full h-full gap-2 p-5 bg-[#f5f5f7] text-[#1d1d1f]">
      <text id="title" class="text-lg font-semibold">Hello from Guppy</text>
      <text id="subtitle" class="text-sm text-[#6e6e73]">
        This window process rerenders its full tree when an assign changes.
      </text>
      <text id="status" class={"text-sm font-semibold text-[" <> @status_color <> "]"}>{@status}</text>
    </div>
    """
  end

  def handle_info(:update_text, window) do
    IO.puts("updated window via IR")
    {:noreply, assign(window, :phase, :updated)}
  end

  def handle_info(:shutdown, window) do
    IO.puts("stopping window process")
    {:stop, :normal, window}
  end

  defp phase_status(:initial), do: {"Waiting for the one-second timer…", "#6e6e73"}

  defp phase_status(:updated),
    do: {"Updated — the timer fired and the tree rerendered.", "#007aff"}
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy hello world")
IO.puts("load_status: #{inspect(Guppy.Native.Nif.load_status())}")
IO.puts("native_build_info: #{inspect(Guppy.native_build_info())}")
IO.puts("native_runtime_status: #{inspect(Guppy.native_runtime_status())}")
IO.puts("native_gui_status: #{inspect(Guppy.native_gui_status())}")
IO.puts("ping: #{inspect(Guppy.ping())}")

{:ok, pid} = Examples.HelloWorldWindow.start_link(:ok)
IO.puts("opened_view_id: #{inspect(Guppy.Window.view_id(pid))}")
IO.puts("native_view_count: #{inspect(Guppy.native_view_count())}")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    IO.puts("native_view_count: #{inspect(Guppy.native_view_count())}")
end
