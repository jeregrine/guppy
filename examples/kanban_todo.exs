defmodule Examples.KanbanTodoWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 2, assign: 3, put_window_opts: 2]

  @column_order [:todo, :doing, :done]
  @column_titles %{todo: "Todo", doing: "Doing", done: "Done"}
  @column_colors %{todo: "#64748b", doing: "#3b82f6", done: "#22c55e"}
  @seed_titles %{
    bug: "Fix drag/drop highlight bug",
    docs: "Write bridge-view architecture notes",
    polish: "Polish kanban card spacing"
  }

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 1260, height: 820],
       window_min_size: [width: 1100, height: 760],
       titlebar: [title: "Guppy kanban todo"]
     )
     |> initial_window()}
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
        panel(
          [
            Guppy.IR.div([Guppy.IR.text("Kanban todo board", id: "title")],
              style: [:text_3xl, :font_black]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text(
                  "Add sample tasks, drag cards across columns, and archive completed work.",
                  id: "subtitle"
                )
              ],
              style: [:text_base, {:text_color_hex, "#94a3b8"}]
            ),
            toolbar()
          ],
          id: "header_panel"
        ),
        Guppy.IR.div(
          Enum.map(@column_order, &column_ir(&1, tasks)),
          id: "board",
          style: [:flex, :flex_row, :gap_4]
        )
      ],
      id: "kanban_root",
      style: [
        :flex,
        :flex_col,
        :w_full,
        :h_full,
        :gap_4,
        :p_6,
        {:bg_hex, "#0f172a"},
        {:text_color_hex, "#f8fafc"}
      ]
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

  defp panel(children, opts) do
    id = Keyword.get(opts, :id)

    Guppy.IR.div(
      children,
      id: id,
      style: [
        :flex,
        :flex_col,
        :gap_2,
        :p_4,
        :rounded_xl,
        :border_1,
        {:border_color_hex, "#334155"},
        {:bg_hex, "#111827"},
        :shadow_md
      ]
    )
  end

  defp toolbar do
    Guppy.IR.div(
      [
        action_button("Add bug", "add:bug", "#d97706", "#f59e0b"),
        action_button("Add docs", "add:docs", "#2563eb", "#3b82f6"),
        action_button("Add polish", "add:polish", "#16a34a", "#22c55e"),
        action_button("Reset board", "reset_board", "#334155", "#475569")
      ],
      id: "toolbar",
      style: [:flex, :flex_row, :flex_wrap, :gap_2, :mt_2]
    )
  end

  defp column_ir(status, tasks) do
    column_tasks = Enum.filter(tasks, &(&1.status == status))
    border_hex = Map.fetch!(@column_colors, status)

    Guppy.IR.div(
      [
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [Guppy.IR.text(Map.fetch!(@column_titles, status), id: "#{status}_title")],
              style: [:text_lg, :font_bold]
            ),
            Guppy.IR.div(
              [Guppy.IR.text("#{length(column_tasks)} cards", id: "#{status}_count")],
              style: [
                :p_1,
                :rounded_full,
                :border_1,
                {:border_color_hex, border_hex},
                {:bg_hex, "#0f172a"},
                :text_sm,
                {:text_color_hex, "#cbd5e1"}
              ]
            )
          ],
          id: "#{status}_header",
          style: [:flex, :flex_row, :items_center, :justify_between, :mb_2]
        ),
        Guppy.IR.scroll(
          [
            Guppy.IR.div(
              [Guppy.IR.text("Drop cards anywhere in this column", id: "#{status}_drop_hint")],
              id: "#{status}_drop_zone",
              style: [
                :p_2,
                :rounded_lg,
                :border_1,
                :border_dashed,
                {:border_color_hex, border_hex},
                {:bg_hex, "#0f172a"},
                :text_sm,
                {:text_color_hex, "#94a3b8"}
              ]
            )
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
        {:h_px, 460},
        :p_4,
        :rounded_xl,
        :border_1,
        {:border_color_hex, border_hex},
        {:bg_hex, "#111827"},
        :gap_2,
        :shadow_md
      ],
      events: %{drop: "drop_on_#{status}"}
    )
  end

  defp task_card(task) do
    Guppy.IR.div(
      [
        Guppy.IR.div([Guppy.IR.text(task.title, id: "task_title_#{task.id}")],
          style: [:text_base, :font_semibold]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text(String.upcase(to_string(task.status)), id: "task_status_#{task.id}")
              ],
              style: [:text_xs, {:text_color_hex, "#94a3b8"}]
            ),
            Guppy.IR.button("Archive",
              id: "archive:#{task.id}_button",
              style: [
                :p_2,
                :rounded_lg,
                :border_1,
                {:border_color_hex, "#991b1b"},
                {:bg_hex, "#7f1d1d"},
                {:text_color_hex, "#fef2f2"}
              ],
              hover_style: [{:bg_hex, "#991b1b"}],
              events: %{click: "archive:#{task.id}"}
            )
          ],
          id: "task_footer_#{task.id}",
          style: [:flex, :flex_row, :items_center, :justify_between]
        )
      ],
      id: "task_card_#{task.id}",
      style: [
        :flex,
        :flex_col,
        :gap_2,
        :p_4,
        :rounded_xl,
        :border_1,
        {:border_color_hex, "#475569"},
        {:bg_hex, "#1e293b"},
        :cursor_pointer,
        :shadow_sm
      ],
      hover_style: [{:bg_hex, "#334155"}],
      events: %{drag_start: "drag_started", drag_move: "drag_moved"}
    )
  end

  defp action_button(label, callback, bg_hex, hover_hex) do
    Guppy.IR.button(label,
      id: "#{callback}_button",
      style: [
        :p_2,
        :rounded_lg,
        :border_1,
        {:border_color_hex, bg_hex},
        {:bg_hex, bg_hex},
        {:text_color_hex, "#f8fafc"},
        :shadow_sm
      ],
      hover_style: [{:bg_hex, hover_hex}],
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
