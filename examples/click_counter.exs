Code.require_file("support/ui.exs", __DIR__)

defmodule Examples.ClickCounterWindow do
  use Guppy.Window

  alias Examples.UI

  @impl Guppy.Window
  def mount(initial_count, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 360, height: 240],
       titlebar: [title: "Click counter"]
     )
     |> assign(:count, initial_count)}
  end

  @impl Guppy.Window
  def handle_event("increment", _event_data, window) do
    {:noreply, assign(window, :count, window.assigns.count + 1)}
  end

  def handle_event("reset", _event_data, window) do
    {:noreply, assign(window, :count, 0)}
  end

  @impl Guppy.Window
  def render(window) do
    assigns = Map.put(window.assigns, :summary, summary_text(window.assigns.count))

    ~GUI"""
    <div class={UI.window_class() <> " items-center justify-center"}>
      <text id="count_label" class="text-3xl font-semibold">{@count}</text>
      <text id="summary_text" class={UI.caption_class()}>{@summary}</text>

      <div id="controls" class="flex flex-row gap-2">
        <button
          id="increment_button"
          click="increment"
          class={UI.primary_button_class()}
          hover_class={UI.primary_button_hover_class()}
        >
          Increment
        </button>
        <button
          id="reset_button"
          click="reset"
          class={UI.button_class()}
          hover_class={UI.button_hover_class()}
        >
          Reset
        </button>
      </div>
    </div>
    """
  end

  defp summary_text(0), do: "No clicks yet"
  defp summary_text(1), do: "1 click recorded"
  defp summary_text(count), do: "#{count} clicks recorded"
end

{:ok, _} = Application.ensure_all_started(:guppy)

{:ok, pid} = Examples.ClickCounterWindow.start_link(0)
Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
