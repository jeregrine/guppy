defmodule Examples.DataTableTreeWindow do
  use Guppy.Window

  @tasks [
    %{
      id: "auth",
      project: "platform",
      title: "Auth refresh",
      status: "In progress",
      owner: "Maya"
    },
    %{id: "menus", project: "platform", title: "App menus", status: "Done", owner: "Jason"},
    %{id: "gallery", project: "design", title: "Style gallery", status: "Ready", owner: "Noor"},
    %{id: "qa", project: "release", title: "Release QA", status: "Blocked", owner: "Ren"}
  ]

  @impl Guppy.Window
  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 920, height: 640],
       titlebar: [title: "Guppy data/table tree demo"]
     )
     |> assign(:expanded, MapSet.new(["all", "platform"]))
     |> assign(:selected_tree_id, "platform")
     |> assign(:table_column_ids, ["title", "status", "owner"])
     |> assign(:table_column_widths, %{"title" => 260, "status" => 120, "owner" => 100})
     |> assign(:selected_row_id, "menus")
     |> assign(:selected_cell, {"menus", "status"})
     |> assign(:sort, %{column_id: "title", direction: :asc})}
  end

  @impl Guppy.Window
  def handle_event("select_tree", %{item_id: item_id}, window) do
    {:noreply, assign(window, :selected_tree_id, item_id)}
  end

  def handle_event("toggle_tree", %{item_id: item_id}, window) do
    expanded =
      if MapSet.member?(window.assigns.expanded, item_id) do
        MapSet.delete(window.assigns.expanded, item_id)
      else
        MapSet.put(window.assigns.expanded, item_id)
      end

    {:noreply, assign(window, :expanded, expanded)}
  end

  def handle_event("select_row", %{row_id: row_id}, window) do
    {:noreply, assign(window, :selected_row_id, row_id)}
  end

  def handle_event("select_cell", %{row_id: row_id, column_id: column_id}, window) do
    {:noreply,
     window
     |> assign(:selected_row_id, row_id)
     |> assign(:selected_cell, {row_id, column_id})}
  end

  def handle_event("sort_table", %{column_id: column_id}, window) do
    current = window.assigns.sort

    direction =
      if current.column_id == column_id and current.direction == :asc do
        :desc
      else
        :asc
      end

    {:noreply, assign(window, :sort, %{column_id: column_id, direction: direction})}
  end

  def handle_event(
        "reorder_column",
        %{column_id: column_id, target_column_id: target_column_id, direction: direction},
        window
      ) do
    {:noreply,
     assign(
       window,
       :table_column_ids,
       reorder_column_ids(window.assigns.table_column_ids, column_id, target_column_id, direction)
     )}
  end

  def handle_event("resize_column", %{column_id: column_id, width_delta: width_delta}, window) do
    {:noreply,
     assign(
       window,
       :table_column_widths,
       resize_column_widths(window.assigns.table_column_widths, column_id, width_delta)
     )}
  end

  @impl Guppy.Window
  def render(window) do
    visible_tasks = visible_tasks(window.assigns.selected_tree_id)
    sorted_tasks = sort_tasks(visible_tasks, window.assigns.sort)

    assigns =
      Map.merge(window.assigns, %{
        table_columns:
          table_columns(window.assigns.table_column_ids, window.assigns.table_column_widths),
        table_rows:
          table_rows(sorted_tasks, window.assigns.selected_row_id, window.assigns.selected_cell),
        tree_nodes: tree_nodes(window.assigns.expanded, window.assigns.selected_tree_id),
        selected_label: selected_label(window.assigns.selected_tree_id),
        selected_row_label: window.assigns.selected_row_id,
        sort_label: "#{window.assigns.sort.column_id} #{window.assigns.sort.direction}"
      })

    ~GUI"""
    <div id="table_tree_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="header" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="title" class="text-2xl font-black">Semantic table + tree</text>
        <text id="subtitle" class="text-base text-[#94a3b8]">
          Tree expansion, table row/cell selection, sorting, Alt-Left/Alt-Right header reordering, and Shift-Left/Shift-Right header resizing are Elixir-owned state driven by native semantic events.
        </text>
        <text id="state_summary" class="text-sm text-[#bfdbfe]">
          Scope {@selected_label}; selected row {@selected_row_label}; sort {@sort_label}
        </text>
      </div>

      <div id="workspace" class="flex flex-row gap-4 flex-1 min-h-0">
        <div id="tree_panel" class="flex flex-col gap-2 w-[240px] p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
          <text id="tree_title" class="text-lg font-bold">Projects</text>
          <tree
            id="project_tree"
            nodes={@tree_nodes}
            selected_id={@selected_tree_id}
            class="flex-1 rounded-lg border-1 border-[#1e293b] bg-[#0b1220]"
            row_class="border-b-1 border-[#1e293b]"
            select="select_tree"
            toggle="toggle_tree"
          />
        </div>

        <div id="table_panel" class="flex flex-col gap-2 flex-1 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
          <text id="table_title" class="text-lg font-bold">Tasks</text>
          <data_table
            id="task_table"
            columns={@table_columns}
            rows={@table_rows}
            selected_row_id={@selected_row_id}
            selected_cell={@selected_cell}
            sort_state={@sort}
            class="flex-1 rounded-lg border-1 border-[#1e293b] bg-[#0b1220]"
            header_class="border-b-1 border-[#334155] bg-[#172554] text-[#bfdbfe] font-bold"
            row_class="border-b-1 border-[#1e293b]"
            cell_class="text-sm"
            row_click="select_row"
            cell_click="select_cell"
            sort="sort_table"
            column_reorder="reorder_column"
            column_resize="resize_column"
          />
        </div>
      </div>
    </div>
    """
  end

  defp table_columns(column_ids, column_widths) do
    definitions = %{
      "title" => %{id: "title", label: "Task", sortable: true},
      "status" => %{id: "status", label: "Status", sortable: true},
      "owner" => %{id: "owner", label: "Owner", sortable: true}
    }

    Enum.map(column_ids, fn column_id ->
      Map.put(Map.fetch!(definitions, column_id), :width, {:px, Map.fetch!(column_widths, column_id)})
    end)
  end

  defp reorder_column_ids(column_ids, column_id, target_column_id, direction) do
    without_column = List.delete(column_ids, column_id)
    target_index =
      Enum.find_index(without_column, &(&1 == target_column_id)) || length(without_column)
    insert_at = if direction == "right", do: target_index + 1, else: target_index

    List.insert_at(without_column, insert_at, column_id)
  end

  defp resize_column_widths(column_widths, column_id, width_delta) do
    Map.update!(column_widths, column_id, fn width -> max(width + width_delta, 64) end)
  end

  defp table_rows(tasks, selected_row_id, selected_cell) do
    Enum.map(tasks, fn task ->
      %{
        id: task.id,
        style: selected_row_style(task.id == selected_row_id),
        cells: [
          table_cell("title", task.title, selected_cell == {task.id, "title"}),
          table_cell("status", task.status, selected_cell == {task.id, "status"}),
          table_cell("owner", task.owner, selected_cell == {task.id, "owner"})
        ]
      }
    end)
  end

  defp table_cell(column_id, text, selected?) do
    %{
      column_id: column_id,
      children: [Guppy.IR.text(text)],
      style: selected_cell_style(selected?)
    }
  end

  defp tree_nodes(expanded, selected_id) do
    [
      %{
        id: "all",
        label: "All tasks",
        expanded: MapSet.member?(expanded, "all"),
        style: selected_tree_style(selected_id == "all"),
        children: [
          %{
            id: "platform",
            label: "Platform",
            expanded: MapSet.member?(expanded, "platform"),
            style: selected_tree_style(selected_id == "platform")
          },
          %{id: "design", label: "Design", style: selected_tree_style(selected_id == "design")},
          %{
            id: "release",
            label: "Release",
            style: selected_tree_style(selected_id == "release")
          }
        ]
      }
    ]
  end

  defp selected_row_style(true),
    do: [Guppy.Style.bg_hex("#172554"), Guppy.Style.border_color_hex("#2563eb")]

  defp selected_row_style(false), do: []

  defp selected_cell_style(true),
    do: [Guppy.Style.bg_hex("#1d4ed8"), Guppy.Style.text_color_hex("#eff6ff")]

  defp selected_cell_style(false), do: []

  defp selected_tree_style(true),
    do: [Guppy.Style.bg_hex("#1d4ed8"), Guppy.Style.text_color_hex("#eff6ff")]

  defp selected_tree_style(false), do: []

  defp visible_tasks("all"), do: @tasks
  defp visible_tasks(project), do: Enum.filter(@tasks, &(&1.project == project))

  defp sort_tasks(tasks, %{column_id: column_id, direction: direction}) do
    sorted = Enum.sort_by(tasks, &Map.fetch!(&1, String.to_atom(column_id)))
    if direction == :desc, do: Enum.reverse(sorted), else: sorted
  end

  defp selected_label("all"), do: "All tasks"
  defp selected_label("platform"), do: "Platform"
  defp selected_label("design"), do: "Design"
  defp selected_label("release"), do: "Release"
  defp selected_label(other), do: other
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy data table/tree example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.DataTableTreeWindow.start_link([])
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
