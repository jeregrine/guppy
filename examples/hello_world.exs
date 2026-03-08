defmodule Examples.HelloWorldWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(:ok, window) do
    Process.send_after(self(), :update_text, 1_000)
    Process.send_after(self(), :shutdown, 5_000)

    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 760, height: 560],
       titlebar: [title: "Guppy hello world"]
     )
     |> assign(:phase, :initial)}
  end

  @impl Guppy.Window
  def render(window) do
    {accent_bg, accent_border, status_label, message} = phase_content(window.assigns.phase)

    assigns =
      Map.merge(window.assigns, %{
        accent_bg: accent_bg,
        accent_border: accent_border,
        status_label: status_label,
        message: message,
        status_panel_class:
          "flex flex-col gap-2 p-4 rounded-xl border-1 shadow-md border-[#{accent_border}] bg-[#{accent_bg}]",
        status_badge_class:
          "p-2 rounded-lg border-1 shadow-sm text-lg font-semibold border-[#{accent_border}] bg-[#{accent_bg}]",
        features: [
          %{id: "feature_process", label: "Window process owns assigns and timers"},
          %{id: "feature_render", label: "Render returns a declarative tree each time"},
          %{id: "feature_native", label: "Native side swaps the visible UI from that tree"}
        ]
      })

    ~G"""
    <div id="hello_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="hero_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="title" class="text-3xl font-black">Guppy hello world</text>
        <text id="subtitle" class="text-base text-[#94a3b8]">
          A small window process renders a full replacement IR tree and updates itself after a timer.
        </text>
      </div>

      <div id="status_panel" class={@status_panel_class}>
        <text id="status_heading" class="text-sm font-semibold text-[#cbd5e1]">Window lifecycle</text>
        <text id="status_label" class={@status_badge_class}>{@status_label}</text>
        <text id="status_message" class="text-base text-[#e2e8f0]">{@message}</text>
      </div>

      <div id="details_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="details_heading" class="text-sm font-semibold text-[#cbd5e1]">
          What this example shows
        </text>

        <div :for={feature <- @features} id={feature.id <> "_row"} class="flex flex-row items-center gap-2">
          <div id={feature.id <> "_dot"} class="w-[10px] h-[10px] rounded-full bg-[#38bdf8]"></div>
          <text id={feature.id} class="flex-1 text-base">{feature.label}</text>
        </div>
      </div>
    </div>
    """
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

  defp phase_content(:initial) do
    {"#172554", "#3b82f6", "Initial render",
     "The first frame is mounted immediately when the window process starts."}
  end

  defp phase_content(:updated) do
    {"#14532d", "#22c55e", "Updated render",
     "A timer fired, the assign changed, and the whole tree rerendered cleanly."}
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
