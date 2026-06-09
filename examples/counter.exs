Code.require_file("support/ui.exs", __DIR__)

defmodule CounterWindow do
  use Guppy.Window

  alias Examples.UI

  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 320, height: 220],
       titlebar: [title: "Counter"]
     )
     |> assign(:count, 0)}
  end

  def render(window) do
    ~GUI"""
    <div class={UI.window_class() <> " items-center justify-center"}>
      <text id="count_label" class="text-3xl font-semibold">{@count}</text>
      <button
        id="increment_button"
        click="increment"
        class={UI.primary_button_class()}
        hover_class={UI.primary_button_hover_class()}
      >
        Increment
      </button>
    </div>
    """
  end

  def handle_event("increment", _event_data, window) do
    {:noreply, assign(window, :count, window.assigns.count + 1)}
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

{:ok, pid} = CounterWindow.start_link(:ok)
Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
