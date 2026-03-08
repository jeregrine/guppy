defmodule Examples.KanbanTodoWindow do
  use Guppy.Window
  use Guppy.Component

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
    columns =
      Enum.map(@column_order, fn status ->
        column_tasks = Enum.filter(window.assigns.tasks, &(&1.status == status))
        border_hex = Map.fetch!(@column_colors, status)

        %{
          status: status,
          title: Map.fetch!(@column_titles, status),
          count: length(column_tasks),
          border_hex: border_hex,
          column_class:
            "flex flex-col w-[320px] h-[460px] p-4 rounded-xl border-1 gap-2 shadow-md border-[#{border_hex}] bg-[#111827]",
          count_class:
            "p-1 rounded-full border-1 text-sm border-[#{border_hex}] bg-[#0f172a] text-[#cbd5e1]",
          drop_zone_class:
            "p-2 rounded-lg border-1 border-dashed text-sm border-[#{border_hex}] bg-[#0f172a] text-[#94a3b8]",
          tasks: Enum.map(column_tasks, &task_view/1)
        }
      end)

    assigns =
      Map.merge(window.assigns, %{
        toolbar_buttons: toolbar_buttons(),
        columns: columns
      })

    ~G"""
    <div id="kanban_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="header_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="title" class="text-3xl font-black">Kanban todo board</text>
        <text id="subtitle" class="text-base text-[#94a3b8]">
          Add sample tasks, drag cards across columns, and archive completed work.
        </text>

        <div id="toolbar" class="flex flex-row flex-wrap gap-2 mt-2">
          <button
            :for={button <- @toolbar_buttons}
            id={button.id}
            click={button.click}
            class={button.class}
            hover_class={button.hover_class}
          >
            {button.label}
          </button>
        </div>
      </div>

      <div id="board" class="flex flex-row gap-4">
        <div
          :for={column <- @columns}
          id={"#{column.status}_column"}
          drop={"drop_on_#{column.status}"}
          class={column.column_class}
        >
          <div id={"#{column.status}_header"} class="flex flex-row items-center justify-between mb-2">
            <text id={"#{column.status}_title"} class="text-lg font-bold">{column.title}</text>
            <text id={"#{column.status}_count"} class={column.count_class}>{column.count} cards</text>
          </div>

          <scroll id={"#{column.status}_scroll"} axis="y" class="flex-1 min-h-0 gap-2">
            <div id={"#{column.status}_drop_zone"} class={column.drop_zone_class}>
              <text id={"#{column.status}_drop_hint"}>Drop cards anywhere in this column</text>
            </div>

            <div
              :for={task <- column.tasks}
              id={task.card_id}
              drag_start="drag_started"
              drag_move="drag_moved"
              class={task.card_class}
              hover_class="bg-[#334155]"
            >
              <text id={task.title_id} class="text-base font-semibold">{task.title}</text>

              <div id={task.footer_id} class="flex flex-row items-center justify-between">
                <text id={task.status_id} class="text-xs text-[#94a3b8]">{task.status_label}</text>
                <button
                  id={task.archive_button_id}
                  click={task.archive_click}
                  class="p-2 rounded-lg border-1 border-[#991b1b] bg-[#7f1d1d] text-[#fef2f2]"
                  hover_class="bg-[#991b1b]"
                >
                  Archive
                </button>
              </div>
            </div>
          </scroll>
        </div>
      </div>
    </div>
    """
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

  defp toolbar_buttons do
    [
      %{
        id: "add:bug_button",
        label: "Add bug",
        click: "add:bug",
        class: "p-2 rounded-lg border-1 border-[#d97706] bg-[#d97706] text-[#f8fafc] shadow-sm",
        hover_class: "bg-[#f59e0b]"
      },
      %{
        id: "add:docs_button",
        label: "Add docs",
        click: "add:docs",
        class: "p-2 rounded-lg border-1 border-[#2563eb] bg-[#2563eb] text-[#f8fafc] shadow-sm",
        hover_class: "bg-[#3b82f6]"
      },
      %{
        id: "add:polish_button",
        label: "Add polish",
        click: "add:polish",
        class: "p-2 rounded-lg border-1 border-[#16a34a] bg-[#16a34a] text-[#f8fafc] shadow-sm",
        hover_class: "bg-[#22c55e]"
      },
      %{
        id: "reset_board_button",
        label: "Reset board",
        click: "reset_board",
        class: "p-2 rounded-lg border-1 border-[#334155] bg-[#334155] text-[#f8fafc] shadow-sm",
        hover_class: "bg-[#475569]"
      }
    ]
  end

  defp task_view(task) do
    %{
      card_id: "task_card_#{task.id}",
      title_id: "task_title_#{task.id}",
      footer_id: "task_footer_#{task.id}",
      status_id: "task_status_#{task.id}",
      archive_button_id: "archive:#{task.id}_button",
      archive_click: "archive:#{task.id}",
      title: task.title,
      status_label: String.upcase(to_string(task.status)),
      card_class:
        "flex flex-col gap-2 p-4 rounded-xl border-1 border-[#475569] bg-[#1e293b] cursor-pointer shadow-sm"
    }
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
