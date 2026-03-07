defmodule GuppyTest do
  use ExUnit.Case

  test "boots the guppy supervision tree" do
    assert Guppy.started?()

    state = Guppy.info()

    assert state.native == Guppy.Native.Nif
    assert state.native_server == Guppy.Native.Nif
    assert state.next_view_id >= 1
    assert is_binary(Guppy.nif_path())
  end

  test "ir validation accepts ordered style lists and rejects invalid values" do
    assert :ok = Guppy.IR.validate(Guppy.IR.text("hello", id: "greeting"))
    assert :ok = Guppy.IR.validate(Guppy.IR.text("hello", events: %{click: "open"}))

    styled_ir =
      Guppy.IR.div(
        [Guppy.IR.text("hello")],
        id: "root",
        hover_style: [{:bg_hex, "#101010"}, {:opacity, 0.9}, :cursor_pointer],
        focus_style: [{:bg_hex, "#202020"}, {:text_color, :yellow}],
        in_focus_style: [{:border_color, :yellow}, :shadow_md],
        active_style: [{:opacity, 0.6}, {:bg_hex, "#303030"}],
        disabled_style: [{:opacity, 0.4}, {:bg, :black}],
        disabled: false,
        stack_priority: 7,
        occlude: true,
        focusable: true,
        tab_stop: true,
        tab_index: 3,
        track_scroll: true,
        anchor_scroll: true,
        actions: %{"save" => "save_action", "open" => "open_action"},
        shortcuts: [{"ctrl-s", "save"}, {"ctrl-o", "open"}],
        events: %{
          hover: "hovered",
          click: "clicked",
          focus: "focused",
          blur: "blurred",
          key_down: "keyed_down",
          key_up: "keyed_up",
          context_menu: "contexted",
          drag_start: "dragged_start",
          drag_move: "dragged_move",
          drop: "dropped",
          mouse_down: "down",
          mouse_up: "up",
          mouse_move: "move",
          scroll_wheel: "wheel"
        },
        style: [
          :flex,
          :flex_col,
          :flex_row,
          :flex_wrap,
          :flex_nowrap,
          :flex_none,
          :flex_auto,
          :flex_grow,
          :flex_shrink,
          :flex_shrink_0,
          :flex_1,
          :size_full,
          :w_full,
          :h_full,
          :w_32,
          :w_96,
          :h_32,
          :min_w_32,
          :min_h_0,
          :min_h_full,
          :max_w_64,
          :max_w_96,
          :max_w_full,
          :max_h_32,
          :max_h_96,
          :max_h_full,
          :gap_1,
          :gap_2,
          :gap_4,
          :p_1,
          :p_2,
          :p_4,
          :p_6,
          :p_8,
          :px_2,
          :py_2,
          :pt_2,
          :pr_2,
          :pb_2,
          :pl_2,
          :m_2,
          :mx_2,
          :my_2,
          :mt_2,
          :mr_2,
          :mb_2,
          :ml_2,
          :relative,
          :absolute,
          :top_0,
          :right_0,
          :bottom_0,
          :left_0,
          :inset_0,
          :top_1,
          :right_1,
          :top_2,
          :right_2,
          :bottom_2,
          :left_2,
          :text_left,
          :text_center,
          :text_right,
          :whitespace_normal,
          :whitespace_nowrap,
          :truncate,
          :text_ellipsis,
          :line_clamp_2,
          :line_clamp_3,
          :text_xs,
          :text_sm,
          :text_base,
          :text_lg,
          :text_xl,
          :text_2xl,
          :text_3xl,
          :leading_none,
          :leading_tight,
          :leading_snug,
          :leading_normal,
          :leading_relaxed,
          :leading_loose,
          :font_thin,
          :font_extralight,
          :font_light,
          :font_normal,
          :font_medium,
          :font_semibold,
          :font_bold,
          :font_extrabold,
          :font_black,
          :italic,
          :not_italic,
          :underline,
          :line_through,
          :items_start,
          :items_end,
          :justify_start,
          :justify_center,
          :justify_end,
          :justify_between,
          :justify_around,
          {:bg, :gray},
          :rounded_sm,
          :rounded_md,
          :rounded_lg,
          :rounded_xl,
          :rounded_2xl,
          :rounded_full,
          :border_1,
          :border_2,
          :border_dashed,
          :border_t_1,
          :border_r_1,
          :border_b_1,
          :border_l_1,
          :shadow_sm,
          :shadow_md,
          :shadow_lg,
          {:border_color, :white},
          {:bg_hex, "#112233"},
          {:text_color_hex, "445566"},
          {:border_color_hex, "#abcdef"},
          {:opacity, 0.75},
          {:w_px, 320},
          {:w_rem, 24.0},
          {:w_frac, 0.5},
          {:h_px, 180},
          {:h_rem, 12.0},
          {:h_frac, 1.0},
          {:scrollbar_width_px, 12},
          {:scrollbar_width_rem, 1.0},
          :overflow_y_scroll,
          {:bg, :blue}
        ]
      )

    assert :ok = Guppy.IR.validate(styled_ir)

    assert styled_ir.focus_style == [{:bg_hex, "#202020"}, {:text_color, :yellow}]
    assert styled_ir.in_focus_style == [{:border_color, :yellow}, :shadow_md]
    assert styled_ir.active_style == [{:opacity, 0.6}, {:bg_hex, "#303030"}]
    assert styled_ir.disabled_style == [{:opacity, 0.4}, {:bg, :black}]
    assert styled_ir.actions == %{"save" => "save_action", "open" => "open_action"}
    assert styled_ir.shortcuts == [{"ctrl-s", "save"}, {"ctrl-o", "open"}]
    assert styled_ir.disabled == false
    assert styled_ir.stack_priority == 7
    assert styled_ir.occlude == true
    assert styled_ir.focusable == true
    assert styled_ir.tab_stop == true
    assert styled_ir.tab_index == 3

    assert styled_ir.style == [
             :flex,
             :flex_col,
             :flex_row,
             :flex_wrap,
             :flex_nowrap,
             :flex_none,
             :flex_auto,
             :flex_grow,
             :flex_shrink,
             :flex_shrink_0,
             :flex_1,
             :size_full,
             :w_full,
             :h_full,
             :w_32,
             :w_96,
             :h_32,
             :min_w_32,
             :min_h_0,
             :min_h_full,
             :max_w_64,
             :max_w_96,
             :max_w_full,
             :max_h_32,
             :max_h_96,
             :max_h_full,
             :gap_1,
             :gap_2,
             :gap_4,
             :p_1,
             :p_2,
             :p_4,
             :p_6,
             :p_8,
             :px_2,
             :py_2,
             :pt_2,
             :pr_2,
             :pb_2,
             :pl_2,
             :m_2,
             :mx_2,
             :my_2,
             :mt_2,
             :mr_2,
             :mb_2,
             :ml_2,
             :relative,
             :absolute,
             :top_0,
             :right_0,
             :bottom_0,
             :left_0,
             :inset_0,
             :top_1,
             :right_1,
             :top_2,
             :right_2,
             :bottom_2,
             :left_2,
             :text_left,
             :text_center,
             :text_right,
             :whitespace_normal,
             :whitespace_nowrap,
             :truncate,
             :text_ellipsis,
             :line_clamp_2,
             :line_clamp_3,
             :text_xs,
             :text_sm,
             :text_base,
             :text_lg,
             :text_xl,
             :text_2xl,
             :text_3xl,
             :leading_none,
             :leading_tight,
             :leading_snug,
             :leading_normal,
             :leading_relaxed,
             :leading_loose,
             :font_thin,
             :font_extralight,
             :font_light,
             :font_normal,
             :font_medium,
             :font_semibold,
             :font_bold,
             :font_extrabold,
             :font_black,
             :italic,
             :not_italic,
             :underline,
             :line_through,
             :items_start,
             :items_end,
             :justify_start,
             :justify_center,
             :justify_end,
             :justify_between,
             :justify_around,
             {:bg, :gray},
             :rounded_sm,
             :rounded_md,
             :rounded_lg,
             :rounded_xl,
             :rounded_2xl,
             :rounded_full,
             :border_1,
             :border_2,
             :border_dashed,
             :border_t_1,
             :border_r_1,
             :border_b_1,
             :border_l_1,
             :shadow_sm,
             :shadow_md,
             :shadow_lg,
             {:border_color, :white},
             {:bg_hex, "#112233"},
             {:text_color_hex, "445566"},
             {:border_color_hex, "#abcdef"},
             {:opacity, 0.75},
             {:w_px, 320},
             {:w_rem, 24.0},
             {:w_frac, 0.5},
             {:h_px, 180},
             {:h_rem, 12.0},
             {:h_frac, 1.0},
             {:scrollbar_width_px, 12},
             {:scrollbar_width_rem, 1.0},
             :overflow_y_scroll,
             {:bg, :blue}
           ]

    assert {:error, {:invalid_id, 123}} = Guppy.IR.validate(Guppy.IR.text("hello", id: 123))

    assert {:error, {:invalid_style_op, :bogus}} =
             Guppy.IR.validate(Guppy.IR.div([], style: [:bogus]))

    assert {:error, {:invalid_style_op, {:bg, :purple}}} =
             Guppy.IR.validate(Guppy.IR.div([], style: [{:bg, :purple}]))

    assert {:error, {:invalid_style_op, {:opacity, 1.5}}} =
             Guppy.IR.validate(Guppy.IR.div([], style: [{:opacity, 1.5}]))

    assert {:error, {:invalid_style_op, {:bg_hex, "#12"}}} =
             Guppy.IR.validate(Guppy.IR.div([], style: [{:bg_hex, "#12"}]))

    assert {:error, {:invalid_style_op, :bogus}} =
             Guppy.IR.validate(Guppy.IR.div([], active_style: [:bogus]))

    assert {:error, {:invalid_style_op, :bogus}} =
             Guppy.IR.validate(Guppy.IR.div([], in_focus_style: [:bogus]))

    assert {:error, {:invalid_style_op, :bogus}} =
             Guppy.IR.validate(Guppy.IR.div([], disabled_style: [:bogus]))

    assert {:error, {:invalid_actions, [:nope]}} =
             Guppy.IR.validate(Guppy.IR.div([], actions: [:nope]))

    assert {:error, {:invalid_action_binding, :save, "save_action"}} =
             Guppy.IR.validate(Guppy.IR.div([], actions: %{save: "save_action"}))

    assert {:error, {:invalid_shortcuts, %{}}} =
             Guppy.IR.validate(Guppy.IR.div([], shortcuts: %{}))

    assert {:error, {:invalid_shortcut_binding, {1, "save"}}} =
             Guppy.IR.validate(
               Guppy.IR.div([], actions: %{"save" => "save_action"}, shortcuts: [{1, "save"}])
             )

    assert {:error, {:unknown_shortcut_action, "ctrl-s", "save"}} =
             Guppy.IR.validate(Guppy.IR.div([], shortcuts: [{"ctrl-s", "save"}]))

    assert {:error, {:track_scroll, "yes"}} =
             Guppy.IR.validate(Guppy.IR.div([], track_scroll: "yes"))

    assert {:error, {:anchor_scroll, 1}} =
             Guppy.IR.validate(Guppy.IR.div([], anchor_scroll: 1))

    assert {:error, {:disabled, "yes"}} =
             Guppy.IR.validate(Guppy.IR.div([], disabled: "yes"))

    assert {:error, {:stack_priority, -1}} =
             Guppy.IR.validate(Guppy.IR.div([], stack_priority: -1))

    assert {:error, {:occlude, "yes"}} =
             Guppy.IR.validate(Guppy.IR.div([], occlude: "yes"))

    assert {:error, {:focusable, "yes"}} =
             Guppy.IR.validate(Guppy.IR.div([], focusable: "yes"))

    assert {:error, {:tab_stop, 1}} =
             Guppy.IR.validate(Guppy.IR.div([], tab_stop: 1))

    assert {:error, {:tab_index, "first"}} =
             Guppy.IR.validate(Guppy.IR.div([], tab_index: "first"))
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

  test "window lifecycle, bridge view IR, native event routing, and owner cleanup are tracked" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        starting_count = native_view_count!()

        {:ok, view_id} = Guppy.open_window()
        on_exit(fn -> maybe_close(view_id) end)

        assert :ok =
                 Guppy.mount(
                   view_id,
                   Guppy.IR.div(
                     [
                       Guppy.IR.text("Hello from IR", id: "greeting"),
                       Guppy.IR.text("Rendered as a nested tree")
                     ],
                     id: "root",
                     style: [:flex, :flex_col, :gap_2, :p_4, {:bg, :gray}]
                   )
                 )

        assert :ok =
                 Guppy.update(
                   view_id,
                   Guppy.IR.div([
                     Guppy.IR.text("Hello again from IR"),
                     Guppy.IR.div([
                       Guppy.IR.text("Nested div rerender")
                     ])
                   ])
                 )

        assert :ok =
                 Guppy.update(
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

        assert :ok = Guppy.update_window_text(view_id, "Hello again from Elixir")
        assert Guppy.native_view_count() == {:ok, starting_count + 1}

        send(Guppy.server(), {:guppy_native_event, view_id, :window_closed, :undefined})

        assert_receive {:guppy_event, ^view_id, %{type: :window_closed}}
        refute Map.has_key?(Guppy.info().views, view_id)

        assert :ok =
                 Guppy.Native.Nif.request(Guppy.Native.Nif, {:close_window, [view_id]})

        assert Guppy.native_view_count() == {:ok, starting_count}

        owner = self()
        {:ok, owned_view_id} = Guppy.open_window(owner)
        on_exit(fn -> maybe_close(owned_view_id) end)

        assert Map.get(Guppy.info().views, owned_view_id) == owner

        pid =
          spawn(fn ->
            {:ok, transient_view_id} = Guppy.open_window(self())
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

        assert Guppy.native_view_count() == {:ok, starting_count + 1}

        :ok = Guppy.close_window(owned_view_id)
        assert Guppy.native_view_count() == {:ok, starting_count}

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.open_window()
    end
  end

  defp native_view_count! do
    case Guppy.native_view_count() do
      {:ok, count} -> count
      other -> flunk("expected native view count, got: #{inspect(other)}")
    end
  end

  defp maybe_close(view_id) do
    case Guppy.close_window(view_id) do
      :ok -> :ok
      {:error, :unknown_view_id} -> :ok
      {:error, :nif_not_loaded} -> :ok
    end
  end

  defp wait_until(fun, timeout \\ 1_000) do
    started_at = System.monotonic_time(:millisecond)
    do_wait_until(fun, timeout, started_at)
  end

  defp do_wait_until(fun, timeout, started_at) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) - started_at > timeout do
        flunk("condition not met within #{timeout}ms")
      else
        Process.sleep(10)
        do_wait_until(fun, timeout, started_at)
      end
    end
  end
end
