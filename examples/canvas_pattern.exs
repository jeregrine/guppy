Code.require_file("support/ui.exs", __DIR__)

defmodule Examples.CanvasPatternWindow do
  use Guppy.Window

  alias Examples.UI

  @states [
    %{id: :open, label: "Open", progress: 0.42, fill: "#007aff", accent: "#8ec2ff"},
    %{id: :review, label: "Review", progress: 0.68, fill: "#d97706", accent: "#f3c577"},
    %{id: :done, label: "Done", progress: 0.9, fill: "#16a34a", accent: "#9fdcb4"}
  ]

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 460, height: 340],
       titlebar: [title: "Canvas pattern"]
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
    <div id="canvas_demo_root" class={UI.window_class()}>
      <text id="canvas_label" class={UI.title_class()}>Release health: {@state_label}</text>
      <canvas
        id="release_canvas"
        commands={@canvas_commands}
        class="w-[320px] h-[180px] rounded-md overflow-hidden"
        click="cycle_status"
      />
      <text id="canvas_hint" class={UI.caption_class()}>
        Click the canvas to cycle state. {@progress_label}
      </text>
    </div>
    """
  end

  defp canvas_commands(state) do
    progress_width = 248 * state.progress

    [
      %{op: :rounded_rect, x: 0, y: 0, width: 320, height: 180, radius: 8, fill: "#ffffff"},
      %{op: :rounded_rect, x: 18, y: 18, width: 284, height: 144, radius: 6, fill: "#f5f5f7"},
      %{
        op: :pattern_rect,
        x: 24,
        y: 24,
        width: 272,
        height: 46,
        radius: 6,
        color: state.accent,
        line_width: 0.045,
        interval: 0.16
      },
      %{op: :rounded_rect, x: 36, y: 104, width: 248, height: 22, radius: 11, fill: "#d2d2d7"},
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
