defmodule Guppy.SuperDemo do
  @palette [:gray, :red, :green, :blue, :yellow]
  @timer_ticks 5
  @timer_interval_ms 1_000
  @demo_ids [:runtime, :interactions, :windows, :styles, :layout, :scroll, :help]

  def run do
    Mix.Task.run("app.start")

    {:ok, main_view_id} = Guppy.open_window(self())

    state =
      %{
        main_view_id: main_view_id,
        aux_view_id: nil,
        child_owner_pid: nil,
        child_monitor_ref: nil,
        child_view_id: nil,
        selected_demo: :runtime,
        div_clicks: 0,
        text_clicks: 0,
        timer_ticks: 0,
        timer_remaining: 0,
        timer_running: false,
        palette_index: 0,
        last_event: "booted",
        statuses: capture_statuses()
      }

    :ok = Guppy.mount(main_view_id, render(state))
    loop(state)
  end

  defp loop(state) do
    receive do
      {:guppy_event, view_id, %{type: :click} = event} ->
        state
        |> handle_click(view_id, event)
        |> continue()

      {:guppy_event, view_id, %{type: :hover} = event} ->
        state
        |> handle_hover(view_id, event)
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

  defp handle_click(state, view_id, %{id: node_id, callback: callback_id}) do
    cond do
      view_id == state.main_view_id ->
        handle_main_click(state, node_id, callback_id)

      view_id == state.aux_view_id ->
        handle_aux_click(state, node_id, callback_id)

      true ->
        state
        |> Map.put(:last_event, "click from unknown view #{view_id}: #{node_id}/#{callback_id}")
        |> rerender!()
    end
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
        |> Map.put(:last_event, "hover #{if hovered, do: "enter", else: "leave"} #{node_id}/#{callback_id}")
        |> rerender!()

      view_id == state.aux_view_id ->
        state
        |> Map.put(:last_event, "aux hover #{if hovered, do: "enter", else: "leave"} #{node_id}/#{callback_id}")
        |> rerender!()

      true ->
        state
        |> Map.put(:last_event, "hover from unknown view #{view_id}: #{node_id}/#{callback_id}")
        |> rerender!()
    end
  end

  defp handle_main_click(state, node_id, callback_id) do
    cond do
      String.starts_with?(callback_id, "select_demo:") ->
        demo_id = callback_id |> String.split(":", parts: 2) |> List.last() |> String.to_existing_atom()

        state
        |> Map.put(:selected_demo, demo_id)
        |> Map.put(:last_event, "selected #{demo_id} from #{node_id}")
        |> rerender!()

      true ->
        handle_main_action(state, node_id, callback_id)
    end
  end

  defp handle_main_action(state, node_id, callback_id) do
    case callback_id do
      "refresh_status" ->
        state
        |> Map.put(:last_event, "refreshed status from #{node_id}")
        |> refresh_statuses()
        |> rerender!()

      "toggle_palette" ->
        state
        |> Map.update!(:palette_index, &rem(&1 + 1, length(@palette)))
        |> Map.put(:last_event, "toggled palette from #{node_id}")
        |> rerender!()

      "div_increment" ->
        state
        |> Map.update!(:div_clicks, &(&1 + 1))
        |> Map.put(:last_event, "div click via #{node_id}")
        |> rerender!()

      "text_increment" ->
        state
        |> Map.update!(:text_clicks, &(&1 + 1))
        |> Map.put(:last_event, "text click via #{node_id}")
        |> rerender!()

      "start_timer" ->
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

      "open_aux_window" ->
        open_aux_window(state, node_id)

      "close_aux_window" ->
        close_aux_window(state, "main control")

      "spawn_child_owner" ->
        spawn_child_owner(state)

      "kill_child_owner" ->
        kill_child_owner(state)

      "quit_demo" ->
        {:stop, Map.put(state, :last_event, "quit requested from #{node_id}")}

      _ ->
        state
        |> Map.put(:last_event, "unhandled main click #{node_id}/#{callback_id}")
        |> rerender!()
    end
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

  defp open_aux_window(%{aux_view_id: view_id} = state, _node_id) when not is_nil(view_id) do
    state
    |> Map.put(:last_event, "auxiliary window already open")
    |> rerender!()
  end

  defp open_aux_window(state, node_id) do
    case Guppy.open_window(self()) do
      {:ok, aux_view_id} ->
        :ok = Guppy.mount(aux_view_id, aux_window_ir())

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
  end

  defp rerender!(state) do
    case Guppy.update(state.main_view_id, render(state)) do
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
          style: [:flex, :flex_1, :w_full, :max_h_full, :gap_2]
        )
      ],
      id: "super_demo_root",
      style: [:size_full, :flex, :flex_col, :gap_2, :p_4]
    )
  end

  defp header_panel(state) do
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
        Guppy.IR.text("Select a demo on the left. The detail panel on the right updates in place.")
      ],
      style: [{:bg, :gray}]
    )
  end

  defp nav_panel(state) do
    items =
      Enum.map(@demo_ids, fn demo_id ->
        nav_button(demo_id, state.selected_demo == demo_id)
      end)

    panel(
      "nav_panel",
      [
        Guppy.IR.text("Demos", id: "nav_title"),
        Guppy.IR.text("The main window stays anchored at the top; switch demos instead of scrolling."),
        Guppy.IR.div(items, id: "nav_items", style: [:flex, :flex_col, :w_full, :gap_2])
      ],
      style: [:w_64, :max_h_full, :flex_col, :items_start, :p_4, {:bg, :gray}]
    )
  end

  defp detail_panel(state) do
    panel(
      "detail_panel",
      [
        Guppy.IR.text("selected_demo = #{state.selected_demo}", id: "selected_demo_label"),
        Guppy.IR.text("native_view_count = #{inspect(state.statuses.native_view_count)}"),
        detail_content(state)
      ],
      style: [:flex, :flex_col, :flex_1, :w_full, :max_h_full, :gap_2, :p_4, :overflow_y_scroll]
    )
  end

  defp detail_content(%{selected_demo: :runtime} = state), do: runtime_demo(state)
  defp detail_content(%{selected_demo: :interactions} = state), do: interactions_demo(state)
  defp detail_content(%{selected_demo: :windows} = state), do: windows_demo(state)
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
      style: [{:bg, :gray}]
    )
  end

  defp interactions_demo(state) do
    panel(
      "interactions_demo",
      [
        Guppy.IR.text("Clicks and rerenders"),
        Guppy.IR.text("div_clicks = #{state.div_clicks}"),
        action_button("Increment div clicks", "div_button", "div_increment", :blue),
        Guppy.IR.text(
          "Increment text clicks by clicking this line",
          id: "text_increment_line",
          events: %{click: "text_increment"}
        ),
        Guppy.IR.text("text_clicks = #{state.text_clicks}"),
        action_button("Start timer rerender demo", "timer_button", "start_timer", :green),
        Guppy.IR.text("timer_ticks = #{state.timer_ticks}"),
        Guppy.IR.text("timer_running = #{state.timer_running}"),
        Guppy.IR.text("timer_remaining = #{state.timer_remaining}")
      ],
      style: [{:bg, :gray}]
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
        action_button("Spawn child-owner window", "spawn_child_button", "spawn_child_owner", :green),
        action_button("Kill child owner (tests DOWN cleanup)", "kill_child_button", "kill_child_owner", :red)
      ],
      style: [{:bg, :gray}]
    )
  end

  defp styles_demo(state) do
    panel(
      "styles_demo",
      [
        Guppy.IR.text("Style tokens and palette changes"),
        Guppy.IR.text("palette = #{palette_color(state)}"),
        Guppy.IR.div(
          [
            Guppy.IR.text("Preview area", id: "preview_title"),
            Guppy.IR.text("Click the button below to rotate colors.", id: "preview_text")
          ],
          id: "preview_panel",
          style: [
            :p_6,
            :rounded_md,
            :border_1,
            {:border_color, contrast_border_color(palette_color(state))},
            {:bg, palette_color(state)},
            {:text_color, contrast_text_color(palette_color(state))}
          ]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text("Centered large italic text", id: "text_style_centered"),
            Guppy.IR.text("This container uses inherited text styling tokens.", id: "text_style_centered_body")
          ],
          id: "text_style_panel",
          style: [:text_center, :text_lg, :italic, :p_4, :rounded_md, :border_1, {:border_color, :white}, {:bg, :gray}]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div([Guppy.IR.text("Thin", id: "font_weight_thin")], id: "font_weight_thin_row", style: [:font_thin]),
            Guppy.IR.div([Guppy.IR.text("Light", id: "font_weight_light")], id: "font_weight_light_row", style: [:font_light]),
            Guppy.IR.div([Guppy.IR.text("Normal", id: "font_weight_normal")], id: "font_weight_normal_row", style: [:font_normal]),
            Guppy.IR.div([Guppy.IR.text("Medium", id: "font_weight_medium")], id: "font_weight_medium_row", style: [:font_medium]),
            Guppy.IR.div([Guppy.IR.text("Semibold", id: "font_weight_semibold")], id: "font_weight_semibold_row", style: [:font_semibold]),
            Guppy.IR.div([Guppy.IR.text("Bold", id: "font_weight_bold")], id: "font_weight_bold_row", style: [:font_bold]),
            Guppy.IR.div([Guppy.IR.text("Black", id: "font_weight_black")], id: "font_weight_black_row", style: [:font_black])
          ],
          id: "font_weight_panel",
          style: [:flex, :flex_col, :gap_1, :text_base, :p_4, :rounded_md, :border_1, {:border_color, :white}, {:bg, :black}]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div([Guppy.IR.text("xl", id: "text_size_xl")], id: "text_size_xl_row", style: [:text_xl]),
            Guppy.IR.div([Guppy.IR.text("2xl", id: "text_size_2xl")], id: "text_size_2xl_row", style: [:text_2xl]),
            Guppy.IR.div([Guppy.IR.text("3xl", id: "text_size_3xl")], id: "text_size_3xl_row", style: [:text_3xl])
          ],
          id: "text_size_panel",
          style: [:flex, :flex_col, :gap_2, :p_4, :rounded_lg, :border_1, {:border_color, :white}, {:bg, :gray}]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div([Guppy.IR.text("leading-none sample line one\nline two", id: "leading_none_text")], id: "leading_none_row", style: [:leading_none]),
            Guppy.IR.div([Guppy.IR.text("leading-relaxed sample line one\nline two", id: "leading_relaxed_text")], id: "leading_relaxed_row", style: [:leading_relaxed])
          ],
          id: "line_height_panel",
          style: [:flex, :flex_col, :gap_2, :p_4, :rounded_md, :border_1, {:border_color, :white}, {:bg, :blue}]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text("This is a long line that should truncate inside a constrained width block to show ordered text overflow styling in the IR bridge.", id: "truncate_demo_label")
          ],
          id: "truncate_demo",
          style: [:max_w_64, :overflow_x_hidden, :truncate, :p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :blue}]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text("This is a longer paragraph intended to demonstrate line clamping in the bridge. It should stop after a small number of lines instead of expanding forever when the width is constrained.", id: "line_clamp_demo_label")
          ],
          id: "line_clamp_demo",
          style: [:max_w_64, :line_clamp_2, :text_sm, :underline, :line_through, :p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :gray}]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div([Guppy.IR.text("sm", id: "radius_sm_label")], id: "radius_sm", style: [:p_2, :rounded_sm, :border_2, :border_dashed, {:border_color, :white}, {:bg, :blue}]),
            Guppy.IR.div([Guppy.IR.text("lg", id: "radius_lg_label")], id: "radius_lg", style: [:p_2, :rounded_lg, :border_2, :border_dashed, {:border_color, :white}, {:bg, :green}, {:text_color, :black}]),
            Guppy.IR.div([Guppy.IR.text("xl", id: "radius_xl_label")], id: "radius_xl", style: [:p_2, :rounded_xl, :border_2, :border_dashed, {:border_color, :white}, {:bg, :yellow}, {:text_color, :black}]),
            Guppy.IR.div([Guppy.IR.text("2xl", id: "radius_2xl_label")], id: "radius_2xl", style: [:p_2, :rounded_2xl, :border_2, :border_dashed, {:border_color, :white}, {:bg, :red}]),
            Guppy.IR.div([Guppy.IR.text("full", id: "radius_full_label")], id: "radius_full", style: [:p_2, :rounded_full, :border_2, :border_dashed, {:border_color, :white}, {:bg, :gray}])
          ],
          id: "radius_border_gallery",
          style: [:flex, :flex_row, :flex_wrap, :gap_2, :w_full]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div([Guppy.IR.text("320px × 180px @ 75% opacity", id: "custom_px_box_label")], id: "custom_px_box", style: [{:w_px, 320}, {:h_px, 180}, {:opacity, 0.75}, :p_2, :rounded_lg, :border_1, {:border_color, :white}, {:bg, :blue}]),
            Guppy.IR.div([Guppy.IR.text("24rem × 12rem", id: "custom_rem_box_label")], id: "custom_rem_box", style: [{:w_rem, 24.0}, {:h_rem, 12.0}, :p_2, :rounded_lg, :border_1, {:border_color, :white}, {:bg, :green}, {:text_color, :black}]),
            Guppy.IR.div(
              [Guppy.IR.text("hex colors + hover", id: "custom_hex_box_label")],
              id: "custom_hex_box",
              style: [{:w_px, 220}, {:h_px, 120}, :p_2, :rounded_lg, {:bg_hex, "#663399"}, {:text_color_hex, "#f8f8f2"}, {:border_color_hex, "#ff79c6"}, :border_2],
              hover_style: [{:bg_hex, "#7c3aed"}, {:border_color_hex, "#facc15"}, {:opacity, 0.9}, :cursor_pointer],
              events: %{hover: "style_hover"}
            ),
            Guppy.IR.div(
              [
                Guppy.IR.div([Guppy.IR.text("50% × 100%", id: "custom_frac_box_label")], id: "custom_frac_box", style: [{:w_frac, 0.5}, {:h_frac, 1.0}, :p_2, :rounded_lg, :border_1, {:border_color, :white}, {:bg, :gray}])
              ],
              id: "custom_frac_frame",
              style: [{:w_px, 320}, {:h_px, 180}, :p_2, :rounded_lg, :border_1, {:border_color, :white}, {:bg, :black}]
            )
          ],
          id: "custom_value_gallery",
          style: [:flex, :flex_row, :flex_wrap, :gap_2, :w_full]
        ),
        action_button("Toggle palette", "toggle_palette_button", "toggle_palette", :white),
        action_button("Quit demo", "quit_demo_button", "quit_demo", :black)
      ],
      style: [{:bg, :gray}]
    )
  end

  defp layout_demo(_state) do
    panel(
      "layout_demo",
      [
        Guppy.IR.text("Flex layout behavior tokens"),
        Guppy.IR.text("This page exercises wrap/nowrap, grow/shrink, and spacing tokens in the ordered style list."),
        Guppy.IR.div(
          [
            flex_chip("wrap_1", "wrap-1", [:flex_none, :w_32, {:bg, :blue}]),
            flex_chip("wrap_2", "wrap-2", [:flex_none, :w_32, {:bg, :green}]),
            flex_chip("wrap_3", "wrap-3", [:flex_none, :w_32, {:bg, :yellow}, {:text_color, :black}]),
            flex_chip("wrap_4", "wrap-4", [:flex_none, :w_32, {:bg, :red}]),
            flex_chip("wrap_5", "wrap-5", [:flex_none, :w_32, {:bg, :gray}]),
            flex_chip("wrap_6", "wrap-6", [:flex_none, :w_32, {:bg, :blue}])
          ],
          id: "wrap_row",
          style: [:flex, :flex_row, :flex_wrap, :gap_2, :w_full, :border_1, {:border_color, :white}, :p_2]
        ),
        Guppy.IR.div(
          [
            flex_chip("nowrap_fixed", "fixed", [:flex_none, :min_w_32, {:bg, :gray}]),
            flex_chip("nowrap_auto", "auto", [:flex_auto, :w_32, {:bg, :blue}]),
            flex_chip("nowrap_grow", "grow", [:flex_grow, :w_32, {:bg, :green}, {:text_color, :black}]),
            flex_chip("nowrap_shrink", "shrink", [:flex_shrink, :w_32, {:bg, :yellow}, {:text_color, :black}]),
            flex_chip("nowrap_shrink0", "shrink-0", [:flex_shrink_0, :w_96, {:bg, :red}])
          ],
          id: "nowrap_row",
          style: [:flex, :flex_row, :flex_nowrap, :overflow_x_scroll, :gap_2, :w_full, :border_1, {:border_color, :white}, :p_2]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [Guppy.IR.text("p_1 + px_2 + py_2", id: "spacing_one_label")],
              id: "spacing_one",
              style: [:p_1, :px_2, :py_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :blue}]
            ),
            Guppy.IR.div(
              [Guppy.IR.text("pt/pr/pb/pl + m_2", id: "spacing_two_label")],
              id: "spacing_two",
              style: [:pt_2, :pr_2, :pb_2, :pl_2, :m_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :green}, {:text_color, :black}]
            ),
            Guppy.IR.div(
              [Guppy.IR.text("mx/my/mt/mr/mb/ml", id: "spacing_three_label")],
              id: "spacing_three",
              style: [:mx_2, :my_2, :mt_2, :mr_2, :mb_2, :ml_2, :p_8, :rounded_md, :border_1, {:border_color, :white}, {:bg, :yellow}, {:text_color, :black}]
            )
          ],
          id: "spacing_examples",
          style: [:flex, :flex_col, :gap_1, :gap_4, :w_full, :border_1, {:border_color, :white}, :p_2]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [
                Guppy.IR.text("relative container", id: "position_box_label"),
                Guppy.IR.div(
                  [Guppy.IR.text("badge", id: "position_badge_label")],
                  id: "position_badge",
                  style: [:absolute, :top_1, :right_1, :p_1, :rounded_md, :border_1, {:border_color, :white}, {:bg, :red}, :shadow_sm]
                ),
                Guppy.IR.div(
                  [Guppy.IR.text("inset overlay", id: "position_overlay_label")],
                  id: "position_overlay",
                  style: [:absolute, :inset_0, :flex, :items_center, :justify_center, :overflow_hidden, {:text_color, :black}, {:bg, :yellow}]
                )
              ],
              id: "position_box",
              style: [:relative, :w_96, :h_32, :p_4, :rounded_md, :border_1, {:border_color, :white}, {:bg, :blue}, :shadow_md]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("offset frame", id: "offset_frame_label"),
                Guppy.IR.div(
                  [Guppy.IR.text("anchored", id: "offset_anchor_label")],
                  id: "offset_anchor",
                  style: [:absolute, :top_2, :right_2, :p_1, :rounded_md, :border_t_1, :border_r_1, :border_b_1, :border_l_1, {:border_color, :white}, {:bg, :green}, {:text_color, :black}, :shadow_sm]
                )
              ],
              id: "offset_frame",
              style: [:relative, :w_96, :h_32, :rounded_md, :border_t_1, :border_r_1, :border_b_1, :border_l_1, {:border_color, :white}, {:bg, :gray}, :shadow_lg],
              events: %{click: "div_increment"}
            ),
            Guppy.IR.div(
              [
                Guppy.IR.div(
                  [Guppy.IR.text("corner note", id: "corner_note_label")],
                  id: "corner_note",
                  style: [:absolute, :top_2, :right_2, :bottom_2, :left_2, :p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :green}, {:text_color, :black}]
                )
              ],
              id: "corner_note_frame",
              style: [:relative, :w_96, :h_32, :rounded_md, :border_1, {:border_color, :white}, {:bg, :black}]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("max width / full constraints", id: "constraint_box_label"),
                Guppy.IR.div(
                  [Guppy.IR.text("max_w_64", id: "constraint_small")],
                  id: "constraint_small_box",
                  style: [:max_w_64, :p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :red}]
                ),
                Guppy.IR.div(
                  [Guppy.IR.text("max_w_96 + max_h_full", id: "constraint_large")],
                  id: "constraint_large_box",
                  style: [:max_w_96, :max_h_full, :p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :blue}]
                )
              ],
              id: "constraint_panel",
              style: [:min_h_full, :max_w_full, :w_full, :flex, :flex_col, :gap_2, :p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, :gray}]
            )
          ],
          id: "position_examples",
          style: [:relative, :flex, :flex_col, :gap_2, :w_full, :border_1, {:border_color, :white}, :p_2]
        )
      ],
      style: [{:bg, :gray}]
    )
  end

  defp scroll_demo(state) do
    long_lines =
      Enum.map(1..24, fn index ->
        Guppy.IR.text(
          "Scroll line #{index}: palette=#{palette_color(state)} div_clicks=#{state.div_clicks} text_clicks=#{state.text_clicks} timer_ticks=#{state.timer_ticks}",
          id: "scroll_line_#{index}"
        )
      end)

    panel(
      "scroll_demo",
      [
        Guppy.IR.text("Scroll demo"),
        Guppy.IR.text("This panel is intentionally taller than the available area."),
        Guppy.IR.text("Use it to verify the right-hand detail panel scrolls while the left nav stays anchored.")
      ] ++ long_lines,
      style: [{:bg, :gray}]
    )
  end

  defp help_demo(_state) do
    panel(
      "help_demo",
      [
        Guppy.IR.text("What to try"),
        Guppy.IR.text("1. Runtime: refresh status without leaving the window."),
        Guppy.IR.text("2. Interactions: click the div button and the text line, then start timer rerenders."),
        Guppy.IR.text("3. Windows: open/close the aux window and kill the child owner process."),
        Guppy.IR.text("4. Styles: rotate palette colors and inspect contrast/readability."),
        Guppy.IR.text("5. Layout: inspect flex wrap/grow/shrink behavior in the Layout demo."),
        Guppy.IR.text("6. Scroll: select the Scroll demo and verify the detail pane scrolls."),
        Guppy.IR.text("7. Close the traffic-light button on any window to test window_closed handling."),
        Guppy.IR.div(
          [
            alignment_chip("justify_start", "start", [:flex, :flex_row, :justify_start, :items_start, :p_2, {:bg, :black}]),
            alignment_chip("justify_end", "end", [:flex, :flex_row, :justify_end, :items_end, :p_2, {:bg, :black}]),
            alignment_chip("justify_between", "between", [:flex, :flex_row, :justify_between, :p_2, {:bg, :black}]),
            alignment_chip("justify_around", "around", [:flex, :flex_row, :justify_around, :p_2, {:bg, :black}])
          ],
          id: "alignment_examples",
          style: [:flex, :flex_col, :gap_2, :w_full]
        )
      ],
      style: [{:bg, :gray}]
    )
  end

  defp panel(id, children, opts) do
    base_style = [:flex, :flex_col, :gap_2, :p_4, :border_1, {:border_color, :white}, :rounded_md]
    merged_style = base_style ++ Keyword.get(opts, :style, [])
    Guppy.IR.div(children, id: id, style: merged_style)
  end

  defp nav_button(demo_id, selected?) do
    label = demo_label(demo_id)
    bg = if selected?, do: :blue, else: :gray

    Guppy.IR.div(
      [Guppy.IR.text(label, id: "nav_#{demo_id}_label")],
      id: "nav_#{demo_id}",
      style: [:p_2, :rounded_md, :border_1, {:border_color, :white}, {:bg, bg}, {:text_color, :white}, :cursor_pointer],
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
      style: [:p_2, :h_32, :rounded_md, :border_1, {:border_color, :white}, {:text_color, :white}] ++ style
    )
  end

  defp action_button(label, id, callback, color) do
    Guppy.IR.div(
      [Guppy.IR.text(label, id: "#{id}_label")],
      id: id,
      style: [
        :p_2,
        :rounded_md,
        :border_1,
        {:border_color, contrast_border_color(color)},
        {:bg, color},
        {:text_color, contrast_text_color(color)},
        :cursor_pointer
      ],
      events: %{click: callback}
    )
  end

  defp demo_label(:runtime), do: "Runtime"
  defp demo_label(:interactions), do: "Interactions"
  defp demo_label(:windows), do: "Windows"
  defp demo_label(:styles), do: "Styles"
  defp demo_label(:layout), do: "Layout"
  defp demo_label(:scroll), do: "Scroll"
  defp demo_label(:help), do: "Help"

  defp palette_color(state), do: Enum.at(@palette, state.palette_index)

  defp contrast_text_color(color) when color in [:yellow, :white, :green], do: :black
  defp contrast_text_color(_color), do: :white

  defp contrast_border_color(color) when color in [:white, :yellow], do: :black
  defp contrast_border_color(_color), do: :white

  defp aux_window_ir do
    Guppy.IR.div(
      [
        Guppy.IR.text("Auxiliary window", id: "aux_title"),
        Guppy.IR.text("This window is owned by the main demo process."),
        Guppy.IR.div(
          [Guppy.IR.text("Close this window", id: "aux_close_label")],
          id: "aux_close_button",
          style: [:p_4, {:bg, :yellow}, {:text_color, :black}, :rounded_md, :cursor_pointer],
          events: %{click: "close_aux_window"}
        )
      ],
      id: "aux_root",
      style: [:flex, :flex_col, :gap_2, :p_4]
    )
  end

  defp child_owner_loop(parent) do
    {:ok, view_id} = Guppy.open_window(self())

    :ok =
      Guppy.mount(
        view_id,
        Guppy.IR.div(
          [
            Guppy.IR.text("Child owner window", id: "child_title"),
            Guppy.IR.text("Kill the owner from the main demo to test DOWN cleanup."),
            Guppy.IR.text("Or close this window manually with the traffic-light button.")
          ],
          id: "child_root",
          style: [:flex, :flex_col, :gap_2, :p_4, {:bg, :gray}, :rounded_md]
        )
      )

    send(parent, {:child_owner_ready, self(), view_id})
    child_owner_receive(parent, view_id)
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
