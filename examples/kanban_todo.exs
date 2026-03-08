defmodule Examples.KanbanTodoWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 2, assign: 3]

  @column_order [:todo, :doing, :done]
  @column_titles %{todo: "Todo", doing: "Doing", done: "Done"}
  @column_colors %{todo: :gray, doing: :blue, done: :green}
  @seed_titles %{
    bug: "Fix drag/drop highlight bug",
    docs: "Write bridge-view architecture notes",
    polish: "Polish kanban card spacing"
  }

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok, initial_window(window)}
  end

  @impl Guppy.Window
  def handle_event("drag_started", _event_data, window) do
    {:noreply, window, :skip_render}
  end

  def handle_event("drag_moved", _event_data, window) do
    {:noreply, window, :skip_render}
  end

  def handle_event("drop_on_todo", %{source_id: source_id}, window) do
    handle_drop(window, source_id, :todo)
  end

  def handle_event("drop_on_doing", %{source_id: source_id}, window) do
    handle_drop(window, source_id, :doing)
  end

  def handle_event("drop_on_done", %{source_id: source_id}, window) do
    handle_drop(window, source_id, :done)
  end

  @impl Guppy.Window
  def handle_event("reset_board", _event_data, window) do
    IO.puts("reset board")
    {:noreply, initial_window(window)}
  end

  def handle_event("add:" <> kind, _event_data, window) do
    title = Map.fetch!(@seed_titles, String.to_existing_atom(kind))
    next_id = window.assigns.next_id
    next_task = %{id: next_id, title: title, status: :todo}

    IO.puts("added task #{inspect(title)}")

    {:noreply,
     assign(window,
       next_id: next_id + 1,
       tasks: window.assigns.tasks ++ [next_task]
     )}
  end

  def handle_event("archive:" <> id_text, _event_data, window) do
    id = String.to_integer(id_text)
    IO.puts("archived task #{id}")
    {:noreply, assign(window, :tasks, Enum.reject(window.assigns.tasks, &(&1.id == id)))}
  end

  @impl Guppy.Window
  def render(window) do
    tasks = window.assigns.tasks

    Guppy.IR.div(
      [
        Guppy.IR.text("Kanban todo board", id: "title"),
        Guppy.IR.text(
          "Add sample tasks, drag cards across columns, or archive them.",
          id: "subtitle"
        ),
        toolbar(),
        Guppy.IR.div(
          Enum.map(@column_order, &column_ir(&1, tasks)),
          id: "board",
          style: [:flex, :flex_row, :gap_4]
        )
      ],
      id: "kanban_root",
      style: [:flex, :flex_col, :gap_4, :p_4, {:bg_hex, "#16181d"}, {:text_color_hex, "#f5f5f5"}]
    )
  end

  defp initial_window(window) do
    assign(window,
      next_id: 4,
      tasks: [
        %{id: 1, title: "Sketch window process API", status: :todo},
        %{id: 2, title: "Refactor bridge render phases", status: :doing},
        %{id: 3, title: "Convert examples to Guppy.Window", status: :done}
      ]
    )
  end

  defp toolbar do
    Guppy.IR.div(
      [
        action_button("Add bug", "add:bug", :yellow),
        action_button("Add docs", "add:docs", :blue),
        action_button("Add polish", "add:polish", :green),
        action_button("Reset board", "reset_board", :gray)
      ],
      id: "toolbar",
      style: [:flex, :flex_row, :gap_2]
    )
  end

  defp column_ir(status, tasks) do
    column_tasks = Enum.filter(tasks, &(&1.status == status))
    color = Map.fetch!(@column_colors, status)

    Guppy.IR.div(
      [
        Guppy.IR.div(
          [
            Guppy.IR.text(Map.fetch!(@column_titles, status), id: "#{status}_title"),
            Guppy.IR.text("#{length(column_tasks)} cards", id: "#{status}_count")
          ],
          id: "#{status}_header",
          style: [:flex, :flex_col, :gap_1, :mb_2]
        ),
        Guppy.IR.scroll(
          [
            Guppy.IR.div([], id: "#{status}_drop_zone", style: [{:h_px, 8}])
            | Enum.map(column_tasks, &task_card/1)
          ],
          id: "#{status}_scroll",
          axis: :y,
          style: [:flex_1, :min_h_0, :gap_2]
        )
      ],
      id: "#{status}_column",
      style: [
        :flex,
        :flex_col,
        {:w_px, 320},
        {:h_px, 420},
        :p_2,
        :rounded_md,
        :border_1,
        {:border_color, color},
        {:bg_hex, "#22252b"},
        :gap_2
      ],
      events: %{drop: "drop_on_#{status}"}
    )
  end

  defp task_card(task) do
    Guppy.IR.div(
      [
        Guppy.IR.text(task.title, id: "task_title_#{task.id}"),
        Guppy.IR.button("Archive",
          id: "archive:#{task.id}_button",
          style: [{:bg, :red}],
          events: %{click: "archive:#{task.id}"}
        )
      ],
      id: "task_card_#{task.id}",
      style: [
        :flex,
        :flex_col,
        :gap_2,
        :p_2,
        :rounded_md,
        :border_1,
        {:border_color, :white},
        {:bg_hex, "#2c3038"},
        :cursor_pointer
      ],
      hover_style: [{:bg_hex, "#363b45"}],
      events: %{drag_start: "drag_started", drag_move: "drag_moved"}
    )
  end

  defp action_button(label, callback, color) do
    Guppy.IR.button(label,
      id: "#{callback}_button",
      style: [{:bg, color}],
      events: %{click: callback}
    )
  end

  defp handle_drop(window, source_id, status) do
    case task_id_from_source(source_id) do
      {:ok, id} ->
        IO.puts("dropped task #{id} on #{status}")
        {:noreply, assign(window, :tasks, move_task(window.assigns.tasks, id, status))}

      :error ->
        {:noreply, window, :skip_render}
    end
  end

  defp task_id_from_source("task_card_" <> id_text) do
    case Integer.parse(id_text) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp task_id_from_source(_source_id), do: :error

  defp move_task(tasks, id, status) do
    Enum.map(tasks, fn
      %{id: ^id} = task -> %{task | status: status}
      task -> task
    end)
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy kanban todo example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.KanbanTodoWindow.start_link(:ok)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
