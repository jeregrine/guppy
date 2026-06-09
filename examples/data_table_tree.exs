Code.require_file("support/table_tree_shared.exs", __DIR__)
Code.require_file("support/ui.exs", __DIR__)

defmodule Examples.DataTableTreeWindow do
  use Guppy.Window

  alias Examples.TableTreeShared
  alias Examples.UI

  @impl Guppy.Window
  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 920, height: 640],
       titlebar: [title: "Tasks"]
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
       TableTreeShared.reorder_column_ids(
         window.assigns.table_column_ids,
         column_id,
         target_column_id,
         direction
       )
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
    visible_tasks = TableTreeShared.visible_tasks(window.assigns.selected_tree_id)
    sorted_tasks = TableTreeShared.sort_tasks(visible_tasks, window.assigns.sort)

    assigns =
      Map.merge(window.assigns, %{
        table_columns:
          TableTreeShared.table_columns(
            window.assigns.table_column_ids,
            window.assigns.table_column_widths
          ),
        table_rows:
          table_rows(sorted_tasks, window.assigns.selected_row_id, window.assigns.selected_cell),
        tree_nodes: tree_nodes(window.assigns.expanded, window.assigns.selected_tree_id),
        selected_label: TableTreeShared.selected_label(window.assigns.selected_tree_id),
        selected_row_label: window.assigns.selected_row_id,
        sort_label: "#{window.assigns.sort.column_id} #{window.assigns.sort.direction}"
      })

    ~GUI"""
    <div id="table_tree_root" class={UI.window_class()}>
      <div id="workspace" class="flex flex-row gap-4 flex-1 min-h-0">
        <div id="tree_panel" class="flex flex-col gap-2 w-[220px]">
          <text id="tree_title" class="text-sm font-semibold">Projects</text>
          <tree
            id="project_tree"
            nodes={@tree_nodes}
            selected_id={@selected_tree_id}
            class={"flex-1 " <> UI.panel_class()}
            select="select_tree"
            toggle="toggle_tree"
          />
        </div>

        <div id="table_panel" class="flex flex-col gap-2 flex-1">
          <text id="table_title" class="text-sm font-semibold">Tasks</text>
          <data_table
            id="task_table"
            columns={@table_columns}
            rows={@table_rows}
            selected_row_id={@selected_row_id}
            selected_cell={@selected_cell}
            sort_state={@sort}
            class={"flex-1 " <> UI.panel_class()}
            header_class={"border-b-1 border-[#d2d2d7] bg-[#f5f5f7] font-semibold text-[" <> UI.text_secondary() <> "]"}
            row_class="border-b-1 border-[#ececf0]"
            cell_class="text-sm"
            row_click="select_row"
            cell_click="select_cell"
            sort="sort_table"
            column_reorder="reorder_column"
            column_resize="resize_column"
          />
        </div>
      </div>

      <text id="state_summary" class={UI.caption_class()}>
        Scope {@selected_label}; selected row {@selected_row_label}; sort {@sort_label}. Click headers to sort, Alt-Left/Alt-Right to reorder, Shift-Left/Shift-Right to resize.
      </text>
    </div>
    """
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
    do: [Guppy.Style.bg_hex("#eaf2fe"), Guppy.Style.border_color_hex(UI.accent())]

  defp selected_row_style(false), do: []

  defp selected_cell_style(true),
    do: [Guppy.Style.bg_hex(UI.accent()), Guppy.Style.text_color_hex("#ffffff")]

  defp selected_cell_style(false), do: []

  defp selected_tree_style(true),
    do: [Guppy.Style.bg_hex(UI.accent()), Guppy.Style.text_color_hex("#ffffff")]

  defp selected_tree_style(false), do: []
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy data table/tree example")

{:ok, pid} = Examples.DataTableTreeWindow.start_link([])

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
