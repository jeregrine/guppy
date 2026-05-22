defmodule Examples.StressTest do
  @moduledoc false

  alias Guppy.IR

  @levels [
    %{name: "warm", factor: 0.5},
    %{name: "hot", factor: 1.0},
    %{name: "meltdown", factor: 2.0}
  ]

  @palette [
    "#0f172a",
    "#111827",
    "#1e1b4b",
    "#172554",
    "#0f766e",
    "#166534",
    "#854d0e",
    "#7f1d1d",
    "#701a75",
    "#312e81"
  ]

  @accent_palette [
    "#38bdf8",
    "#60a5fa",
    "#818cf8",
    "#a78bfa",
    "#f472b6",
    "#fb7185",
    "#f59e0b",
    "#22c55e"
  ]

  def run do
    {:ok, _} = Application.ensure_all_started(:guppy)

    config = load_config()
    print_banner(config)

    initial_state = initial_state(config)
    initial_ir = render_tree(initial_state)

    {:ok, view_id} = Guppy.open_window(initial_ir, window_opts(), config.timeout_ms)

    now_us = now_us()

    state =
      %{initial_state | view_id: view_id}
      |> Map.merge(%{
        started_at_us: now_us,
        sample_started_at_us: now_us,
        native_counters: fetch_counters()
      })
      |> schedule_tick(0)

    loop(state)
  end

  def print_help do
    IO.puts("""
    Guppy IR stress test

    Run optimized:
      MIX_ENV=prod mix run examples/stress_test.exs

    Or keep Mix in dev while selecting an optimized native build:
      GUPPY_NATIVE_RELEASE=1 mix run examples/stress_test.exs

    Validate one generated frame without opening a window:
      mix run --no-start examples/stress_test.exs -- --validate-only

    The stress test runs continuously until the window is closed or the process
    is interrupted. For bounded automated checks, use --validate-only.

    Optional knobs:
      GUPPY_STRESS_FPS=60
      GUPPY_STRESS_UNIFORM_ITEMS=12000
      GUPPY_STRESS_LIST_ROWS=1200
      GUPPY_STRESS_SCROLL_ROWS=900
      GUPPY_STRESS_GRID_CELLS=384
      GUPPY_STRESS_TIMEOUT_MS=15000     # native render request timeout, not run duration
      GUPPY_STRESS_PRINT=1              # default: 1; set 0 to silence per-sample lines
      GUPPY_STRESS_SAMPLE_MS=1000       # command-line sample interval
      GUPPY_STRESS_FORMAT=kv            # kv or jsonl
      GUPPY_STRESS_MEASURE_IR=0         # set 1 to add external ETF byte-size sampling

    Command-line output includes per-sample fps/renders, Elixir build time,
    end-to-end render call time, native ETF encode/decode counters, BEAM memory,
    mailbox depth, missed-frame counts, event deltas, and a stop summary.

    In the window:
      - Pause/Resume stops the frame pump.
      - Intensity cycles warm/hot/meltdown.
      - Space toggles pause when the root has focus.
      - The middle pane auto-scrolls by moving an anchor every frame.
      - The right pane rebuilds uniform_list and list payloads every frame.
    """)
  end

  def validate_once do
    config = load_config()
    state = initial_state(config)

    case IR.validate(render_tree(state)) do
      :ok ->
        IO.puts(
          "stress test IR validates (#{approx_records(effective_config(state))} records/items)"
        )

        :ok

      {:error, reason} ->
        IO.puts("stress test IR validation failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp initial_state(config) do
    now_us = now_us()

    %{
      view_id: nil,
      config: config,
      tick_ref: nil,
      frame: 0,
      renders: 0,
      paused?: false,
      intensity_index: 1,
      started_at_us: now_us,
      sample_started_at_us: now_us,
      sample_frame: 0,
      sample_renders: 0,
      sample_max_build_us: 0,
      sample_max_render_us: 0,
      sample_build_us_sum: 0,
      sample_render_us_sum: 0,
      sample_ir_measure_us_sum: 0,
      sample_ir_bytes_sum: 0,
      sample_max_ir_bytes: 0,
      sample_missed_frames: 0,
      sample_event_counts: %{},
      fps: 0.0,
      renders_per_second: 0.0,
      last_build_us: 0,
      last_render_us: 0,
      last_ir_measure_us: 0,
      last_ir_bytes: 0,
      max_build_us: 0,
      max_render_us: 0,
      max_ir_bytes: 0,
      total_build_us: 0,
      total_render_us: 0,
      total_ir_measure_us: 0,
      total_ir_bytes: 0,
      total_missed_frames: 0,
      samples_printed: 0,
      native_counters: %{},
      native_encode_us: 0.0,
      native_decode_us: 0.0,
      native_render_delta: 0,
      event_counts: %{},
      last_event: "booting",
      selected: "none"
    }
  end

  defp loop(state) do
    receive do
      {:tick, ref} when ref == state.tick_ref ->
        handle_tick(state)

      {:tick, _stale_ref} ->
        loop(state)

      {:guppy_event, view_id, %{type: :window_closed}} when view_id == state.view_id ->
        IO.puts("stress test window closed")
        print_summary(state)
        :ok

      {:guppy_event, view_id, event} when view_id == state.view_id ->
        case handle_event(event, state) do
          {:ok, next_state} -> loop(next_state)
          {:stop, reason, next_state} -> stop(reason, next_state)
        end

      other ->
        state
        |> Map.put(:last_event, "ignored #{inspect(other)}")
        |> loop()
    end
  end

  defp handle_tick(%{paused?: true} = state) do
    state
    |> schedule_tick(250)
    |> loop()
  end

  defp handle_tick(state) do
    tick_started_ms = now_ms()
    state = %{state | frame: state.frame + 1}

    case render_now(state) do
      {:ok, next_state} ->
        elapsed_ms = now_ms() - tick_started_ms
        delay_ms = max(0, next_state.config.target_frame_ms - elapsed_ms)

        next_state
        |> schedule_tick(delay_ms)
        |> loop()

      {:error, reason, next_state} ->
        stop({:render_failed, reason}, next_state)
    end
  end

  defp handle_event(%{callback: "toggle_pause"} = event, state) do
    paused? = not state.paused?

    state =
      event
      |> bump_event(state)
      |> Map.put(:paused?, paused?)
      |> Map.put(:last_event, if(paused?, do: "paused", else: "resumed"))
      |> schedule_tick(if(paused?, do: 250, else: 0))

    render_after_event(state)
  end

  defp handle_event(%{callback: "next_intensity"} = event, state) do
    next_index = rem(state.intensity_index + 1, length(@levels))
    next_level = Enum.at(@levels, next_index)

    state =
      event
      |> bump_event(state)
      |> Map.put(:intensity_index, next_index)
      |> Map.put(:last_event, "intensity => #{next_level.name}")

    render_after_event(state)
  end

  defp handle_event(%{callback: "reset_stats"} = event, state) do
    now_us = now_us()

    state =
      event
      |> bump_event(state)
      |> Map.merge(%{
        started_at_us: now_us,
        sample_started_at_us: now_us,
        sample_frame: state.frame,
        sample_renders: state.renders,
        sample_max_build_us: 0,
        sample_max_render_us: 0,
        sample_build_us_sum: 0,
        sample_render_us_sum: 0,
        sample_ir_measure_us_sum: 0,
        sample_ir_bytes_sum: 0,
        sample_max_ir_bytes: 0,
        sample_missed_frames: 0,
        sample_event_counts: %{},
        fps: 0.0,
        renders_per_second: 0.0,
        max_build_us: 0,
        max_render_us: 0,
        max_ir_bytes: 0,
        total_build_us: 0,
        total_render_us: 0,
        total_ir_measure_us: 0,
        total_ir_bytes: 0,
        total_missed_frames: 0,
        samples_printed: 0,
        native_counters: fetch_counters(),
        native_encode_us: 0.0,
        native_decode_us: 0.0,
        native_render_delta: 0,
        event_counts: %{},
        last_event: "stats reset"
      })

    render_after_event(state)
  end

  defp handle_event(%{callback: "close_window"} = event, state) do
    state = bump_event(event, state)
    _ = safe_close(state.view_id)
    {:stop, :normal, state}
  end

  defp handle_event(%{type: :window_close_requested} = event, state) do
    state =
      event
      |> bump_event(state)
      |> Map.put(:last_event, "window close requested")

    {:ok, state}
  end

  defp handle_event(event, state) do
    state =
      event
      |> bump_event(state)
      |> Map.put(:selected, selected_label(event))
      |> Map.put(:last_event, event_label(event))

    if state.paused? do
      render_after_event(state)
    else
      {:ok, state}
    end
  end

  defp render_after_event(state) do
    case render_now(state) do
      {:ok, next_state} -> {:ok, next_state}
      {:error, reason, next_state} -> {:stop, {:render_failed, reason}, next_state}
    end
  end

  defp render_now(state) do
    build_started_us = now_us()
    ir = render_tree(state)
    build_us = now_us() - build_started_us

    measure_started_us = now_us()
    ir_bytes = maybe_measure_ir_bytes(ir, state.config)
    ir_measure_us = now_us() - measure_started_us

    render_started_us = now_us()
    result = Guppy.render(state.view_id, ir, state.config.timeout_ms)
    render_us = now_us() - render_started_us

    next_state =
      state
      |> Map.merge(%{
        renders: state.renders + 1,
        last_build_us: build_us,
        last_render_us: render_us,
        last_ir_measure_us: ir_measure_us,
        last_ir_bytes: ir_bytes,
        sample_max_build_us: max(state.sample_max_build_us, build_us),
        sample_max_render_us: max(state.sample_max_render_us, render_us),
        sample_build_us_sum: state.sample_build_us_sum + build_us,
        sample_render_us_sum: state.sample_render_us_sum + render_us,
        sample_ir_measure_us_sum: state.sample_ir_measure_us_sum + ir_measure_us,
        sample_ir_bytes_sum: state.sample_ir_bytes_sum + ir_bytes,
        sample_max_ir_bytes: max(state.sample_max_ir_bytes, ir_bytes),
        sample_missed_frames:
          state.sample_missed_frames + missed_frame_count(build_us, render_us, state.config),
        max_build_us: max(state.max_build_us, build_us),
        max_render_us: max(state.max_render_us, render_us),
        max_ir_bytes: max(state.max_ir_bytes, ir_bytes),
        total_build_us: state.total_build_us + build_us,
        total_render_us: state.total_render_us + render_us,
        total_ir_measure_us: state.total_ir_measure_us + ir_measure_us,
        total_ir_bytes: state.total_ir_bytes + ir_bytes,
        total_missed_frames:
          state.total_missed_frames + missed_frame_count(build_us, render_us, state.config)
      })
      |> maybe_roll_sample()

    case result do
      :ok ->
        {:ok, next_state}

      {:error, reason} ->
        {:error, reason, Map.put(next_state, :last_event, "render error #{inspect(reason)}")}
    end
  end

  defp maybe_roll_sample(state) do
    now_us = now_us()
    elapsed_us = now_us - state.sample_started_at_us

    if elapsed_us >= state.config.sample_interval_ms * 1_000 do
      seconds = elapsed_us / 1_000_000
      frames = state.frame - state.sample_frame
      renders = state.renders - state.sample_renders
      {native_stats, counters} = native_sample(state.native_counters)
      sample = build_sample(state, seconds, frames, renders, native_stats)

      next_state = %{
        state
        | fps: frames / seconds,
          renders_per_second: renders / seconds,
          native_counters: counters,
          native_encode_us: native_stats.encode_us,
          native_decode_us: native_stats.decode_us,
          native_render_delta: native_stats.render_count,
          sample_started_at_us: now_us,
          sample_frame: state.frame,
          sample_renders: state.renders,
          sample_max_build_us: 0,
          sample_max_render_us: 0,
          sample_build_us_sum: 0,
          sample_render_us_sum: 0,
          sample_ir_measure_us_sum: 0,
          sample_ir_bytes_sum: 0,
          sample_max_ir_bytes: 0,
          sample_missed_frames: 0,
          sample_event_counts: state.event_counts,
          samples_printed: state.samples_printed + 1
      }

      maybe_print_stats(next_state, sample)
    else
      state
    end
  end

  defp build_sample(state, seconds, frames, renders, native_stats) do
    process_info = Process.info(self(), [:memory, :message_queue_len, :reductions]) || []
    effective = effective_config(state)

    %{
      sample: state.samples_printed + 1,
      uptime_s: (now_us() - state.started_at_us) / 1_000_000,
      window_s: seconds,
      level: current_level(state).name,
      frame: state.frame,
      renders: state.renders,
      fps: safe_div(frames, seconds),
      rps: safe_div(renders, seconds),
      target_fps: state.config.target_fps,
      missed_frames: state.sample_missed_frames,
      missed_total: state.total_missed_frames,
      records: approx_records(effective),
      uniform_items: effective.uniform_items,
      list_rows: effective.list_rows,
      scroll_rows: effective.scroll_rows,
      grid_cells: effective.grid_cells,
      build_ms: us_to_ms(state.last_build_us),
      build_avg_ms: us_to_ms(avg_count(state.sample_build_us_sum, renders)),
      build_max_ms: us_to_ms(state.sample_max_build_us),
      render_ms: us_to_ms(state.last_render_us),
      render_avg_ms: us_to_ms(avg_count(state.sample_render_us_sum, renders)),
      render_max_ms: us_to_ms(state.sample_max_render_us),
      ir_measure_ms: us_to_ms(state.last_ir_measure_us),
      ir_measure_avg_ms: us_to_ms(avg_count(state.sample_ir_measure_us_sum, renders)),
      ir_bytes: state.last_ir_bytes,
      ir_bytes_avg: avg_count(state.sample_ir_bytes_sum, renders),
      ir_bytes_max: state.sample_max_ir_bytes,
      native_render_count: native_stats.render_count,
      native_encode_us: native_stats.encode_us,
      native_decode_us: native_stats.decode_us,
      native_event_send_count: native_stats.event_send_count,
      native_event_send_failure_count: native_stats.event_send_failure_count,
      beam_proc_mem_bytes: Keyword.get(process_info, :memory, 0),
      beam_total_mem_bytes: :erlang.memory(:total),
      mailbox_len: Keyword.get(process_info, :message_queue_len, 0),
      reductions: Keyword.get(process_info, :reductions, 0),
      events_delta: event_delta(state.event_counts, state.sample_event_counts),
      events_total: Enum.sum(Map.values(state.event_counts)),
      last_event: state.last_event,
      selected: state.selected
    }
  end

  defp maybe_print_stats(%{config: %{print_stats?: true}} = state, sample) do
    print_sample(state.config, sample)
    state
  end

  defp maybe_print_stats(state, _sample), do: state

  defp print_sample(%{print_format: :jsonl}, sample) do
    sample
    |> Map.put(:events_delta, event_counts_to_string(sample.events_delta))
    |> json_line()
    |> IO.puts()
  end

  defp print_sample(_config, sample) do
    IO.puts(
      "[guppy-stress] " <>
        "sample=#{sample.sample} uptime=#{fmt_float(sample.uptime_s, 1)}s " <>
        "level=#{sample.level} frame=#{sample.frame} records=#{sample.records} " <>
        "fps=#{fmt_float(sample.fps, 1)}/#{sample.target_fps} rps=#{fmt_float(sample.rps, 1)} " <>
        "missed=#{sample.missed_frames}(total=#{sample.missed_total}) " <>
        "build_ms=#{fmt_float(sample.build_ms, 2)} avg=#{fmt_float(sample.build_avg_ms, 2)} max=#{fmt_float(sample.build_max_ms, 2)} " <>
        "render_ms=#{fmt_float(sample.render_ms, 2)} avg=#{fmt_float(sample.render_avg_ms, 2)} max=#{fmt_float(sample.render_max_ms, 2)} " <>
        "native_encode_us=#{fmt_float(sample.native_encode_us, 1)} native_decode_us=#{fmt_float(sample.native_decode_us, 1)} " <>
        "native_renders=#{sample.native_render_count} native_event_failures=#{sample.native_event_send_failure_count} " <>
        "ir_bytes=#{format_bytes(sample.ir_bytes)} ir_avg=#{format_bytes(round(sample.ir_bytes_avg))} " <>
        "beam_mem=#{format_bytes(sample.beam_total_mem_bytes)} proc_mem=#{format_bytes(sample.beam_proc_mem_bytes)} mq=#{sample.mailbox_len} " <>
        "events_delta=#{event_counts_to_string(sample.events_delta)} events_total=#{sample.events_total} " <>
        "last=#{inspect(sample.last_event)}"
    )
  end

  defp json_line(map) do
    pairs =
      map
      |> Enum.sort_by(fn {key, _value} -> Atom.to_string(key) end)
      |> Enum.map_join(",", fn {key, value} -> json_pair(key, value) end)

    "{" <> pairs <> "}"
  end

  defp json_pair(key, value), do: json_string(Atom.to_string(key)) <> ":" <> json_value(value)
  defp json_value(nil), do: "null"
  defp json_value(value) when is_boolean(value), do: if(value, do: "true", else: "false")
  defp json_value(value) when is_atom(value), do: json_string(Atom.to_string(value))
  defp json_value(value) when is_binary(value), do: json_string(value)
  defp json_value(value) when is_integer(value), do: Integer.to_string(value)
  defp json_value(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 6)
  defp json_value(value), do: json_string(inspect(value))

  defp json_string(value) do
    [?", value |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\""), ?"]
    |> IO.iodata_to_binary()
  end

  defp render_tree(state) do
    config = effective_config(state)

    IR.div(
      [
        header(state, config),
        volatile_controls(state),
        body(state, config)
      ],
      id: "stress_root",
      style: root_style(),
      focusable: true,
      tab_stop: true,
      actions: %{"stress.toggle_pause" => "toggle_pause"},
      shortcuts: [{"space", "stress.toggle_pause"}],
      events: %{key_down: "root_key_down", scroll_wheel: "root_scroll_wheel"}
    )
  end

  defp header(state, config) do
    level = current_level(state)

    IR.div(
      [
        IR.div(
          [
            IR.text("Guppy IR bridge stress test", id: "stress_title", style: title_text_style()),
            IR.text(
              "full-tree replacement at #{state.config.target_fps}fps target · #{level.name} · " <>
                "#{approx_records(config)} changing IR records/items",
              id: "stress_subtitle",
              style: muted_text_style()
            ),
            IR.text(
              "Close the window or press Close below to stop. Release native builds are strongly recommended.",
              id: "stress_hint",
              style: tiny_text_style()
            )
          ],
          id: "stress_copy",
          style: [:flex, :flex_col, :gap_1, :flex_1]
        ),
        IR.div(metric_tiles(state, config),
          id: "stress_metrics",
          style: [:grid, {:grid_cols, 5}, :gap_1, {:w_px, 760}]
        )
      ],
      id: "stress_header",
      style: panel_base_style() ++ [:flex, :flex_row, :items_center, :gap_2]
    )
  end

  defp metric_tiles(state, config) do
    [
      metric_tile("frame", Integer.to_string(state.frame), "#38bdf8", "metric_frame"),
      metric_tile("fps", fmt_float(state.fps, 1), "#22c55e", "metric_fps"),
      metric_tile("renders/s", fmt_float(state.renders_per_second, 1), "#a78bfa", "metric_rps"),
      metric_tile("build", fmt_ms(state.last_build_us), "#f59e0b", "metric_build"),
      metric_tile("render", fmt_ms(state.last_render_us), "#fb7185", "metric_render"),
      metric_tile("max render", fmt_ms(state.max_render_us), "#f43f5e", "metric_max_render"),
      metric_tile(
        "native encode",
        "#{fmt_float(state.native_encode_us, 1)}µs",
        "#60a5fa",
        "metric_encode"
      ),
      metric_tile(
        "native decode",
        "#{fmt_float(state.native_decode_us, 1)}µs",
        "#818cf8",
        "metric_decode"
      ),
      metric_tile(
        "events",
        Integer.to_string(Enum.sum(Map.values(state.event_counts))),
        "#eab308",
        "metric_events"
      ),
      metric_tile(
        "records",
        Integer.to_string(approx_records(config)),
        "#14b8a6",
        "metric_records"
      )
    ]
  end

  defp metric_tile(label, value, accent, id) do
    IR.div(
      [
        IR.text(label, id: "#{id}_label", style: tiny_text_style()),
        IR.text(value,
          id: "#{id}_value",
          style: [:text_sm, :font_black, {:text_color_hex, accent}]
        )
      ],
      id: id,
      style: [
        :p_2,
        :rounded_lg,
        :border_1,
        {:border_color_hex, "#1e293b"},
        {:bg_hex, "#020617"}
      ]
    )
  end

  defp volatile_controls(state) do
    frame = state.frame
    paused? = state.paused?

    IR.div(
      [
        IR.button(if(paused?, do: "Resume", else: "Pause"),
          id: "pause_button",
          style: control_button_style("#2563eb"),
          hover_style: [{:bg_hex, "#3b82f6"}],
          events: %{click: "toggle_pause"}
        ),
        IR.button("Intensity: #{current_level(state).name}",
          id: "intensity_button",
          style: control_button_style("#7c3aed"),
          hover_style: [{:bg_hex, "#8b5cf6"}],
          events: %{click: "next_intensity"}
        ),
        IR.button("Reset stats",
          id: "reset_stats_button",
          style: control_button_style("#334155"),
          hover_style: [{:bg_hex, "#475569"}],
          events: %{click: "reset_stats"}
        ),
        IR.button("Close",
          id: "close_button",
          style: control_button_style("#991b1b"),
          hover_style: [{:bg_hex, "#b91c1c"}],
          events: %{click: "close_window"}
        ),
        IR.text_input("frame=#{frame} render=#{state.renders} selected=#{state.selected}",
          id: "volatile_text_input",
          placeholder: "volatile retained text input",
          style: input_style(),
          events: %{
            change: "volatile_input_changed",
            focus: "volatile_input_focus",
            blur: "volatile_input_blur"
          }
        ),
        IR.checkbox("flip #{rem(frame, 2)}", rem(frame, 2) == 0,
          id: "volatile_checkbox",
          style: control_chip_style(),
          events: %{change: "volatile_checkbox_changed"}
        ),
        IR.radio("phase #{rem(frame, 3)}", Integer.to_string(rem(frame, 3)), rem(frame, 3) == 0,
          id: "volatile_radio",
          style: control_chip_style(),
          events: %{change: "volatile_radio_changed"}
        ),
        IR.select(select_options(frame),
          id: "volatile_select",
          value: Integer.to_string(rem(frame, 6)),
          open: false,
          style: input_style() ++ [{:w_px, 170}],
          list_style: [
            :p_1,
            :rounded_lg,
            :border_1,
            {:border_color_hex, "#334155"},
            {:bg_hex, "#020617"}
          ],
          option_style: [:p_2, {:text_color_hex, "#e2e8f0"}],
          events: %{
            change: "volatile_select_changed",
            click: "volatile_select_clicked",
            close: "volatile_select_closed"
          }
        )
      ],
      id: "volatile_controls",
      style: panel_base_style() ++ [:flex, :flex_row, :items_center, :gap_2]
    )
  end

  defp body(state, config) do
    IR.div(
      [
        grid_panel(state, config),
        scroll_panel(state, config),
        virtual_list_panel(state, config)
      ],
      id: "stress_body",
      style: [:flex, :flex_row, :flex_1, :min_h_0, :gap_2]
    )
  end

  defp grid_panel(state, config) do
    grid_cols = grid_columns(config.grid_cells)

    panel(
      "grid_panel",
      "Mutating explicit-id grid",
      "#{config.grid_cells} cells: style order, colors, text runs, hover/click handlers all churn every frame.",
      [
        IR.scroll(
          [
            IR.div(grid_cells(state, config),
              id: "grid_cells",
              style: [:grid, {:grid_cols, grid_cols}, :gap_1, :p_1]
            )
          ],
          id: "grid_scroll",
          axis: :y,
          style: scroll_box_style()
        )
      ],
      [{:w_px, 420}]
    )
  end

  defp grid_cells(state, config) do
    frame = state.frame

    for index <- 0..(config.grid_cells - 1) do
      hot? = rem(index + frame, 29) == 0
      accent = accent(index + frame)
      base = color(index * 7 + frame)
      override = color(index + frame * 3)

      style =
        [
          :p_1,
          :rounded_md,
          :border_1,
          {:h_px, if(hot?, do: 44, else: 34)},
          {:bg_hex, base},
          {:border_color_hex, "#1e293b"}
        ] ++
          if hot? do
            [{:bg_hex, override}, {:border_color_hex, accent}, :shadow_sm]
          else
            []
          end

      IR.div(
        [
          IR.rich_text(
            [
              {Integer.to_string(index, 36), [:font_black, {:text_color_hex, accent}]},
              {" · ", [{:text_color_hex, "#64748b"}]},
              {Integer.to_string(rem(frame + index * 17, 10_000)), [{:text_color_hex, "#e2e8f0"}]}
            ],
            id: "grid_cell_#{index}_label",
            style: [:text_xs, :truncate]
          )
        ],
        id: "grid_cell_#{index}",
        style: style,
        hover_style: [{:border_color_hex, "#f8fafc"}, {:bg_hex, "#334155"}],
        events: %{click: "grid_cell_click"}
      )
    end
  end

  defp scroll_panel(state, config) do
    anchor = anchor_index(state, config)

    panel(
      "scroll_panel",
      "Auto-scroll anchor chase",
      "#{config.scroll_rows} real div rows. One moving anchor_scroll target forces retained scroll state to chase it.",
      [
        IR.div(
          [
            IR.text("anchor row", id: "anchor_label", style: tiny_text_style()),
            IR.text(Integer.to_string(anchor),
              id: "anchor_value",
              style: [:text_lg, :font_black, {:text_color_hex, "#facc15"}]
            ),
            IR.text("wheel #{Map.get(state.event_counts, :scroll_wheel, 0)}",
              id: "wheel_value",
              style: muted_text_style()
            )
          ],
          id: "anchor_status",
          style: [
            :flex,
            :flex_row,
            :items_center,
            :justify_between,
            :gap_2,
            :p_2,
            :rounded_lg,
            {:bg_hex, "#020617"}
          ]
        ),
        IR.scroll(
          [
            IR.div(scroll_rows(state, config, anchor),
              id: "anchor_rows",
              style: [:flex, :flex_col, :gap_1, :p_1]
            )
          ],
          id: "anchor_scroll",
          axis: :y,
          style: scroll_box_style()
        )
      ],
      [{:w_px, 390}]
    )
  end

  defp scroll_rows(state, config, anchor) do
    frame = state.frame

    for index <- 0..(config.scroll_rows - 1) do
      distance = abs(index - anchor)
      hot? = distance <= 2
      accent = if(hot?, do: "#facc15", else: accent(index + frame))

      row_style =
        [
          :flex,
          :flex_row,
          :items_center,
          :gap_2,
          :p_2,
          :rounded_lg,
          :border_1,
          {:bg_hex, if(hot?, do: "#422006", else: color(index + frame))},
          {:border_color_hex, if(hot?, do: "#facc15", else: "#1e293b")}
        ]

      IR.div(
        [
          IR.div([],
            id: "scroll_row_#{index}_spark",
            style: [{:w_px, 10}, {:h_px, 10}, :rounded_full, {:bg_hex, accent}]
          ),
          IR.div(
            [
              IR.text(if(index == anchor, do: "▶ row #{index}", else: "row #{index}"),
                id: "scroll_row_#{index}_title",
                style: [
                  :text_sm,
                  :font_bold,
                  {:text_color_hex, if(hot?, do: "#fef3c7", else: "#e2e8f0")}
                ]
              ),
              IR.text("phase=#{rem(frame + index, 997)} distance=#{distance}",
                id: "scroll_row_#{index}_meta",
                style: tiny_text_style()
              )
            ],
            id: "scroll_row_#{index}_copy",
            style: [:flex, :flex_col, :flex_1]
          )
        ],
        id: "scroll_row_#{index}",
        style: row_style,
        anchor_scroll: index == anchor,
        events: %{click: "scroll_row_click"}
      )
    end
  end

  defp virtual_list_panel(state, config) do
    panel(
      "virtual_panel",
      "Virtual list churn",
      "uniform_list rotates #{config.uniform_items} labels; list rotates #{config.list_rows} variable static rows every frame.",
      [
        IR.div(
          [
            IR.text("uniform_list",
              id: "uniform_heading",
              style: [:text_sm, :font_black, {:text_color_hex, "#38bdf8"}]
            ),
            IR.uniform_list(uniform_items(state, config),
              id: "uniform_virtual_list",
              style: virtual_box_style(),
              item_style: uniform_item_style(state),
              events: %{click: "uniform_item_click"}
            )
          ],
          id: "uniform_section",
          style: [:flex, :flex_col, :flex_none, :gap_1]
        ),
        IR.div(
          [
            IR.text("list",
              id: "generic_heading",
              style: [:text_sm, :font_black, {:text_color_hex, "#a78bfa"}]
            ),
            IR.list(generic_items(state, config),
              id: "generic_virtual_list",
              style: virtual_box_style(),
              item_style: [:p_1],
              events: %{click: "generic_item_click"}
            )
          ],
          id: "generic_section",
          style: [:flex, :flex_col, :flex_none, :gap_1]
        )
      ],
      [:flex_1]
    )
  end

  defp uniform_items(state, config) do
    frame = state.frame
    count = config.uniform_items
    shift = rem(frame * 13, count)

    for index <- 0..(count - 1) do
      source = rem(index + shift, count)
      hot? = rem(source + frame, 211) < 3
      marker = if hot?, do: "◆", else: "·"

      %{
        id: "urow_#{source}",
        label:
          "#{marker} uniform #{source} visible-index=#{index} frame=#{frame} checksum=#{rem(source * 97 + frame, 65_535)}"
      }
    end
  end

  defp generic_items(state, config) do
    frame = state.frame
    count = config.list_rows
    shift = rem(frame * 7, count)

    for index <- 0..(count - 1) do
      source = rem(index + shift, count)
      hot? = rem(source + frame, 89) < 5
      accent = if(hot?, do: "#facc15", else: accent(source + frame))

      children =
        [
          IR.div(
            [
              IR.div([],
                id: "generic_row_#{source}_spark",
                style: [{:w_px, 8}, {:h_px, 8}, :rounded_full, {:bg_hex, accent}]
              ),
              IR.div(
                [
                  IR.text("row #{source} / index #{index}",
                    id: "generic_row_#{source}_title",
                    style: [:text_sm, :font_bold, {:text_color_hex, "#f8fafc"}]
                  ),
                  IR.text("payload=#{rem(source * 1_103 + frame * 31, 999_983)} frame=#{frame}",
                    id: "generic_row_#{source}_meta",
                    style: tiny_text_style()
                  )
                ] ++ extra_generic_lines(source, frame),
                id: "generic_row_#{source}_copy",
                style: [:flex, :flex_col, :flex_1]
              )
            ],
            id: "generic_row_#{source}_card",
            style: [
              :flex,
              :flex_row,
              :items_center,
              :gap_2,
              if(hot?, do: :p_4, else: :p_2),
              :rounded_lg,
              :border_1,
              {:bg_hex, if(hot?, do: "#312e81", else: color(source + frame))},
              {:border_color_hex, if(hot?, do: "#facc15", else: "#1e293b")}
            ],
            events: %{click: "generic_inner_click"}
          )
        ]

      %{id: "generic_item_#{source}", children: children}
    end
  end

  defp extra_generic_lines(source, frame) do
    if rem(source + frame, 6) == 0 do
      [
        IR.text("extra variable-height line #{rem(source * 13 + frame, 4096)}",
          id: "generic_row_#{source}_extra",
          style: [:text_xs, {:text_color_hex, "#c4b5fd"}]
        )
      ]
    else
      []
    end
  end

  defp panel(id, title, subtitle, children, extra_style) do
    IR.div(
      [
        IR.div(
          [
            IR.text(title,
              id: "#{id}_title",
              style: [:text_lg, :font_black, {:text_color_hex, "#f8fafc"}]
            ),
            IR.text(subtitle, id: "#{id}_subtitle", style: tiny_text_style())
          ],
          id: "#{id}_header",
          style: [:flex, :flex_col, :gap_1]
        )
      ] ++ children,
      id: id,
      style: panel_base_style() ++ [:flex, :flex_col, :h_full, :min_h_0, :gap_2] ++ extra_style
    )
  end

  defp select_options(frame) do
    for index <- 0..5 do
      %{
        value: Integer.to_string(index),
        label: "volatile option #{index} / #{rem(frame + index, 100)}",
        disabled: rem(frame + index, 11) == 0
      }
    end
  end

  defp anchor_index(_state, %{scroll_rows: count}) when count <= 1, do: 0
  defp anchor_index(state, %{scroll_rows: count}), do: rem(state.frame * 9, count)

  defp uniform_item_style(state) do
    [
      :border_b_1,
      {:border_color_hex, "#1e293b"},
      {:bg_hex, color(state.frame)},
      {:text_color_hex, "#e2e8f0"}
    ]
  end

  defp root_style do
    [
      :flex,
      :flex_col,
      :w_full,
      :h_full,
      :min_h_0,
      :gap_2,
      :p_2,
      {:bg_hex, "#020617"},
      {:text_color_hex, "#f8fafc"}
    ]
  end

  defp panel_base_style do
    [
      :p_2,
      :rounded_xl,
      :border_1,
      :shadow_md,
      {:border_color_hex, "#1e293b"},
      {:bg_hex, "#0f172a"}
    ]
  end

  defp scroll_box_style do
    [
      :flex_1,
      :min_h_0,
      :rounded_lg,
      :border_1,
      {:border_color_hex, "#1e293b"},
      {:bg_hex, "#020617"},
      {:scrollbar_width_px, 10}
    ]
  end

  defp virtual_box_style do
    # GPUI virtual lists need a concrete viewport height; flex-only wrappers can
    # collapse and make rows look blank.
    [
      {:h_px, 300},
      :rounded_lg,
      :border_1,
      {:border_color_hex, "#1e293b"},
      {:bg_hex, "#020617"},
      {:scrollbar_width_px, 10}
    ]
  end

  defp title_text_style do
    [:text_2xl, :font_black, {:text_color_hex, "#f8fafc"}]
  end

  defp muted_text_style do
    [:text_sm, {:text_color_hex, "#94a3b8"}]
  end

  defp tiny_text_style do
    [:text_xs, {:text_color_hex, "#94a3b8"}]
  end

  defp control_button_style(bg) do
    [
      :p_2,
      :rounded_lg,
      :border_1,
      :shadow_sm,
      {:bg_hex, bg},
      {:border_color_hex, bg},
      {:text_color_hex, "#f8fafc"}
    ]
  end

  defp control_chip_style do
    [
      :p_2,
      :rounded_lg,
      :border_1,
      {:border_color_hex, "#334155"},
      {:bg_hex, "#020617"},
      {:text_color_hex, "#e2e8f0"}
    ]
  end

  defp input_style do
    [
      :p_2,
      :rounded_lg,
      :border_1,
      {:w_px, 300},
      {:border_color_hex, "#334155"},
      {:bg_hex, "#020617"},
      {:text_color_hex, "#e2e8f0"}
    ]
  end

  defp effective_config(state) do
    level = current_level(state)
    config = state.config

    %{
      uniform_items: scaled(config.uniform_items, level.factor),
      list_rows: scaled(config.list_rows, level.factor),
      scroll_rows: scaled(config.scroll_rows, level.factor),
      grid_cells: scaled(config.grid_cells, level.factor)
    }
  end

  defp scaled(value, factor), do: max(1, round(value * factor))

  defp approx_records(config) do
    config.uniform_items + config.list_rows * 5 + config.scroll_rows * 4 + config.grid_cells * 2 +
      80
  end

  defp grid_columns(count) do
    cond do
      count >= 900 -> 24
      count >= 480 -> 20
      count >= 240 -> 16
      true -> 12
    end
  end

  defp current_level(state), do: Enum.at(@levels, state.intensity_index)

  defp color(index), do: Enum.at(@palette, rem(abs(index), length(@palette)))
  defp accent(index), do: Enum.at(@accent_palette, rem(abs(index), length(@accent_palette)))

  defp load_config do
    fps = env_int("GUPPY_STRESS_FPS", 60, 1, 240)

    %{
      target_fps: fps,
      target_frame_ms: max(1, div(1_000, fps)),
      uniform_items: env_int("GUPPY_STRESS_UNIFORM_ITEMS", 12_000, 100, 100_000),
      list_rows: env_int("GUPPY_STRESS_LIST_ROWS", 1_200, 10, 20_000),
      scroll_rows: env_int("GUPPY_STRESS_SCROLL_ROWS", 900, 10, 10_000),
      grid_cells: env_int("GUPPY_STRESS_GRID_CELLS", 384, 12, 5_000),
      timeout_ms: env_int("GUPPY_STRESS_TIMEOUT_MS", 15_000, 1_000, 120_000),
      sample_interval_ms: env_int("GUPPY_STRESS_SAMPLE_MS", 1_000, 100, 60_000),
      print_stats?: env_bool("GUPPY_STRESS_PRINT", true),
      print_format: env_format("GUPPY_STRESS_FORMAT", :kv),
      measure_ir?: env_bool("GUPPY_STRESS_MEASURE_IR", false)
    }
  end

  defp env_int(name, default, lower, upper) do
    case System.get_env(name) do
      nil ->
        default

      value ->
        case Integer.parse(value) do
          {parsed, ""} ->
            parsed |> max(lower) |> min(upper)

          _ ->
            IO.puts("Ignoring invalid #{name}=#{inspect(value)}; using #{default}")
            default
        end
    end
  end

  defp env_bool(name, default) do
    case System.get_env(name) do
      nil ->
        default

      value when value in ["1", "true", "TRUE", "yes", "YES", "on", "ON"] ->
        true

      value when value in ["0", "false", "FALSE", "no", "NO", "off", "OFF"] ->
        false

      value ->
        IO.puts("Ignoring invalid #{name}=#{inspect(value)}; using #{default}")
        default
    end
  end

  defp env_format(name, default) do
    case System.get_env(name) do
      nil ->
        default

      value when value in ["kv", "human"] ->
        :kv

      "jsonl" ->
        :jsonl

      value ->
        IO.puts("Ignoring invalid #{name}=#{inspect(value)}; using #{default}")
        default
    end
  end

  defp print_banner(config) do
    IO.puts("""
    Guppy IR stress test
      target fps:      #{config.target_fps}
      uniform items:   #{config.uniform_items}
      list rows:       #{config.list_rows}
      auto-scroll rows:#{config.scroll_rows}
      grid cells:      #{config.grid_cells}
      timeout:         #{config.timeout_ms}ms
      sample interval: #{config.sample_interval_ms}ms
      stats output:    #{if(config.print_stats?, do: config.print_format, else: "off")}
      measure IR size: #{config.measure_ir?}

    Tip: use MIX_ENV=prod or GUPPY_NATIVE_RELEASE=1 for the intended stress profile.
    """)
  end

  defp window_opts do
    [
      window_bounds: [width: 1580, height: 980],
      window_min_size: [width: 1240, height: 760],
      titlebar: [title: "Guppy IR stress test"]
    ]
  end

  defp schedule_tick(state, delay_ms) do
    ref = make_ref()
    Process.send_after(self(), {:tick, ref}, delay_ms)
    %{state | tick_ref: ref}
  end

  defp bump_event(event, state) do
    type = Map.get(event, :type, :unknown)

    %{state | event_counts: Map.update(state.event_counts, type, 1, &(&1 + 1))}
  end

  defp selected_label(%{callback: callback, id: id})
       when callback in [
              "uniform_item_click",
              "generic_item_click",
              "generic_inner_click",
              "scroll_row_click",
              "grid_cell_click"
            ] do
    "#{callback}: #{short_id(id)}"
  end

  defp selected_label(_event), do: "none"

  defp event_label(event) do
    type = Map.get(event, :type, :unknown)
    callback = Map.get(event, :callback, "none")
    id = event |> Map.get(:id, "") |> short_id()
    "#{type}/#{callback} #{id}"
  end

  defp short_id(id) when is_binary(id) do
    id
    |> String.split(".")
    |> List.last()
    |> String.slice(0, 48)
  end

  defp short_id(other), do: inspect(other)

  defp fetch_counters do
    case Guppy.native_performance_counters() do
      {:ok, counters} when is_map(counters) -> counters
      _ -> %{}
    end
  end

  defp maybe_measure_ir_bytes(ir, %{measure_ir?: true}), do: :erlang.external_size(ir)
  defp maybe_measure_ir_bytes(_ir, _config), do: 0

  defp missed_frame_count(build_us, render_us, config) do
    if build_us + render_us > config.target_frame_ms * 1_000, do: 1, else: 0
  end

  defp event_delta(current, previous) do
    current
    |> Enum.reduce(%{}, fn {type, count}, acc ->
      delta = count - Map.get(previous, type, 0)
      if delta > 0, do: Map.put(acc, type, delta), else: acc
    end)
  end

  defp event_counts_to_string(counts) when map_size(counts) == 0, do: "none"

  defp event_counts_to_string(counts) do
    counts
    |> Enum.sort_by(fn {type, _count} -> Atom.to_string(type) end)
    |> Enum.map_join(",", fn {type, count} -> "#{type}:#{count}" end)
  end

  defp native_sample(previous) do
    current = fetch_counters()

    render_count = delta(current, previous, "render_ir_decode_count")
    decode_ns = delta(current, previous, "render_ir_decode_native_time_ns")
    encode_ns = delta(current, previous, "render_ir_to_binary_native_time_ns")

    stats = %{
      render_count: render_count,
      decode_us: avg_us(decode_ns, render_count),
      encode_us: avg_us(encode_ns, render_count),
      event_send_count: delta(current, previous, "native_event_send_count"),
      event_send_failure_count: delta(current, previous, "native_event_send_failure_count")
    }

    {stats, current}
  end

  defp delta(current, previous, key),
    do: max(0, Map.get(current, key, 0) - Map.get(previous, key, 0))

  defp avg_us(_ns, 0), do: 0.0
  defp avg_us(ns, count), do: ns / count / 1_000

  defp avg_count(_value, 0), do: 0.0
  defp avg_count(value, count), do: value / count

  defp safe_div(_value, 0), do: 0.0
  defp safe_div(value, divisor), do: value / divisor

  defp us_to_ms(us), do: us / 1_000

  defp format_bytes(0), do: "n/a"
  defp format_bytes(bytes) when bytes < 1_024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{fmt_float(bytes / 1_024, 1)}KiB"
  defp format_bytes(bytes), do: "#{fmt_float(bytes / 1_048_576, 1)}MiB"

  defp fmt_ms(us), do: "#{fmt_float(us / 1_000, 2)}ms"
  defp fmt_float(value, decimals), do: :erlang.float_to_binary(value / 1, decimals: decimals)

  defp now_us, do: System.monotonic_time(:microsecond)
  defp now_ms, do: System.monotonic_time(:millisecond)

  defp safe_close(nil), do: :ok

  defp safe_close(view_id) do
    Guppy.close_window(view_id)
  catch
    _, _ -> :ok
  end

  defp print_summary(state) do
    elapsed_s = max((now_us() - state.started_at_us) / 1_000_000, 0.001)
    counters = fetch_counters()

    IO.puts(
      "[guppy-stress-summary] " <>
        "uptime=#{fmt_float(elapsed_s, 1)}s frames=#{state.frame} renders=#{state.renders} " <>
        "avg_fps=#{fmt_float(state.frame / elapsed_s, 1)} avg_rps=#{fmt_float(state.renders / elapsed_s, 1)} " <>
        "avg_build_ms=#{fmt_float(us_to_ms(avg_count(state.total_build_us, state.renders)), 2)} " <>
        "avg_render_ms=#{fmt_float(us_to_ms(avg_count(state.total_render_us, state.renders)), 2)} " <>
        "max_build_ms=#{fmt_float(us_to_ms(state.max_build_us), 2)} max_render_ms=#{fmt_float(us_to_ms(state.max_render_us), 2)} " <>
        "missed_frames=#{state.total_missed_frames} events=#{Enum.sum(Map.values(state.event_counts))} " <>
        "ir_avg=#{format_bytes(round(avg_count(state.total_ir_bytes, state.renders)))} ir_max=#{format_bytes(state.max_ir_bytes)} " <>
        "native_render_decodes=#{Map.get(counters, "render_ir_decode_count", 0)} " <>
        "native_event_failures=#{Map.get(counters, "native_event_send_failure_count", 0)}"
    )
  end

  defp stop(:normal, state) do
    print_summary(state)
    :ok
  end

  defp stop(reason, state) do
    IO.puts("stress test stopping: #{inspect(reason)}")
    print_summary(state)
    _ = safe_close(state.view_id)
    :ok
  end
end

args = System.argv()

cond do
  "--help" in args or "-h" in args ->
    Examples.StressTest.print_help()

  "--validate-only" in args ->
    Examples.StressTest.validate_once()

  true ->
    Examples.StressTest.run()
end
