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
                 stylesheet: %{classes: %{"card" => %{style: "p-2", hover_style: "bg-blue"}}},
                 package: %{bundle_id: "dev.guppy.test"}
               },
               Guppy.TestApp
             )

    assert config.id == "Guppy.TestApp"
    assert [%{id: "main", start: true}, %{id: "secondary", start: false}] = config.windows
    assert config.exit_on_last_window_closed == false
    assert Map.has_key?(config.commands, "new_file")
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

    assert :ok = Guppy.App.dispatch(app_name, "new_file", %{source: :test})
    assert_receive {:app_command, "new_file", %{source: :test}}

    assert :ok = Guppy.App.dispatch_key(app_name, "cmd-n", %{source: :keymap})
    assert_receive {:app_command, "new_file", %{source: :keymap, key: "cmd-n"}}

    send(app_name, {:guppy_menu_event, %{id: "new_file", callback: "new_file"}})
    assert_receive {:app_command, "new_file", %{id: "new_file", callback: "new_file"}}

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
    assert {:ok, "#ffffff"} = Guppy.theme_color(app_name, :surface)
    assert {:ok, ^panel_style} = Guppy.theme_style(app_name, :panel)

    Guppy.App.put_window_context(app_name, "test")
    assert {:ok, ^panel_style} = Guppy.theme_style(:panel)
    assert "#ffffff" = Guppy.theme_color!(:surface)
    assert {:ok, ^panel_style} = Guppy.Component.theme_style(:panel)
    assert "#ffffff" = Guppy.Component.theme_color!(:surface)

    assert :ok = Guppy.App.set_stylesheet(app_name, %{classes: %{"pill" => "px-2 bg-green"}})
    assert {:style, style} = app_name |> Guppy.App.styles("pill") |> List.keyfind(:style, 0)
    assert {:bg, :green} in style

    palette_ir = Guppy.App.CommandPalette.render(%Guppy.Window{assigns: %{app: app_name}})
    assert :ok = Guppy.IR.validate(palette_ir)
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
      start_supervised({Guppy.TestApp, name: app_name, parent: self(), runtime_server: server})

    assert Guppy.App.theme(app_name).id == "test-dark"
    assert_receive {:guppy_test_native_request, {:set_menus, [_menus]}, _timeout}

    server_pid = Process.whereis(server)
    Process.exit(server_pid, :kill)

    wait_until(fn ->
      restarted = Process.whereis(server)
      is_pid(restarted) and restarted != server_pid
    end)

    assert_receive {:guppy_test_native_request, {:set_menus, [_menus]}, _timeout}, 500
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
end
