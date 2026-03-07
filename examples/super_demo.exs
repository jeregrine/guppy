defmodule Guppy.SuperDemo do
  @palette [:gray, :red, :green, :blue, :yellow]
  @timer_ticks 5
  @timer_interval_ms 1_000

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

  defp continue(state) do
    loop(state)
  end

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

  defp handle_main_click(state, node_id, callback_id) do
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
    if state.aux_view_id do
      _ = Guppy.close_window(state.aux_view_id)
    end

    if state.child_owner_pid do
      send(state.child_owner_pid, :stop)
    end
  end

  defp rerender!(state) do
    case Guppy.update(state.main_view_id, render(state)) do
      :ok -> state
      {:error, :unknown_view_id} -> {:stop, state}
      {:error, reason} -> raise "failed to update super demo: #{inspect(reason)}"
    end
  end

  defp refresh_statuses(state) do
    Map.put(state, :statuses, capture_statuses())
  end

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
        section("super demo", [
          Guppy.IR.text("Guppy super demo"),
          Guppy.IR.text("Every major tracer-shot feature is testable from this window."),
          Guppy.IR.text("last_event = #{state.last_event}")
        ]),
        row("top_row", [
          section("runtime", runtime_lines(state), style: %{bg: :gray, rounded_md: true, p_4: true}),
          section("interactions", interaction_lines(state))
        ]),
        row("middle_row", [
          section("windows", window_lines(state)),
          section("preview", preview_lines(state), style: %{bg: palette_color(state), text_color: contrast_text_color(palette_color(state)), rounded_md: true, p_4: true})
        ]),
        section("controls", control_lines())
      ],
      id: "super_demo_root",
      style: %{flex: true, flex_col: true, gap_2: true, p_4: true}
    )
  end

  defp runtime_lines(state) do
    [
      Guppy.IR.text("load_status = #{inspect(state.statuses.load_status)}"),
      Guppy.IR.text("native_build_info = #{inspect(state.statuses.native_build_info)}"),
      Guppy.IR.text("native_runtime_status = #{inspect(state.statuses.native_runtime_status)}"),
      Guppy.IR.text("native_gui_status = #{inspect(state.statuses.native_gui_status)}"),
      Guppy.IR.text("ping = #{inspect(state.statuses.ping)}"),
      Guppy.IR.text("native_view_count = #{inspect(state.statuses.native_view_count)}")
    ]
  end

  defp interaction_lines(state) do
    [
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
    ]
  end

  defp window_lines(state) do
    [
      Guppy.IR.text("main_view_id = #{state.main_view_id}"),
      Guppy.IR.text("aux_view_id = #{inspect(state.aux_view_id)}"),
      Guppy.IR.text("child_owner_pid = #{inspect(state.child_owner_pid)}"),
      Guppy.IR.text("child_view_id = #{inspect(state.child_view_id)}"),
      action_button("Open auxiliary window", "open_aux_button", "open_aux_window", :yellow),
      action_button("Close auxiliary window", "close_aux_button", "close_aux_window", :yellow),
      action_button("Spawn child-owner window", "spawn_child_button", "spawn_child_owner", :green),
      action_button("Kill child owner (tests DOWN cleanup)", "kill_child_button", "kill_child_owner", :red)
    ]
  end

  defp preview_lines(state) do
    [
      Guppy.IR.text("palette = #{palette_color(state)}"),
      Guppy.IR.text("This panel changes color via clicks and timer updates."),
      action_button("Toggle palette", "toggle_palette_button", "toggle_palette", :white),
      action_button("Refresh runtime status", "refresh_status_button", "refresh_status", :white),
      action_button("Quit demo", "quit_demo_button", "quit_demo", :black)
    ]
  end

  defp control_lines do
    [
      Guppy.IR.text("Try these in one place:"),
      Guppy.IR.text("1. Click div and text actions"),
      Guppy.IR.text("2. Start timer rerenders"),
      Guppy.IR.text("3. Open/close the auxiliary window"),
      Guppy.IR.text("4. Spawn and kill the child-owner window to test owner cleanup"),
      Guppy.IR.text("5. Close the red traffic-light button to test window_closed")
    ]
  end

  defp section(id, children, opts \\ []) do
    base_style = %{flex: true, flex_col: true, gap_2: true, p_4: true, border_1: true, border_color: :white, rounded_md: true}
    merged_style = Map.merge(base_style, Keyword.get(opts, :style, %{}))

    Guppy.IR.div(children, id: id, style: merged_style)
  end

  defp row(id, children) do
    Guppy.IR.div(children, id: id, style: %{flex: true, gap_2: true})
  end

  defp action_button(label, id, callback, color) do
    Guppy.IR.div(
      [Guppy.IR.text(label, id: "#{id}_label")],
      id: id,
      style: %{
        p_2: true,
        rounded_md: true,
        border_1: true,
        border_color: contrast_border_color(color),
        bg: color,
        text_color: contrast_text_color(color),
        cursor_pointer: true
      },
      events: %{click: callback}
    )
  end

  defp palette_color(state) do
    Enum.at(@palette, state.palette_index)
  end

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
          style: %{p_4: true, bg: :yellow, text_color: :black, rounded_md: true, cursor_pointer: true},
          events: %{click: "close_aux_window"}
        )
      ],
      id: "aux_root",
      style: %{flex: true, flex_col: true, gap_2: true, p_4: true}
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
          style: %{flex: true, flex_col: true, gap_2: true, p_4: true, bg: :gray, rounded_md: true}
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
