defmodule Examples.KanbanTodoWindow do
  use Guppy.Window

  @column_order [:backlog, :planned, :in_progress, :review, :blocked, :done]

  @column_meta %{
    backlog: %{title: "Backlog", accent: "#64748b"},
    planned: %{title: "Planned", accent: "#0ea5e9"},
    in_progress: %{title: "In Progress", accent: "#8b5cf6"},
    review: %{title: "In Review", accent: "#f59e0b"},
    blocked: %{title: "Blocked", accent: "#ef4444"},
    done: %{title: "Done", accent: "#22c55e"}
  }

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 1480, height: 860],
       window_min_size: [width: 1200, height: 740],
       titlebar: [title: "Guppy launch board"]
     )
     |> initial_window()}
  end

  @impl Guppy.Window
  def handle_event("draft_changed", %{value: value}, window) do
    {:noreply,
     assign(window,
       draft_title: value,
       notice: composer_notice(value),
       notice_tone: notice_tone_for_draft(value)
     )}
  end

  def handle_event("add_task", _event_data, window) do
    add_task_from_draft(window)
  end

  def handle_event("archive_done", _event_data, window) do
    archive_done_tasks(window)
  end

  def handle_event("archive:" <> id_text, _event_data, window) do
    archive_task(window, String.to_integer(id_text))
  end

  def handle_event("drag_started", _event_data, window) do
    {:noreply, window, :skip_render}
  end

  def handle_event("drag_moved", _event_data, window) do
    {:noreply, window, :skip_render}
  end

  def handle_event("drop_on_backlog", %{source_id: source_id}, window) do
    handle_drop(window, source_id, :backlog)
  end

  def handle_event("drop_on_planned", %{source_id: source_id}, window) do
    handle_drop(window, source_id, :planned)
  end

  def handle_event("drop_on_in_progress", %{source_id: source_id}, window) do
    handle_drop(window, source_id, :in_progress)
  end

  def handle_event("drop_on_review", %{source_id: source_id}, window) do
    handle_drop(window, source_id, :review)
  end

  def handle_event("drop_on_blocked", %{source_id: source_id}, window) do
    handle_drop(window, source_id, :blocked)
  end

  def handle_event("drop_on_done", %{source_id: source_id}, window) do
    handle_drop(window, source_id, :done)
  end

  @impl Guppy.Window
  def render(window) do
    tasks = window.assigns.tasks
    counts = count_by_status(tasks)
    columns = Enum.map(@column_order, &column_view(&1, tasks, counts))

    board_width_px = length(columns) * 264 + max(length(columns) - 1, 0) * 8 + 8
    open_count = length(tasks) - Map.get(counts, :done, 0)
    blocked_count = Map.get(counts, :blocked, 0)
    done_count = Map.get(counts, :done, 0)

    assigns =
      Map.merge(window.assigns, %{
        add_disabled: blank?(window.assigns.draft_title),
        done_count: done_count,
        board_columns_class:
          "flex flex-row flex-nowrap gap-2 h-full pr-2 w-[#{board_width_px}px]",
        header_metrics: [
          %{id: "open_scope", label: "Open", value: open_count, class: metric_class(:open)},
          %{
            id: "blocked_scope",
            label: "Blocked",
            value: blocked_count,
            class: metric_class(:blocked)
          },
          %{id: "done_scope", label: "Done", value: done_count, class: metric_class(:done)}
        ],
        columns: columns
      })

    ~G"""
    <div id="kanban_root" class="flex flex-col w-full h-full gap-2 p-2 bg-[#09111f] text-[#f8fafc]">
      <div id="top_shell" class="flex flex-col gap-2 p-2 rounded-xl border-1 border-[#1e293b] bg-[#0f172a] shadow-md">
        <div id="board_header" class="flex flex-row items-center justify-between gap-2">
          <div id="board_header_copy" class="flex flex-col gap-1 flex-1">
            <text id="eyebrow" class="text-xs font-semibold text-[#93c5fd]">PRODUCT DELIVERY</text>
            <text id="title" class="text-xl font-black">Launch readiness board</text>
            <text id="subtitle" class="text-xs text-[#94a3b8] leading-snug">
              Release work, blockers, and final polish in one dense production-style surface.
            </text>
          </div>

          <div id="header_metrics" class="flex flex-row items-center gap-2">
            <div :for={metric <- @header_metrics} id={metric.id} class={metric.class}>
              <text id={metric.id <> "_label"} class="text-xs text-[#94a3b8]">{metric.label}</text>
              <text id={metric.id <> "_value"} class="text-sm font-bold">{metric.value}</text>
            </div>
          </div>
        </div>

        <div id="toolbar" class="flex flex-row items-center gap-2">
          <text_input
            id="draft_title"
            value={@draft_title}
            placeholder="Add a bug, feature, or release task"
            change="draft_changed"
            class="flex-1 p-2 rounded-lg border-1 border-[#334155] bg-[#0b1220] text-[#f8fafc]"
          />

          <button
            id="add_task_button"
            click="add_task"
            disabled={@add_disabled}
            class="p-2 rounded-lg border-1 border-[#2563eb] bg-[#2563eb] text-[#eff6ff] shadow-sm"
            hover_class="bg-[#3b82f6]"
            disabled_class="border-[#1e293b] bg-[#0b1220] text-[#475569]"
          >
            Add card
          </button>

          <button
            id="archive_done_button"
            click="archive_done"
            disabled={@done_count == 0}
            class="p-2 rounded-lg border-1 border-[#334155] bg-[#111827] text-[#e2e8f0]"
            hover_class="bg-[#1e293b]"
            disabled_class="border-[#1e293b] bg-[#0b1220] text-[#475569]"
          >
            Archive completed
          </button>

          <div id="toolbar_notice" class={notice_class(@notice_tone)}>
            <text id="toolbar_notice_text" class="text-xs font-medium">{@notice}</text>
          </div>
        </div>
      </div>

      <div id="board_panel" class="flex flex-col flex-1 min-h-0 rounded-xl border-1 border-[#1e293b] bg-[#0d1526] shadow-md p-2">
        <scroll id="board_scroll" axis="x" class="flex-1 min-h-0 scrollbar-w-[10px]">
          <div id="board_columns" class={@board_columns_class}>
            <div
              :for={column <- @columns}
              id={column.id}
              drop={column.drop_event}
              class={column.class}
            >
              <div id={column.header_id} class="flex flex-row items-center justify-between gap-2 p-1">
                <div id={column.title_id <> "_wrap"} class="flex flex-row items-center gap-2 flex-1">
                  <div id={column.accent_id} class={column.accent_class}></div>
                  <text id={column.title_id} class="text-sm font-bold">{column.title}</text>
                </div>

                <div id={column.count_badge_id} class={column.count_badge_class}>
                  <text id={column.count_id} class="text-xs font-semibold">{column.count}</text>
                </div>
              </div>

              <scroll id={column.scroll_id} axis="y" class="flex-1 min-h-0 scrollbar-w-[8px]">
                <div id={column.stack_id} class="flex flex-col gap-2 pr-2">
                  <div :if={column.empty?} id={column.empty_id} class={column.empty_class}>
                    <text id={column.empty_text_id} class="text-xs text-[#94a3b8]">
                      No work items in this stage.
                    </text>
                  </div>

                  <div
                    :for={task <- column.tasks}
                    id={task.card_id}
                    drag_start="drag_started"
                    drag_move="drag_moved"
                    class={task.card_class}
                    hover_class="bg-[#162033]"
                  >
                    <div id={task.top_id} class="flex flex-row items-center justify-between gap-2">
                      <div id={task.team_badge_id} class={task.team_badge_class}>
                        <text id={task.team_text_id} class="text-xs font-semibold">{task.team}</text>
                      </div>

                      <text id={task.updated_id} class="text-xs text-[#64748b]">{task.updated_at}</text>
                    </div>

                    <div id={task.body_id} class="flex flex-col gap-1">
                      <text id={task.title_id} class="text-sm font-semibold leading-snug">{task.title}</text>
                      <text id={task.summary_id} class="text-xs text-[#94a3b8] leading-snug line-clamp-2 whitespace-normal">
                        {task.summary}
                      </text>
                    </div>

                    <div id={task.footer_id} class="flex flex-row items-center justify-between gap-2">
                      <div id={task.assignee_wrap_id} class="flex flex-col gap-1 flex-1">
                        <text id={task.assignee_label_id} class="text-xs text-[#64748b]">OWNER</text>
                        <text id={task.assignee_id} class="text-xs font-medium text-[#cbd5e1]">{task.assignee}</text>
                      </div>

                      <div id={task.priority_badge_id} class={task.priority_badge_class}>
                        <text id={task.priority_text_id} class="text-xs font-semibold">{task.priority_label}</text>
                      </div>
                    </div>

                    <div :if={task.done?} id={task.actions_id} class="flex flex-row justify-end">
                      <button
                        id={task.archive_button_id}
                        click={task.archive_click}
                        class="p-2 rounded-lg border-1 border-[#166534] bg-[#14532d] text-[#dcfce7]"
                        hover_class="bg-[#166534]"
                      >
                        Archive
                      </button>
                    </div>
                  </div>
                </div>
              </scroll>
            </div>
          </div>
        </scroll>
      </div>
    </div>
    """
  end

  defp initial_window(window) do
    assign(window,
      next_id: 109,
      draft_title: "",
      notice: "Add a clear title to create a new backlog card.",
      notice_tone: :neutral,
      tasks: seed_tasks()
    )
  end

  defp seed_tasks do
    [
      %{
        id: 101,
        title: "Polish onboarding empty states",
        summary:
          "Tighten copy and layout for first-run project setup so new teams understand the happy path immediately.",
        status: :backlog,
        assignee: "Design",
        priority: :medium,
        team: "UX",
        updated_at: "Queued"
      },
      %{
        id: 102,
        title: "Finalize beta access checklist",
        summary:
          "Align release, support, and docs on the final beta rollout criteria and owner handoff.",
        status: :planned,
        assignee: "Operations",
        priority: :high,
        team: "OPS",
        updated_at: "Today"
      },
      %{
        id: 103,
        title: "Add keyboard focus ring consistency",
        summary:
          "Bring hover and focus treatments into the same visual system across buttons, cards, and text input.",
        status: :in_progress,
        assignee: "Frontend",
        priority: :high,
        team: "UI",
        updated_at: "2h ago"
      },
      %{
        id: 104,
        title: "Write native runtime troubleshooting guide",
        summary:
          "Document bootstrap failure modes, common build issues, and the recommended local validation loop.",
        status: :review,
        assignee: "Docs",
        priority: :medium,
        team: "DOCS",
        updated_at: "Review"
      },
      %{
        id: 105,
        title: "Resolve drag target hover regression",
        summary:
          "Drop targets are not always visibly active while moving cards across packed columns on larger boards.",
        status: :blocked,
        assignee: "Runtime",
        priority: :high,
        team: "CORE",
        updated_at: "Blocked"
      },
      %{
        id: 106,
        title: "Ship window options validation coverage",
        summary:
          "Round out option validation so incorrect nested values fail fast before crossing the native boundary.",
        status: :done,
        assignee: "Backend",
        priority: :medium,
        team: "ELIXIR",
        updated_at: "Ready"
      },
      %{
        id: 107,
        title: "Review professional example styling",
        summary:
          "Promote the new application shell and panel system across examples to make the project feel beta-ready.",
        status: :in_progress,
        assignee: "Design",
        priority: :low,
        team: "UX",
        updated_at: "Today"
      },
      %{
        id: 108,
        title: "Prepare beta release notes draft",
        summary:
          "Capture the window API, template sigil, and flagship board improvements in the launch narrative.",
        status: :planned,
        assignee: "Product",
        priority: :medium,
        team: "PM",
        updated_at: "Queued"
      }
    ]
  end

  defp composer_notice(value) do
    if blank?(value) do
      "Add a clear title to create a new backlog card."
    else
      "Ready to add \"#{String.trim(value)}\"."
    end
  end

  defp notice_tone_for_draft(value) do
    if blank?(value), do: :neutral, else: :ready
  end

  defp add_task_from_draft(window) do
    title = String.trim(window.assigns.draft_title)

    if title == "" do
      {:noreply,
       assign(window,
         notice: "Add a task title before creating a new card.",
         notice_tone: :warning
       )}
    else
      task = %{
        id: window.assigns.next_id,
        title: title,
        summary: "New work item created from the board composer.",
        status: :backlog,
        assignee: "Unassigned",
        priority: :medium,
        team: "PM",
        updated_at: "Just now"
      }

      {:noreply,
       assign(window,
         next_id: window.assigns.next_id + 1,
         draft_title: "",
         notice: "Added \"#{title}\" to Backlog.",
         notice_tone: :success,
         tasks: [task | window.assigns.tasks]
       )}
    end
  end

  defp archive_done_tasks(window) do
    {done_tasks, remaining_tasks} = Enum.split_with(window.assigns.tasks, &(&1.status == :done))

    case done_tasks do
      [] ->
        {:noreply,
         assign(window,
           notice: "No completed cards to archive.",
           notice_tone: :neutral
         )}

      tasks ->
        {:noreply,
         assign(window,
           tasks: remaining_tasks,
           notice: "Archived #{length(tasks)} completed #{noun(length(tasks), "card", "cards")}.",
           notice_tone: :success
         )}
    end
  end

  defp archive_task(window, id) do
    case Enum.find(window.assigns.tasks, &(&1.id == id)) do
      nil ->
        {:noreply, window, :skip_render}

      task ->
        {:noreply,
         assign(window,
           tasks: Enum.reject(window.assigns.tasks, &(&1.id == id)),
           notice: "Archived \"#{task.title}\".",
           notice_tone: :success
         )}
    end
  end

  defp count_by_status(tasks) do
    Enum.reduce(tasks, %{}, fn task, acc ->
      Map.update(acc, task.status, 1, &(&1 + 1))
    end)
  end

  defp column_view(status, tasks, counts) do
    meta = Map.fetch!(@column_meta, status)
    column_tasks = tasks |> Enum.filter(&(&1.status == status)) |> Enum.sort_by(&task_sort_key/1)

    %{
      id: "#{status}_column",
      title: meta.title,
      count: Map.get(counts, status, 0),
      drop_event: "drop_on_#{status}",
      header_id: "#{status}_header",
      title_id: "#{status}_title",
      accent_id: "#{status}_accent",
      count_id: "#{status}_count",
      count_badge_id: "#{status}_count_badge",
      scroll_id: "#{status}_scroll",
      stack_id: "#{status}_stack",
      empty_id: "#{status}_empty",
      empty_text_id: "#{status}_empty_text",
      empty?: column_tasks == [],
      class:
        "flex flex-col flex-none w-[264px] h-full gap-2 p-2 rounded-xl border-1 bg-[#0b1220] border-[#{meta.accent}] shadow-sm",
      accent_class: "w-[8px] h-[8px] rounded-full bg-[#{meta.accent}]",
      count_badge_class:
        "px-2 py-2 rounded-full border-1 bg-[#111827] border-[#{meta.accent}] text-[#e2e8f0]",
      empty_class:
        "p-2 rounded-lg border-1 border-dashed border-[#{meta.accent}] bg-[#09111f] opacity-[0.9]",
      tasks: Enum.map(column_tasks, &task_view/1)
    }
  end

  defp task_view(task) do
    %{
      card_id: "task_card_#{task.id}",
      top_id: "task_top_#{task.id}",
      team_badge_id: "task_team_badge_#{task.id}",
      team_text_id: "task_team_text_#{task.id}",
      updated_id: "task_updated_#{task.id}",
      body_id: "task_body_#{task.id}",
      title_id: "task_title_#{task.id}",
      summary_id: "task_summary_#{task.id}",
      footer_id: "task_footer_#{task.id}",
      assignee_wrap_id: "task_assignee_wrap_#{task.id}",
      assignee_label_id: "task_assignee_label_#{task.id}",
      assignee_id: "task_assignee_#{task.id}",
      priority_badge_id: "task_priority_badge_#{task.id}",
      priority_text_id: "task_priority_text_#{task.id}",
      actions_id: "task_actions_#{task.id}",
      archive_button_id: "task_archive_#{task.id}",
      archive_click: "archive:#{task.id}",
      title: task.title,
      summary: task.summary,
      assignee: task.assignee,
      team: task.team,
      updated_at: task.updated_at,
      priority_label: String.upcase(to_string(task.priority)),
      done?: task.status == :done,
      card_class:
        "flex flex-col gap-2 p-2 rounded-lg border-1 border-[#1e293b] bg-[#111827] shadow-sm cursor-pointer",
      team_badge_class: team_badge_class(task.team),
      priority_badge_class: priority_badge_class(task.priority)
    }
  end

  defp handle_drop(window, source_id, status) do
    case task_id_from_source(source_id) do
      {:ok, id} ->
        move_task(window, id, status)

      :error ->
        {:noreply, window, :skip_render}
    end
  end

  defp move_task(window, id, status) do
    case Enum.find(window.assigns.tasks, &(&1.id == id)) do
      nil ->
        {:noreply, window, :skip_render}

      %{status: ^status} ->
        {:noreply, window, :skip_render}

      task ->
        updated_tasks =
          Enum.map(window.assigns.tasks, fn
            %{id: ^id} = current -> %{current | status: status, updated_at: "Just now"}
            current -> current
          end)

        {:noreply,
         assign(window,
           tasks: updated_tasks,
           notice: "Moved \"#{task.title}\" to #{Map.fetch!(@column_meta, status).title}.",
           notice_tone: :success
         )}
    end
  end

  defp task_id_from_source("task_card_" <> id_text) do
    case Integer.parse(id_text) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp task_id_from_source(_source_id), do: :error

  defp priority_badge_class(:high),
    do: "px-2 py-2 rounded-full border-1 border-[#7f1d1d] bg-[#450a0a] text-[#fecaca]"

  defp priority_badge_class(:medium),
    do: "px-2 py-2 rounded-full border-1 border-[#92400e] bg-[#451a03] text-[#fde68a]"

  defp priority_badge_class(:low),
    do: "px-2 py-2 rounded-full border-1 border-[#334155] bg-[#0f172a] text-[#cbd5e1]"

  defp team_badge_class("UX"),
    do: "px-2 py-2 rounded-full border-1 border-[#1d4ed8] bg-[#172554] text-[#bfdbfe]"

  defp team_badge_class("UI"),
    do: "px-2 py-2 rounded-full border-1 border-[#7c3aed] bg-[#2e1065] text-[#ddd6fe]"

  defp team_badge_class("CORE"),
    do: "px-2 py-2 rounded-full border-1 border-[#991b1b] bg-[#450a0a] text-[#fecaca]"

  defp team_badge_class("DOCS"),
    do: "px-2 py-2 rounded-full border-1 border-[#0f766e] bg-[#042f2e] text-[#99f6e4]"

  defp team_badge_class("ELIXIR"),
    do: "px-2 py-2 rounded-full border-1 border-[#6d28d9] bg-[#2e1065] text-[#e9d5ff]"

  defp team_badge_class("OPS"),
    do: "px-2 py-2 rounded-full border-1 border-[#b45309] bg-[#451a03] text-[#fde68a]"

  defp team_badge_class("PM"),
    do: "px-2 py-2 rounded-full border-1 border-[#2563eb] bg-[#172554] text-[#dbeafe]"

  defp team_badge_class(_team),
    do: "px-2 py-2 rounded-full border-1 border-[#334155] bg-[#0f172a] text-[#cbd5e1]"

  defp notice_class(:neutral),
    do: "p-2 rounded-lg border-1 border-[#334155] bg-[#111827] text-[#cbd5e1]"

  defp notice_class(:ready),
    do: "p-2 rounded-lg border-1 border-[#2563eb] bg-[#172554] text-[#dbeafe]"

  defp notice_class(:warning),
    do: "p-2 rounded-lg border-1 border-[#92400e] bg-[#451a03] text-[#fde68a]"

  defp notice_class(:success),
    do: "p-2 rounded-lg border-1 border-[#166534] bg-[#14532d] text-[#dcfce7]"

  defp metric_class(:open),
    do: "flex flex-col gap-1 px-2 py-2 rounded-lg border-1 border-[#2563eb] bg-[#111827] min-w-32"

  defp metric_class(:blocked),
    do: "flex flex-col gap-1 px-2 py-2 rounded-lg border-1 border-[#991b1b] bg-[#111827] min-w-32"

  defp metric_class(:done),
    do: "flex flex-col gap-1 px-2 py-2 rounded-lg border-1 border-[#166534] bg-[#111827] min-w-32"

  defp task_sort_key(task), do: {priority_rank(task.priority), task.id}

  defp priority_rank(:high), do: 0
  defp priority_rank(:medium), do: 1
  defp priority_rank(:low), do: 2

  defp blank?(value), do: String.trim(value) == ""

  defp noun(1, singular, _plural), do: singular
  defp noun(_count, _singular, plural), do: plural
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy kanban board example")
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
