Code.require_file("support/ui.exs", __DIR__)

defmodule Examples.TextClicksWindow do
  use Guppy.Window

  alias Examples.UI

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 420, height: 280],
       titlebar: [title: "Text clicks"]
     )
     |> assign(:status, "Waiting for a click")}
  end

  @impl Guppy.Window
  def handle_event("line_one", _event_data, window) do
    {:noreply, assign(window, :status, "Clicked the first line")}
  end

  def handle_event("line_two", _event_data, window) do
    {:noreply, assign(window, :status, "Clicked the second line")}
  end

  @impl Guppy.Window
  def render(window) do
    assigns =
      Map.merge(window.assigns, %{
        rows: [
          %{
            id: "line_one",
            title: "First line",
            body: "Use a clickable text node as the primary action."
          },
          %{
            id: "line_two",
            title: "Second line",
            body: "Wire a different callback through the same window process."
          }
        ]
      })

    ~GUI"""
    <div id="text_click_root" class={UI.window_class()}>
      <div id="choices" class={UI.panel_class()}>
        <div
          :for={row <- @rows}
          id={row.id <> "_row"}
          click={row.id}
          class="flex flex-col gap-1 px-3 py-2 cursor-pointer"
          hover_class={UI.button_hover_class()}
        >
          <text id={row.id <> "_title"} class="text-sm font-semibold">{row.title}</text>
          <text id={row.id} click={row.id} class={UI.caption_class()}>{row.body}</text>
        </div>
      </div>

      <text id="status" class={UI.caption_class()}>{@status}</text>
    </div>
    """
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

{:ok, pid} = Examples.TextClicksWindow.start_link(:ok)
Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
