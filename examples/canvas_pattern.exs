defmodule Examples.CanvasPatternWindow do
  use Guppy.Window

  @states [
    %{id: :open, label: "Open", progress: 0.42, fill: "#2563eb", accent: "#60a5fa"},
    %{id: :review, label: "Review", progress: 0.68, fill: "#d97706", accent: "#fbbf24"},
    %{id: :done, label: "Done", progress: 0.9, fill: "#16a34a", accent: "#86efac"}
  ]

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 760, height: 520],
       titlebar: [title: "Guppy canvas pattern demo"]
     )
     |> assign(:selected, :open)}
  end

  @impl Guppy.Window
  def handle_event("cycle_status", _event, window) do
    {:noreply, assign(window, :selected, next_state(window.assigns.selected).id)}
  end

  @impl Guppy.Window
  def render(window) do
    state = current_state(window.assigns.selected)

    assigns =
      Map.merge(window.assigns, %{
        state_label: state.label,
        progress_label: "#{round(state.progress * 100)}% complete",
        canvas_commands: canvas_commands(state)
      })

    ~GUI"""
    <div id="canvas_demo_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="header" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-linear-gradient-[135,#111827:0,#1e3a8a:1] shadow-md">
        <text id="title" class="text-2xl font-black">Canvas + pattern painting</text>
        <text id="subtitle" class="text-base text-[#94a3b8]">
          The card below is a data-only canvas: ordered native draw commands, a slash-pattern command, and a normal click callback.
        </text>
      </div>

      <div id="content" class="flex flex-row gap-4">
        <div id="canvas_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
          <text id="canvas_label" class="text-lg font-bold">Release health: {@state_label}</text>
          <canvas id="release_canvas" commands={@canvas_commands} class="w-[320px] h-[180px] rounded-xl overflow-hidden" click="cycle_status" />
          <text id="canvas_hint" class="text-sm text-[#94a3b8]">Click the canvas to cycle state. {@progress_label}</text>
        </div>

        <div id="notes" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md w-[300px]">
          <text id="notes_title" class="text-lg font-bold">Why canvas here?</text>
          <text id="note_1" class="text-sm text-[#cbd5e1]">The diagonal capacity band uses GPUI pattern painting instead of a flat background.</text>
          <text id="note_2" class="text-sm text-[#cbd5e1]">Elixir still owns state and sends plain data commands; no Elixir code runs during native paint.</text>
          <text id="note_3" class="text-sm text-[#cbd5e1]">The primitive is intentionally coarse-hit-tested: the whole canvas emits one click callback.</text>
        </div>
      </div>
    </div>
    """
  end

  defp canvas_commands(state) do
    progress_width = 248 * state.progress

    [
      %{op: :rounded_rect, x: 0, y: 0, width: 320, height: 180, radius: 18, fill: "#111827"},
      %{op: :rounded_rect, x: 18, y: 18, width: 284, height: 144, radius: 14, fill: "#0f172a"},
      %{
        op: :pattern_rect,
        x: 24,
        y: 24,
        width: 272,
        height: 46,
        radius: 12,
        color: state.accent,
        line_width: 0.045,
        interval: 0.16
      },
      %{op: :rounded_rect, x: 36, y: 104, width: 248, height: 22, radius: 11, fill: "#334155"},
      %{
        op: :rounded_rect,
        x: 36,
        y: 104,
        width: progress_width,
        height: 22,
        radius: 11,
        fill: state.fill
      },
      %{op: :rounded_rect, x: 36, y: 140, width: 112, height: 16, radius: 8, fill: state.accent}
    ]
  end

  defp current_state(id), do: Enum.find(@states, &(&1.id == id))

  defp next_state(id) do
    index = Enum.find_index(@states, &(&1.id == id)) || 0
    Enum.at(@states, rem(index + 1, length(@states)))
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy canvas pattern example")

{:ok, pid} = Examples.CanvasPatternWindow.start_link(:ok)

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
