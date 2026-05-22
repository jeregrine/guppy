defmodule Examples.TableTreeShared do
  @moduledoc false

  @task_specs [
    {"auth", "platform", "Auth refresh", "In progress", "Maya"},
    {"menus", "platform", "App menus", "Done", "Jason"},
    {"gallery", "design", "Style gallery", "Ready", "Noor"},
    {"qa", "release", "Release QA", "Blocked", "Ren"}
  ]

  @tasks Enum.map(@task_specs, fn {id, project, title, status, owner} ->
           %{id: id, project: project, title: title, status: status, owner: owner}
         end)

  @columns %{
    "title" => %{id: "title", label: "Task", sortable: true, pinned: true},
    "status" => %{id: "status", label: "Status", sortable: true},
    "owner" => %{id: "owner", label: "Owner", sortable: true}
  }

  def tasks, do: @tasks

  def visible_tasks("all"), do: @tasks

  def visible_tasks(project) when project in ["platform", "design", "release"],
    do: Enum.filter(@tasks, &(&1.project == project))

  def visible_tasks("task_" <> task_id), do: Enum.filter(@tasks, &(&1.id == task_id))
  def visible_tasks(task_id), do: Enum.filter(@tasks, &(&1.id == task_id))

  def table_columns(column_ids, column_widths) do
    Enum.map(column_ids, fn column_id ->
      @columns
      |> Map.fetch!(column_id)
      |> Map.put(:width, {:px, Map.fetch!(column_widths, column_id)})
    end)
  end

  def sort_tasks(tasks, %{column_id: column_id, direction: direction}) do
    sorted = Enum.sort_by(tasks, &task_sort_value(&1, column_id))
    if direction == :desc, do: Enum.reverse(sorted), else: sorted
  end

  def reorder_column_ids(column_ids, column_id, target_column_id, direction) do
    without_column = List.delete(column_ids, column_id)

    target_index =
      Enum.find_index(without_column, &(&1 == target_column_id)) || length(without_column)

    insert_at = if direction == "right", do: target_index + 1, else: target_index
    List.insert_at(without_column, insert_at, column_id)
  end

  def selected_row_id_for([], _row_id), do: nil

  def selected_row_id_for(tasks, row_id) do
    task_ids = MapSet.new(tasks, & &1.id)

    if MapSet.member?(task_ids, row_id),
      do: row_id,
      else: tasks |> List.first() |> Map.fetch!(:id)
  end

  def selected_cell_for(nil, _cell), do: nil

  def selected_cell_for(row_id, {row_id, column_id})
      when column_id in ["title", "status", "owner"],
      do: {row_id, column_id}

  def selected_cell_for(row_id, _cell), do: {row_id, "status"}

  def selected_label("all"), do: "All tasks"
  def selected_label("platform"), do: "Platform"
  def selected_label("design"), do: "Design"
  def selected_label("release"), do: "Release"
  def selected_label(other), do: other

  defp task_sort_value(task, "title"), do: task.title
  defp task_sort_value(task, "status"), do: task.status
  defp task_sort_value(task, "owner"), do: task.owner
  defp task_sort_value(task, _unknown_column), do: task.title
end
