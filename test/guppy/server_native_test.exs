defmodule Guppy.ServerNativeTest do
  use ExUnit.Case

  import Guppy.TestSupport

  test "boots the guppy supervision tree" do
    assert Guppy.started?()

    state = Guppy.info()

    assert state.native == Guppy.Native.Nif
    assert state.native_server == Guppy.Native.Nif
    assert state.next_view_id >= 1
  end

  test "native ping is wired through the server" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        assert {:ok, :pong} = Guppy.ping()
        assert {:ok, "guppy_nif_rust_core"} = Guppy.native_build_info()
        assert {:ok, "started"} = Guppy.native_runtime_status()

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.ping()
    end
  end

  test "open_window/2 treats a keyword list as options for a caller-owned window" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        starting_count = native_view_count!()

        assert {:ok, view_id} = Guppy.open_window(Guppy.IR.text("opts smoke"), show: false)
        on_exit(fn -> maybe_close(view_id) end)

        assert Map.get(Guppy.info().views, view_id) == self()
        assert Guppy.native_view_count() == {:ok, starting_count + 1}
        assert :ok = Guppy.close_window(view_id)
        assert Guppy.native_view_count() == {:ok, starting_count}

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} =
                 Guppy.open_window(Guppy.IR.text("opts smoke"), show: false)
    end
  end

  test "native request crashes are contained and reported" do
    server = :"guppy_crashing_native_#{System.unique_integer([:positive])}"
    handler_id = {__MODULE__, self(), :crashing_native_request_telemetry}

    :ok = attach_forwarding_telemetry(handler_id, [:guppy, :native, :request])

    try do
      start_supervised!(
        {Guppy.Server,
         name: server, native: Guppy.CrashingNative, native_server: Guppy.CrashingNative}
      )

      assert {:error, :runtime_unavailable} = Guppy.Server.ping(server)
      assert Process.alive?(Process.whereis(server))

      assert_receive {:telemetry_event, [:guppy, :native, :request], %{duration: duration},
                      %{command: :ping, status: {:error, :runtime_unavailable}}}

      assert is_integer(duration)
    after
      :telemetry.detach(handler_id)
    end
  end

  test "native request timeouts are bounded and leave the server responsive" do
    server = :"guppy_blocking_native_#{System.unique_integer([:positive])}"
    handler_id = {__MODULE__, self(), :blocking_native_request_telemetry}

    :ok = attach_forwarding_telemetry(handler_id, [:guppy, :native, :request])

    try do
      start_supervised!(
        {Guppy.Server,
         name: server,
         native: Guppy.BlockingNative,
         native_server: Guppy.BlockingNative,
         native_request_timeout: 10}
      )

      assert {:error, :native_timeout} = Guppy.Server.ping(server, 10)
      assert Process.alive?(Process.whereis(server))

      assert {:error, :native_timeout} = Guppy.Server.view_count(server, 10)

      assert_receive {:telemetry_event, [:guppy, :native, :request], %{duration: duration},
                      %{command: :ping, status: {:error, :native_timeout}}}

      assert is_integer(duration)
    after
      :telemetry.detach(handler_id)
    end
  end

  test "native request timeout is passed through the server to the native bridge" do
    server = :"guppy_timeout_recording_native_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Guppy.Server,
       name: server,
       native: Guppy.TimeoutRecordingNative,
       native_server: self(),
       native_request_timeout: 25}
    )

    assert_receive {:guppy_test_native_request, {:set_event_target, [_pid]}, 25}

    assert {:ok, :pong} = Guppy.Server.ping(server, 37)
    assert_receive {:guppy_test_native_request, {:ping, []}, 37}
  end

  test "native event target monitor clears dead target without clearing newer registrations" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        original_server = Guppy.server()

        on_exit(fn ->
          Guppy.Native.Nif.request(Guppy.Native.Nif, {:set_event_target, [original_server]})
        end)

        first_target = spawn(fn -> Process.sleep(:infinity) end)

        assert :ok =
                 Guppy.Native.Nif.request(Guppy.Native.Nif, {:set_event_target, [first_target]})

        assert {:ok, {:some, first_generation}} = Guppy.Native.Nif.event_target_status()

        second_target = spawn(fn -> Process.sleep(:infinity) end)

        assert :ok =
                 Guppy.Native.Nif.request(Guppy.Native.Nif, {:set_event_target, [second_target]})

        assert {:ok, {:some, second_generation}} = Guppy.Native.Nif.event_target_status()
        assert second_generation > first_generation

        Process.exit(first_target, :kill)
        Process.sleep(50)
        assert {:ok, {:some, ^second_generation}} = Guppy.Native.Nif.event_target_status()

        Process.exit(second_target, :kill)

        wait_until(fn ->
          status = apply(Guppy.Native.Nif, :event_target_status, [])
          match?({:ok, :none}, status)
        end)

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.Native.Nif.event_target_status()
    end
  end

  test "server restart re-registers the event target and resets native views" do
    server = :"guppy_restart_native_#{System.unique_integer([:positive])}"

    {:ok, native_state} =
      start_supervised(
        {Agent,
         fn ->
           %{
             event_targets: [],
             current_event_target: nil,
             views: %{99 => true},
             renders: [],
             close_all_count: 0,
             unknown_requests: []
           }
         end}
      )

    supervisor_name = :"guppy_restart_supervisor_#{System.unique_integer([:positive])}"

    {:ok, supervisor} =
      start_supervised(%{
        id: supervisor_name,
        start:
          {Supervisor, :start_link,
           [
             [
               {Guppy.Server,
                name: server,
                native: Guppy.RestartRecordingNative,
                native_server: native_state,
                native_request_timeout: 25}
             ],
             [strategy: :one_for_one, name: supervisor_name]
           ]}
      })

    first_server = Process.whereis(server)
    assert is_pid(first_server)

    assert %{event_targets: [^first_server], views: %{}, close_all_count: 1} =
             Agent.get(native_state, & &1)

    {:ok, view_id} = Guppy.Server.open_window(server, self(), Guppy.IR.text("restart"), [], 25)
    assert view_id == 1
    assert {:ok, 1} = Guppy.Server.view_count(server, 25)

    Process.exit(first_server, :kill)

    wait_until(fn ->
      pid = Process.whereis(server)
      is_pid(pid) and pid != first_server
    end)

    restarted_server = Process.whereis(server)

    assert %{event_targets: [^first_server, ^restarted_server], views: %{}, close_all_count: 2} =
             Agent.get(native_state, & &1)

    assert Supervisor.which_children(supervisor) != []
  end

  test "native requests emit telemetry" do
    handler_id = {__MODULE__, self(), :native_request_telemetry}

    :ok = attach_forwarding_telemetry(handler_id, [:guppy, :native, :request])

    try do
      _ = Guppy.ping()

      assert_receive {:telemetry_event, [:guppy, :native, :request], %{duration: duration},
                      %{command: :ping, status: status}}

      assert is_integer(duration)
      assert status in [:ok, {:error, :nif_not_loaded}]
    after
      :telemetry.detach(handler_id)
    end
  end

  test "native decode errors preserve reasons instead of raising badarg" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        assert {:error, {:decode_error, reason}} =
                 Guppy.Native.Nif.request(Guppy.Native.Nif, {:render, [1, %{kind: :text}]})

        assert is_binary(reason)
        assert reason != ""

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} =
                 Guppy.Native.Nif.request(Guppy.Native.Nif, {:render, [1, %{kind: :text}]})
    end
  end

  test "direct NIF calls emit telemetry when native code is loaded" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        handler_id = {__MODULE__, self(), :native_nif_telemetry}

        :ok = attach_forwarding_telemetry(handler_id, [:guppy, :native, :nif])

        try do
          assert {:ok, :pong} = Guppy.ping()

          assert_receive {:telemetry_event, [:guppy, :native, :nif], %{duration: duration},
                          %{command: :ping, status: :ok}}

          assert is_integer(duration)
        after
          :telemetry.detach(handler_id)
        end

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.ping()
    end
  end

  test "native performance counters expose Rust boundary timing" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        assert {:ok, before_counters} = Guppy.native_performance_counters()
        assert is_map(before_counters)
        assert is_integer(before_counters["render_ir_decode_count"])
        assert is_integer(before_counters["render_ir_decode_native_time_ns"])
        assert is_integer(before_counters["open_ir_decode_count"])
        assert is_integer(before_counters["open_ir_decode_native_time_ns"])
        assert is_integer(before_counters["native_event_send_count"])
        assert is_integer(before_counters["native_event_send_native_time_ns"])
        assert is_integer(before_counters["native_event_send_failure_count"])

        ir = Guppy.IR.text("counter probe", id: "counter_probe")
        {:ok, view_id} = Guppy.open_window(ir, show: false)
        on_exit(fn -> maybe_close(view_id) end)
        assert :ok = Guppy.render(view_id, ir)

        assert {:ok, after_counters} = Guppy.native_performance_counters()

        assert after_counters["open_ir_decode_count"] >=
                 before_counters["open_ir_decode_count"] + 1

        assert after_counters["render_ir_decode_count"] >=
                 before_counters["render_ir_decode_count"] + 1

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.native_performance_counters()
    end
  end

  test "native event routing emits telemetry" do
    handler_id = {__MODULE__, self(), :event_route_telemetry}

    :ok = attach_forwarding_telemetry(handler_id, [:guppy, :event, :route])

    try do
      send(Guppy.server(), {
        :guppy_native_event,
        -1,
        :click,
        %{id: "missing", callback: "missing"}
      })

      assert_receive {:telemetry_event, [:guppy, :event, :route], %{count: 1},
                      %{view_id: -1, type: :click, status: :unknown_view_id}}

      send(Guppy.server(), {:guppy_native_event, -1, :window_close_requested, :undefined})

      assert_receive {:telemetry_event, [:guppy, :event, :route], %{count: 1},
                      %{view_id: -1, type: :window_close_requested, status: :unknown_view_id}}

      send(Guppy.server(), {:guppy_native_event, -1, :window_closed, :undefined})

      assert_receive {:telemetry_event, [:guppy, :event, :route], %{count: 1},
                      %{view_id: -1, type: :window_closed, status: :unknown_view_id}}
    after
      :telemetry.detach(handler_id)
    end
  end

  test "window option validation accepts supported shapes and rejects invalid ones" do
    assert {:ok, %{}} = Guppy.Server.validate_window_options_for_test([])

    assert {:ok, %{window_bounds: %{width: 960, height: 720, state: :windowed}}} =
             Guppy.Server.validate_window_options_for_test(
               window_bounds: [width: 960, height: 720]
             )

    assert {:ok,
            %{
              titlebar: %{
                title: "Example",
                appears_transparent: true,
                traffic_light_position: %{x: 12, y: 18}
              },
              focus: false,
              show: true,
              kind: :floating,
              is_movable: false,
              is_resizable: true,
              is_minimizable: false,
              display_id: 2,
              window_background: :transparent,
              app_id: "dev.example.guppy",
              window_min_size: %{width: 640, height: 480},
              window_decorations: :client,
              tabbing_identifier: "example-tab-group"
            }} =
             Guppy.Server.validate_window_options_for_test(
               titlebar: [
                 title: "Example",
                 appears_transparent: true,
                 traffic_light_position: [x: 12, y: 18]
               ],
               focus: false,
               show: true,
               kind: :floating,
               is_movable: false,
               is_resizable: true,
               is_minimizable: false,
               display_id: 2,
               window_background: :transparent,
               app_id: "dev.example.guppy",
               window_min_size: [width: 640, height: 480],
               window_decorations: :client,
               tabbing_identifier: "example-tab-group"
             )

    assert {:error, :invalid_window_options} =
             Guppy.Server.validate_window_options_for_test(window_bounds: [width: 960])

    assert {:error, :invalid_window_options} =
             Guppy.Server.validate_window_options_for_test(window_min_size: [width: 640])

    assert {:error, :invalid_window_options} =
             Guppy.Server.validate_window_options_for_test(titlebar: [unknown: true])

    assert {:error, :invalid_window_options} =
             Guppy.Server.validate_window_options_for_test(unknown_key: true)

    assert {:error, :invalid_window_options} =
             Guppy.Server.validate_window_options_for_test(kind: :dialog)
  end

  test "hidden window positioning options reach the native window path" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        starting_count = native_view_count!()

        {:ok, view_id} =
          Guppy.open_window(
            Guppy.IR.text("positioning smoke"),
            show: false,
            focus: false,
            window_bounds: [x: 24, y: 32, width: 320, height: 240],
            window_min_size: [width: 160, height: 120],
            kind: :floating,
            window_decorations: :client,
            window_background: :transparent
          )

        on_exit(fn -> maybe_close(view_id) end)
        assert Guppy.native_view_count() == {:ok, starting_count + 1}
        assert :ok = Guppy.close_window(view_id)
        assert Guppy.native_view_count() == {:ok, starting_count}

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} =
                 Guppy.open_window(Guppy.IR.text("positioning smoke"), show: false)
    end
  end

  test "view ownership is enforced by the server" do
    parent = self()

    spawn(fn ->
      send(
        parent,
        {:owner_mismatch, Guppy.Server.open_window(Guppy.Server, parent, Guppy.IR.text("nope"))}
      )
    end)

    assert_receive {:owner_mismatch, {:error, :owner_mismatch}}

    case Guppy.Native.Nif.load_status() do
      :ok ->
        {:ok, view_id} = Guppy.open_window(Guppy.IR.text("owned by caller"))
        on_exit(fn -> maybe_close(view_id) end)

        spawn(fn ->
          send(parent, {:foreign_render, Guppy.render(view_id, Guppy.IR.text("nope"))})

          send(
            parent,
            {:foreign_render_again, Guppy.render(view_id, Guppy.IR.text("still nope"))}
          )

          send(parent, {:foreign_close, Guppy.close_window(view_id)})
        end)

        assert_receive {:foreign_render, {:error, :not_view_owner}}
        assert_receive {:foreign_render_again, {:error, :not_view_owner}}
        assert_receive {:foreign_close, {:error, :not_view_owner}}

        assert :ok = Guppy.close_window(view_id)

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.open_window(Guppy.IR.text("hello"))
    end
  end

  test "window lifecycle, bridge view IR, native event routing, and owner cleanup are tracked" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        starting_count = native_view_count!()

        {:ok, view_id} =
          Guppy.open_window(
            Guppy.IR.div(
              [
                Guppy.IR.text("Hello from IR", id: "greeting"),
                Guppy.IR.text("Rendered as a nested tree")
              ],
              id: "root",
              style: [:flex, :flex_col, :gap_2, :p_4, {:bg, :gray}]
            )
          )

        on_exit(fn -> maybe_close(view_id) end)

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.scroll(
                     [
                       Guppy.IR.text("Hello again from IR"),
                       Guppy.IR.div([
                         Guppy.IR.text("Nested div rerender")
                       ])
                     ],
                     id: "scroll_root",
                     style: [{:h_px, 180}, :p_2, :rounded_md, :border_1, {:border_color, :white}]
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.div([Guppy.IR.text("Hover for tooltip")],
                     id: "tooltip_target",
                     tooltip: "Native tooltip smoke"
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.popover(
                     "Help",
                     true,
                     [Guppy.IR.text("Native popover body")],
                     id: "native_popover",
                     anchor: :bottom_right,
                     anchor_offset: {0, 10},
                     anchor_position_mode: :local,
                     anchor_fit: :snap_to_window_with_margin,
                     snap_margin: 10,
                     stack_priority: 2,
                     events: %{click: "open_popover", close: "close_popover"}
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.div(
                     [
                       Guppy.IR.div([Guppy.IR.text("Header")], style: [:col_span_full]),
                       Guppy.IR.div([Guppy.IR.text("Content")],
                         style: [{:col_span, 3}, {:row_span, 2}]
                       )
                     ],
                     id: "native_grid",
                     animation: %{
                       id: "native_grid_fade",
                       duration_ms: 250,
                       repeat: true,
                       from: 0.4,
                       to: 1.0
                     },
                     style: [:grid, {:grid_cols, 5}, {:grid_rows, 3}, :gap_1]
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.rich_text(
                     [
                       %{text: "Native ", style: [:font_bold]},
                       %{text: "rich text", style: [{:text_color, :yellow}, :underline]}
                     ],
                     id: "native_rich_text",
                     events: %{click: "native_rich_text_clicked"}
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.uniform_list(
                     [%{id: "native_item_1", label: "Native item 1"}],
                     id: "native_uniform_items",
                     style: [{:h_px, 120}],
                     item_style: [:p_2],
                     events: %{click: "native_item_clicked"}
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.list(
                     [
                       %{
                         id: "native_generic_1",
                         children: [
                           Guppy.IR.text("Native generic row"),
                           Guppy.IR.div([Guppy.IR.text("Variable height detail")])
                         ]
                       }
                     ],
                     id: "native_generic_items",
                     style: [{:h_px, 140}],
                     item_style: [:p_2, :border_b_1],
                     events: %{click: "native_generic_item_clicked"}
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.select(
                     [
                       %{value: "todo", label: "Todo"},
                       %{value: "done", label: "Done"}
                     ],
                     id: "native_status_select",
                     value: "todo",
                     open: true,
                     placeholder: "Pick status",
                     style: [{:w_px, 240}],
                     list_style: [:p_1, :shadow_lg],
                     option_style: [:p_2],
                     events: %{
                       click: "toggle_status",
                       change: "status_changed",
                       close: "close_status"
                     }
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.radio(
                     "High priority",
                     "high",
                     true,
                     id: "native_priority_high",
                     events: %{change: "priority_changed"}
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.text_input(
                     "Jason",
                     id: "native_name",
                     placeholder: "Name",
                     style: [{:w_px, 240}],
                     events: %{
                       change: "name_changed",
                       focus: "name_focused",
                       blur: "name_blurred"
                     }
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.textarea(
                     "Line one\nLine two",
                     id: "native_notes",
                     placeholder: "Notes",
                     style: [{:w_px, 320}, {:h_px, 120}],
                     events: %{
                       change: "notes_changed",
                       focus: "notes_focused",
                       blur: "notes_blurred"
                     }
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.button(
                     "Save via button node",
                     id: "save_button",
                     style: [{:bg, :blue}],
                     focus_visible_style: [{:border_color, :yellow}, :shadow_lg],
                     events: %{click: "save"}
                   )
                 )

        assert :ok =
                 Guppy.render(
                   view_id,
                   Guppy.IR.div(
                     [
                       Guppy.IR.text("Clickable IR tree"),
                       Guppy.IR.text("Simulated click should roundtrip",
                         id: "increment_text",
                         events: %{click: "increment"}
                       )
                     ],
                     id: "increment_button",
                     events: %{click: "increment"}
                   )
                 )

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :click,
          %{id: "increment_text", callback: "increment"}
        })

        assert_receive {:guppy_event, ^view_id,
                        %{type: :click, id: "increment_text", callback: "increment"}}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :close,
          %{id: "native_popover.popover", callback: "close_popover"}
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :close,
                          id: "native_popover.popover",
                          callback: "close_popover"
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :change,
          %{id: "name_input", callback: "name_changed", value: "Jason"}
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :change,
                          id: "name_input",
                          callback: "name_changed",
                          value: "Jason"
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :hover,
          %{id: "increment_button", callback: "hover_increment", hovered: true}
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :hover,
                          id: "increment_button",
                          callback: "hover_increment",
                          hovered: true
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :focus,
          %{id: "increment_button", callback: "focused"}
        })

        assert_receive {:guppy_event, ^view_id,
                        %{type: :focus, id: "increment_button", callback: "focused"}}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :blur,
          %{id: "increment_button", callback: "blurred"}
        })

        assert_receive {:guppy_event, ^view_id,
                        %{type: :blur, id: "increment_button", callback: "blurred"}}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :key_down,
          %{
            id: "increment_button",
            callback: "keyed_down",
            key: "j",
            key_char: "j",
            is_held: false,
            modifiers: %{
              control: true,
              alt: false,
              shift: false,
              platform: false,
              function: false
            }
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :key_down,
                          id: "increment_button",
                          callback: "keyed_down",
                          key: "j",
                          key_char: "j",
                          is_held: false,
                          modifiers: %{control: true}
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :key_up,
          %{
            id: "increment_button",
            callback: "keyed_up",
            key: "j",
            key_char: nil,
            modifiers: %{
              control: false,
              alt: false,
              shift: false,
              platform: false,
              function: false
            }
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :key_up,
                          id: "increment_button",
                          callback: "keyed_up",
                          key: "j",
                          key_char: nil,
                          modifiers: %{}
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :context_menu,
          %{
            id: "increment_button",
            callback: "contexted",
            x: 128.0,
            y: 72.0,
            modifiers: %{
              control: false,
              alt: false,
              shift: false,
              platform: true,
              function: false
            }
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :context_menu,
                          id: "increment_button",
                          callback: "contexted",
                          x: 128.0,
                          y: 72.0,
                          modifiers: %{platform: true}
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :action,
          %{
            id: "keyboard_pad",
            callback: "shortcut_primary",
            action: "primary",
            shortcut: "ctrl-j",
            key: "j",
            key_char: "j",
            modifiers: %{
              control: true,
              alt: false,
              shift: false,
              platform: false,
              function: false
            }
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :action,
                          id: "keyboard_pad",
                          callback: "shortcut_primary",
                          action: "primary",
                          shortcut: "ctrl-j",
                          key: "j",
                          key_char: "j",
                          modifiers: %{control: true}
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :drag_start,
          %{
            id: "drag_source",
            callback: "dragged_start",
            source_id: "drag_source"
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :drag_start,
                          id: "drag_source",
                          callback: "dragged_start",
                          source_id: "drag_source"
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :drag_move,
          %{
            id: "drag_source",
            callback: "dragged_move",
            source_id: "drag_source",
            pressed_button: :left,
            x: 136.0,
            y: 84.0,
            modifiers: %{
              control: true,
              alt: false,
              shift: false,
              platform: false,
              function: false
            }
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :drag_move,
                          id: "drag_source",
                          callback: "dragged_move",
                          source_id: "drag_source",
                          pressed_button: :left,
                          x: 136.0,
                          y: 84.0,
                          modifiers: %{control: true}
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :drop,
          %{
            id: "drop_target",
            callback: "dropped",
            source_id: "drag_source"
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :drop,
                          id: "drop_target",
                          callback: "dropped",
                          source_id: "drag_source"
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :mouse_down,
          %{
            id: "increment_button",
            callback: "pointer_down",
            button: :left,
            x: 120.5,
            y: 64.0,
            click_count: 1,
            first_mouse: false,
            modifiers: %{
              control: false,
              alt: false,
              shift: true,
              platform: false,
              function: false
            }
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :mouse_down,
                          id: "increment_button",
                          callback: "pointer_down",
                          button: :left,
                          x: 120.5,
                          y: 64.0,
                          click_count: 1,
                          first_mouse: false,
                          modifiers: %{shift: true}
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :mouse_up,
          %{
            id: "increment_button",
            callback: "pointer_up",
            button: :left,
            x: 122.0,
            y: 70.0,
            click_count: 1,
            modifiers: %{
              control: false,
              alt: false,
              shift: false,
              platform: false,
              function: false
            }
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :mouse_up,
                          id: "increment_button",
                          callback: "pointer_up",
                          button: :left,
                          x: 122.0,
                          y: 70.0,
                          click_count: 1,
                          modifiers: %{}
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :mouse_move,
          %{
            id: "increment_button",
            callback: "pointer_move",
            pressed_button: nil,
            x: 140.0,
            y: 88.0,
            modifiers: %{
              control: false,
              alt: true,
              shift: false,
              platform: false,
              function: false
            }
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :mouse_move,
                          id: "increment_button",
                          callback: "pointer_move",
                          pressed_button: nil,
                          x: 140.0,
                          y: 88.0,
                          modifiers: %{alt: true}
                        }}

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :scroll_wheel,
          %{
            id: "increment_button",
            callback: "pointer_scroll",
            x: 140.0,
            y: 88.0,
            delta_kind: :pixels,
            delta_x: 0.0,
            delta_y: -24.0,
            modifiers: %{
              control: false,
              alt: false,
              shift: false,
              platform: true,
              function: false
            }
          }
        })

        assert_receive {:guppy_event, ^view_id,
                        %{
                          type: :scroll_wheel,
                          id: "increment_button",
                          callback: "pointer_scroll",
                          x: 140.0,
                          y: 88.0,
                          delta_kind: :pixels,
                          delta_x: delta_x,
                          delta_y: -24.0,
                          modifiers: %{platform: true}
                        }}

        assert delta_x == 0.0

        assert :ok = Guppy.render(view_id, Guppy.IR.text("Hello again from Elixir"))
        assert Guppy.native_view_count() == {:ok, starting_count + 1}

        close_route_handler_id = {__MODULE__, self(), :known_window_closed_route}
        :ok = attach_forwarding_telemetry(close_route_handler_id, [:guppy, :event, :route])
        on_exit(fn -> :telemetry.detach(close_route_handler_id) end)

        send(Guppy.server(), {:guppy_native_event, view_id, :window_close_requested, :undefined})

        assert_receive {:guppy_event, ^view_id, %{type: :window_close_requested}}

        assert_receive {:telemetry_event, [:guppy, :event, :route], %{count: 1},
                        %{view_id: ^view_id, type: :window_close_requested, status: :ok}}

        assert Map.has_key?(Guppy.info().views, view_id)

        send(Guppy.server(), {:guppy_native_event, view_id, :window_closed, :undefined})

        assert_receive {:guppy_event, ^view_id, %{type: :window_closed}}

        assert_receive {:telemetry_event, [:guppy, :event, :route], %{count: 1},
                        %{view_id: ^view_id, type: :window_closed, status: :ok}}

        refute Map.has_key?(Guppy.info().views, view_id)

        assert :ok =
                 Guppy.Native.Nif.request(Guppy.Native.Nif, {:close_window, [view_id]})

        assert Guppy.native_view_count() == {:ok, starting_count}

        owner = self()
        {:ok, owned_view_id} = Guppy.open_window(Guppy.IR.text("owned by owner"))
        on_exit(fn -> maybe_close(owned_view_id) end)

        assert Map.get(Guppy.info().views, owned_view_id) == owner

        cleanup_handler_id = {__MODULE__, self(), :owner_cleanup_native_request}
        :ok = attach_forwarding_telemetry(cleanup_handler_id, [:guppy, :native, :request])
        on_exit(fn -> :telemetry.detach(cleanup_handler_id) end)

        pid =
          spawn(fn ->
            {:ok, transient_view_id} = Guppy.open_window(Guppy.IR.text("transient"))
            send(owner, {:opened_view, transient_view_id})
            Process.sleep(:infinity)
          end)

        transient_view_id =
          receive do
            {:opened_view, view_id} -> view_id
          after
            1_000 -> flunk("timed out waiting for transient window")
          end

        assert Map.get(Guppy.info().views, transient_view_id) == pid
        assert Guppy.native_view_count() == {:ok, starting_count + 2}

        Process.exit(pid, :kill)
        wait_until(fn -> not Map.has_key?(Guppy.info().views, transient_view_id) end)

        assert_receive {:telemetry_event, [:guppy, :native, :request], %{duration: duration},
                        %{command: :close_window, status: :ok}}

        assert is_integer(duration)
        assert Guppy.native_view_count() == {:ok, starting_count + 1}

        :ok = Guppy.close_window(owned_view_id)
        assert Guppy.native_view_count() == {:ok, starting_count}

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.open_window(Guppy.IR.text("hello"))
    end
  end
end
