defmodule Guppy.AppTest do
  use ExUnit.Case

  import Guppy.TestSupport

  test "validates app config resources and defaults first window to start" do
    assert {:ok, config} =
             Guppy.App.Config.validate(
               %{
                 windows: [
                   %{id: "main", module: Guppy.AppContextWindow},
                   %{id: "secondary", module: Guppy.AppContextWindow}
                 ],
                 commands: [%{id: "new_file", label: "New File"}],
                 keymap: [%{key: "cmd-n", command: "new_file"}],
                 dock_menu: [%{id: "new_file", label: "New", callback: "new_file"}],
                 app_badge: "4",
                 stylesheet: %{classes: %{"card" => %{style: "p-2", hover_style: "bg-blue"}}},
                 package: %{bundle_id: "dev.guppy.test"}
               },
               Guppy.TestApp
             )

    assert config.id == "Guppy.TestApp"
    assert [%{id: "main", start: true}, %{id: "secondary", start: false}] = config.windows
    assert config.exit_on_last_window_closed == false
    assert Map.has_key?(config.commands, "new_file")
    assert config.dock_menu == [%{id: "new_file", label: "New", callback: "new_file"}]
    assert config.app_badge == "4"
    assert config.package.bundle_id == "dev.guppy.test"

    assert {:error, {:duplicate_window_id, "main"}} =
             Guppy.App.Config.validate(%{
               windows: [
                 %{id: "main", module: Guppy.AppContextWindow},
                 %{id: "main", module: Guppy.AppContextWindow}
               ]
             })

    assert {:error, {:unknown_command, "missing"}} =
             Guppy.App.Config.validate(%{keymap: [%{key: "cmd-x", command: "missing"}]})

    assert {:ok, %{exit_on_last_window_closed: true}} =
             Guppy.App.Config.validate(%{exit_on_last_window_closed: true})

    assert {:error, :invalid_exit_on_last_window_closed} =
             Guppy.App.Config.validate(%{exit_on_last_window_closed: :yes})

    assert {:error, :invalid_app_badge} = Guppy.App.Config.validate(%{app_badge: 4})
  end

  test "stylesheet resolves app class refs and Tailwind-style variants" do
    assert {:ok, stylesheet} =
             Guppy.App.Stylesheet.validate(%{
               classes: %{
                 "card" => %{style: "p-2", hover_style: "bg-blue"},
                 "danger" => "bg-red"
               }
             })

    resolved = Guppy.App.Stylesheet.resolve(stylesheet, "card hover:bg-red danger")

    assert {:style, style} = List.keyfind(resolved, :style, 0)
    assert {:hover_style, hover_style} = List.keyfind(resolved, :hover_style, 0)
    assert {:padding, :all, {:rem, 0.5}} in style
    assert {:bg, :red} in style
    assert {:bg, :blue} in hover_style
    assert {:bg, :red} in hover_style
  end

  test "app owns config/resource slots and dispatches menu commands" do
    app_name = :"guppy_test_app_#{System.unique_integer([:positive])}"

    {:ok, _pid} = start_supervised({Guppy.TestApp, name: app_name, parent: self()})

    assert %Guppy.App.Config{} = config = Guppy.App.config(app_name)
    assert config.metadata.parent == self()
    assert config.theme_families == %{}
    assert Guppy.App.theme(app_name).id == "test-dark"
    assert Guppy.App.package(app_name).bundle_id == "dev.guppy.test"
    assert Map.has_key?(Guppy.App.commands(app_name), "new_file")
    assert [%{key: "cmd-n", command: "new_file"}] = Guppy.App.keymap(app_name)
    assert [%{id: "new_file", label: "New", callback: "new_file"}] = Guppy.App.dock_menu(app_name)

    assert :ok = Guppy.App.dispatch(app_name, "new_file", %{source: :test})
    assert_receive {:app_command, "new_file", %{source: :test}}

    assert :ok = Guppy.App.dispatch_key(app_name, "cmd-n", %{source: :keymap})
    assert_receive {:app_command, "new_file", %{source: :keymap, key: "cmd-n"}}

    send(app_name, {:guppy_menu_event, %{id: "new_file", callback: "new_file"}})
    assert_receive {:app_command, "new_file", %{id: "new_file", callback: "new_file"}}

    send(
      app_name,
      {:guppy_menu_event, %{type: :dock_menu_action, id: "new_file", callback: "new_file"}}
    )

    assert_receive {:app_command, "new_file",
                    %{type: :dock_menu_action, id: "new_file", callback: "new_file"}}

    send(app_name, {:guppy_app_event, %{type: :app_activated}})
    assert_receive {:app_event, "app_activated", %{}}

    assert :ok = Guppy.App.set_command_enabled(app_name, "new_file", false)
    assert Guppy.App.commands(app_name)["new_file"].enabled == false
    assert :ok = Guppy.App.dispatch(app_name, "new_file", %{source: :disabled})
    refute_receive {:app_command, "new_file", %{source: :disabled}}, 100

    assert {:error, :invalid_command_enabled} =
             Guppy.App.set_command_enabled(app_name, "new_file", :yes)

    assert {:error, {:unknown_command, "missing"}} =
             Guppy.App.set_command_enabled(app_name, "missing", true)

    assert :ok = Guppy.App.set_command_enabled(app_name, "new_file", true)
    assert :ok = Guppy.App.dispatch(app_name, "new_file", %{source: :reenabled})
    assert_receive {:app_command, "new_file", %{source: :reenabled}}

    assert :ok =
             Guppy.App.set_dock_menu(app_name, [
               %{id: "new_file", label: "New from Dock", callback: "new_file"}
             ])

    assert [%{label: "New from Dock"}] = Guppy.App.dock_menu(app_name)

    assert :ok =
             Guppy.App.set_theme(app_name, %{
               id: "light",
               name: "Light",
               appearance: :light,
               colors: %{surface: "#ffffff", text: :black},
               styles: %{
                 panel: ["p-2", {:theme_color, :bg, :surface}, {:theme_color, :text_color, :text}]
               }
             })

    assert Guppy.App.theme(app_name).id == "light"

    assert :ok =
             Guppy.App.register_theme_family(app_name, %{
               id: "builtin",
               name: "Built-in",
               themes: [Guppy.App.Theme.default(:dark), Guppy.App.Theme.default(:light)]
             })

    assert %{"builtin" => family} = Guppy.App.theme_families(app_name)
    assert Map.has_key?(family.themes, "guppy.dark")
    assert :ok = Guppy.App.set_theme(app_name, "guppy.dark")
    assert Guppy.App.theme(app_name).id == "guppy.dark"
    assert {:error, {:unknown_theme, "missing"}} = Guppy.App.set_theme(app_name, "missing")

    assert :ok =
             Guppy.App.set_theme(app_name, %{
               id: "light",
               name: "Light",
               appearance: :light,
               colors: %{surface: "#ffffff", text: :black},
               styles: %{
                 panel: ["p-2", {:theme_color, :bg, :surface}, {:theme_color, :text_color, :text}]
               }
             })

    assert {:ok, "#ffffff"} = Guppy.App.theme_color(app_name, :surface)
    assert {:ok, panel_style} = Guppy.App.theme_style(app_name, "panel")
    assert {:bg_hex, "#ffffff"} in panel_style
    assert {:text_color, :black} in panel_style

    assert Guppy.active_theme(app_name).id == "light"
    assert {:ok, "#ffffff"} = Guppy.App.theme_color(app_name, :surface)
    assert {:ok, ^panel_style} = Guppy.App.theme_style(app_name, :panel)

    Guppy.App.put_window_context(app_name, "test")
    assert {:ok, ^panel_style} = Guppy.App.theme_style(:panel)
    assert "#ffffff" = Guppy.App.theme_color!(:surface)

    assert :ok = Guppy.App.set_stylesheet(app_name, %{classes: %{"pill" => "px-2 bg-green"}})
    assert {:style, style} = app_name |> Guppy.App.styles("pill") |> List.keyfind(:style, 0)
    assert {:bg, :green} in style

    palette_ir = Guppy.App.CommandPalette.render(%Guppy.Window{assigns: %{app: app_name}})
    assert :ok = Guppy.IR.validate(palette_ir)
  end

  test "runtime command replacement preserves compiled app resources" do
    app_name = :"guppy_runtime_commands_app_#{System.unique_integer([:positive])}"
    {:ok, _pid} = start_supervised({Guppy.TestApp, name: app_name, parent: self()})

    assert :ok = Guppy.App.set_commands(app_name, [%{id: "new_file", label: "New File"}])
    assert Map.has_key?(Guppy.App.commands(app_name), "new_file")
  end

  test "keymap routing skips disabled commands in priority order" do
    app_name = :"guppy_keymap_priority_app_#{System.unique_integer([:positive])}"
    {:ok, _pid} = start_supervised({Guppy.TestApp, name: app_name, parent: self()})

    assert :ok =
             Guppy.App.set_commands(app_name, [
               %{id: "new_file", label: "New File", enabled: false},
               %{id: "open_file", label: "Open File"}
             ])

    assert :ok =
             Guppy.App.set_keymap(app_name, [
               %{key: "cmd-o", command: "new_file"},
               %{key: "cmd-o", command: "open_file"}
             ])

    assert :ok = Guppy.App.dispatch_key(app_name, "cmd-o", %{source: :priority_test})
    assert_receive {:app_command, "open_file", %{source: :priority_test, key: "cmd-o"}}
    refute_receive {:app_command, "new_file", _payload}, 100
  end

  test "app context menu renders command items and dispatches selection" do
    app_name = :"guppy_context_menu_app_#{System.unique_integer([:positive])}"
    {:ok, _pid} = start_supervised({Guppy.TestApp, name: app_name, parent: self()})

    assert :ok =
             Guppy.App.set_commands(app_name, [
               %{id: "new_file", label: "New File"},
               %{id: "delete_file", label: "Delete File", enabled: false}
             ])

    window = %Guppy.Window{
      assigns: %{
        app: app_name,
        id: "file_menu",
        items: [%{command: "new_file"}, :separator, %{command: "delete_file"}]
      }
    }

    ir = Guppy.App.ContextMenu.render(window)
    assert :ok = Guppy.IR.validate(ir)

    assert [new_file, _separator, delete_file] = ir.children
    assert new_file.id == "file_menu.new_file"
    assert new_file.label == "New File"
    assert new_file.events == %{click: "run_context_menu_command"}
    assert delete_file.disabled == true

    assert {:stop, :normal, ^window} =
             Guppy.App.ContextMenu.handle_event(
               "run_context_menu_command",
               %{id: "file_menu.new_file"},
               window
             )

    assert_receive {:app_command, "new_file", %{source: :context_menu, menu_id: "file_menu"}}
  end

  test "app context menu returns focus to the source app window after selection" do
    app_name = :"guppy_context_menu_focus_app_#{System.unique_integer([:positive])}"
    {:ok, _pid} = start_supervised({Guppy.ContextMenuFocusApp, name: app_name, parent: self()})

    window = %Guppy.Window{
      assigns: %{
        app: app_name,
        id: "focus_menu",
        items: [%{command: "new_file"}],
        return_focus_to: "main"
      }
    }

    assert {:stop, :normal, ^window} =
             Guppy.App.ContextMenu.handle_event(
               "run_context_menu_command",
               %{id: "focus_menu.new_file"},
               window
             )

    assert_receive {:fake_app_command, "new_file",
                    %{source: :context_menu, menu_id: "focus_menu"}}

    assert_receive {:fake_app_focus_window, "main"}
  end

  test "app opens context menu as a transient popup window" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        app_name = :"guppy_context_menu_window_app_#{System.unique_integer([:positive])}"
        {:ok, _pid} = start_supervised({Guppy.TestApp, name: app_name, parent: self()})

        assert {:ok, menu_pid} =
                 Guppy.App.open_context_menu(app_name, [%{command: "new_file"}],
                   id: "test_context_menu",
                   window_options: [show: false, window_bounds: [width: 180, height: 100]]
                 )

        assert Guppy.App.window_pid(app_name, "test_context_menu") == menu_pid
        assert :ok = Guppy.App.close_window(app_name, "test_context_menu")
        wait_until(fn -> Guppy.App.window_pid(app_name, "test_context_menu") == nil end)

      {:error, _reason} ->
        :ok
    end
  end

  test "app command bindings produce root IR shortcut options" do
    app_name = :"guppy_command_bindings_app_#{System.unique_integer([:positive])}"
    {:ok, _pid} = start_supervised({Guppy.TestApp, name: app_name, parent: self()})

    assert [actions: %{"new_file" => callback}, shortcuts: [{"cmd-n", "new_file"}]] =
             Guppy.App.command_bindings(app_name)

    assert callback == Guppy.App.command_callback()
    assert :ok = Guppy.IR.validate(Guppy.IR.div([], Guppy.App.command_bindings(app_name)))
  end

  test "app-supervised windows route command shortcut actions to the app coordinator" do
    app_name = :"guppy_window_command_app_#{System.unique_integer([:positive])}"
    {:ok, _pid} = start_supervised({Guppy.TestApp, name: app_name, parent: self()})

    state = %Guppy.Window.State{
      module: Guppy.AppContextWindow,
      window: %Guppy.Window{view_id: 321},
      app: app_name,
      app_window_id: "main"
    }

    assert {:noreply, next_state} =
             Guppy.Window.handle_window_message(
               Guppy.AppContextWindow,
               {:guppy_event, 321,
                %{
                  type: :action,
                  id: "root",
                  callback: Guppy.App.command_callback(),
                  action: "new_file",
                  shortcut: "cmd-n"
                }},
               state
             )

    assert next_state.window == state.window

    assert_receive {:app_command, "new_file",
                    %{
                      action: "new_file",
                      shortcut: "cmd-n",
                      source: :window_shortcut,
                      window_id: "main"
                    }}
  end

  test "app-owned app badge installs, updates, and validates through native" do
    server = :"guppy_app_badge_native_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Guppy.Server,
       name: server,
       native: Guppy.TimeoutRecordingNative,
       native_server: self(),
       native_request_timeout: 25}
    )

    assert_receive {:guppy_test_native_request, {:set_event_target, [_pid]}, 25}

    app_name = :"guppy_badge_app_#{System.unique_integer([:positive])}"

    {:ok, _pid} =
      start_supervised(
        {Guppy.TestApp, name: app_name, parent: self(), runtime_server: server, app_badge: "2"}
      )

    assert_receive {:guppy_test_native_request, {:set_menus, [_menus]}, _timeout}
    assert_receive {:guppy_test_native_request, {:set_dock_menu, [_dock_menu]}, _timeout}
    assert_receive {:guppy_test_native_request, {:set_app_badge, ["2"]}, _timeout}
    assert Guppy.App.app_badge(app_name) == "2"

    assert :ok = Guppy.App.set_app_badge(app_name, nil)
    assert_receive {:guppy_test_native_request, {:set_app_badge, [nil]}, _timeout}
    assert Guppy.App.app_badge(app_name) == nil

    assert {:error, :invalid_app_badge} = Guppy.App.set_app_badge(app_name, 2)
    refute_receive {:guppy_test_native_request, {:set_app_badge, [_]}, _timeout}
  end

  test "app-owned menus derive enabled state from command registry" do
    server = :"guppy_app_command_menu_native_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Guppy.Server,
       name: server,
       native: Guppy.TimeoutRecordingNative,
       native_server: self(),
       native_request_timeout: 25}
    )

    assert_receive {:guppy_test_native_request, {:set_event_target, [_pid]}, 25}

    app_name = :"guppy_command_menu_app_#{System.unique_integer([:positive])}"

    {:ok, _pid} =
      start_supervised({Guppy.TestApp, name: app_name, parent: self(), runtime_server: server})

    assert_receive {:guppy_test_native_request, {:set_menus, [initial_menus]}, _timeout}
    assert_receive {:guppy_test_native_request, {:set_dock_menu, [initial_dock_menu]}, _timeout}
    assert [%{items: [%{id: "new_file"} = initial_item]}] = initial_menus
    assert [%{id: "new_file"} = initial_dock_item] = initial_dock_menu
    refute Map.get(initial_item, :enabled) == false
    refute Map.get(initial_dock_item, :enabled) == false

    assert :ok = Guppy.App.set_command_enabled(app_name, "new_file", false)
    assert_receive {:guppy_test_native_request, {:set_menus, [disabled_menus]}, _timeout}, 500

    assert_receive {:guppy_test_native_request, {:set_dock_menu, [disabled_dock_menu]}, _timeout},
                   500

    assert [%{items: [%{id: "new_file", enabled: false}]}] = disabled_menus
    assert [%{id: "new_file", enabled: false}] = disabled_dock_menu

    assert :ok = Guppy.App.set_command_enabled(app_name, "new_file", true)
    assert_receive {:guppy_test_native_request, {:set_menus, [reenabled_menus]}, _timeout}, 500

    assert_receive {:guppy_test_native_request, {:set_dock_menu, [reenabled_dock_menu]},
                    _timeout},
                   500

    assert [%{items: [%{id: "new_file"} = reenabled_item]}] = reenabled_menus
    assert [%{id: "new_file"} = reenabled_dock_item] = reenabled_dock_menu
    refute Map.get(reenabled_item, :enabled) == false
    refute Map.get(reenabled_dock_item, :enabled) == false
  end

  test "app can stop when the last app-supervised window closes" do
    app_name = :"guppy_exit_app_#{System.unique_integer([:positive])}"
    {:ok, app_pid} = Guppy.ExitOnLastWindowApp.start_link(name: app_name)
    app_ref = Process.monitor(app_pid)

    assert {:ok, window_pid} = Guppy.App.open_window(app_name, "plain")
    assert Process.alive?(window_pid)

    assert :ok = Guppy.App.close_window(app_name, "plain")
    assert_receive {:DOWN, ^app_ref, :process, ^app_pid, :normal}, 1_000
  end

  test "app stays alive by default when the last app-supervised window closes" do
    app_name = :"guppy_keep_alive_app_#{System.unique_integer([:positive])}"
    {:ok, app_pid} = start_supervised({Guppy.KeepAliveOnLastWindowApp, name: app_name})
    app_ref = Process.monitor(app_pid)

    assert {:ok, window_pid} = Guppy.App.open_window(app_name, "plain")
    assert Process.alive?(window_pid)

    assert :ok = Guppy.App.close_window(app_name, "plain")
    refute_receive {:DOWN, ^app_ref, :process, ^app_pid, _reason}, 100
    assert Process.alive?(app_pid)
  end

  test "app closes dependent windows when their parent window closes" do
    app_name = :"guppy_parent_child_app_#{System.unique_integer([:positive])}"
    {:ok, _app_pid} = start_supervised({Guppy.KeepAliveOnLastWindowApp, name: app_name})

    assert {:ok, parent_pid} =
             Guppy.App.open_window(app_name, "parent", module: Guppy.AppPlainWindow)

    assert {:ok, child_pid} =
             Guppy.App.open_window(app_name, "child",
               module: Guppy.AppPlainWindow,
               metadata: %{close_with_parent: true, parent_window_id: "parent"}
             )

    assert Guppy.App.windows(app_name) == %{"child" => child_pid, "parent" => parent_pid}

    assert :ok = Guppy.App.close_window(app_name, "parent")
    wait_until(fn -> Guppy.App.windows(app_name) == %{} end)
    refute Process.alive?(parent_pid)
    refute Process.alive?(child_pid)
  end

  test "transient app windows do not keep exit-on-last-window apps alive" do
    app_name = :"guppy_transient_exit_app_#{System.unique_integer([:positive])}"
    {:ok, app_pid} = Guppy.ExitOnLastWindowApp.start_link(name: app_name)
    app_ref = Process.monitor(app_pid)

    assert {:ok, _root_pid} = Guppy.App.open_window(app_name, "plain")

    assert {:ok, transient_pid} =
             Guppy.App.open_window(app_name, "palette",
               module: Guppy.AppPlainWindow,
               metadata: %{transient: true}
             )

    transient_ref = Process.monitor(transient_pid)

    assert :ok = Guppy.App.close_window(app_name, "plain")
    assert_receive {:DOWN, ^transient_ref, :process, ^transient_pid, _reason}, 1_000
    assert_receive {:DOWN, ^app_ref, :process, ^app_pid, :normal}, 1_000
  end

  test "app can focus an app-supervised window" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        app_name = :"guppy_focus_app_window_#{System.unique_integer([:positive])}"
        {:ok, _pid} = start_supervised({Guppy.TestApp, name: app_name, parent: self()})

        assert {:ok, _pid} =
                 Guppy.App.open_window(app_name, "main", arg: self(), opts: [show: false])

        assert :ok = Guppy.App.focus_window(app_name, "main")

      {:error, _reason} ->
        :ok
    end
  end

  test "app-supervised windows are registered and receive app context" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        app_name = :"guppy_window_app_#{System.unique_integer([:positive])}"
        {:ok, _pid} = start_supervised({Guppy.TestApp, name: app_name, parent: self()})

        assert {:ok, pid} =
                 Guppy.App.open_window(app_name, "main", arg: self(), opts: [show: false])

        assert Guppy.App.window_pid(app_name, "main") == pid
        assert Guppy.App.windows(app_name) == %{"main" => pid}

        assert_receive {:app_context_mount, ^app_name, "main"}
        assert_receive {:app_context_render, ^app_name, "main"}

        assert :ok = Guppy.App.close_window(app_name, "main")
        wait_until(fn -> Guppy.App.window_pid(app_name, "main") == nil end)

      {:error, _reason} ->
        :ok
    end
  end

  test "app reinstalls native resources after runtime server restart" do
    server = :"guppy_app_restart_native_#{System.unique_integer([:positive])}"
    app_name = :"guppy_restart_app_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Guppy.Server,
       name: server,
       native: Guppy.TimeoutRecordingNative,
       native_server: self(),
       native_request_timeout: 25}
    )

    {:ok, _pid} =
      start_supervised(
        {Guppy.TestApp, name: app_name, parent: self(), runtime_server: server, app_badge: "8"}
      )

    assert Guppy.App.theme(app_name).id == "test-dark"
    assert_receive {:guppy_test_native_request, {:set_menus, [_menus]}, _timeout}
    assert_receive {:guppy_test_native_request, {:set_dock_menu, [_dock_menu]}, _timeout}
    assert_receive {:guppy_test_native_request, {:set_app_badge, ["8"]}, _timeout}

    server_pid = Process.whereis(server)
    Process.exit(server_pid, :kill)

    wait_until(fn ->
      restarted = Process.whereis(server)
      is_pid(restarted) and restarted != server_pid
    end)

    assert_receive {:guppy_test_native_request, {:set_menus, [_menus]}, _timeout}, 500
    assert_receive {:guppy_test_native_request, {:set_dock_menu, [_dock_menu]}, _timeout}, 500
    assert_receive {:guppy_test_native_request, {:set_app_badge, ["8"]}, _timeout}, 500
    assert Guppy.App.theme(app_name).id == "test-dark"
  end

  test "server enforces a single native app owner for native-global resources" do
    server = :"guppy_app_owner_native_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Guppy.Server,
       name: server,
       native: Guppy.TimeoutRecordingNative,
       native_server: self(),
       native_request_timeout: 25}
    )

    assert_receive {:guppy_test_native_request, {:set_event_target, [_pid]}, 25}

    parent = self()

    owner =
      spawn(fn ->
        receive do
          :claim -> send(parent, {:claim, Guppy.Server.claim_app_owner(server, self())})
        end

        receive do
          :stop -> :ok
        end
      end)

    send(owner, :claim)
    assert_receive {:claim, :ok}

    assert {:error, :native_app_owner_already_claimed} =
             Guppy.Server.set_menus(server, self(), [], 25)

    send(owner, :stop)
    wait_until(fn -> Guppy.Server.info(server).app_owner == nil end)
    assert :ok = Guppy.Server.set_menus(server, self(), [], 25)
  end

  test "concurrent open_window calls for the same id do not start two windows" do
    server = :"guppy_race_server_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Guppy.Server,
       name: server,
       native: Guppy.TimeoutRecordingNative,
       native_server: self(),
       native_request_timeout: 25}
    )

    app_name = :"guppy_race_app_#{System.unique_integer([:positive])}"

    {:ok, _sup} =
      start_supervised(
        {Guppy.StoppingCommandApp, name: app_name, parent: self(), runtime_server: server}
      )

    parent = self()

    first =
      Task.async(fn ->
        Guppy.App.open_window(app_name, "raced",
          module: Guppy.SlowStartWindow,
          arg: %{block_on: parent}
        )
      end)

    assert_receive {:slow_start_begun, window_pid}

    # While the first open is still starting, a second open for the same id
    # must be rejected instead of starting a second untracked window.
    assert {:error, {:duplicate_window_id, "raced"}} =
             Guppy.App.open_window(app_name, "raced",
               module: Guppy.SlowStartWindow,
               arg: %{block_on: parent}
             )

    send(window_pid, :guppy_release_slow_start)
    assert {:ok, ^window_pid} = Task.await(first)
    assert Guppy.App.window_pid(app_name, "raced") == window_pid
    refute_receive {:slow_start_begun, _other}, 100
  end

  test "dispatching an unknown command logs a warning" do
    server = :"guppy_unknown_cmd_server_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Guppy.Server,
       name: server,
       native: Guppy.TimeoutRecordingNative,
       native_server: self(),
       native_request_timeout: 25}
    )

    app_name = :"guppy_unknown_cmd_app_#{System.unique_integer([:positive])}"

    {:ok, _sup} =
      start_supervised(
        {Guppy.StoppingCommandApp, name: app_name, parent: self(), runtime_server: server}
      )

    log =
      ExUnit.CaptureLog.capture_log([level: :warning], fn ->
        assert :ok = Guppy.App.dispatch(app_name, "no_such_command", %{})
        # Synchronous call to make sure the cast above has been processed.
        _ = Guppy.App.commands(app_name)
      end)

    assert log =~ "no_such_command"
    assert log =~ "unknown command"
  end

  test "handle_command can stop the coordinator via {:stop, reason, state}" do
    server = :"guppy_stop_app_server_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Guppy.Server,
       name: server,
       native: Guppy.TimeoutRecordingNative,
       native_server: self(),
       native_request_timeout: 25}
    )

    app_name = :"guppy_stop_app_#{System.unique_integer([:positive])}"

    {:ok, _sup} =
      start_supervised(
        {Guppy.StoppingCommandApp, name: app_name, parent: self(), runtime_server: server}
      )

    coordinator = Process.whereis(app_name)
    assert is_pid(coordinator)

    assert :ok = Guppy.App.dispatch(app_name, "ping", %{n: 1})
    assert_receive {:app_command, "ping", %{n: 1}}

    ref = Process.monitor(coordinator)
    assert :ok = Guppy.App.dispatch(app_name, "stop_me", %{})
    assert_receive {:DOWN, ^ref, :process, ^coordinator, :normal}
  end
end
