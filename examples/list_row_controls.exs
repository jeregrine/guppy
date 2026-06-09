Code.require_file("support/ui.exs", __DIR__)

defmodule Examples.ListRowControlsWindow do
  use Guppy.Window

  alias Examples.UI

  @initial_tasks [
    %{id: "task_1", title: "Wire row-control event payloads", done: false, priority: "high"},
    %{id: "task_2", title: "Keep row ids stable across renders", done: true, priority: "normal"},
    %{id: "task_3", title: "Prune controls when rows disappear", done: false, priority: "normal"}
  ]

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 640, height: 420],
       titlebar: [title: "List row controls"]
     )
     |> assign(:tasks, @initial_tasks)
     |> assign(:last_event, "Click a row button, checkbox, or radio control")}
  end

  @impl Guppy.Window
  def handle_event("toggle_done", %{row_id: row_id, checked: checked} = event, window) do
    {:noreply,
     window
     |> update_task(row_id, &%{&1 | done: checked})
     |> assign(:last_event, describe_row_event(event, "done = #{checked}"))}
  end

  def handle_event("set_priority", %{row_id: row_id, value: priority} = event, window) do
    {:noreply,
     window
     |> update_task(row_id, &%{&1 | priority: priority})
     |> assign(:last_event, describe_row_event(event, "priority = #{priority}"))}
  end

  def handle_event("open_row", event, window) do
    {:noreply, assign(window, :last_event, describe_row_event(event, "button clicked"))}
  end

  @impl Guppy.Window
  def render(window) do
    rows = Enum.map(window.assigns.tasks, &task_row/1)

    Guppy.IR.div(
      [
        Guppy.IR.list(rows,
          id: "task_list",
          style: [
            {:h_px, 280},
            :rounded_md,
            :border_1,
            {:border_color_hex, UI.border()},
            {:bg_hex, UI.surface()}
          ],
          item_style: [:p_2, :border_b_1, {:border_color_hex, "#ececf0"}]
        ),
        Guppy.IR.text(window.assigns.last_event,
          id: "last_event",
          style: [:text_xs, {:text_color_hex, UI.text_secondary()}]
        )
      ],
      id: "list_row_controls_root",
      style: [
        :flex,
        :flex_col,
        :gap_4,
        :p_4,
        :w_full,
        :h_full,
        {:bg_hex, UI.window_bg()},
        {:text_color_hex, UI.text()}
      ]
    )
  end

  defp task_row(task) do
    %{
      id: task.id,
      children: [
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text(task.title, id: "#{task.id}_title", style: [:font_semibold]),
                Guppy.IR.text("row id: #{task.id}",
                  style: [:text_xs, {:text_color_hex, UI.text_secondary()}]
                )
              ],
              style: [:flex, :flex_col, :gap_1, :flex_1]
            ),
            Guppy.IR.checkbox("Done", task.done,
              id: "done",
              events: %{change: "toggle_done"},
              style: [:gap_2, {:text_color_hex, UI.text()}]
            ),
            Guppy.IR.radio("High", "high", task.priority == "high",
              id: "priority_high",
              events: %{change: "set_priority"},
              style: [:gap_2, {:text_color_hex, UI.text()}]
            ),
            Guppy.IR.button("Open",
              id: "open",
              events: %{click: "open_row"},
              style: [
                :p_1,
                :rounded_md,
                :border_1,
                :text_sm,
                {:border_color_hex, UI.border()},
                {:bg_hex, UI.surface()}
              ]
            )
          ],
          id: "#{task.id}_layout",
          style: [:flex, :flex_row, :items_center, :gap_4]
        )
      ]
    }
  end

  defp update_task(window, row_id, fun) do
    tasks =
      Enum.map(window.assigns.tasks, fn
        %{id: ^row_id} = task -> fun.(task)
        task -> task
      end)

    assign(window, :tasks, tasks)
  end

  defp describe_row_event(event, detail) do
    "#{detail} from #{event.list_id}/#{event.row_id}/#{event.control_id}"
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy list row controls example")

{:ok, pid} = Examples.ListRowControlsWindow.start_link(:ok)

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
