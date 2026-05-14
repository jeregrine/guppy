defmodule Examples.ListRowControlsWindow do
  use Guppy.Window

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
       window_bounds: [width: 760, height: 520],
       titlebar: [title: "Guppy list row controls"]
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
        Guppy.IR.div(
          [
            Guppy.IR.text("List row controls", id: "title", style: [:text_2xl, :font_black]),
            Guppy.IR.text(
              "Generic list rows can now host retained button, checkbox, and radio controls with row-aware event payloads.",
              id: "subtitle",
              style: [:text_sm, {:text_color_hex, "#94a3b8"}]
            )
          ],
          id: "header",
          style: [:flex, :flex_col, :gap_1]
        ),
        Guppy.IR.list(rows,
          id: "task_list",
          style: [{:h_px, 300}, :rounded_lg, :border_1, {:border_color_hex, "#334155"}],
          item_style: [:p_2, :border_b_1, {:border_color_hex, "#1e293b"}]
        ),
        Guppy.IR.div(
          [Guppy.IR.text(window.assigns.last_event, id: "last_event", style: [:text_sm])],
          id: "event_panel",
          style: [:p_2, :rounded_md, {:bg_hex, "#111827"}, {:text_color_hex, "#e2e8f0"}]
        )
      ],
      id: "list_row_controls_root",
      style: [
        :flex,
        :flex_col,
        :gap_4,
        :p_6,
        :w_full,
        :h_full,
        {:bg_hex, "#0f172a"},
        {:text_color_hex, "#f8fafc"}
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
                  style: [:text_xs, {:text_color_hex, "#94a3b8"}]
                )
              ],
              style: [:flex, :flex_col, :gap_1, :flex_1]
            ),
            Guppy.IR.checkbox("Done", task.done,
              id: "done",
              events: %{change: "toggle_done"},
              style: [:gap_2]
            ),
            Guppy.IR.radio("High", "high", task.priority == "high",
              id: "priority_high",
              events: %{change: "set_priority"},
              style: [:gap_2]
            ),
            Guppy.IR.button("Open",
              id: "open",
              events: %{click: "open_row"},
              style: [:p_2, :rounded_md, :border_1]
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
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.ListRowControlsWindow.start_link(:ok)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
