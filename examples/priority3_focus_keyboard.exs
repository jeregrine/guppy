defmodule Guppy.Examples.Priority3FocusKeyboard.MainWindow do
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
       window_bounds: [width: 1180, height: 820],
       titlebar: [title: "Guppy Priority 3 keyboard/focus demo"],
       focus: true,
       show: true
     )
     |> assign(:note, "Focus me, then press Cmd-K: text-input shortcut wins.")
     |> assign(:events, [
       "Open: Tab through widgets; use arrows/Home/End; Enter/Space; Shift-F10."
     ])
     |> assign(:expanded, MapSet.new(["all", "platform"]))
     |> assign(:selected_tree_id, "platform")
     |> assign(:selected_uniform_id, "uniform_focus")
     |> assign(:selected_list_row_id, "list_shortcuts")
     |> assign(:table_column_ids, ["title", "status", "owner"])
     |> assign(:table_column_widths, %{"title" => 280, "status" => 132, "owner" => 112})
     |> assign(:selected_row_id, "menus")
     |> assign(:selected_cell, {"menus", "status"})
     |> assign(:sort, %{column_id: "title", direction: :asc})}
  end

  @impl Guppy.Window
  def render(window) do
    visible_tasks = visible_tasks(window.assigns.selected_tree_id)
    sorted_tasks = sort_tasks(visible_tasks, window.assigns.sort)
    selected_row_id = selected_row_id_for(sorted_tasks, window.assigns.selected_row_id)
    selected_cell = selected_cell_for(selected_row_id, window.assigns.selected_cell)
    command_bindings = command_bindings()

    assigns =
      Map.merge(window.assigns, %{
        command_actions: Keyword.fetch!(command_bindings, :actions),
        command_shortcuts: Keyword.fetch!(command_bindings, :shortcuts),
        input_actions: %{"local_note_ping" => "local_input_shortcut"},
        input_shortcuts: [{"cmd-k", "local_note_ping"}],
        uniform_items: uniform_items(window.assigns.selected_uniform_id),
        list_items: list_items(window.assigns.selected_list_row_id),
        tree_nodes: tree_nodes(window.assigns.expanded, window.assigns.selected_tree_id),
        table_columns:
          table_columns(window.assigns.table_column_ids, window.assigns.table_column_widths),
        table_rows: table_rows(sorted_tasks, selected_row_id, selected_cell),
        selected_row_id: selected_row_id,
        selected_cell: selected_cell,
        recent_events: Enum.with_index(window.assigns.events, 1),
        sort_label: "#{window.assigns.sort.column_id} #{window.assigns.sort.direction}",
        selected_cell_label: format_cell(selected_cell)
      })

    ~GUI"""
    <div id="priority3_root" class="w-full h-full bg-[#0f172a] text-[#f8fafc]" actions={@command_actions} shortcuts={@command_shortcuts}>
      <scroll id="priority3_scroll" axis="y" class="w-full h-full scrollbar-w-[10px]">
        <div id="priority3_content" class="flex flex-col gap-4 p-5">
          <div id="header" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
            <text id="title" class="text-3xl font-black">Priority 3: keyboard, focus, semantic widgets</text>
            <text id="subtitle" class="text-sm text-[#94a3b8] leading-snug">
              Focus scopes, roving focus, shortcut priority, data-table/tree keyboard behavior, focus-visible affordances, Elixir-owned selection state, and the current accessibility boundary.
            </text>
            <text id="instructions" class="text-sm text-[#bfdbfe]">
              Try Tab / Shift-Tab, arrows, Home/End, Enter/Space, Shift-F10, Cmd-K, Alt-Left/Alt-Right on table headers, and Shift-Left/Shift-Right on table headers.
            </text>
          </div>

          <div id="shortcut_panel" class="flex flex-row gap-4 p-4 rounded-xl border-1 border-[#7c3aed] bg-[#1e1b4b] shadow-md">
            <div id="shortcut_notes" class="flex flex-col gap-2 flex-1">
              <text class="text-lg font-bold text-[#ddd6fe]">Shortcut priority</text>
              <text class="text-sm text-[#c4b5fd] leading-snug">
                The window root has an app command on Cmd-K. The text input has its own Cmd-K shortcut. Focus the input and press Cmd-K: the focused text-input action stops propagation before the app-command root.
              </text>
            </div>
            <div id="shortcut_input_box" class="flex flex-col gap-2 w-[520px]">
              <text class="text-sm font-bold text-[#ddd6fe]">Local text-input shortcut target</text>
              <text_input
                id="priority_note"
                value={@note}
                placeholder="Type here"
                class="p-3 rounded-lg border-1 border-[#a78bfa] bg-[#0b1220] text-[#f8fafc]"
                actions={@input_actions}
                shortcuts={@input_shortcuts}
                change="note_changed"
                focus="input_focused"
                blur="input_blurred"
                context_menu="input_context"
              />
            </div>
          </div>

          <div id="virtual_panel" class="flex flex-col gap-3 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
            <div class="flex flex-col gap-1">
              <text class="text-lg font-bold">Virtual list roving focus</text>
              <text class="text-sm text-[#94a3b8] leading-snug">
                uniform_list and list rows with click/context_menu callbacks are tab stops. Up/Down/Home/End rove focus; Enter/Space activate; Shift-F10 emits context_menu. Keyboard-focused retained rows/items draw native focus-visible borders.
              </text>
            </div>
            <div id="list_columns" class="flex flex-row gap-4">
              <div class="flex flex-col gap-2 flex-1">
                <text class="text-sm font-bold text-[#bfdbfe]">uniform_list</text>
                <uniform_list
                  id="priority_uniform"
                  items={@uniform_items}
                  class="h-[150px] rounded-lg border-1 border-[#1e293b] bg-[#0b1220]"
                  item_class="p-2 border-b-1 border-[#1e293b]"
                  click="uniform_clicked"
                  context_menu="uniform_context"
                />
              </div>
              <div class="flex flex-col gap-2 flex-1">
                <text class="text-sm font-bold text-[#bfdbfe]">generic list</text>
                <list
                  id="priority_list"
                  items={@list_items}
                  class="h-[150px] rounded-lg border-1 border-[#1e293b] bg-[#0b1220]"
                  item_class="p-2 border-b-1 border-[#1e293b]"
                  click="list_clicked"
                  context_menu="list_context"
                />
              </div>
            </div>
          </div>

          <div id="tree_table_panel" class="flex flex-col gap-3 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
            <div class="flex flex-row gap-3">
              <text class="text-sm text-[#bfdbfe]">Tree: {@selected_tree_id}</text>
              <text class="text-sm text-[#bfdbfe]">Sort: {@sort_label}</text>
              <text class="text-sm text-[#bfdbfe]">Cell: {@selected_cell_label}</text>
            </div>
            <div class="flex flex-row gap-4">
              <div id="tree_panel" class="flex flex-col gap-2 w-[300px]">
                <text class="text-lg font-bold">Tree</text>
                <text class="text-xs text-[#94a3b8] leading-snug">Rows support Up/Down/Home/End, Left/Right parent-child focus, selection, disclosure, and context menus.</text>
                <tree
                  id="priority_tree"
                  nodes={@tree_nodes}
                  selected_id={@selected_tree_id}
                  class="h-[260px] rounded-lg border-1 border-[#1e293b] bg-[#0b1220]"
                  row_class="border-b-1 border-[#1e293b]"
                  select="tree_selected"
                  toggle="tree_toggled"
                  context_menu="tree_context"
                />
              </div>

              <div id="table_panel" class="flex flex-col gap-2 flex-1">
                <text class="text-lg font-bold">Data table</text>
                <text class="text-xs text-[#94a3b8] leading-snug">
                  Pinned title column renders first. Headers sort with Enter/Space, reorder with Alt-Left/Alt-Right or pointer Alt-drag, resize with Shift-Left/Shift-Right or pointer drag, and move focus with arrows/Home/End. Rows/cells own selection styles in Elixir.
                </text>
                <data_table
                  id="priority_table"
                  columns={@table_columns}
                  rows={@table_rows}
                  selected_row_id={@selected_row_id}
                  selected_cell={@selected_cell}
                  sort_state={@sort}
                  class="h-[260px] rounded-lg border-1 border-[#1e293b] bg-[#0b1220]"
                  header_class="border-b-1 border-[#334155] bg-[#172554] text-[#bfdbfe] font-bold"
                  row_class="border-b-1 border-[#1e293b]"
                  cell_class="text-sm"
                  row_click="table_row_selected"
                  cell_click="table_cell_selected"
                  sort="table_sorted"
                  column_reorder="table_column_reordered"
                  column_resize="table_column_resized"
                  row_context_menu="table_row_context"
                  cell_context_menu="table_cell_context"
                />
              </div>
            </div>
          </div>

          <div id="accessibility_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#475569] bg-[#111827] shadow-md">
            <text class="text-lg font-bold">Accessibility/semantics boundary</text>
            <text class="text-sm text-[#cbd5e1] leading-snug">
              GPUI 0.2.2 does not expose public element-level role/label/state APIs, so Guppy intentionally rejects placeholder role/aria fields. The example uses truthful semantics instead: stable ids, labels, selected/sort/expanded state, focus handles, and typed event payloads owned by Elixir.
            </text>
          </div>

          <div id="event_log" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
            <text class="text-lg font-bold">Recent semantic events</text>
            <div id="event_rows" class="grid grid-cols-2 gap-2">
              <div :for={{event, index} <- @recent_events} id={"event_#{index}"} class="p-2 rounded-md bg-[#0b1220]">
                <text class="text-xs text-[#e2e8f0]">{event}</text>
              </div>
            </div>
          </div>
        </div>
      </scroll>
    </div>
    """
  end

  @impl Guppy.Window
  def handle_event("note_changed", %{value: value}, window) do
    {:noreply, assign(window, :note, value)}
  end

  def handle_event("input_focused", _event, window),
    do: {:noreply, log(window, "text_input focused")}

  def handle_event("input_blurred", _event, window),
    do: {:noreply, log(window, "text_input blurred")}

  def handle_event("input_context", event, window) do
    {:noreply, log(window, "text_input context #{event_position(event)}")}
  end

  def handle_event("local_input_shortcut", %{shortcut: shortcut}, window) do
    {:noreply, log(window, "local text_input shortcut won over app command: #{shortcut}")}
  end

  def handle_event("local_root_shortcut", %{shortcut: shortcut}, window) do
    {:noreply, log(window, "standalone root shortcut: #{shortcut}")}
  end

  def handle_event("uniform_clicked", %{id: node_id}, window) do
    item_id = last_node_segment(node_id)

    {:noreply,
     window
     |> assign(:selected_uniform_id, item_id)
     |> log("uniform_list click #{item_id}")}
  end

  def handle_event("uniform_context", %{id: node_id} = event, window) do
    {:noreply,
     log(window, "uniform_list context #{last_node_segment(node_id)} #{event_position(event)}")}
  end

  def handle_event("list_clicked", %{id: node_id}, window) do
    row_id = last_node_segment(node_id)

    {:noreply,
     window
     |> assign(:selected_list_row_id, row_id)
     |> log("list row click #{row_id}")}
  end

  def handle_event("list_context", %{id: node_id} = event, window) do
    {:noreply,
     log(window, "list row context #{last_node_segment(node_id)} #{event_position(event)}")}
  end

  def handle_event("tree_selected", %{item_id: item_id}, window) do
    tasks = item_id |> visible_tasks() |> sort_tasks(window.assigns.sort)
    selected_row_id = selected_row_id_for(tasks, window.assigns.selected_row_id)
    selected_cell = selected_cell_for(selected_row_id, window.assigns.selected_cell)

    {:noreply,
     window
     |> assign(:selected_tree_id, item_id)
     |> assign(:selected_row_id, selected_row_id)
     |> assign(:selected_cell, selected_cell)
     |> log("tree select #{item_id}")}
  end

  def handle_event("tree_toggled", %{item_id: item_id}, window) do
    expanded = toggle_set(window.assigns.expanded, item_id)

    {:noreply,
     window
     |> assign(:expanded, expanded)
     |> log("tree toggle #{item_id}")}
  end

  def handle_event("tree_context", %{item_id: item_id} = event, window) do
    {:noreply, log(window, "tree context #{item_id} #{event_position(event)}")}
  end

  def handle_event("table_row_selected", %{row_id: row_id}, window) do
    {:noreply,
     window
     |> assign(:selected_row_id, row_id)
     |> log("table row select #{row_id}")}
  end

  def handle_event("table_cell_selected", %{row_id: row_id, column_id: column_id}, window) do
    {:noreply,
     window
     |> assign(:selected_row_id, row_id)
     |> assign(:selected_cell, {row_id, column_id})
     |> log("table cell select #{row_id}/#{column_id}")}
  end

  def handle_event("table_sorted", %{column_id: column_id}, window) do
    current = window.assigns.sort

    direction =
      if current.column_id == column_id and current.direction == :asc do
        :desc
      else
        :asc
      end

    {:noreply,
     window
     |> assign(:sort, %{column_id: column_id, direction: direction})
     |> log("table sort #{column_id} #{direction}")}
  end

  def handle_event(
        "table_column_reordered",
        %{column_id: column_id, target_column_id: target_column_id, direction: direction},
        window
      ) do
    next_ids =
      reorder_column_ids(window.assigns.table_column_ids, column_id, target_column_id, direction)

    {:noreply,
     window
     |> assign(:table_column_ids, next_ids)
     |> log("table reorder #{column_id} #{direction} of #{target_column_id}")}
  end

  def handle_event(
        "table_column_resized",
        %{column_id: column_id, width_delta: width_delta},
        window
      ) do
    next_widths = resize_column_widths(window.assigns.table_column_widths, column_id, width_delta)

    {:noreply,
     window
     |> assign(:table_column_widths, next_widths)
     |> log("table resize #{column_id} #{signed(width_delta)}px")}
  end

  def handle_event("table_row_context", %{row_id: row_id} = event, window) do
    {:noreply, log(window, "table row context #{row_id} #{event_position(event)}")}
  end

  def handle_event("table_cell_context", %{row_id: row_id, column_id: column_id} = event, window) do
    {:noreply, log(window, "table cell context #{row_id}/#{column_id} #{event_position(event)}")}
  end

  def handle_info({:priority3_app_command, "global_ping", %{shortcut: shortcut}}, window) do
    {:noreply, log(window, "app command from root shortcut: #{shortcut}")}
  end

  defp command_bindings do
    case Guppy.App.current_app() do
      nil ->
        [
          actions: %{"global_ping" => "local_root_shortcut"},
          shortcuts: [{"cmd-k", "global_ping"}]
        ]

      app ->
        Guppy.App.command_bindings(app)
    end
  end

  defp uniform_items(selected_id) do
    [
      uniform_item("uniform_focus", "Focus scopes", selected_id),
      uniform_item("uniform_roving", "Roving Up/Down/Home/End", selected_id),
      uniform_item("uniform_context", "Shift-F10 context menu", selected_id),
      uniform_item("uniform_visible", "Native focus-visible border", selected_id)
    ]
  end

  defp uniform_item(id, label, selected_id) do
    prefix = if id == selected_id, do: "✓ ", else: "  "
    %{id: id, label: prefix <> label}
  end

  defp list_items(selected_id) do
    [
      list_row(
        "list_shortcuts",
        "Shortcut bubbling",
        "Focused child shortcuts beat root app commands.",
        selected_id
      ),
      list_row(
        "list_context",
        "Keyboard context menus",
        "Shift-F10 emits context_menu from the focused row.",
        selected_id
      ),
      list_row(
        "list_focus",
        "Retained focus handles",
        "Virtual rows keep stable keyboard targets across rerenders.",
        selected_id
      )
    ]
  end

  defp list_row(id, title, detail, selected_id) do
    selected? = id == selected_id

    %{
      id: id,
      children: [
        Guppy.IR.div(
          [
            Guppy.IR.text(title, style: [:font_bold]),
            Guppy.IR.text(detail,
              style: [:text_xs, {:text_color_hex, if(selected?, do: "#dbeafe", else: "#94a3b8")}]
            )
          ],
          id: "#{id}_content",
          style: row_style(selected?) ++ [:flex, :flex_col, :gap_1]
        )
      ]
    }
  end

  defp tree_nodes(expanded, selected_id) do
    [
      %{
        id: "all",
        label: "All tasks",
        expanded: MapSet.member?(expanded, "all"),
        style: selected_style(selected_id == "all"),
        children: [
          %{
            id: "platform",
            label: "Platform",
            expanded: MapSet.member?(expanded, "platform"),
            style: selected_style(selected_id == "platform"),
            children: [
              %{
                id: "task_auth",
                label: "Auth refresh",
                style: selected_style(selected_id == "task_auth")
              },
              %{
                id: "task_menus",
                label: "App menus",
                style: selected_style(selected_id == "task_menus")
              }
            ]
          },
          %{
            id: "design",
            label: "Design",
            expanded: MapSet.member?(expanded, "design"),
            style: selected_style(selected_id == "design"),
            children: [
              %{
                id: "task_gallery",
                label: "Style gallery",
                style: selected_style(selected_id == "task_gallery")
              }
            ]
          },
          %{
            id: "release",
            label: "Release",
            expanded: MapSet.member?(expanded, "release"),
            style: selected_style(selected_id == "release"),
            children: [
              %{
                id: "task_qa",
                label: "Release QA",
                style: selected_style(selected_id == "task_qa")
              }
            ]
          }
        ]
      }
    ]
  end

  defp table_columns(column_ids, column_widths) do
    definitions = %{
      "title" => %{id: "title", label: "Task", sortable: true, pinned: true},
      "status" => %{id: "status", label: "Status", sortable: true},
      "owner" => %{id: "owner", label: "Owner", sortable: true}
    }

    Enum.map(column_ids, fn column_id ->
      Map.put(
        Map.fetch!(definitions, column_id),
        :width,
        {:px, Map.fetch!(column_widths, column_id)}
      )
    end)
  end

  defp selected_row_id_for([], _selected_row_id), do: nil

  defp selected_row_id_for(tasks, selected_row_id) do
    task_ids = MapSet.new(tasks, & &1.id)

    if MapSet.member?(task_ids, selected_row_id) do
      selected_row_id
    else
      tasks |> List.first() |> Map.fetch!(:id)
    end
  end

  defp selected_cell_for(nil, _selected_cell), do: nil

  defp selected_cell_for(selected_row_id, {row_id, column_id})
       when row_id == selected_row_id and column_id in ["title", "status", "owner"] do
    {row_id, column_id}
  end

  defp selected_cell_for(selected_row_id, _selected_cell), do: {selected_row_id, "status"}

  defp table_rows(tasks, selected_row_id, selected_cell) do
    Enum.map(tasks, fn task ->
      %{
        id: task.id,
        style: row_style(task.id == selected_row_id),
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

  defp visible_tasks("all"), do: @tasks

  defp visible_tasks(project) when project in ["platform", "design", "release"],
    do: Enum.filter(@tasks, &(&1.project == project))

  defp visible_tasks("task_" <> task_id), do: Enum.filter(@tasks, &(&1.id == task_id))
  defp visible_tasks(task_id), do: Enum.filter(@tasks, &(&1.id == task_id))

  defp sort_tasks(tasks, %{column_id: column_id, direction: direction}) do
    sorted = Enum.sort_by(tasks, &task_sort_value(&1, column_id))
    if direction == :desc, do: Enum.reverse(sorted), else: sorted
  end

  defp task_sort_value(task, "title"), do: task.title
  defp task_sort_value(task, "status"), do: task.status
  defp task_sort_value(task, "owner"), do: task.owner
  defp task_sort_value(task, _unknown_column), do: task.title

  defp reorder_column_ids(column_ids, column_id, target_column_id, direction) do
    without_column = List.delete(column_ids, column_id)

    target_index =
      Enum.find_index(without_column, &(&1 == target_column_id)) || length(without_column)

    insert_at = if direction == "right", do: target_index + 1, else: target_index

    List.insert_at(without_column, insert_at, column_id)
  end

  defp resize_column_widths(column_widths, column_id, width_delta) do
    Map.update!(column_widths, column_id, fn width -> max(width + width_delta, 72) end)
  end

  defp toggle_set(set, value) do
    if MapSet.member?(set, value), do: MapSet.delete(set, value), else: MapSet.put(set, value)
  end

  defp row_style(true),
    do: [Guppy.Style.bg_hex("#172554"), Guppy.Style.border_color_hex("#2563eb")]

  defp row_style(false), do: []

  defp selected_style(true),
    do: [Guppy.Style.bg_hex("#1d4ed8"), Guppy.Style.text_color_hex("#eff6ff")]

  defp selected_style(false), do: []

  defp selected_cell_style(true),
    do: [Guppy.Style.bg_hex("#1d4ed8"), Guppy.Style.text_color_hex("#eff6ff")]

  defp selected_cell_style(false), do: []

  defp log(window, message) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second) |> Calendar.strftime("%H:%M:%S")
    assign(window, :events, ["#{timestamp} #{message}" | window.assigns.events] |> Enum.take(6))
  end

  defp last_node_segment(node_id), do: node_id |> String.split(".") |> List.last()
  defp format_cell({row_id, column_id}), do: "#{row_id}/#{column_id}"
  defp format_cell(_), do: "none"
  defp signed(delta) when delta > 0, do: "+#{delta}"
  defp signed(delta), do: Integer.to_string(delta)

  defp event_position(%{x: x, y: y}), do: "at #{round(x)},#{round(y)}"
  defp event_position(_event), do: "from keyboard"
end

defmodule Guppy.Examples.Priority3FocusKeyboard do
  use Guppy.App,
    windows: [
      %{id: "main", module: Guppy.Examples.Priority3FocusKeyboard.MainWindow, start: false}
    ],
    commands: [
      %{id: "global_ping", label: "Priority 3 root shortcut ping"}
    ],
    keymap: [
      %{key: "cmd-k", command: "global_ping"}
    ],
    package: %{bundle_id: "dev.guppy.examples.priority3_focus_keyboard"},
    exit_on_last_window_closed: true

  @impl Guppy.App
  def handle_command("global_ping", payload, state) do
    if pid = command_target(payload, state) do
      send(pid, {:priority3_app_command, "global_ping", payload})
    end

    {:noreply, state}
  end

  defp command_target(%{window_id: window_id}, state) when is_binary(window_id) do
    case Map.get(state.windows, window_id) do
      %{pid: pid} when is_pid(pid) -> pid
      _ -> nil
    end
  end

  defp command_target(_payload, _state), do: nil
end

if "--validate-only" in System.argv() do
  window_module = Guppy.Examples.Priority3FocusKeyboard.MainWindow
  {:ok, window} = window_module.mount(:ok, %Guppy.Window{})
  :ok = Guppy.IR.validate(window_module.render(window))

  for item_id <- ["task_auth", "task_menus", "task_gallery", "task_qa", "platform", "all"] do
    {:noreply, window} = window_module.handle_event("tree_selected", %{item_id: item_id}, window)
    :ok = Guppy.IR.validate(window_module.render(window))
  end

  IO.puts("priority3_focus_keyboard.exs IR validates")
else
  {:ok, _} = Application.ensure_all_started(:guppy)

  IO.puts("Guppy Priority 3 keyboard/focus example")

  IO.puts(
    "Try Tab/Shift-Tab, arrows, Home/End, Enter/Space, Shift-F10, Cmd-K, Alt-Left/Right, and Shift-Left/Right."
  )

  IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
  IO.inspect(Guppy.native_build_info(), label: "native_build_info")
  IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
  IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

  {:ok, app_pid} = Guppy.Examples.Priority3FocusKeyboard.start_link([])

  {:ok, _main_window} =
    Guppy.App.open_window(Guppy.Examples.Priority3FocusKeyboard, "main", [], 30_000)

  app_ref = Process.monitor(app_pid)

  receive do
    {:DOWN, ^app_ref, :process, ^app_pid, _reason} -> :ok
  end
end
