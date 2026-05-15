defmodule CounterWindow do
  use Guppy.Window

  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 760, height: 560],
       titlebar: [title: "Counter"]
     )
     |> assign(:count, 0)}
  end

  def render(window) do
    ~GUI"""
    <div class="flex flex-col gap-2 p-4 bg-[#0f172a] text-[#f8fafc]">
      <text id="count_label" class="text-2xl font-bold">count = {@count}</text>
      <button id="increment_button" click="increment" class="p-2 rounded-md border-1">
        Increment
      </button>
    </div>
    """
  end

  def handle_event("increment", _event_data, window) do
    {:noreply, assign(window, :count, window.assigns.count + 1)}
  end
end

{:ok, pid} = CounterWindow.start_link(:ok)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
