Code.require_file("support/table_tree_shared.exs", __DIR__)

defmodule Guppy.SuperDemo do
  use Guppy.Component

  alias Examples.TableTreeShared

  @palette [:gray, :red, :green, :blue, :yellow]
  @surface_base "#09111f"
  @surface_panel "#0f172a"
  @surface_panel_alt "#111827"
  @surface_muted "#1e293b"
  @border_subtle "#334155"
  @text_primary "#f8fafc"
  @text_secondary "#cbd5e1"
  @text_muted "#94a3b8"
  @focus_ring "#facc15"
  @timer_ticks 5
  @timer_interval_ms 1_000
  @asset_icon_path "/tmp/guppy_super_demo_feature.svg"
  @demo_ids [
    :runtime,
    :components,
    :interactions,
    :collections,
    :windows,
    :native_shell,
    :styles,
    :layout,
    :scroll,
    :help
  ]
  @demo_id_by_name Map.new(@demo_ids, fn demo_id -> {Atom.to_string(demo_id), demo_id} end)
  @palette_index_by_name %{
    "gray" => 0,
    "red" => 1,
    "green" => 2,
    "blue" => 3,
    "yellow" => 4
  }

  prop(:feature_card, :id, :string, required: true)
  prop(:feature_card, :title, :string, required: true)
  prop(:feature_card, :badge, :string, required: true)
  prop(:feature_card, :body, :string, required: true)
  prop(:feature_card, :class, :string, required: true)
  prop(:feature_card, :animation, :any, default: nil)

  def run do
    {:ok, _} = Application.ensure_all_started(:guppy)
    ensure_demo_assets!()

    initial_state =
      %{
        main_view_id: nil,
        aux_view_id: nil,
        child_owner_pid: nil,
        child_monitor_ref: nil,
        child_view_id: nil,
        selected_demo: :runtime,
        div_clicks: 0,
        text_clicks: 0,
        text_input_value: "Type here",
        text_input_changes: 0,
        textarea_value: "Line one\nLine two",
        textarea_changes: 0,
        notifications_enabled: true,
        checkbox_changes: 0,
        selected_priority: "medium",
        radio_changes: 0,
        selected_status: "todo",
        status_select_open: false,
        select_changes: 0,
        popover_open: false,
        table_expanded: MapSet.new(["all", "platform"]),
        table_selected_tree_id: "platform",
        table_column_ids: ["title", "status", "owner"],
        table_column_widths: %{"title" => 260, "status" => 120, "owner" => 100},
        table_selected_row_id: "menus",
        table_selected_cell: {"menus", "status"},
        table_sort: %{column_id: "title", direction: :asc},
        row_control_tasks: row_control_seed(),
        row_control_last_event: "Click a row control to see row-aware payloads.",
        canvas_state: :open,
        shell_badge_count: 0,
        shell_status: "Install menus, try file dialogs, or use clipboard helpers.",
        shell_events: ["Native shell controls ready"],
        mouse_downs: 0,
        mouse_ups: 0,
        mouse_moves: 0,
        scroll_wheels: 0,
        pointer_status: "none yet",
        focus_events: 0,
        blur_events: 0,
        key_downs: 0,
        key_ups: 0,
        context_menus: 0,
        context_menu_open: false,
        action_events: 0,
        drag_starts: 0,
        drag_moves: 0,
        drops: 0,
        drag_status: "none yet",
        underlay_clicks: 0,
        overlay_clicks: 0,
        stack_status: "none yet",
        keyboard_status: "none yet",
        scroll_anchor_index: 1,
        timer_ticks: 0,
        timer_remaining: 0,
        timer_running: false,
        palette_index: 0,
        last_event: "booted",
        statuses: capture_statuses()
      }

    {:ok, main_view_id} =
      Guppy.open_window(
        render(initial_state),
        window_bounds: [width: 1320, height: 920],
        window_min_size: [width: 1120, height: 760],
        titlebar: [title: "Guppy super demo"]
      )

    state = %{initial_state | main_view_id: main_view_id}
    :ok = Guppy.render(main_view_id, render(state))
    loop(state)
  end

  defp loop({:stop, state}) do
    cleanup(state)
    :ok
  end

  defp loop(state) do
    receive do
      {:guppy_event, view_id, %{type: type} = event} when type in [:click, :close] ->
        state
        |> handle_click(view_id, event)
        |> continue()

      {:guppy_event, view_id, %{type: :hover} = event} ->
        state
        |> handle_hover(view_id, event)
        |> continue()

      {:guppy_event, view_id, %{type: :change} = event} ->
        state
        |> handle_change(view_id, event)
        |> continue()

      {:guppy_event, view_id, %{type: type} = event}
      when type in [:mouse_down, :mouse_up, :mouse_move, :scroll_wheel] ->
        state
        |> handle_pointer_event(view_id, event)
        |> continue()

      {:guppy_event, view_id, %{type: type} = event}
      when type in [:focus, :blur, :key_down, :key_up, :context_menu, :action] ->
        state
        |> handle_keyboard_event(view_id, event)
        |> continue()

      {:guppy_event, view_id, %{type: type} = event}
      when type in [:drag_start, :drag_move, :drop] ->
        state
        |> handle_drag_event(view_id, event)
        |> continue()

      {:guppy_event, view_id, %{type: :window_close_requested}} ->
        state
        |> handle_window_close_requested(view_id)
        |> continue()

      {:guppy_event, view_id, %{type: :window_closed}} ->
        state
        |> handle_window_closed(view_id)
        |> continue()

      {:child_owner_ready, pid, view_id} ->
        ref = Process.monitor(pid)

        state
        |> Map.put(:child_owner_pid, pid)
        |> Map.put(:child_monitor_ref, ref)
        |> Map.put(:child_view_id, view_id)
        |> Map.put(:last_event, "child owner window opened (view #{view_id})")
        |> refresh_statuses()
        |> rerender!()
        |> loop()

      {:child_owner_closed, pid, reason} ->
        state
        |> maybe_clear_child(pid)
        |> Map.put(:last_event, "child owner window closed (#{inspect(reason)})")
        |> refresh_statuses()
        |> rerender!()
        |> loop()

      {:guppy_menu_event, event} ->
        callback = Map.get(event, :callback, Map.get(event, :id, "unknown"))

        case callback do
          "badge_increment" ->
            update_badge(state, state.shell_badge_count + 1)

          "badge_clear" ->
            clear_badge(state)

          "write_clipboard" ->
            write_clipboard(state)

          _ ->
            state
            |> log_shell_event("Menu callback #{inspect(event)}")
            |> Map.put(:last_event, "menu callback #{callback}")
            |> rerender!()
        end
        |> loop()

      {:DOWN, ref, :process, pid, reason} ->
        if ref == state.child_monitor_ref do
          Process.send_after(self(), :refresh_statuses, 50)

          state
          |> maybe_clear_child(pid)
          |> Map.put(:last_event, "child owner exited (#{inspect(reason)})")
          |> rerender!()
          |> loop()
        else
          loop(state)
        end

      :refresh_statuses ->
        state
        |> refresh_statuses()
        |> rerender!()
        |> loop()

      :timer_tick ->
        state
        |> handle_timer_tick()
        |> continue()

      other ->
        state
        |> Map.put(:last_event, "unexpected message: #{inspect(other)}")
        |> rerender!()
        |> loop()
    end
  end

  defp continue({:stop, state}) do
    cleanup(state)
    :ok
  end

  defp continue(state), do: loop(state)

  defp handle_click(state, view_id, %{id: node_id, callback: callback_id} = event) do
    cond do
      view_id == state.main_view_id ->
        handle_main_click(state, node_id, callback_id, event)

      view_id == state.aux_view_id ->
        handle_aux_click(state, node_id, callback_id)

      true ->
        state
        |> Map.put(:last_event, "click from unknown view #{view_id}: #{node_id}/#{callback_id}")
        |> rerender!()
    end
  end

  defp handle_window_close_requested(state, view_id) when view_id == state.main_view_id do
    Map.put(state, :last_event, "main window close requested")
  end

  defp handle_window_close_requested(state, view_id) when view_id == state.aux_view_id do
    Map.put(state, :last_event, "auxiliary window close requested")
  end

  defp handle_window_close_requested(state, view_id) do
    Map.put(state, :last_event, "window #{view_id} close requested")
  end

  defp handle_window_closed(state, view_id) when view_id == state.main_view_id do
    {:stop, Map.put(state, :last_event, "main window closed manually")}
  end

  defp handle_window_closed(state, view_id) when view_id == state.aux_view_id do
    state
    |> Map.put(:aux_view_id, nil)
    |> Map.put(:last_event, "auxiliary window closed manually")
    |> refresh_statuses()
    |> rerender!()
  end

  defp handle_window_closed(state, view_id) do
    state
    |> Map.put(:last_event, "window #{view_id} closed")
    |> rerender!()
  end

  defp handle_hover(state, view_id, %{id: node_id, callback: callback_id, hovered: hovered}) do
    cond do
      view_id == state.main_view_id ->
        state
        |> Map.put(
          :last_event,
          "hover #{if hovered, do: "enter", else: "leave"} #{node_id}/#{callback_id}"
        )
        |> rerender!()

      view_id == state.aux_view_id ->
        state
        |> Map.put(
          :last_event,
          "aux hover #{if hovered, do: "enter", else: "leave"} #{node_id}/#{callback_id}"
        )
        |> rerender!()

      true ->
        state
        |> Map.put(:last_event, "hover from unknown view #{view_id}: #{node_id}/#{callback_id}")
        |> rerender!()
    end
  end

  defp handle_change(state, view_id, %{id: node_id, callback: callback_id} = event) do
    cond do
      view_id == state.main_view_id ->
        handle_main_change(state, node_id, callback_id, event)

      view_id == state.aux_view_id ->
        state
        |> Map.put(:last_event, "aux change #{node_id}/#{callback_id}")
        |> rerender!()

      true ->
        state
        |> Map.put(:last_event, "change from unknown view #{view_id}: #{node_id}/#{callback_id}")
        |> rerender!()
    end
  end

  defp handle_main_change(state, node_id, callback_id, event)
       when node_id in ["priority_low", "priority_medium", "priority_high"] do
    state
    |> Map.put(:selected_priority, Map.get(event, :value, ""))
    |> Map.update!(:radio_changes, &(&1 + 1))
    |> Map.put(:last_event, "change #{node_id}/#{callback_id}")
    |> rerender!()
  end

  defp handle_main_change(state, "notifications_checkbox" = node_id, callback_id, event) do
    checked = Map.get(event, :checked, false)

    state
    |> Map.put(:notifications_enabled, checked)
    |> Map.update!(:checkbox_changes, &(&1 + 1))
    |> Map.put(:last_event, "checkbox #{node_id}/#{callback_id} = #{checked}")
    |> rerender!()
  end

  defp handle_main_change(state, "demo_textarea" = node_id, callback_id, event) do
    state
    |> Map.put(:textarea_value, Map.get(event, :value, ""))
    |> Map.update!(:textarea_changes, &(&1 + 1))
    |> Map.put(:last_event, "change #{node_id}/#{callback_id}")
    |> rerender!()
  end

  defp handle_main_change(state, "status_select" <> _suffix = node_id, callback_id, event) do
    state
    |> Map.put(:selected_status, Map.get(event, :value, ""))
    |> Map.put(:status_select_open, false)
    |> Map.update!(:select_changes, &(&1 + 1))
    |> Map.put(:last_event, "select change #{node_id}/#{callback_id}")
    |> rerender!()
  end

  defp handle_main_change(state, node_id, "row_done_changed", event) do
    row_id = Map.get(event, :row_id, "")
    checked = Map.get(event, :checked, false)

    state
    |> update_row_control_task(row_id, &%{&1 | done: checked})
    |> Map.put(:row_control_last_event, "done = #{checked} from #{row_id}/#{node_id}")
    |> Map.put(:last_event, "row checkbox #{row_id}/#{node_id}")
    |> rerender!()
  end

  defp handle_main_change(state, node_id, "row_priority_changed", event) do
    row_id = Map.get(event, :row_id, "")
    value = Map.get(event, :value, "")

    state
    |> update_row_control_task(row_id, &%{&1 | priority: value})
    |> Map.put(:row_control_last_event, "priority = #{value} from #{row_id}/#{node_id}")
    |> Map.put(:last_event, "row radio #{row_id}/#{node_id}")
    |> rerender!()
  end

  defp handle_main_change(state, node_id, callback_id, %{value: value}) do
    state
    |> Map.put(:text_input_value, value)
    |> Map.update!(:text_input_changes, &(&1 + 1))
    |> Map.put(:last_event, "change #{node_id}/#{callback_id}")
    |> rerender!()
  end

  defp handle_main_change(state, node_id, callback_id, event) do
    state
    |> Map.put(
      :last_event,
      "change #{node_id}/#{callback_id}: #{inspect(Map.drop(event, [:type, :id, :callback]))}"
    )
    |> rerender!()
  end

  defp handle_pointer_event(state, view_id, event) do
    {type, node_id, callback_id} = event_fields(event)

    cond do
      view_id == state.main_view_id ->
        state
        |> update_pointer_counters(type)
        |> Map.put(:pointer_status, format_pointer_event(type, event))
        |> Map.put(:last_event, "#{type} #{node_id}/#{callback_id}")
        |> rerender!()

      view_id == state.aux_view_id ->
        state
        |> Map.put(:last_event, "aux #{type} #{node_id}/#{callback_id}")
        |> rerender!()

      true ->
        state
        |> Map.put(:last_event, "#{type} from unknown view #{view_id}: #{node_id}/#{callback_id}")
        |> rerender!()
    end
  end

  defp handle_keyboard_event(state, view_id, event) do
    {type, node_id, callback_id} = event_fields(event)

    cond do
      view_id == state.main_view_id ->
        state
        |> update_keyboard_counters(type)
        |> maybe_open_context_menu(type)
        |> Map.put(:keyboard_status, format_keyboard_event(type, event))
        |> Map.put(:last_event, "#{type} #{node_id}/#{callback_id}")
        |> rerender!()

      view_id == state.aux_view_id ->
        state
        |> Map.put(:last_event, "aux #{type} #{node_id}/#{callback_id}")
        |> rerender!()

      true ->
        state
        |> Map.put(:last_event, "#{type} from unknown view #{view_id}: #{node_id}/#{callback_id}")
        |> rerender!()
    end
  end

  defp handle_drag_event(state, view_id, event) do
    {type, node_id, callback_id} = event_fields(event)

    cond do
      view_id == state.main_view_id ->
        state
        |> update_drag_counters(type)
        |> Map.put(:drag_status, format_drag_event(type, event))
        |> Map.put(:last_event, "#{type} #{node_id}/#{callback_id}")
        |> rerender!()

      view_id == state.aux_view_id ->
        state
        |> Map.put(:last_event, "aux #{type} #{node_id}/#{callback_id}")
        |> rerender!()

      true ->
        state
        |> Map.put(:last_event, "#{type} from unknown view #{view_id}: #{node_id}/#{callback_id}")
        |> rerender!()
    end
  end

  defp event_fields(%{type: type, id: node_id, callback: callback_id}),
    do: {type, node_id, callback_id}

  defp handle_main_click(state, node_id, "select_demo:" <> demo_name, _event) do
    case Map.fetch(@demo_id_by_name, demo_name) do
      {:ok, demo_id} ->
        state
        |> Map.put(:selected_demo, demo_id)
        |> Map.put(:last_event, "selected #{demo_id} from #{node_id}")
        |> rerender!()

      :error ->
        handle_main_action(state, node_id, "select_demo:" <> demo_name)
    end
  end

  defp handle_main_click(state, node_id, callback_id, event) do
    handle_main_action(state, node_id, callback_id, event)
  end

  defp handle_main_action(state, node_id, callback_id, event \\ %{})

  defp handle_main_action(state, node_id, "refresh_status", _event) do
    state
    |> Map.put(:last_event, "refreshed status from #{node_id}")
    |> refresh_statuses()
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "toggle_palette", _event) do
    state
    |> Map.update!(:palette_index, &rem(&1 + 1, length(@palette)))
    |> Map.put(:last_event, "toggled palette from #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "select_palette:" <> color_name, _event) do
    case Map.fetch(@palette_index_by_name, color_name) do
      {:ok, palette_index} ->
        state
        |> Map.put(:palette_index, palette_index)
        |> Map.put(:last_event, "selected #{color_name} palette from #{node_id}")
        |> rerender!()

      :error ->
        state
        |> Map.put(:last_event, "unknown palette #{color_name} from #{node_id}")
        |> rerender!()
    end
  end

  defp handle_main_action(state, node_id, "div_increment", _event) do
    state
    |> Map.update!(:div_clicks, &(&1 + 1))
    |> Map.put(:last_event, "div click via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "text_increment", _event) do
    state
    |> Map.update!(:text_clicks, &(&1 + 1))
    |> Map.put(:last_event, "text click via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "uniform_item_clicked", _event) do
    state
    |> Map.put(:last_event, "uniform list click via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "generic_item_clicked", _event) do
    state
    |> Map.put(:last_event, "generic list click via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "open_popover", _event) do
    state
    |> Map.put(:popover_open, true)
    |> Map.put(:last_event, "opened popover via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "close_popover", _event) do
    state
    |> Map.put(:popover_open, false)
    |> Map.put(:last_event, "closed popover via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "toggle_status_select", _event) do
    state
    |> Map.update!(:status_select_open, &(!&1))
    |> Map.put(:last_event, "toggled select via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "close_status_select", _event) do
    state
    |> Map.put(:status_select_open, false)
    |> Map.put(:last_event, "closed select via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "underlay_click", _event) do
    state
    |> Map.update!(:underlay_clicks, &(&1 + 1))
    |> Map.put(:stack_status, "underlay clicked via #{node_id}")
    |> Map.put(:last_event, "underlay click via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "overlay_click", _event) do
    state
    |> Map.update!(:overlay_clicks, &(&1 + 1))
    |> Map.put(:stack_status, "overlay clicked via #{node_id}")
    |> Map.put(:last_event, "overlay click via #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "scroll_anchor_prev", _event) do
    state
    |> Map.update!(:scroll_anchor_index, &max(&1 - 1, 1))
    |> Map.put(:last_event, "moved scroll anchor up from #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "scroll_anchor_next", _event) do
    state
    |> Map.update!(:scroll_anchor_index, &min(&1 + 1, 24))
    |> Map.put(:last_event, "moved scroll anchor down from #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, _node_id, "start_timer", _event) do
    if state.timer_running do
      state
      |> Map.put(:last_event, "timer already running")
      |> rerender!()
    else
      Process.send_after(self(), :timer_tick, @timer_interval_ms)

      state
      |> Map.put(:timer_running, true)
      |> Map.put(:timer_remaining, @timer_ticks)
      |> Map.put(:last_event, "started timer updates")
      |> rerender!()
    end
  end

  defp handle_main_action(state, _node_id, "collection_tree_select", event) do
    item_id = Map.get(event, :item_id, "all")

    state
    |> Map.put(:table_selected_tree_id, item_id)
    |> sync_table_selection()
    |> Map.put(:last_event, "tree selected #{item_id}")
    |> rerender!()
  end

  defp handle_main_action(state, _node_id, "collection_tree_toggle", event) do
    item_id = Map.get(event, :item_id, "all")

    state
    |> Map.update!(:table_expanded, &toggle_set(&1, item_id))
    |> Map.put(:last_event, "tree toggled #{item_id}")
    |> rerender!()
  end

  defp handle_main_action(state, _node_id, "collection_row_select", event) do
    row_id = Map.get(event, :row_id, "")

    state
    |> Map.put(:table_selected_row_id, row_id)
    |> Map.put(:table_selected_cell, {row_id, "status"})
    |> Map.put(:last_event, "table row #{row_id}")
    |> rerender!()
  end

  defp handle_main_action(state, _node_id, "collection_cell_select", event) do
    row_id = Map.get(event, :row_id, "")
    column_id = Map.get(event, :column_id, "status")

    state
    |> Map.put(:table_selected_row_id, row_id)
    |> Map.put(:table_selected_cell, {row_id, column_id})
    |> Map.put(:last_event, "table cell #{row_id}/#{column_id}")
    |> rerender!()
  end

  defp handle_main_action(state, _node_id, "collection_sort", event) do
    column_id = Map.get(event, :column_id, "title")

    state
    |> Map.update!(:table_sort, &next_sort(&1, column_id))
    |> sync_table_selection()
    |> Map.put(:last_event, "table sort #{column_id}")
    |> rerender!()
  end

  defp handle_main_action(state, _node_id, "collection_column_reorder", event) do
    state
    |> Map.update!(:table_column_ids, fn column_ids ->
      TableTreeShared.reorder_column_ids(
        column_ids,
        Map.get(event, :column_id, "title"),
        Map.get(event, :target_column_id, "title"),
        Map.get(event, :direction, "left")
      )
    end)
    |> Map.put(:last_event, "table column reorder")
    |> rerender!()
  end

  defp handle_main_action(state, _node_id, "collection_column_resize", event) do
    state
    |> Map.update!(:table_column_widths, fn widths ->
      resize_column_widths(
        widths,
        Map.get(event, :column_id, "title"),
        Map.get(event, :width_delta, 0)
      )
    end)
    |> Map.put(:last_event, "table column resize")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "row_open", event) do
    row_id = Map.get(event, :row_id, node_id)

    state
    |> Map.put(:row_control_last_event, "button clicked from #{row_id}/#{node_id}")
    |> Map.put(:last_event, "row button #{row_id}/#{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "context_menu_action", _event) do
    state
    |> Map.put(:context_menu_open, false)
    |> Map.put(:keyboard_status, "context menu action from #{node_id}")
    |> Map.put(:last_event, "context menu action #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, node_id, "cycle_canvas", _event) do
    state
    |> Map.update!(:canvas_state, &next_canvas_state/1)
    |> Map.put(:last_event, "cycled canvas from #{node_id}")
    |> rerender!()
  end

  defp handle_main_action(state, _node_id, "badge_increment", _event),
    do: update_badge(state, state.shell_badge_count + 1)

  defp handle_main_action(state, _node_id, "badge_clear", _event), do: clear_badge(state)

  defp handle_main_action(state, _node_id, "open_file_dialog", _event),
    do: open_file_dialog(state)

  defp handle_main_action(state, _node_id, "choose_directory_dialog", _event),
    do: choose_directory_dialog(state)

  defp handle_main_action(state, _node_id, "save_file_dialog", _event),
    do: save_file_dialog(state)

  defp handle_main_action(state, _node_id, "read_clipboard", _event), do: read_clipboard(state)
  defp handle_main_action(state, _node_id, "write_clipboard", _event), do: write_clipboard(state)

  defp handle_main_action(state, _node_id, "install_menus", _event),
    do: install_super_demo_menus(state)

  defp handle_main_action(state, _node_id, "install_dock_menu", _event),
    do: install_super_demo_dock_menu(state)

  defp handle_main_action(state, _node_id, "clear_shell_chrome", _event),
    do: clear_shell_chrome(state)

  defp handle_main_action(state, node_id, "open_aux_window", _event),
    do: open_aux_window(state, node_id)

  defp handle_main_action(state, _node_id, "close_aux_window", _event),
    do: close_aux_window(state, "main control")

  defp handle_main_action(state, _node_id, "spawn_child_owner", _event),
    do: spawn_child_owner(state)

  defp handle_main_action(state, _node_id, "kill_child_owner", _event),
    do: kill_child_owner(state)

  defp handle_main_action(state, node_id, "quit_demo", _event),
    do: {:stop, Map.put(state, :last_event, "quit requested from #{node_id}")}

  defp handle_main_action(state, node_id, callback_id, _event) do
    state
    |> Map.put(:last_event, "unhandled main click #{node_id}/#{callback_id}")
    |> rerender!()
  end

  defp handle_aux_click(state, node_id, "close_aux_window") do
    close_aux_window(state, "aux window click #{node_id}")
  end

  defp handle_aux_click(state, node_id, callback_id) do
    state
    |> Map.put(:last_event, "aux click #{node_id}/#{callback_id}")
    |> rerender!()
  end

  defp handle_timer_tick(%{timer_running: false} = state), do: state

  defp handle_timer_tick(state) do
    next_ticks = state.timer_ticks + 1
    next_remaining = max(state.timer_remaining - 1, 0)

    state =
      state
      |> Map.put(:timer_ticks, next_ticks)
      |> Map.put(:timer_remaining, next_remaining)
      |> Map.put(:palette_index, rem(state.palette_index + 1, length(@palette)))
      |> Map.put(:last_event, "timer tick #{next_ticks}")
      |> rerender!()

    if next_remaining > 0 do
      Process.send_after(self(), :timer_tick, @timer_interval_ms)
      state
    else
      state
      |> Map.put(:timer_running, false)
      |> Map.put(:last_event, "timer finished after #{next_ticks} ticks")
      |> rerender!()
    end
  end

  defp update_pointer_counters(state, :mouse_down),
    do: Map.update!(state, :mouse_downs, &(&1 + 1))

  defp update_pointer_counters(state, :mouse_up), do: Map.update!(state, :mouse_ups, &(&1 + 1))

  defp update_pointer_counters(state, :mouse_move),
    do: Map.update!(state, :mouse_moves, &(&1 + 1))

  defp update_pointer_counters(state, :scroll_wheel),
    do: Map.update!(state, :scroll_wheels, &(&1 + 1))

  defp update_keyboard_counters(state, :focus), do: Map.update!(state, :focus_events, &(&1 + 1))
  defp update_keyboard_counters(state, :blur), do: Map.update!(state, :blur_events, &(&1 + 1))
  defp update_keyboard_counters(state, :key_down), do: Map.update!(state, :key_downs, &(&1 + 1))
  defp update_keyboard_counters(state, :key_up), do: Map.update!(state, :key_ups, &(&1 + 1))

  defp update_keyboard_counters(state, :context_menu),
    do: Map.update!(state, :context_menus, &(&1 + 1))

  defp update_keyboard_counters(state, :action), do: Map.update!(state, :action_events, &(&1 + 1))

  defp maybe_open_context_menu(state, :context_menu), do: Map.put(state, :context_menu_open, true)
  defp maybe_open_context_menu(state, _type), do: state

  defp update_drag_counters(state, :drag_start), do: Map.update!(state, :drag_starts, &(&1 + 1))
  defp update_drag_counters(state, :drag_move), do: Map.update!(state, :drag_moves, &(&1 + 1))
  defp update_drag_counters(state, :drop), do: Map.update!(state, :drops, &(&1 + 1))

  defp format_pointer_event(:mouse_down, event) do
    "down #{event.button} @ (#{format_number(event.x)}, #{format_number(event.y)}) clicks=#{event.click_count} mods=#{format_modifiers(event.modifiers)}"
  end

  defp format_pointer_event(:mouse_up, event) do
    "up #{event.button} @ (#{format_number(event.x)}, #{format_number(event.y)}) clicks=#{event.click_count} mods=#{format_modifiers(event.modifiers)}"
  end

  defp format_pointer_event(:mouse_move, event) do
    "move pressed=#{event.pressed_button} @ (#{format_number(event.x)}, #{format_number(event.y)}) mods=#{format_modifiers(event.modifiers)}"
  end

  defp format_pointer_event(:scroll_wheel, event) do
    "wheel #{event.delta_kind} Δ(#{format_number(event.delta_x)}, #{format_number(event.delta_y)}) @ (#{format_number(event.x)}, #{format_number(event.y)}) mods=#{format_modifiers(event.modifiers)}"
  end

  defp format_keyboard_event(:focus, _event), do: "focus gained"
  defp format_keyboard_event(:blur, _event), do: "focus lost"

  defp format_keyboard_event(:key_down, event) do
    "down #{event.key} key_char=#{inspect(event.key_char)} held=#{event.is_held} mods=#{format_modifiers(event.modifiers)}"
  end

  defp format_keyboard_event(:key_up, event) do
    "up #{event.key} key_char=#{inspect(event.key_char)} mods=#{format_modifiers(event.modifiers)}"
  end

  defp format_keyboard_event(:context_menu, event) do
    "context menu @ (#{format_number(event.x)}, #{format_number(event.y)}) mods=#{format_modifiers(event.modifiers)}"
  end

  defp format_keyboard_event(:action, event) do
    "action #{event.action} via #{event.shortcut} key=#{event.key} key_char=#{inspect(event.key_char)} mods=#{format_modifiers(event.modifiers)}"
  end

  defp format_drag_event(:drag_start, event) do
    "start source=#{event.source_id}"
  end

  defp format_drag_event(:drag_move, event) do
    "move source=#{event.source_id} pressed=#{event.pressed_button} @ (#{format_number(event.x)}, #{format_number(event.y)}) mods=#{format_modifiers(event.modifiers)}"
  end

  defp format_drag_event(:drop, event) do
    "drop source=#{event.source_id} on #{event.id}"
  end

  defp format_modifiers(modifiers) do
    active =
      modifiers
      |> Enum.filter(fn {_key, value} -> value end)
      |> Enum.map(fn {key, _value} -> key end)
      |> Enum.sort()

    case active do
      [] -> "none"
      keys -> Enum.join(keys, "+")
    end
  end

  defp format_number(number) when is_integer(number), do: Integer.to_string(number)

  defp format_number(number) when is_float(number),
    do: :erlang.float_to_binary(number, decimals: 1)

  defp ensure_demo_assets! do
    File.write!(@asset_icon_path, """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <rect x="6" y="6" width="52" height="52" rx="14" fill="#172554" stroke="#60a5fa" stroke-width="4"/>
      <path d="M18 34 L28 44 L47 20" fill="none" stroke="#f8fafc" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
    """)
  end

  defp sync_table_selection(state) do
    tasks =
      state.table_selected_tree_id
      |> TableTreeShared.visible_tasks()
      |> TableTreeShared.sort_tasks(state.table_sort)

    row_id = TableTreeShared.selected_row_id_for(tasks, state.table_selected_row_id)

    state
    |> Map.put(:table_selected_row_id, row_id)
    |> Map.put(
      :table_selected_cell,
      TableTreeShared.selected_cell_for(row_id, state.table_selected_cell)
    )
  end

  defp next_sort(%{column_id: column_id, direction: :asc}, column_id),
    do: %{column_id: column_id, direction: :desc}

  defp next_sort(_sort, column_id), do: %{column_id: column_id, direction: :asc}

  defp toggle_set(set, value) do
    if MapSet.member?(set, value), do: MapSet.delete(set, value), else: MapSet.put(set, value)
  end

  defp resize_column_widths(widths, column_id, width_delta) do
    Map.update!(widths, column_id, fn width -> max(width + width_delta, 72) end)
  end

  defp collection_tree_nodes(expanded, selected_id) do
    [
      tree_item("all", "All tasks", expanded, selected_id,
        children: [
          tree_item("platform", "Platform", expanded, selected_id),
          tree_item("design", "Design", expanded, selected_id),
          tree_item("release", "Release", expanded, selected_id)
        ]
      )
    ]
  end

  defp tree_item(id, label, expanded, selected_id, opts \\ []) do
    %{id: id, label: label, style: selected_collection_style(id == selected_id)}
    |> maybe_put_tree(:expanded, if(opts[:children], do: MapSet.member?(expanded, id)))
    |> maybe_put_tree(:children, opts[:children])
  end

  defp maybe_put_tree(map, _key, nil), do: map
  defp maybe_put_tree(map, key, value), do: Map.put(map, key, value)

  defp collection_table_rows(tasks, selected_row_id, selected_cell) do
    Enum.map(tasks, fn task ->
      %{
        id: task.id,
        style: selected_row_style(task.id == selected_row_id),
        cells: [
          collection_table_cell("title", task.title, selected_cell == {task.id, "title"}),
          collection_table_cell("status", task.status, selected_cell == {task.id, "status"}),
          collection_table_cell("owner", task.owner, selected_cell == {task.id, "owner"})
        ]
      }
    end)
  end

  defp collection_table_cell(column_id, text, selected?) do
    %{
      column_id: column_id,
      children: [Guppy.IR.text(text)],
      style: selected_cell_style(selected?)
    }
  end

  defp selected_row_style(true), do: [{:bg_hex, "#172554"}, {:border_color_hex, "#2563eb"}]
  defp selected_row_style(false), do: []
  defp selected_cell_style(true), do: [{:bg_hex, "#1d4ed8"}, {:text_color_hex, "#eff6ff"}]
  defp selected_cell_style(false), do: []
  defp selected_collection_style(true), do: selected_cell_style(true)
  defp selected_collection_style(false), do: []

  defp super_context_menu(false), do: Guppy.IR.div([], id: "super_context_menu_placeholder")

  defp super_context_menu(true) do
    Guppy.ContextMenu.render(
      [
        menu_item("copy", "Copy", "context_menu_action"),
        menu_item("rename", "Rename", "context_menu_action"),
        :separator,
        menu_item("disabled", "Disabled item", "context_menu_action", disabled: true)
      ],
      id: "super_context",
      style: [
        {:width, {:px, 240}},
        {:padding, :all, {:rem, 0.25}},
        {:bg_hex, "#ffffff"},
        {:text_color, :black},
        {:border_width, :all, {:px, 1}},
        {:border_color_hex, "#34d399"}
      ],
      item_style: [{:padding, :all, {:rem, 0.5}}],
      disabled_item_style: [{:padding, :all, {:rem, 0.5}}, {:text_color, :gray}],
      separator_style: [{:height, {:px, 1}}, {:bg_hex, "#d1fae5"}]
    )
  end

  defp row_control_seed do
    [
      row_control_task("row_task_1", "Wire row-control payloads", false, "high"),
      row_control_task("row_task_2", "Keep row ids stable", true, "normal"),
      row_control_task("row_task_3", "Prune retained controls", false, "normal")
    ]
  end

  defp row_control_task(id, title, done, priority) do
    %{id: id, title: title, done: done, priority: priority}
  end

  defp row_control_item(task) do
    %{
      id: task.id,
      children: [
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text(task.title, id: "#{task.id}_title", style: [:font_semibold]),
                Guppy.IR.text("row id: #{task.id}",
                  style: [:text_xs, {:text_color_hex, @text_muted}]
                )
              ],
              style: [:flex, :flex_col, :gap_1, :flex_1]
            ),
            Guppy.IR.checkbox("Done", task.done,
              id: "row_done",
              events: %{change: "row_done_changed"},
              style: [:gap_2]
            ),
            Guppy.IR.radio("High", "high", task.priority == "high",
              id: "row_priority_high",
              events: %{change: "row_priority_changed"},
              style: [:gap_2]
            ),
            Guppy.IR.radio("Normal", "normal", task.priority == "normal",
              id: "row_priority_normal",
              events: %{change: "row_priority_changed"},
              style: [:gap_2]
            ),
            Guppy.IR.button("Open",
              id: "row_open",
              events: %{click: "row_open"},
              style: [:p_2, :rounded_md, :border_1]
            )
          ],
          id: "#{task.id}_layout",
          style: [:flex, :flex_row, :items_center, :gap_4]
        )
      ]
    }
  end

  defp update_row_control_task(state, row_id, fun) do
    Map.update!(state, :row_control_tasks, fn tasks ->
      Enum.map(tasks, fn
        %{id: ^row_id} = task -> fun.(task)
        task -> task
      end)
    end)
  end

  defp canvas_state(:open), do: canvas_state("Open", 0.42, "#2563eb", "#60a5fa")
  defp canvas_state(:review), do: canvas_state("Review", 0.68, "#d97706", "#fbbf24")
  defp canvas_state(:done), do: canvas_state("Done", 0.9, "#16a34a", "#86efac")

  defp canvas_state(label, progress, fill, accent) do
    %{label: label, progress: progress, fill: fill, accent: accent}
  end

  defp next_canvas_state(:open), do: :review
  defp next_canvas_state(:review), do: :done
  defp next_canvas_state(:done), do: :open

  defp canvas_commands(state) do
    progress_width = 248 * state.progress

    [
      canvas_command(:rounded_rect, 0, 0, 320, 180, radius: 18, fill: "#111827"),
      canvas_command(:rounded_rect, 18, 18, 284, 144, radius: 14, fill: "#0f172a"),
      canvas_command(:pattern_rect, 24, 24, 272, 46,
        radius: 12,
        color: state.accent,
        line_width: 0.045,
        interval: 0.16
      ),
      canvas_command(:rounded_rect, 36, 104, 248, 22, radius: 11, fill: "#334155"),
      canvas_command(:rounded_rect, 36, 104, progress_width, 22, radius: 11, fill: state.fill),
      canvas_command(:rounded_rect, 36, 140, 112, 16, radius: 8, fill: state.accent)
    ]
  end

  defp canvas_command(op, x, y, width, height, opts) do
    opts
    |> Map.new()
    |> Map.merge(%{op: op, x: x, y: y, width: width, height: height})
  end

  defp update_badge(state, count) do
    result = Guppy.set_app_badge(Integer.to_string(count))

    state
    |> Map.put(:shell_badge_count, count)
    |> Map.put(:shell_status, "set app badge to #{count}: #{inspect(result)}")
    |> log_shell_event("Set app badge to #{count}")
    |> Map.put(:last_event, "set app badge")
    |> rerender!()
  end

  defp clear_badge(state) do
    result = Guppy.set_app_badge(nil)

    state
    |> Map.put(:shell_badge_count, 0)
    |> Map.put(:shell_status, "cleared app badge: #{inspect(result)}")
    |> log_shell_event("Cleared app badge")
    |> Map.put(:last_event, "cleared app badge")
    |> rerender!()
  end

  defp open_file_dialog(state) do
    result =
      Guppy.open_file_dialog(
        [
          multiple: true,
          prompt: "Open Elixir source",
          directory: File.cwd!(),
          filters: ["ex", "exs"],
          owner_view_id: state.main_view_id
        ],
        120_000
      )

    shell_result(state, "open file dialog", result)
  end

  defp choose_directory_dialog(state) do
    result =
      Guppy.choose_directory_dialog(
        [prompt: "Choose a directory", directory: File.cwd!(), owner_view_id: state.main_view_id],
        120_000
      )

    shell_result(state, "choose directory dialog", result)
  end

  defp save_file_dialog(state) do
    result =
      Guppy.save_file_dialog(
        [
          directory: File.cwd!(),
          default_name: "guppy-super-demo.txt",
          filters: ["txt"],
          owner_view_id: state.main_view_id
        ],
        120_000
      )

    shell_result(state, "save file dialog", result)
  end

  defp read_clipboard(state) do
    result = Guppy.read_clipboard_text()
    shell_result(state, "read clipboard", result)
  end

  defp write_clipboard(state) do
    text = "Guppy super demo #{System.system_time(:second)}"
    result = Guppy.write_clipboard_text(text)
    shell_result(state, "write clipboard", result)
  end

  defp install_super_demo_menus(state) do
    result = Guppy.set_menus(super_demo_menu_spec())
    shell_result(state, "install menus", result)
  end

  defp install_super_demo_dock_menu(state) do
    result = Guppy.set_dock_menu(super_demo_dock_menu_spec())
    shell_result(state, "install Dock menu", result)
  end

  defp clear_shell_chrome(state) do
    _ = Guppy.set_menus([])
    _ = Guppy.set_dock_menu([])
    _ = Guppy.set_app_badge(nil)

    state
    |> Map.put(:shell_badge_count, 0)
    |> Map.put(:shell_status, "cleared menus, Dock menu, and badge")
    |> log_shell_event("Cleared native shell chrome")
    |> Map.put(:last_event, "cleared shell chrome")
    |> rerender!()
  end

  defp shell_result(state, label, result) do
    message = "#{label}: #{format_shell_result(result)}"

    state
    |> Map.put(:shell_status, message)
    |> log_shell_event(message)
    |> Map.put(:last_event, label)
    |> rerender!()
  end

  defp log_shell_event(state, message) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second) |> Calendar.strftime("%H:%M:%S")
    Map.update!(state, :shell_events, &Enum.take(["#{timestamp} #{message}" | &1], 6))
  end

  defp format_shell_result({:ok, nil}), do: "cancel"
  defp format_shell_result({:ok, values}) when is_list(values), do: Enum.join(values, ", ")
  defp format_shell_result({:ok, value}), do: inspect(value)
  defp format_shell_result(:ok), do: ":ok"
  defp format_shell_result(other), do: inspect(other)

  defp super_demo_menu_spec do
    [
      %{label: "Guppy", items: []},
      %{
        label: "Demo",
        items: [
          menu_item("super_badge", "Increment Badge", "badge_increment", shortcut: "cmd-b"),
          menu_item("super_clipboard", "Write Clipboard", "write_clipboard")
        ]
      }
    ]
  end

  defp super_demo_dock_menu_spec do
    [
      menu_item("super_badge_dock", "Increment Badge", "badge_increment"),
      menu_item("super_clear_dock", "Clear Badge", "badge_clear")
    ]
  end

  defp menu_item(id, label, callback, opts \\ []) do
    %{id: id, label: label, callback: callback}
    |> maybe_put_tree(:shortcut, opts[:shortcut])
    |> maybe_put_tree(:disabled, opts[:disabled])
  end

  defp open_aux_window(%{aux_view_id: view_id} = state, _node_id) when not is_nil(view_id) do
    state
    |> Map.put(:last_event, "auxiliary window already open")
    |> rerender!()
  end

  defp open_aux_window(state, node_id) do
    case Guppy.open_window(
           aux_window_ir(),
           window_bounds: [width: 560, height: 420],
           titlebar: [title: "Guppy super demo auxiliary window"]
         ) do
      {:ok, aux_view_id} ->
        state
        |> Map.put(:aux_view_id, aux_view_id)
        |> Map.put(:last_event, "opened auxiliary window from #{node_id}")
        |> refresh_statuses()
        |> rerender!()

      {:error, reason} ->
        state
        |> Map.put(:last_event, "failed to open auxiliary window: #{inspect(reason)}")
        |> rerender!()
    end
  end

  defp close_aux_window(%{aux_view_id: nil} = state, source) do
    state
    |> Map.put(:last_event, "no auxiliary window to close (#{source})")
    |> rerender!()
  end

  defp close_aux_window(state, source) do
    case Guppy.close_window(state.aux_view_id) do
      :ok ->
        state
        |> Map.put(:aux_view_id, nil)
        |> Map.put(:last_event, "closed auxiliary window (#{source})")
        |> refresh_statuses()
        |> rerender!()

      {:error, :unknown_view_id} ->
        state
        |> Map.put(:aux_view_id, nil)
        |> Map.put(:last_event, "auxiliary window already closed")
        |> refresh_statuses()
        |> rerender!()

      {:error, reason} ->
        state
        |> Map.put(:last_event, "failed to close auxiliary window: #{inspect(reason)}")
        |> rerender!()
    end
  end

  defp spawn_child_owner(%{child_owner_pid: pid} = state) when is_pid(pid) do
    state
    |> Map.put(:last_event, "child owner already running")
    |> rerender!()
  end

  defp spawn_child_owner(state) do
    parent = self()
    spawn(fn -> child_owner_loop(parent) end)

    state
    |> Map.put(:last_event, "spawned child owner process")
    |> rerender!()
  end

  defp kill_child_owner(%{child_owner_pid: nil} = state) do
    state
    |> Map.put(:last_event, "no child owner process to kill")
    |> rerender!()
  end

  defp kill_child_owner(state) do
    Process.exit(state.child_owner_pid, :kill)

    state
    |> Map.put(:last_event, "sent :kill to child owner process")
    |> rerender!()
  end

  defp maybe_clear_child(state, pid) do
    if pid == state.child_owner_pid do
      state
      |> Map.put(:child_owner_pid, nil)
      |> Map.put(:child_monitor_ref, nil)
      |> Map.put(:child_view_id, nil)
    else
      state
    end
  end

  defp cleanup(state) do
    if state.aux_view_id, do: _ = Guppy.close_window(state.aux_view_id)
    if state.child_owner_pid, do: send(state.child_owner_pid, :stop)
    _ = Guppy.set_menus([])
    _ = Guppy.set_dock_menu([])
    _ = Guppy.set_app_badge(nil)
  end

  defp rerender!(state) do
    case Guppy.render(state.main_view_id, render(state)) do
      :ok -> state
      {:error, :unknown_view_id} -> {:stop, state}
      {:error, reason} -> raise "failed to update super demo: #{inspect(reason)}"
    end
  end

  defp refresh_statuses(state), do: Map.put(state, :statuses, capture_statuses())

  defp capture_statuses do
    %{
      load_status: Guppy.Native.Nif.load_status(),
      native_build_info: Guppy.native_build_info(),
      native_runtime_status: Guppy.native_runtime_status(),
      native_gui_status: Guppy.native_gui_status(),
      ping: Guppy.ping(),
      native_view_count: Guppy.native_view_count()
    }
  end

  defp render(state) do
    Guppy.IR.div(
      [
        header_panel(state),
        Guppy.IR.div(
          [nav_panel(state), detail_panel(state)],
          id: "main_split",
          style: [:flex, :flex_1, :w_full, :min_h_0, :max_h_full, :gap_2]
        )
      ],
      id: "super_demo_root",
      style: [
        :size_full,
        :flex,
        :flex_col,
        :gap_2,
        :p_4,
        {:bg_hex, @surface_base},
        {:text_color_hex, @text_primary}
      ]
    )
  end

  defp header_panel(state) do
    theme = palette_theme(palette_color(state))

    panel(
      "header_panel",
      [
        Guppy.IR.div(
          [
            Guppy.IR.text("Guppy super demo", id: "demo_title"),
            Guppy.IR.text("last_event = #{state.last_event}", id: "last_event_label")
          ],
          id: "header_row",
          style: [:flex, :flex_row, :w_full, :justify_between, :items_start]
        ),
        Guppy.IR.text(
          "Select a demo on the left. The detail panel on the right updates in place."
        )
      ],
      style: [
        {:bg_hex, theme.accent},
        {:border_color_hex, theme.border},
        {:text_color_hex, theme.text}
      ]
    )
  end

  defp nav_panel(state) do
    theme = palette_theme(palette_color(state))

    items =
      Enum.map(@demo_ids, fn demo_id ->
        nav_button(demo_id, state.selected_demo == demo_id, theme)
      end)

    panel(
      "nav_panel",
      [
        Guppy.IR.text("Demos", id: "nav_title"),
        Guppy.IR.text(
          "The main window stays anchored at the top; switch demos instead of scrolling."
        ),
        Guppy.IR.div(items, id: "nav_items", style: [:flex, :flex_col, :w_full, :gap_2])
      ],
      style: [
        :w_64,
        :min_h_0,
        :max_h_full,
        :flex_col,
        :items_start,
        :p_4,
        {:bg_hex, @surface_panel_alt},
        {:border_color_hex, @border_subtle}
      ]
    )
  end

  defp detail_panel(state) do
    panel(
      "detail_panel",
      [
        Guppy.IR.text("selected_demo = #{state.selected_demo}", id: "selected_demo_label"),
        Guppy.IR.text(
          "live native windows (Guppy.native_view_count) = #{inspect(state.statuses.native_view_count)}"
        ),
        Guppy.IR.scroll(
          [detail_content(state)],
          id: "detail_scroll",
          style: [:flex_1, :w_full, :min_h_0, :max_h_full]
        )
      ],
      style: [
        :flex,
        :flex_col,
        :flex_1,
        :w_full,
        :min_h_0,
        :max_h_full,
        :overflow_hidden,
        :gap_2,
        :p_4
      ]
    )
  end

  defp detail_content(%{selected_demo: :runtime} = state), do: runtime_demo(state)
  defp detail_content(%{selected_demo: :components} = state), do: components_demo(state)
  defp detail_content(%{selected_demo: :interactions} = state), do: interactions_demo(state)
  defp detail_content(%{selected_demo: :collections} = state), do: collections_demo(state)
  defp detail_content(%{selected_demo: :windows} = state), do: windows_demo(state)
  defp detail_content(%{selected_demo: :native_shell} = state), do: native_shell_demo(state)
  defp detail_content(%{selected_demo: :styles} = state), do: styles_demo(state)
  defp detail_content(%{selected_demo: :layout} = state), do: layout_demo(state)
  defp detail_content(%{selected_demo: :scroll} = state), do: scroll_demo(state)
  defp detail_content(%{selected_demo: :help} = state), do: help_demo(state)

  defp runtime_demo(state) do
    panel(
      "runtime_demo",
      [
        Guppy.IR.text("Runtime status shown in the UI"),
        Guppy.IR.text("load_status = #{inspect(state.statuses.load_status)}"),
        Guppy.IR.text("native_build_info = #{inspect(state.statuses.native_build_info)}"),
        Guppy.IR.text("native_runtime_status = #{inspect(state.statuses.native_runtime_status)}"),
        Guppy.IR.text("native_gui_status = #{inspect(state.statuses.native_gui_status)}"),
        Guppy.IR.text("ping = #{inspect(state.statuses.ping)}"),
        action_button("Refresh runtime status", "refresh_status_button", "refresh_status", :white)
      ],
      style: [{:bg_hex, @surface_panel}]
    )
  end

  defp components_demo(state) do
    assigns = %{
      cards: component_feature_cards(state),
      component_items: [
        %{id: "component_item_1", label: "Function components validate declared props"},
        %{id: "component_item_2", label: "Template controls emit native change callbacks"},
        %{id: "component_item_3", label: "Stable animation ids survive full-tree rerenders"}
      ],
      intro_runs: [
        %{text: "New authoring path: ", style: [:font_semibold]},
        %{text: "~GUI templates", style: [{:text_color_hex, "#93c5fd"}, :font_bold]},
        %{text: " + local components + native controls."}
      ],
      notifications_enabled: state.notifications_enabled,
      checkbox_changes: state.checkbox_changes,
      popover_open: state.popover_open,
      status_options: [
        %{value: "todo", label: "Todo"},
        %{value: "doing", label: "Doing"},
        %{value: "done", label: "Done"}
      ],
      selected_status: state.selected_status,
      status_select_open: state.status_select_open
    }

    ~GUI"""
    <div id="components_demo" class="flex flex-col gap-4 p-4 rounded-xl border-1 border-[#334155] bg-[#0f172a] text-[#e2e8f0]">
      <text id="components_title" class="text-xl font-black">Components and new primitives</text>
      <rich_text id="components_intro" runs={@intro_runs} class="text-base leading-relaxed" />

      <div id="component_card_grid" class="grid grid-cols-[3] gap-2 w-full">
        <.feature_card
          :for={card <- @cards}
          id={card.id}
          title={card.title}
          badge={card.badge}
          body={card.body}
          class={card.class}
          animation={card.animation}
        >
          <text id={card.detail_id} class="text-xs text-[#94a3b8] leading-snug">{card.detail}</text>
        </.feature_card>
      </div>

      <div id="component_controls" class="flex flex-row flex-wrap gap-2 items-center p-2 rounded-lg border-1 border-[#334155] bg-[#111827]">
        <checkbox
          id="notifications_checkbox"
          checked={@notifications_enabled}
          change="notifications_changed"
          class="gap-2 p-2 rounded-lg border-1 border-[#334155] bg-[#0b1220]"
          focus_visible_class="border-yellow shadow-lg"
        >
          Enable checkbox state
        </checkbox>

        <text id="notifications_state" class="text-sm text-[#cbd5e1]">notifications_enabled = {@notifications_enabled}</text>
        <text id="checkbox_changes" class="text-sm text-[#94a3b8]">checkbox_changes = {@checkbox_changes}</text>
      </div>

      <div id="component_select_row" class="flex flex-row flex-wrap gap-2 items-center">
        <select
          id="status_select_component"
          value={@selected_status}
          open={@status_select_open}
          options={@status_options}
          placeholder="Template select"
          click="toggle_status_select"
          change="status_select_changed"
          close="close_status_select"
          class="w-[240px] border-1 border-[#60a5fa] bg-[#0b1220] text-[#f8fafc] cursor-pointer"
          list_class="w-[240px] p-1 rounded-lg border-1 border-[#334155] bg-[#0f172a] text-[#e2e8f0] shadow-lg"
          option_class="p-2 rounded-md"
        />

        <popover
          id="component_popover"
          label="Template popover"
          open={@popover_open}
          click="open_popover"
          close="close_popover"
          class="p-2 rounded-lg border-1 border-[#60a5fa] bg-[#111827]"
          popover_class="p-4 gap-2 bg-[#f8fafc] text-[#0f172a] shadow-lg"
          anchor="bottom_right"
          anchor_position_mode="local"
          anchor_fit="snap_to_window_with_margin"
          anchor_offset={{0, 10}}
          snap_margin="10"
          close_on_click_outside="true"
          stack_priority="3"
        >
          <text>Popover content is authored in the template compiler.</text>
          <text>It uses local positioning, snap margin, and close callbacks.</text>
        </popover>

        <button id="component_palette_button" click="toggle_palette" class="p-2 rounded-lg border-1 border-[#2563eb] bg-[#172554] text-[#dbeafe]" hover_class="bg-[#1d4ed8]">
          Rotate palette
        </button>
      </div>

      <spacer id="component_spacer" class="h-[12px]" />
      <uniform_list id="component_uniform_list" items={@component_items} class="h-[120px] rounded-lg border-1 border-[#334155] bg-[#0b1220]" item_class="p-2 border-b-1" />
    </div>
    """
  end

  defp interactions_demo(state) do
    panel(
      "interactions_demo",
      [
        Guppy.IR.text("Clicks, pointer events, and rerenders"),
        Guppy.IR.text(
          "Use Tab to focus clickable cards and buttons, then press Enter or Space to activate them."
        ),
        Guppy.IR.popover(
          "Open popover",
          state.popover_open,
          [
            Guppy.IR.text("Popover content is rendered in a GPUI deferred anchored layer."),
            Guppy.IR.text("Click outside the popover to emit the close callback.")
          ],
          id: "demo_popover",
          style: [:p_2, :rounded_md, :border_1, {:border_color, :blue}],
          popover_style: [:p_4, :gap_2],
          anchor: :bottom_left,
          anchor_offset: {0, 8},
          anchor_position_mode: :local,
          anchor_fit: :snap_to_window_with_margin,
          snap_margin: 8,
          stack_priority: 2,
          events: %{click: "open_popover", close: "close_popover"}
        ),
        Guppy.IR.div(
          [Guppy.IR.text("Hover this row to exercise the native tooltip path.")],
          id: "tooltip_demo_row",
          tooltip: "Tooltips use GPUI's native tooltip mechanism.",
          style: [:p_2, :rounded_md, :border_1, {:border_color, :yellow}]
        ),
        Guppy.IR.text("div_clicks = #{state.div_clicks}"),
        action_button("Increment div clicks", "div_button", "div_increment", :blue),
        Guppy.IR.text("Disabled button below should not increment div_clicks."),
        disabled_action_button("Disabled increment button", "disabled_div_button"),
        Guppy.IR.text(
          "Increment text clicks by clicking this line",
          id: "text_increment_line",
          events: %{click: "text_increment"}
        ),
        Guppy.IR.text("text_clicks = #{state.text_clicks}"),
        Guppy.IR.rich_text(
          [
            %{text: "Rich text runs: ", style: [:font_semibold]},
            %{text: "yellow", style: [{:text_color, :yellow}, :underline]},
            %{text: " + bold", style: [:font_bold]}
          ],
          id: "rich_text_demo",
          style: [:text_base],
          events: %{click: "text_increment"}
        ),
        Guppy.IR.text_input(
          state.text_input_value,
          id: "demo_text_input",
          placeholder: "Type in this field",
          style: [:w_full],
          events: %{
            change: "demo_text_input_changed",
            focus: "demo_text_input_focused",
            blur: "demo_text_input_blurred"
          }
        ),
        Guppy.IR.text("text_input_value = #{inspect(state.text_input_value)}"),
        Guppy.IR.text("text_input_changes = #{state.text_input_changes}"),
        Guppy.IR.textarea(
          state.textarea_value,
          id: "demo_textarea",
          placeholder: "Type multiple lines",
          style: [:w_full, {:h_px, 120}],
          events: %{
            change: "demo_textarea_changed",
            focus: "demo_textarea_focused",
            blur: "demo_textarea_blurred"
          }
        ),
        Guppy.IR.text("textarea_value = #{inspect(state.textarea_value)}"),
        Guppy.IR.text("textarea_changes = #{state.textarea_changes}"),
        Guppy.IR.div(
          [
            radio_option("Low", "low", state.selected_priority),
            radio_option("Medium", "medium", state.selected_priority),
            radio_option("High", "high", state.selected_priority)
          ],
          id: "priority_radio_group",
          style: [:flex, :flex_row, :gap_4]
        ),
        Guppy.IR.text("selected_priority = #{state.selected_priority}"),
        Guppy.IR.text("radio_changes = #{state.radio_changes}"),
        Guppy.IR.select(
          [
            %{value: "todo", label: "Todo"},
            %{value: "doing", label: "Doing"},
            %{value: "done", label: "Done"}
          ],
          id: "status_select",
          value: state.selected_status,
          open: state.status_select_open,
          placeholder: "Pick status",
          style: [
            {:w_px, 240},
            :cursor_pointer,
            {:border_color_hex, "#60a5fa"},
            {:bg_hex, "#0b1220"},
            {:text_color_hex, "#f8fafc"}
          ],
          list_style: [
            {:w_px, 240},
            :p_1,
            :rounded_lg,
            :border_1,
            {:border_color_hex, "#334155"},
            {:bg_hex, "#0f172a"},
            {:text_color_hex, "#e2e8f0"},
            :shadow_lg
          ],
          option_style: [:p_2, :rounded_md],
          events: %{
            click: "toggle_status_select",
            change: "status_select_changed",
            close: "close_status_select"
          }
        ),
        Guppy.IR.text("selected_status = #{state.selected_status}"),
        Guppy.IR.text("select_changes = #{state.select_changes}"),
        Guppy.IR.uniform_list(
          Enum.map(1..100, &%{id: "uniform_demo_item_#{&1}", label: "Uniform item #{&1}"}),
          id: "interaction_uniform_list",
          style: [{:h_px, 160}, :border_1, {:border_color, :white}],
          item_style: [:p_2, :border_b_1],
          events: %{click: "uniform_item_clicked"}
        ),
        Guppy.IR.list(
          Enum.map(1..40, fn index ->
            %{
              id: "generic_demo_item_#{index}",
              children: [
                Guppy.IR.text("Generic list item #{index}"),
                Guppy.IR.div(
                  [Guppy.IR.text("Variable-height detail line #{rem(index, 4) + 1}")],
                  style: [:text_sm, {:text_color, :yellow}]
                )
              ]
            }
          end),
          id: "interaction_generic_list",
          style: [{:h_px, 180}, :border_1, {:border_color, :yellow}],
          item_style: [:p_2, :border_b_1],
          events: %{click: "generic_item_clicked"}
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text("Pointer pad", id: "pointer_pad_title"),
            Guppy.IR.text("Move, press, release, and use the wheel inside this box.",
              id: "pointer_pad_body"
            )
          ],
          id: "pointer_pad",
          style: [
            :flex,
            :flex_col,
            :justify_center,
            :items_center,
            :text_center,
            :gap_2,
            :w_full,
            {:h_px, 220},
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, :black},
            :cursor_pointer
          ],
          hover_style: [{:bg_hex, "#2a2a2a"}],
          events: %{
            mouse_down: "pointer_down",
            mouse_up: "pointer_up",
            mouse_move: "pointer_move",
            scroll_wheel: "pointer_scroll"
          }
        ),
        Guppy.IR.text("mouse_downs = #{state.mouse_downs}"),
        Guppy.IR.text("mouse_ups = #{state.mouse_ups}"),
        Guppy.IR.text("mouse_moves = #{state.mouse_moves}"),
        Guppy.IR.text("scroll_wheels = #{state.scroll_wheels}"),
        Guppy.IR.div(
          [Guppy.IR.text("pointer_status = #{state.pointer_status}", id: "pointer_status_label")],
          id: "pointer_status_panel",
          style: [:p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :gray}, :text_sm]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text("Keyboard focus pad", id: "keyboard_pad_title"),
            Guppy.IR.text(
              "Click here, then press keys. Use Tab to test focus participation. Right click for a context-menu event. Pressing the box also exercises active styling. While focused, press ctrl-j or ctrl-k to dispatch shortcut actions.",
              id: "keyboard_pad_body"
            )
          ],
          id: "keyboard_pad",
          focusable: true,
          tab_stop: true,
          tab_index: 1,
          focus_style: [{:bg_hex, "#204060"}],
          focus_visible_style: [{:border_color, :yellow}, :shadow_lg],
          in_focus_style: [:shadow_lg],
          active_style: [{:bg_hex, "#10263c"}, {:opacity, 0.92}],
          actions: %{
            "primary" => "shortcut_primary",
            "secondary" => "shortcut_secondary"
          },
          shortcuts: [{"ctrl-j", "primary"}, {"ctrl-k", "secondary"}],
          style: [
            :flex,
            :flex_col,
            :justify_center,
            :items_center,
            :text_center,
            :gap_2,
            :w_full,
            {:h_px, 180},
            :rounded_md,
            :border_2,
            {:border_color, :white},
            {:bg, :black},
            :cursor_pointer
          ],
          events: %{
            focus: "keyboard_focus",
            blur: "keyboard_blur",
            key_down: "keyboard_down",
            key_up: "keyboard_up",
            context_menu: "keyboard_context_menu"
          }
        ),
        Guppy.IR.text("focus_events = #{state.focus_events}"),
        Guppy.IR.text("blur_events = #{state.blur_events}"),
        Guppy.IR.text("key_downs = #{state.key_downs}"),
        Guppy.IR.text("key_ups = #{state.key_ups}"),
        Guppy.IR.text("context_menus = #{state.context_menus}"),
        Guppy.IR.text("action_events = #{state.action_events}"),
        Guppy.IR.div(
          [
            Guppy.IR.text("keyboard_status = #{state.keyboard_status}",
              id: "keyboard_status_label"
            )
          ],
          id: "keyboard_status_panel",
          style: [:p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :gray}, :text_sm]
        ),
        super_context_menu(state.context_menu_open),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text("Drag source", id: "drag_source_title"),
                Guppy.IR.text("Drag this box into the drop zone.", id: "drag_source_body")
              ],
              id: "drag_source",
              style: [
                :flex,
                :flex_col,
                :justify_center,
                :items_center,
                :text_center,
                :gap_2,
                :flex_1,
                {:h_px, 160},
                :rounded_md,
                :border_2,
                {:border_color, :white},
                {:bg, :blue},
                :cursor_pointer
              ],
              hover_style: [{:bg_hex, "#335fdd"}],
              events: %{
                drag_start: "drag_source_start",
                drag_move: "drag_source_move"
              }
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("Drop target", id: "drop_target_title"),
                Guppy.IR.text("Release the drag here to emit a drop event.",
                  id: "drop_target_body"
                )
              ],
              id: "drop_target",
              style: [
                :flex,
                :flex_col,
                :justify_center,
                :items_center,
                :text_center,
                :gap_2,
                :flex_1,
                {:h_px, 160},
                :rounded_md,
                :border_2,
                {:border_color, :yellow},
                {:bg, :black}
              ],
              events: %{drop: "drag_target_drop"}
            )
          ],
          id: "drag_demo_row",
          style: [:flex, :flex_row, :w_full, :gap_2]
        ),
        Guppy.IR.text("drag_starts = #{state.drag_starts}"),
        Guppy.IR.text("drag_moves = #{state.drag_moves}"),
        Guppy.IR.text("drops = #{state.drops}"),
        Guppy.IR.div(
          [Guppy.IR.text("drag_status = #{state.drag_status}", id: "drag_status_label")],
          id: "drag_status_panel",
          style: [:p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :gray}, :text_sm]
        ),
        Guppy.IR.text("Stacking / overlay demo"),
        Guppy.IR.text(
          "The blue card is deferred above the yellow card, overlaps it, and occludes clicks underneath it."
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text("Underlay card", id: "underlay_title"),
                Guppy.IR.text("Click the exposed yellow edge; the blue card should sit on top.",
                  id: "underlay_body"
                )
              ],
              id: "underlay_card",
              style: [
                :absolute,
                :top_2,
                :left_2,
                {:w_px, 320},
                {:h_px, 160},
                :p_4,
                :rounded_md,
                :border_2,
                {:border_color, :black},
                {:bg, :yellow},
                {:text_color, :black}
              ],
              events: %{click: "underlay_click"}
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("Overlay card", id: "overlay_title"),
                Guppy.IR.text(
                  "This card uses stack_priority + occlude and should block clicks below it.",
                  id: "overlay_body"
                )
              ],
              id: "overlay_card",
              stack_priority: 10,
              occlude: true,
              style: [
                :absolute,
                :top_1,
                :left_2,
                {:w_px, 240},
                {:h_px, 120},
                :p_4,
                :rounded_md,
                :border_2,
                {:border_color, :white},
                {:bg, :blue},
                {:text_color, :white},
                :cursor_pointer,
                :shadow_lg
              ],
              hover_style: [{:bg_hex, "#295ee5"}],
              events: %{click: "overlay_click"}
            )
          ],
          id: "stack_demo_frame",
          style: [
            :relative,
            :w_full,
            {:h_px, 190},
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, :gray},
            :overflow_hidden
          ]
        ),
        Guppy.IR.text("underlay_clicks = #{state.underlay_clicks}"),
        Guppy.IR.text("overlay_clicks = #{state.overlay_clicks}"),
        Guppy.IR.div(
          [Guppy.IR.text("stack_status = #{state.stack_status}", id: "stack_status_label")],
          id: "stack_status_panel",
          style: [:p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :gray}, :text_sm]
        ),
        action_button("Start timer rerender demo", "timer_button", "start_timer", :green),
        Guppy.IR.text("timer_ticks = #{state.timer_ticks}"),
        Guppy.IR.text("timer_running = #{state.timer_running}"),
        Guppy.IR.text("timer_remaining = #{state.timer_remaining}")
      ],
      style: [{:bg_hex, @surface_panel}]
    )
  end

  defp collections_demo(state) do
    visible_tasks = TableTreeShared.visible_tasks(state.table_selected_tree_id)
    sorted_tasks = TableTreeShared.sort_tasks(visible_tasks, state.table_sort)
    state = sync_table_selection(%{state | table_selected_row_id: state.table_selected_row_id})
    canvas = canvas_state(state.canvas_state)

    panel(
      "collections_demo",
      [
        Guppy.IR.text("Semantic collections, row controls, and canvas"),
        Guppy.IR.text(
          "This combines the standalone table/tree, list-row-control, and canvas examples in one tab."
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text("Project tree", id: "collection_tree_title"),
                Guppy.IR.tree(
                  collection_tree_nodes(state.table_expanded, state.table_selected_tree_id),
                  id: "collection_project_tree",
                  selected_id: state.table_selected_tree_id,
                  style: [{:h_px, 240}, :rounded_lg, :border_1, {:bg_hex, "#0b1220"}],
                  row_style: [:border_b_1, {:border_color_hex, "#1e293b"}],
                  events: %{select: "collection_tree_select", toggle: "collection_tree_toggle"}
                )
              ],
              id: "collection_tree_panel",
              style: [:flex, :flex_col, :gap_2, {:w_px, 260}]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("Task table", id: "collection_table_title"),
                Guppy.IR.data_table(
                  TableTreeShared.table_columns(
                    state.table_column_ids,
                    state.table_column_widths
                  ),
                  collection_table_rows(
                    sorted_tasks,
                    state.table_selected_row_id,
                    state.table_selected_cell
                  ),
                  id: "collection_task_table",
                  selected_row_id: state.table_selected_row_id,
                  selected_cell: state.table_selected_cell,
                  sort: state.table_sort,
                  style: [{:h_px, 260}, :rounded_lg, :border_1, {:bg_hex, "#0b1220"}],
                  header_style: [
                    :border_b_1,
                    {:border_color_hex, "#334155"},
                    {:bg_hex, "#172554"},
                    {:text_color_hex, "#bfdbfe"},
                    :font_bold
                  ],
                  row_style: [:border_b_1, {:border_color_hex, "#1e293b"}],
                  cell_style: [:text_sm],
                  events: %{
                    row_click: "collection_row_select",
                    cell_click: "collection_cell_select",
                    sort: "collection_sort",
                    column_reorder: "collection_column_reorder",
                    column_resize: "collection_column_resize"
                  }
                )
              ],
              id: "collection_table_panel",
              style: [:flex, :flex_col, :gap_2, :flex_1]
            )
          ],
          id: "collection_tree_table_row",
          style: [:flex, :flex_row, :gap_4, :w_full]
        ),
        Guppy.IR.text(
          "Scope #{TableTreeShared.selected_label(state.table_selected_tree_id)}; selected #{inspect(state.table_selected_cell)}; sort #{state.table_sort.column_id} #{state.table_sort.direction}"
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text("Row controls", id: "row_controls_title"),
                Guppy.IR.list(
                  Enum.map(state.row_control_tasks, &row_control_item/1),
                  id: "row_control_list",
                  style: [{:h_px, 220}, :rounded_lg, :border_1, {:bg_hex, "#0b1220"}],
                  item_style: [:p_2, :border_b_1, {:border_color_hex, "#1e293b"}]
                ),
                Guppy.IR.div(
                  [
                    Guppy.IR.text(state.row_control_last_event,
                      id: "row_control_status",
                      style: [:truncate]
                    )
                  ],
                  id: "row_control_status_panel",
                  style: [
                    :w_full,
                    :overflow_hidden,
                    :p_2,
                    :rounded_md,
                    {:bg_hex, "#0b1220"},
                    :text_sm
                  ]
                )
              ],
              id: "row_controls_panel",
              style: [:flex, :flex_col, :gap_2, :flex_1, :flex_shrink, {:min_width, {:px, 0}}]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("Canvas + pattern", id: "canvas_title"),
                Guppy.IR.canvas(
                  canvas_commands(canvas),
                  id: "collection_canvas",
                  style: [{:w_px, 320}, {:h_px, 180}, :rounded_xl, :overflow_hidden],
                  events: %{click: "cycle_canvas"}
                ),
                Guppy.IR.text("#{canvas.label}: #{round(canvas.progress * 100)}% complete"),
                Guppy.IR.text("Click the canvas to cycle the data-only draw commands.")
              ],
              id: "canvas_panel",
              style: [:flex, :flex_col, :gap_2, :flex_none, {:w_px, 360}]
            )
          ],
          id: "row_controls_canvas_row",
          style: [:flex, :flex_row, :items_start, :gap_4, :w_full]
        )
      ],
      style: [{:bg_hex, @surface_panel}]
    )
  end

  defp native_shell_demo(state) do
    panel(
      "native_shell_demo",
      [
        Guppy.IR.text("Native shell, assets, and dialogs"),
        Guppy.IR.text(
          "This tab covers the standalone menu, MarkdownView asset, and native shell examples: app badge, menus, Dock menu, file dialogs, clipboard, icon, and image primitives."
        ),
        Guppy.IR.div(
          [
            Guppy.IR.icon({:path, @asset_icon_path},
              id: "native_shell_icon",
              style: [{:w_px, 36}, {:h_px, 36}]
            ),
            Guppy.IR.image({:path, @asset_icon_path},
              id: "native_shell_image",
              object_fit: :contain,
              grayscale: false,
              style: [{:w_px, 96}, {:h_px, 64}, :rounded_lg, :border_1, {:bg_hex, "#0b1220"}]
            ),
            Guppy.IR.text("Shared SVG rendered once as <icon> and once as <image>.")
          ],
          id: "asset_preview_row",
          style: [:flex, :flex_row, :items_center, :gap_4, :w_full]
        ),
        Guppy.IR.div(
          [
            action_button(
              "Increment app badge",
              "badge_increment_button",
              "badge_increment",
              :blue
            ),
            action_button("Clear app badge", "badge_clear_button", "badge_clear", :gray),
            action_button("Install app menus", "install_menus_button", "install_menus", :green),
            action_button(
              "Install Dock menu",
              "install_dock_button",
              "install_dock_menu",
              :green
            ),
            action_button("Clear menus/badge", "clear_shell_button", "clear_shell_chrome", :red)
          ],
          id: "shell_chrome_buttons",
          style: [:flex, :flex_row, :flex_wrap, :gap_2]
        ),
        Guppy.IR.div(
          [
            action_button("Open file…", "open_file_dialog_button", "open_file_dialog", :yellow),
            action_button(
              "Choose directory…",
              "choose_directory_dialog_button",
              "choose_directory_dialog",
              :yellow
            ),
            action_button("Save file…", "save_file_dialog_button", "save_file_dialog", :yellow),
            action_button("Read clipboard", "read_clipboard_button", "read_clipboard", :white),
            action_button("Write clipboard", "write_clipboard_button", "write_clipboard", :white)
          ],
          id: "dialog_clipboard_buttons",
          style: [:flex, :flex_row, :flex_wrap, :gap_2]
        ),
        Guppy.IR.text("badge_count = #{state.shell_badge_count}"),
        Guppy.IR.div(
          [Guppy.IR.text("shell_status = #{state.shell_status}", id: "shell_status_text")],
          id: "shell_status_panel",
          style: [:p_2, :rounded_md, :border_1, {:border_color_hex, @border_subtle}, :text_sm]
        ),
        Guppy.IR.div(
          Enum.map(Enum.with_index(state.shell_events, 1), fn {event, index} ->
            Guppy.IR.text("#{index}. #{event}", id: "shell_event_#{index}", style: [:text_sm])
          end),
          id: "shell_event_log",
          style: [:flex, :flex_col, :gap_1, :p_2, :rounded_md, {:bg_hex, "#0b1220"}]
        )
      ],
      style: [{:bg_hex, @surface_panel}]
    )
  end

  defp windows_demo(state) do
    panel(
      "windows_demo",
      [
        Guppy.IR.text("Window lifecycle"),
        Guppy.IR.text("main_view_id = #{state.main_view_id}"),
        Guppy.IR.text("aux_view_id = #{inspect(state.aux_view_id)}"),
        Guppy.IR.text("child_owner_pid = #{inspect(state.child_owner_pid)}"),
        Guppy.IR.text("child_view_id = #{inspect(state.child_view_id)}"),
        action_button("Open auxiliary window", "open_aux_button", "open_aux_window", :yellow),
        action_button("Close auxiliary window", "close_aux_button", "close_aux_window", :yellow),
        action_button(
          "Spawn child-owner window",
          "spawn_child_button",
          "spawn_child_owner",
          :green
        ),
        action_button(
          "Kill child owner (tests DOWN cleanup)",
          "kill_child_button",
          "kill_child_owner",
          :red
        )
      ],
      style: [{:bg_hex, @surface_panel}]
    )
  end

  defp styles_demo(state) do
    theme = palette_theme(palette_color(state))

    panel(
      "styles_demo",
      [
        Guppy.IR.text("Style tokens and palette changes"),
        Guppy.IR.text("palette = #{theme.label} (#{theme.accent})"),
        Guppy.IR.text(
          "Click a swatch to select a palette. Palette changes recolor the header, the selected nav button, the preview card, and the swatches below."
        ),
        Guppy.IR.div(
          Enum.map(@palette, fn color ->
            palette_swatch(color, color == palette_color(state))
          end),
          id: "palette_swatch_row",
          style: [:flex, :flex_row, :flex_wrap, :gap_2, :w_full]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text("Preview area", id: "preview_title"),
                Guppy.IR.text("Click the button below to rotate colors.", id: "preview_text")
              ],
              id: "preview_panel",
              style: [
                :flex_1,
                :p_6,
                :rounded_md,
                :border_1,
                {:border_color_hex, theme.border},
                {:bg_hex, theme.accent},
                {:text_color_hex, theme.text}
              ]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("Palette impact", id: "palette_impact_title"),
                Guppy.IR.text(
                  "Header chrome and the selected nav item also follow the current palette now.",
                  id: "palette_impact_body"
                ),
                Guppy.IR.text("current accent = #{theme.label} / #{theme.accent}",
                  id: "palette_impact_value"
                )
              ],
              id: "palette_impact_panel",
              style: [
                :flex_1,
                :p_6,
                :rounded_md,
                :border_1,
                {:border_color_hex, theme.border},
                {:bg_hex, theme.accent},
                {:text_color_hex, theme.text}
              ]
            )
          ],
          id: "palette_preview_row",
          style: [:flex, :flex_row, :flex_wrap, :gap_2, :w_full]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text("Centered large italic text", id: "text_style_centered"),
            Guppy.IR.text("This container uses inherited text styling tokens.",
              id: "text_style_centered_body"
            )
          ],
          id: "text_style_panel",
          style: [
            :text_center,
            :text_lg,
            :italic,
            :p_4,
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, :gray}
          ]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div([Guppy.IR.text("Thin", id: "font_weight_thin")],
              id: "font_weight_thin_row",
              style: [:font_thin]
            ),
            Guppy.IR.div([Guppy.IR.text("Light", id: "font_weight_light")],
              id: "font_weight_light_row",
              style: [:font_light]
            ),
            Guppy.IR.div([Guppy.IR.text("Normal", id: "font_weight_normal")],
              id: "font_weight_normal_row",
              style: [:font_normal]
            ),
            Guppy.IR.div([Guppy.IR.text("Medium", id: "font_weight_medium")],
              id: "font_weight_medium_row",
              style: [:font_medium]
            ),
            Guppy.IR.div([Guppy.IR.text("Semibold", id: "font_weight_semibold")],
              id: "font_weight_semibold_row",
              style: [:font_semibold]
            ),
            Guppy.IR.div([Guppy.IR.text("Bold", id: "font_weight_bold")],
              id: "font_weight_bold_row",
              style: [:font_bold]
            ),
            Guppy.IR.div([Guppy.IR.text("Black", id: "font_weight_black")],
              id: "font_weight_black_row",
              style: [:font_black]
            )
          ],
          id: "font_weight_panel",
          style: [
            :flex,
            :flex_col,
            :gap_1,
            :text_base,
            :p_4,
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, :black}
          ]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div([Guppy.IR.text("xl", id: "text_size_xl")],
              id: "text_size_xl_row",
              style: [:text_xl]
            ),
            Guppy.IR.div([Guppy.IR.text("2xl", id: "text_size_2xl")],
              id: "text_size_2xl_row",
              style: [:text_2xl]
            ),
            Guppy.IR.div([Guppy.IR.text("3xl", id: "text_size_3xl")],
              id: "text_size_3xl_row",
              style: [:text_3xl]
            )
          ],
          id: "text_size_panel",
          style: [
            :flex,
            :flex_col,
            :gap_2,
            :p_4,
            :rounded_lg,
            :border_1,
            {:border_color, :white},
            {:bg, :gray}
          ]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [Guppy.IR.text("leading-none sample line one\nline two", id: "leading_none_text")],
              id: "leading_none_row",
              style: [:leading_none]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("leading-relaxed sample line one\nline two",
                  id: "leading_relaxed_text"
                )
              ],
              id: "leading_relaxed_row",
              style: [:leading_relaxed]
            )
          ],
          id: "line_height_panel",
          style: [
            :flex,
            :flex_col,
            :gap_2,
            :p_4,
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, :blue}
          ]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text(
              "This is a long line that should truncate inside a constrained width block to show ordered text overflow styling in the IR bridge.",
              id: "truncate_demo_label"
            )
          ],
          id: "truncate_demo",
          style: [
            :max_w_64,
            :overflow_x_hidden,
            :truncate,
            :p_2,
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, :blue}
          ]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text(
              "This is a longer paragraph intended to demonstrate line clamping in the bridge. It should stop after a small number of lines instead of expanding forever when the width is constrained.",
              id: "line_clamp_demo_label"
            )
          ],
          id: "line_clamp_demo",
          style: [
            :max_w_64,
            :line_clamp_2,
            :text_sm,
            :underline,
            :line_through,
            :p_2,
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, :gray}
          ]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div([Guppy.IR.text("sm", id: "radius_sm_label")],
              id: "radius_sm",
              style: [
                :p_2,
                :rounded_sm,
                :border_2,
                :border_dashed,
                {:border_color, :white},
                {:bg, :blue}
              ]
            ),
            Guppy.IR.div([Guppy.IR.text("lg", id: "radius_lg_label")],
              id: "radius_lg",
              style: [
                :p_2,
                :rounded_lg,
                :border_2,
                :border_dashed,
                {:border_color, :white},
                {:bg, :green},
                {:text_color, :black}
              ]
            ),
            Guppy.IR.div([Guppy.IR.text("xl", id: "radius_xl_label")],
              id: "radius_xl",
              style: [
                :p_2,
                :rounded_xl,
                :border_2,
                :border_dashed,
                {:border_color, :white},
                {:bg, :yellow},
                {:text_color, :black}
              ]
            ),
            Guppy.IR.div([Guppy.IR.text("2xl", id: "radius_2xl_label")],
              id: "radius_2xl",
              style: [
                :p_2,
                :rounded_2xl,
                :border_2,
                :border_dashed,
                {:border_color, :white},
                {:bg, :red}
              ]
            ),
            Guppy.IR.div([Guppy.IR.text("full", id: "radius_full_label")],
              id: "radius_full",
              style: [
                :p_2,
                :rounded_full,
                :border_2,
                :border_dashed,
                {:border_color, :white},
                {:bg, :gray}
              ]
            )
          ],
          id: "radius_border_gallery",
          style: [:flex, :flex_row, :flex_wrap, :gap_2, :w_full]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [Guppy.IR.text("320px × 180px @ 75% opacity", id: "custom_px_box_label")],
              id: "custom_px_box",
              style: [
                {:w_px, 320},
                {:h_px, 180},
                {:opacity, 0.75},
                :p_2,
                :rounded_lg,
                :border_1,
                {:border_color, :white},
                {:bg, :blue}
              ]
            ),
            Guppy.IR.div([Guppy.IR.text("24rem × 12rem", id: "custom_rem_box_label")],
              id: "custom_rem_box",
              style: [
                {:w_rem, 24.0},
                {:h_rem, 12.0},
                :p_2,
                :rounded_lg,
                :border_1,
                {:border_color, :white},
                {:bg, :green},
                {:text_color, :black}
              ]
            ),
            Guppy.IR.div(
              [Guppy.IR.text("hex colors + hover", id: "custom_hex_box_label")],
              id: "custom_hex_box",
              style: [
                {:w_px, 220},
                {:h_px, 120},
                :p_2,
                :rounded_lg,
                {:bg_hex, "#663399"},
                {:text_color_hex, "#f8f8f2"},
                {:border_color_hex, "#ff79c6"},
                :border_2
              ],
              hover_style: [
                {:bg_hex, "#7c3aed"},
                {:border_color_hex, "#facc15"},
                {:opacity, 0.9},
                :cursor_pointer
              ],
              events: %{hover: "style_hover"}
            ),
            Guppy.IR.div(
              [
                Guppy.IR.div([Guppy.IR.text("50% × 100%", id: "custom_frac_box_label")],
                  id: "custom_frac_box",
                  style: [
                    {:w_frac, 0.5},
                    {:h_frac, 1.0},
                    :p_2,
                    :rounded_lg,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :gray}
                  ]
                )
              ],
              id: "custom_frac_frame",
              style: [
                {:w_px, 320},
                {:h_px, 180},
                :p_2,
                :rounded_lg,
                :border_1,
                {:border_color, :white},
                {:bg, :black}
              ]
            )
          ],
          id: "custom_value_gallery",
          style: [:flex, :flex_row, :flex_wrap, :gap_2, :w_full]
        ),
        action_button(
          "Toggle palette",
          "toggle_palette_button",
          "toggle_palette",
          palette_color(state)
        ),
        action_button("Quit demo", "quit_demo_button", "quit_demo", :black)
      ],
      style: [{:bg_hex, @surface_panel}]
    )
  end

  defp layout_demo(_state) do
    panel(
      "layout_demo",
      [
        Guppy.IR.text("Flex layout behavior tokens"),
        Guppy.IR.text(
          "This page exercises wrap/nowrap, grow/shrink, grid, and spacing tokens in the ordered style list."
        ),
        Guppy.IR.div(
          [
            grid_cell("grid_header", "Header", [
              :col_span_full,
              {:bg, :white},
              {:text_color, :black}
            ]),
            grid_cell("grid_nav", "Nav", [{:col_span, 1}, {:row_span, 2}, {:bg, :blue}]),
            grid_cell("grid_content", "Content", [
              {:col_span, 3},
              {:row_span, 2},
              {:bg, :green},
              {:text_color, :black}
            ]),
            grid_cell("grid_side", "Aside", [{:col_span, 1}, {:row_span, 2}, {:bg, :red}]),
            grid_cell("grid_footer", "Footer", [
              :col_span_full,
              {:bg, :black},
              {:text_color, :white}
            ])
          ],
          id: "grid_examples",
          animation: %{
            id: "grid_examples_fade",
            duration_ms: 1_200,
            repeat: true,
            from: 0.85,
            to: 1.0
          },
          style: [:grid, {:grid_cols, 5}, {:grid_rows, 4}, :gap_1, :w_full, {:h_px, 220}, :p_2]
        ),
        Guppy.IR.div(
          [
            flex_chip("wrap_1", "wrap-1", [:flex_none, :w_32, {:bg, :blue}]),
            flex_chip("wrap_2", "wrap-2", [:flex_none, :w_32, {:bg, :green}]),
            flex_chip("wrap_3", "wrap-3", [
              :flex_none,
              :w_32,
              {:bg, :yellow},
              {:text_color, :black}
            ]),
            flex_chip("wrap_4", "wrap-4", [:flex_none, :w_32, {:bg, :red}]),
            flex_chip("wrap_5", "wrap-5", [:flex_none, :w_32, {:bg, :gray}]),
            flex_chip("wrap_6", "wrap-6", [:flex_none, :w_32, {:bg, :blue}])
          ],
          id: "wrap_row",
          style: [
            :flex,
            :flex_row,
            :flex_wrap,
            :gap_2,
            :w_full,
            :border_1,
            {:border_color, :white},
            :p_2
          ]
        ),
        Guppy.IR.div(
          [
            flex_chip("nowrap_fixed", "fixed", [:flex_none, :min_w_32, {:bg, :gray}]),
            flex_chip("nowrap_auto", "auto", [:flex_auto, :w_32, {:bg, :blue}]),
            flex_chip("nowrap_grow", "grow", [
              :flex_grow,
              :w_32,
              {:bg, :green},
              {:text_color, :black}
            ]),
            flex_chip("nowrap_shrink", "shrink", [
              :flex_shrink,
              :w_32,
              {:bg, :yellow},
              {:text_color, :black}
            ]),
            flex_chip("nowrap_shrink0", "shrink-0", [:flex_shrink_0, :w_96, {:bg, :red}])
          ],
          id: "nowrap_row",
          style: [
            :flex,
            :flex_row,
            :flex_nowrap,
            :items_start,
            :overflow_x_scroll,
            :gap_2,
            :w_full,
            :border_1,
            {:border_color, :white},
            :p_2
          ]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.div(
                  [Guppy.IR.text("p_1 + px_2 + py_2", id: "spacing_one_label")],
                  id: "spacing_one",
                  style: [
                    :p_1,
                    :px_2,
                    :py_2,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :blue}
                  ]
                )
              ],
              id: "spacing_one_frame",
              style: [:h_32, :p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :black}]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.div(
                  [Guppy.IR.text("pt/pr/pb/pl + m_2", id: "spacing_two_label")],
                  id: "spacing_two",
                  style: [
                    :pt_2,
                    :pr_2,
                    :pb_2,
                    :pl_2,
                    :m_2,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :green},
                    {:text_color, :black}
                  ]
                )
              ],
              id: "spacing_two_frame",
              style: [:h_32, :p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :black}]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.div(
                  [Guppy.IR.text("mx/my/mt/mr/mb/ml", id: "spacing_three_label")],
                  id: "spacing_three",
                  style: [
                    :mx_2,
                    :my_2,
                    :mt_2,
                    :mr_2,
                    :mb_2,
                    :ml_2,
                    :p_8,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :yellow},
                    {:text_color, :black}
                  ]
                )
              ],
              id: "spacing_three_frame",
              style: [:h_32, :p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :black}]
            )
          ],
          id: "spacing_examples",
          style: [:flex, :flex_col, :gap_4, :w_full, :border_1, {:border_color, :white}, :p_2]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text("relative container", id: "position_box_label"),
                Guppy.IR.div(
                  [Guppy.IR.text("badge", id: "position_badge_label")],
                  id: "position_badge",
                  style: [
                    :absolute,
                    :top_1,
                    :right_1,
                    :p_1,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :red},
                    :shadow_sm
                  ]
                ),
                Guppy.IR.div(
                  [Guppy.IR.text("inset overlay", id: "position_overlay_label")],
                  id: "position_overlay",
                  style: [
                    :absolute,
                    :inset_0,
                    :flex,
                    :items_center,
                    :justify_center,
                    :overflow_hidden,
                    {:text_color, :black},
                    {:bg, :yellow}
                  ]
                )
              ],
              id: "position_box",
              style: [
                :relative,
                :w_96,
                :h_32,
                :p_4,
                :rounded_md,
                :border_1,
                {:border_color, :white},
                {:bg, :blue},
                :shadow_md
              ]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("offset frame", id: "offset_frame_label"),
                Guppy.IR.div(
                  [Guppy.IR.text("anchored", id: "offset_anchor_label")],
                  id: "offset_anchor",
                  style: [
                    :absolute,
                    :top_2,
                    :right_2,
                    :p_1,
                    :rounded_md,
                    :border_t_1,
                    :border_r_1,
                    :border_b_1,
                    :border_l_1,
                    {:border_color, :white},
                    {:bg, :green},
                    {:text_color, :black},
                    :shadow_sm
                  ]
                )
              ],
              id: "offset_frame",
              style: [
                :relative,
                :w_96,
                :h_32,
                :rounded_md,
                :border_t_1,
                :border_r_1,
                :border_b_1,
                :border_l_1,
                {:border_color, :white},
                {:bg, :gray},
                :shadow_lg
              ],
              events: %{click: "div_increment"}
            ),
            Guppy.IR.div(
              [
                Guppy.IR.div(
                  [Guppy.IR.text("corner note", id: "corner_note_label")],
                  id: "corner_note",
                  style: [
                    :absolute,
                    :top_2,
                    :right_2,
                    :bottom_2,
                    :left_2,
                    :p_2,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :green},
                    {:text_color, :black}
                  ]
                )
              ],
              id: "corner_note_frame",
              style: [
                :relative,
                :w_96,
                :h_32,
                :rounded_md,
                :border_1,
                {:border_color, :white},
                {:bg, :black}
              ]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("max width / full constraints", id: "constraint_box_label"),
                Guppy.IR.div(
                  [Guppy.IR.text("max_w_64", id: "constraint_small")],
                  id: "constraint_small_box",
                  style: [
                    :max_w_64,
                    :p_2,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :red}
                  ]
                ),
                Guppy.IR.div(
                  [Guppy.IR.text("max_w_96 + max_h_full", id: "constraint_large")],
                  id: "constraint_large_box",
                  style: [
                    :max_w_96,
                    :max_h_full,
                    :p_2,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :blue}
                  ]
                ),
                Guppy.IR.div(
                  [
                    Guppy.IR.div(
                      [
                        Guppy.IR.text("min_h_full inside bounded frame",
                          id: "constraint_fill_label"
                        )
                      ],
                      id: "constraint_fill_inner",
                      style: [
                        :min_h_full,
                        :w_full,
                        :p_2,
                        :rounded_md,
                        :border_1,
                        {:border_color, :white},
                        {:bg, :green},
                        {:text_color, :black}
                      ]
                    )
                  ],
                  id: "constraint_fill_frame",
                  style: [
                    {:h_px, 160},
                    :w_full,
                    :p_2,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :black}
                  ]
                )
              ],
              id: "constraint_panel",
              style: [
                :w_full,
                :flex,
                :flex_col,
                :gap_2,
                :p_2,
                :rounded_md,
                :border_1,
                {:border_color, :white},
                {:bg, :gray}
              ]
            )
          ],
          id: "position_examples",
          style: [:flex, :flex_col, :gap_2, :w_full, :border_1, {:border_color, :white}, :p_2]
        )
      ],
      style: [{:bg_hex, @surface_panel}]
    )
  end

  defp scroll_demo(state) do
    narrow_lines =
      Enum.map(1..28, fn index ->
        Guppy.IR.div(
          [
            Guppy.IR.text(
              "narrow #{index}: palette=#{palette_color(state)} timer_ticks=#{state.timer_ticks}",
              id: "scroll_narrow_line_#{index}"
            )
          ],
          id: "scroll_narrow_row_#{index}",
          style: [
            :p_2,
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, if(rem(index, 2) == 0, do: :gray, else: :black)}
          ]
        )
      end)

    wide_lines =
      Enum.map(1..28, fn index ->
        Guppy.IR.div(
          [
            Guppy.IR.text(
              "wide #{index}: div_clicks=#{state.div_clicks} text_clicks=#{state.text_clicks}",
              id: "scroll_wide_line_#{index}"
            )
          ],
          id: "scroll_wide_row_#{index}",
          style: [
            :p_2,
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, if(rem(index, 2) == 0, do: :gray, else: :black)}
          ]
        )
      end)

    anchored_rows =
      Enum.map(1..24, fn index ->
        active? = index == state.scroll_anchor_index

        Guppy.IR.div(
          [
            Guppy.IR.text("tracked row #{index}", id: "tracked_row_#{index}_title"),
            Guppy.IR.text(
              "palette=#{palette_color(state)} timer_ticks=#{state.timer_ticks} div_clicks=#{state.div_clicks}",
              id: "tracked_row_#{index}_body"
            )
          ],
          id: "tracked_row_#{index}",
          anchor_scroll: true,
          scroll_to: active?,
          style: [
            :flex,
            :flex_col,
            :gap_1,
            :p_2,
            :rounded_md,
            :border_1,
            {:border_color, :white},
            {:bg, if(active?, do: :yellow, else: :gray)},
            {:text_color, if(active?, do: :black, else: :white)}
          ]
        )
      end)

    panel(
      "scroll_demo",
      [
        Guppy.IR.text("Scroll demo"),
        Guppy.IR.text(
          "This page exercises the explicit scroll node, tracked scroll state, scroll anchoring, and explicit scrollbar width values."
        ),
        Guppy.IR.text(
          "Use it to verify the right-hand detail panel scrolls while the left nav stays anchored."
        ),
        Guppy.IR.text(
          "The narrow/wide boxes intentionally overflow so scrollbar width differences should be easy to see while scrolling."
        ),
        Guppy.IR.div(
          [
            action_button(
              "Anchor previous row",
              "scroll_anchor_prev_button",
              "scroll_anchor_prev",
              :white
            ),
            action_button(
              "Anchor next row",
              "scroll_anchor_next_button",
              "scroll_anchor_next",
              :white
            ),
            Guppy.IR.text("active_anchor_row = #{state.scroll_anchor_index}",
              id: "active_anchor_row_label"
            )
          ],
          id: "scroll_anchor_controls",
          style: [:flex, :flex_row, :gap_2, :items_center, :w_full]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text("tracked + anchored scroll box", id: "tracked_scroll_title"),
            Guppy.IR.text(
              "Scroll this box manually, then move the active row. The box should keep its position across rerenders and bring the highlighted row into view."
            ),
            Guppy.IR.scroll(
              anchored_rows,
              id: "tracked_scroll_box",
              style: [
                :flex,
                :flex_col,
                :gap_2,
                :w_full,
                {:h_px, 280},
                {:scrollbar_width_px, 10},
                :p_2,
                :rounded_md,
                :border_1,
                {:border_color, :white},
                {:bg, :black}
              ]
            )
          ],
          id: "tracked_scroll_panel",
          style: [:flex, :flex_col, :gap_2, :w_full, :min_h_0]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text("narrow scrollbar width", id: "scroll_narrow_title"),
                Guppy.IR.scroll(
                  narrow_lines,
                  id: "scroll_narrow_box",
                  style: [
                    :flex,
                    :flex_col,
                    :gap_2,
                    :w_full,
                    {:h_px, 180},
                    {:scrollbar_width_px, 8},
                    :p_2,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :black}
                  ]
                )
              ],
              id: "scroll_narrow_panel",
              style: [:flex, :flex_col, :gap_2, :flex_1, :min_h_0, :w_full]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("wide scrollbar width", id: "scroll_wide_title"),
                Guppy.IR.scroll(
                  wide_lines,
                  id: "scroll_wide_box",
                  style: [
                    :flex,
                    :flex_col,
                    :gap_2,
                    :w_full,
                    {:h_px, 180},
                    {:scrollbar_width_rem, 1.0},
                    :p_2,
                    :rounded_md,
                    :border_1,
                    {:border_color, :white},
                    {:bg, :black}
                  ]
                )
              ],
              id: "scroll_wide_panel",
              style: [:flex, :flex_col, :gap_2, :flex_1, :min_h_0, :w_full]
            )
          ],
          id: "scroll_compare_row",
          style: [:flex, :flex_row, :gap_4, :items_start, :w_full]
        )
      ],
      style: [{:bg_hex, @surface_panel}]
    )
  end

  defp help_demo(_state) do
    panel(
      "help_demo",
      [
        Guppy.Markdown.render(%{
          id: "help_markdown",
          source:
            "## What to try\n\nUse the demos to exercise **native GPUI** features rendered from Elixir IR. Inline `code` and lists come from the Markdown component.\n\n- Runtime: refresh status without leaving the window.\n- Components: inspect `~GUI`, local function components, checkbox/select/popover controls, and animation.\n- Interactions: click text, controls, pointer, drag/drop, and keyboard pads.\n- Collections: use tree/table selection, list row controls, and canvas drawing.\n- Native shell: try menus, Dock menu, badges, file dialogs, clipboard, icon, and image."
        }),
        Guppy.IR.text("1. Runtime: refresh status without leaving the window."),
        Guppy.IR.text(
          "2. Components: toggle the checkbox, open the popover, rotate the palette, and watch the animated component card."
        ),
        Guppy.IR.text(
          "3. Interactions: click the div button, the text line, the pointer pad, and the keyboard pad, then start timer rerenders."
        ),
        Guppy.IR.text(
          "4. Collections: select tree rows, table rows/cells, row controls, and canvas states."
        ),
        Guppy.IR.text("5. Windows: open/close the aux window and kill the child owner process."),
        Guppy.IR.text(
          "6. Native shell: install menus/Dock menu, use dialogs, and read/write clipboard."
        ),
        Guppy.IR.text("7. Styles: rotate palette colors and inspect contrast/readability."),
        Guppy.IR.text("8. Layout: inspect flex wrap/grow/shrink behavior in the Layout demo."),
        Guppy.IR.text(
          "9. Scroll: select the Scroll demo and verify tracked scroll state, scroll anchoring, and nested scrollbar widths."
        ),
        Guppy.IR.text(
          "10. Close the traffic-light button on any window to test window_closed handling."
        ),
        Guppy.IR.div(
          [
            alignment_chip("justify_start", "start", [
              :flex,
              :flex_row,
              :justify_start,
              :items_start,
              :p_2,
              {:bg, :black}
            ]),
            alignment_chip("justify_end", "end", [
              :flex,
              :flex_row,
              :justify_end,
              :items_end,
              :p_2,
              {:bg, :black}
            ]),
            alignment_chip("justify_between", "between", [
              :flex,
              :flex_row,
              :justify_between,
              :p_2,
              {:bg, :black}
            ]),
            alignment_chip("justify_around", "around", [
              :flex,
              :flex_row,
              :justify_around,
              :p_2,
              {:bg, :black}
            ])
          ],
          id: "alignment_examples",
          style: [:flex, :flex_col, :gap_2, :w_full]
        )
      ],
      style: [{:bg_hex, @surface_panel}]
    )
  end

  defp component_feature_cards(state) do
    theme = palette_theme(palette_color(state))

    [
      component_card(
        "component_card_templates",
        "Template components",
        "~GUI",
        "Local function components keep example markup small while prop declarations catch bad calls early.",
        "This card is rendered by <.feature_card> with typed props and nested children.",
        feature_card_class("#172554", "#60a5fa", "#dbeafe")
      ),
      component_card(
        "component_card_controls",
        "Native controls",
        "forms",
        "Checkbox, select, text input, textarea, radio, and popover nodes all roundtrip to Elixir state.",
        "Toggle the checkbox below and watch the owning Elixir process rerender the full tree.",
        feature_card_class("#052e16", "#22c55e", "#dcfce7")
      ),
      component_card(
        "component_card_animation",
        "Opacity animation",
        "stable id",
        "Animations are keyed by stable ids so native state can survive full-tree replacements.",
        "This card pulses gently while the palette, checkbox, and select state continue to rerender.",
        feature_card_class(theme.soft, theme.border, @text_primary),
        %{
          id: "super_demo_component_card_pulse",
          duration_ms: 1_400,
          repeat: true,
          from: 0.78,
          to: 1.0
        }
      )
    ]
  end

  defp component_card(id, title, badge, body, detail, class, animation \\ nil) do
    %{
      id: id,
      title: title,
      badge: badge,
      body: body,
      detail: detail,
      detail_id: "#{id}_detail",
      class: class,
      animation: animation
    }
  end

  defp feature_card(assigns) do
    ~GUI"""
    <div id={@id} class={@class} animation={@animation}>
      <div id={@id <> "_header"} class="flex flex-row items-center justify-between gap-2">
        <text id={@id <> "_title"} class="text-base font-bold">{@title}</text>
        <text id={@id <> "_badge"} class="text-xs font-semibold px-2 py-2 rounded-full border-1 border-[#334155] bg-[#0b1220] text-[#cbd5e1]">{@badge}</text>
      </div>

      <text id={@id <> "_body"} class="text-sm leading-snug">{@body}</text>
      {@children}
    </div>
    """
  end

  defp feature_card_class(bg, border, text) do
    Enum.join(
      [
        "flex flex-col gap-2 p-4 rounded-xl border-1 shadow-sm",
        "bg-[#{bg}]",
        "border-[#{border}]",
        "text-[#{text}]"
      ],
      " "
    )
  end

  defp panel(id, children, opts) do
    base_style = [
      :flex,
      :flex_col,
      :gap_2,
      :p_4,
      :border_1,
      {:border_color_hex, @border_subtle},
      :rounded_lg,
      {:bg_hex, @surface_panel},
      {:text_color_hex, @text_primary}
    ]

    merged_style = base_style ++ Keyword.get(opts, :style, [])
    Guppy.IR.div(children, id: id, style: merged_style)
  end

  defp nav_button(demo_id, selected?, theme) do
    label = demo_label(demo_id)

    style =
      if selected? do
        [
          {:bg_hex, theme.accent},
          {:border_color_hex, theme.border},
          {:text_color_hex, theme.text}
        ]
      else
        [
          {:bg_hex, @surface_muted},
          {:border_color_hex, @border_subtle},
          {:text_color_hex, @text_secondary}
        ]
      end

    Guppy.IR.button(
      label,
      id: "nav_#{demo_id}",
      style: style,
      focus_style: [{:border_color_hex, @focus_ring}],
      active_style: [{:opacity, 0.82}],
      events: %{click: "select_demo:#{demo_id}"}
    )
  end

  defp alignment_chip(id, label, style) do
    Guppy.IR.div(
      [
        Guppy.IR.text(label, id: "#{id}_left"),
        Guppy.IR.text("•", id: "#{id}_middle"),
        Guppy.IR.text(label, id: "#{id}_right")
      ],
      id: id,
      style: [:border_1, {:border_color, :white}, {:text_color, :white}] ++ style
    )
  end

  defp flex_chip(id, label, style) do
    Guppy.IR.div(
      [Guppy.IR.text(label, id: "#{id}_label")],
      id: id,
      style:
        [:p_2, :h_32, :rounded_md, :border_1, {:border_color, :white}, {:text_color, :white}] ++
          style
    )
  end

  defp grid_cell(id, label, style) do
    Guppy.IR.div(
      [Guppy.IR.text(label, id: "#{id}_label")],
      id: id,
      style:
        [:flex, :items_center, :justify_center, :rounded_md, :border_1, {:border_color, :white}] ++
          style
    )
  end

  defp radio_option(label, value, selected_value) do
    Guppy.IR.radio(
      label,
      value,
      value == selected_value,
      id: "priority_#{value}",
      style: [:gap_2, :p_2, :rounded_md, :border_1, {:border_color, :white}],
      active_style: [{:opacity, 0.8}],
      events: %{change: "priority_changed"}
    )
  end

  defp action_button(label, id, callback, color) do
    theme = button_theme(color)

    Guppy.IR.button(
      label,
      id: id,
      style: [
        {:border_color_hex, theme.border},
        {:bg_hex, theme.bg},
        {:text_color_hex, theme.text}
      ],
      focus_style: [{:border_color_hex, @focus_ring}],
      active_style: [{:opacity, 0.8}],
      events: %{click: callback}
    )
  end

  defp palette_swatch(color, selected?) do
    theme = palette_theme(color)

    style =
      [
        :flex,
        :items_center,
        :justify_center,
        :w_32,
        :p_2,
        :rounded_md,
        :cursor_pointer,
        {:bg_hex, theme.accent},
        {:text_color_hex, theme.text},
        {:border_color_hex, if(selected?, do: @focus_ring, else: theme.border)}
      ] ++ if(selected?, do: [:border_2, :shadow_md], else: [:border_1])

    label = if selected?, do: "#{theme.label} ✓", else: theme.label

    Guppy.IR.div(
      [Guppy.IR.text(label, id: "palette_swatch_#{color}_label")],
      id: "palette_swatch_#{color}",
      style: style,
      hover_style: [
        {:border_color_hex, @focus_ring},
        {:bg_hex, theme.soft},
        :shadow_md
      ],
      active_style: [{:opacity, 0.86}],
      events: %{click: "select_palette:#{color}"}
    )
  end

  defp disabled_action_button(label, id) do
    Guppy.IR.button(
      label,
      id: id,
      disabled: true,
      disabled_style: [
        {:opacity, 0.45},
        {:bg_hex, @surface_muted},
        {:border_color_hex, @border_subtle},
        {:text_color_hex, @text_muted}
      ],
      style: [
        {:border_color_hex, @focus_ring},
        {:bg_hex, "#facc15"},
        {:text_color_hex, "#111827"}
      ],
      events: %{click: "disabled_increment"}
    )
  end

  defp demo_label(:runtime), do: "Runtime"
  defp demo_label(:components), do: "Components"
  defp demo_label(:interactions), do: "Interactions"
  defp demo_label(:collections), do: "Collections"
  defp demo_label(:windows), do: "Windows"
  defp demo_label(:native_shell), do: "Native shell"
  defp demo_label(:styles), do: "Styles"
  defp demo_label(:layout), do: "Layout"
  defp demo_label(:scroll), do: "Scroll"
  defp demo_label(:help), do: "Help"

  defp palette_color(state), do: Enum.at(@palette, state.palette_index)

  defp palette_theme(:gray),
    do: palette_theme("Slate", "#334155", "#1e293b", "#64748b", "#f8fafc")

  defp palette_theme(:red), do: palette_theme("Rose", "#be123c", "#3f0a1f", "#fb7185", "#fff1f2")

  defp palette_theme(:green),
    do: palette_theme("Emerald", "#047857", "#052e2b", "#34d399", "#ecfdf5")

  defp palette_theme(:blue), do: palette_theme("Sky", "#2563eb", "#172554", "#60a5fa", "#eff6ff")

  defp palette_theme(:yellow),
    do: palette_theme("Amber", "#f59e0b", "#451a03", "#fbbf24", "#111827")

  defp palette_theme(label, accent, soft, border, text) do
    %{label: label, accent: accent, soft: soft, border: border, text: text}
  end

  defp button_theme(color) when color in [:gray, :red, :green, :blue, :yellow] do
    theme = palette_theme(color)
    button_theme(theme.accent, theme.border, theme.text)
  end

  defp button_theme(:white), do: button_theme("#f8fafc", "#cbd5e1", "#0f172a")
  defp button_theme(:black), do: button_theme("#020617", "#475569", "#f8fafc")
  defp button_theme(bg, border, text), do: %{bg: bg, border: border, text: text}

  defp aux_window_ir do
    ~GUI"""
    <div id="aux_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <text id="aux_title" class="text-2xl font-black">Auxiliary window</text>
      <text>This window is owned by the main demo process.</text>
      <div id="aux_close_button" click="close_aux_window" class="p-4 rounded-md bg-yellow text-black cursor-pointer">
        <text id="aux_close_label">Close this window</text>
      </div>
    </div>
    """
  end

  defp child_owner_loop(parent) do
    {:ok, view_id} =
      Guppy.open_window(
        child_owner_ir(),
        window_bounds: [width: 640, height: 420],
        titlebar: [title: "Guppy child owner window"]
      )

    send(parent, {:child_owner_ready, self(), view_id})
    child_owner_receive(parent, view_id)
  end

  defp child_owner_ir do
    ~GUI"""
    <div id="child_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <text id="child_title" class="text-2xl font-black">Child owner window</text>
      <text>Kill the owner from the main demo to test DOWN cleanup.</text>
      <text>Or close this window manually with the traffic-light button.</text>
    </div>
    """
  end

  defp child_owner_receive(parent, view_id) do
    receive do
      :stop ->
        _ = Guppy.close_window(view_id)
        send(parent, {:child_owner_closed, self(), :stopped})

      {:guppy_event, ^view_id, %{type: :window_closed}} ->
        send(parent, {:child_owner_closed, self(), :manual_close})

      _other ->
        child_owner_receive(parent, view_id)
    end
  end
end

Guppy.SuperDemo.run()
