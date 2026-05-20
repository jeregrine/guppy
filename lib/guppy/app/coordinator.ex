defmodule Guppy.App.Coordinator do
  @moduledoc false

  use GenServer

  alias Guppy.App.{Command, Config, Stylesheet, Theme, ThemeFamily, WindowSpec}

  defstruct module: nil,
            app_ref: nil,
            app_supervisor: nil,
            config: nil,
            window_supervisor: nil,
            runtime_server: Guppy.Server,
            server_monitor: nil,
            windows: %{}

  @type window_entry :: %{pid: pid(), spec: WindowSpec.t()}
  @type state :: %__MODULE__{
          module: module(),
          app_ref: GenServer.server(),
          app_supervisor: GenServer.server(),
          config: Config.t(),
          window_supervisor: GenServer.server(),
          runtime_server: GenServer.server(),
          server_monitor: reference() | nil,
          windows: %{optional(String.t()) => window_entry()}
        }

  @type callback_result :: {:noreply, state()} | {:stop, term(), state()}

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    module = Keyword.fetch!(opts, :module)
    config_input = Keyword.fetch!(opts, :config)

    with {:ok, config} <- build_config(module, config_input),
         :ok <- claim_native_app_owner(Keyword.get(opts, :runtime_server, Guppy.Server)) do
      state = %__MODULE__{
        module: module,
        app_ref: Keyword.fetch!(opts, :name),
        app_supervisor: Keyword.fetch!(opts, :app_supervisor),
        config: config,
        window_supervisor: Keyword.fetch!(opts, :window_supervisor),
        runtime_server: Keyword.get(opts, :runtime_server, Guppy.Server),
        server_monitor: monitor_server(Keyword.get(opts, :runtime_server, Guppy.Server))
      }

      state = state |> install_menus() |> install_dock_menu() |> install_app_badge()
      {:ok, open_startup_windows(state)}
    else
      {:stop, reason} -> {:stop, reason}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:config, _from, state), do: {:reply, state.config, state}
  def handle_call(:theme, _from, state), do: {:reply, state.config.theme, state}
  def handle_call(:theme_families, _from, state), do: {:reply, state.config.theme_families, state}
  def handle_call(:stylesheet, _from, state), do: {:reply, state.config.stylesheet, state}
  def handle_call(:commands, _from, state), do: {:reply, state.config.commands, state}
  def handle_call(:keymap, _from, state), do: {:reply, state.config.keymap, state}
  def handle_call(:menus, _from, state), do: {:reply, state.config.menus, state}
  def handle_call(:dock_menu, _from, state), do: {:reply, state.config.dock_menu, state}
  def handle_call(:app_badge, _from, state), do: {:reply, state.config.app_badge, state}
  def handle_call(:package, _from, state), do: {:reply, state.config.package, state}

  def handle_call(:windows, _from, state) do
    state = refresh_windows(state)
    {:reply, Map.new(state.windows, fn {id, entry} -> {id, entry.pid} end), state}
  end

  def handle_call({:window_pid, window_id}, _from, state) do
    state = refresh_windows(state)
    pid = state.windows |> Map.get(window_id, %{}) |> Map.get(:pid)
    {:reply, pid, state}
  end

  def handle_call({:open_window, window_id, overrides}, from, state) do
    case prepare_open_window(state, window_id, overrides) do
      {:ok, spec, state} ->
        parent = self()

        spawn(fn ->
          result = start_window_child(state, spec)
          send(parent, {:guppy_app_window_started, from, spec, result})
        end)

        {:noreply, state}

      {:error, reason, state} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:close_window, window_id}, _from, state) do
    state = refresh_windows(state)

    case Map.fetch(state.windows, window_id) do
      {:ok, %{pid: pid}} ->
        reply = DynamicSupervisor.terminate_child(state.window_supervisor, pid)

        next_state =
          state
          |> delete_window(window_id)
          |> close_dependent_windows(window_id)
          |> maybe_stop_app_after_last_window()

        {:reply, reply, next_state}

      :error ->
        {:reply, {:error, :unknown_window_id}, state}
    end
  end

  def handle_call({:focus_window, window_id}, _from, state) do
    state = refresh_windows(state)

    case Map.fetch(state.windows, window_id) do
      {:ok, %{pid: pid}} -> {:reply, Guppy.Window.focus(pid), state}
      :error -> {:reply, {:error, :unknown_window_id}, state}
    end
  end

  def handle_call({:set_theme, theme}, _from, state) do
    case resolve_theme(state, theme) do
      {:ok, theme} -> {:reply, :ok, put_config(state, %{state.config | theme: theme})}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:register_theme_family, family}, _from, state) do
    case ThemeFamily.validate(family) do
      {:ok, family} ->
        config = %{
          state.config
          | theme_families: Map.put(state.config.theme_families, family.id, family)
        }

        {:reply, :ok, put_config(state, config)}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:set_stylesheet, stylesheet}, _from, state) do
    case Stylesheet.validate(stylesheet) do
      {:ok, stylesheet} ->
        {:reply, :ok, put_config(state, %{state.config | stylesheet: stylesheet})}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:set_commands, commands}, _from, state) do
    case Config.validate(%{state.config | commands: commands}) do
      {:ok, config} ->
        {:reply, :ok, state |> put_config(config) |> install_menus() |> install_dock_menu()}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:set_command_enabled, command_id, enabled}, _from, state) do
    cond do
      not is_boolean(enabled) ->
        {:reply, {:error, :invalid_command_enabled}, state}

      not is_binary(command_id) or command_id == "" ->
        {:reply, {:error, {:unknown_command, command_id}}, state}

      true ->
        case Map.fetch(state.config.commands, command_id) do
          {:ok, command} ->
            commands = Map.put(state.config.commands, command_id, %{command | enabled: enabled})

            state =
              state
              |> put_config(%{state.config | commands: commands})
              |> install_menus()
              |> install_dock_menu()

            {:reply, :ok, state}

          :error ->
            {:reply, {:error, {:unknown_command, command_id}}, state}
        end
    end
  end

  def handle_call({:set_keymap, keymap}, _from, state) do
    case Config.validate(%{state.config | keymap: keymap}) do
      {:ok, config} -> {:reply, :ok, put_config(state, config)}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:set_menus, menus}, _from, state) do
    case Config.validate(%{state.config | menus: menus}) do
      {:ok, config} ->
        state = put_config(state, config)

        case set_native_menus(state) do
          :ok -> {:reply, :ok, state}
          error -> {:reply, error, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:set_dock_menu, items}, _from, state) do
    case Config.validate(%{state.config | dock_menu: items}) do
      {:ok, config} ->
        state = put_config(state, config)

        case set_native_dock_menu(state) do
          :ok -> {:reply, :ok, state}
          error -> {:reply, error, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:set_app_badge, label}, _from, state) do
    case Config.validate(%{state.config | app_badge: label}) do
      {:ok, config} ->
        state = put_config(state, config)

        case set_native_app_badge(state) do
          :ok -> {:reply, :ok, state}
          error -> {:reply, error, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_cast({:dispatch_command, command_id, payload}, state) do
    {:noreply, dispatch_command(state, command_id, payload)}
  end

  def handle_cast({:dispatch_key, key, payload}, state) do
    command_id = first_enabled_key_command(state, key)

    if is_binary(command_id) do
      {:noreply, dispatch_command(state, command_id, Map.put(payload, :key, key))}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:guppy_menu_event, %{callback: command_id} = payload}, state)
      when is_binary(command_id) do
    {:noreply, dispatch_command(state, command_id, payload)}
  end

  def handle_info({:guppy_app_event, %{type: type} = payload}, state) when is_atom(type) do
    apply_callback(
      state,
      invoke_callback(state.module, :handle_event, [
        Atom.to_string(type),
        event_data(payload),
        state
      ])
    )
  end

  def handle_info(
        {:DOWN, monitor_ref, :process, _pid, _reason},
        %{server_monitor: monitor_ref} = state
      ) do
    Process.send_after(self(), :guppy_reinstall_native_resources, 50)
    {:noreply, %{state | server_monitor: nil}}
  end

  def handle_info({:guppy_app_window_started, from, spec, result}, state) do
    case result do
      {:ok, pid} ->
        GenServer.reply(from, {:ok, pid})
        {:noreply, put_window(state, spec, pid)}

      {:error, reason} ->
        GenServer.reply(from, {:error, reason})
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    case window_id_for_monitor(state, monitor_ref) do
      nil ->
        {:noreply, state}

      window_id ->
        next_state =
          state
          |> delete_window(window_id)
          |> close_dependent_windows(window_id)
          |> maybe_stop_app_after_last_window()

        {:noreply, next_state}
    end
  end

  def handle_info(:guppy_reinstall_native_resources, state) do
    case claim_native_app_owner(state.runtime_server) do
      :ok ->
        state = state |> install_menus() |> install_dock_menu() |> install_app_badge()
        {:noreply, %{state | server_monitor: monitor_server(state.runtime_server)}}

      {:error, _reason} ->
        Process.send_after(self(), :guppy_reinstall_native_resources, 50)
        {:noreply, state}
    end
  end

  def handle_info(message, state) do
    apply_callback(state, invoke_callback(state.module, :handle_info, [message, state]))
  end

  defp build_config(module, config_input) do
    config_input = Keyword.drop(config_input, [:name, :runtime_server])

    config_result =
      if function_exported?(module, :init, 1) do
        module.init(config_input)
      else
        config_input
      end

    case config_result do
      {:ok, config} -> Config.validate(config, module)
      {:stop, reason} -> {:stop, reason}
      config -> Config.validate(config, module)
    end
  end

  defp claim_native_app_owner(runtime_server) do
    Guppy.Server.claim_app_owner(runtime_server, self())
  catch
    :exit, _reason -> {:error, :server_unavailable}
  end

  defp monitor_server(runtime_server) do
    case Process.whereis(runtime_server) do
      pid when is_pid(pid) -> Process.monitor(pid)
      nil -> nil
    end
  end

  defp install_menus(%{config: %{menus: []}} = state), do: state

  defp install_menus(state) do
    _ = set_native_menus(state)
    state
  end

  defp set_native_menus(state) do
    Guppy.Server.set_menus(state.runtime_server, self(), effective_menus(state.config))
  end

  defp install_dock_menu(%{config: %{dock_menu: []}} = state), do: state

  defp install_dock_menu(state) do
    _ = set_native_dock_menu(state)
    state
  end

  defp set_native_dock_menu(state) do
    Guppy.Server.set_dock_menu(state.runtime_server, self(), effective_dock_menu(state.config))
  end

  defp install_app_badge(%{config: %{app_badge: nil}} = state), do: state

  defp install_app_badge(state) do
    _ = set_native_app_badge(state)
    state
  end

  defp set_native_app_badge(state) do
    Guppy.Server.set_app_badge(state.runtime_server, self(), state.config.app_badge)
  end

  defp effective_menus(%Config{menus: menus, commands: commands}) do
    Enum.map(menus, &effective_menu(&1, commands))
  end

  defp effective_dock_menu(%Config{dock_menu: dock_menu, commands: commands}) do
    Enum.map(dock_menu, &effective_menu_item(&1, commands))
  end

  defp effective_menu(%{items: items} = menu, commands) when is_list(items) do
    %{menu | items: Enum.map(items, &effective_menu_item(&1, commands))}
  end

  defp effective_menu(menu, _commands), do: menu

  defp effective_menu_item(%{items: items} = item, commands) when is_list(items) do
    %{item | items: Enum.map(items, &effective_menu_item(&1, commands))}
  end

  defp effective_menu_item(%{callback: command_id} = item, commands) when is_binary(command_id) do
    case Map.fetch(commands, command_id) do
      {:ok, %Command{enabled: false}} -> Map.put(item, :enabled, false)
      {:ok, %Command{enabled: true}} -> item
      :error -> item
    end
  end

  defp effective_menu_item(item, _commands), do: item

  defp open_startup_windows(state) do
    Enum.reduce(state.config.windows, state, fn
      %WindowSpec{start: true} = spec, acc ->
        case do_start_window(acc, spec) do
          {:ok, _pid, acc} -> acc
          {:error, _reason, acc} -> acc
        end

      _spec, acc ->
        acc
    end)
  end

  defp prepare_open_window(state, window_id, overrides) do
    state = refresh_windows(state)

    if Map.has_key?(state.windows, window_id) do
      {:error, {:duplicate_window_id, window_id}, state}
    else
      case find_or_build_spec(state.config, window_id, overrides) do
        {:ok, spec} -> {:ok, spec, state}
        {:error, reason} -> {:error, reason, state}
      end
    end
  end

  defp find_or_build_spec(config, window_id, overrides) do
    configured = Enum.find(config.windows, &(&1.id == window_id))

    spec_map =
      configured
      |> case do
        nil -> %{id: window_id}
        spec -> Map.from_struct(spec)
      end
      |> Map.merge(Map.new(overrides))
      |> Map.put(:id, window_id)

    WindowSpec.validate(spec_map, false)
  end

  defp do_start_window(state, %WindowSpec{} = spec) do
    case start_window_child(state, spec) do
      {:ok, pid} -> {:ok, pid, put_window(state, spec, pid)}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp start_window_child(state, %WindowSpec{} = spec) do
    child_spec = %{
      id: {:guppy_app_window, spec.id},
      start:
        {spec.module, :start_link,
         [{:guppy_app_window, state.app_ref, spec.id, spec.arg}, spec.opts]},
      restart: spec.restart,
      shutdown: 5_000,
      type: :worker
    }

    case DynamicSupervisor.start_child(state.window_supervisor, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:ok, pid, _info} -> {:ok, pid}
      :ignore -> {:error, :window_ignored}
      {:error, reason} -> {:error, reason}
    end
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp put_window(state, spec, pid) do
    monitor_ref = Process.monitor(pid)

    %{
      state
      | windows: Map.put(state.windows, spec.id, %{pid: pid, spec: spec, monitor: monitor_ref})
    }
  end

  defp delete_window(state, window_id) do
    case Map.pop(state.windows, window_id) do
      {nil, _windows} ->
        state

      {%{monitor: monitor_ref}, windows} when is_reference(monitor_ref) ->
        Process.demonitor(monitor_ref, [:flush])
        %{state | windows: windows}

      {_entry, windows} ->
        %{state | windows: windows}
    end
  end

  defp window_id_for_monitor(state, monitor_ref) do
    Enum.find_value(state.windows, fn
      {window_id, %{monitor: ^monitor_ref}} -> window_id
      _entry -> nil
    end)
  end

  defp close_dependent_windows(state, parent_window_id) do
    state.windows
    |> Enum.filter(fn {window_id, entry} ->
      window_id != parent_window_id and close_with_parent?(entry.spec, parent_window_id)
    end)
    |> Enum.map(fn {window_id, _entry} -> window_id end)
    |> Enum.reduce(state, fn window_id, acc -> close_tracked_window(acc, window_id) end)
  end

  defp close_transient_windows(state) do
    state.windows
    |> Enum.filter(fn {_window_id, entry} -> transient_window?(entry.spec) end)
    |> Enum.map(fn {window_id, _entry} -> window_id end)
    |> Enum.reduce(state, fn window_id, acc -> close_tracked_window(acc, window_id) end)
  end

  defp close_tracked_window(state, window_id) do
    case Map.fetch(state.windows, window_id) do
      {:ok, %{pid: pid}} ->
        _ = DynamicSupervisor.terminate_child(state.window_supervisor, pid)

        state
        |> delete_window(window_id)
        |> close_dependent_windows(window_id)

      :error ->
        state
    end
  end

  defp close_with_parent?(%WindowSpec{metadata: metadata}, parent_window_id) do
    Map.get(metadata, :close_with_parent) == true and
      Map.get(metadata, :parent_window_id) == parent_window_id
  end

  defp transient_window?(%WindowSpec{metadata: metadata}),
    do: Map.get(metadata, :transient) == true

  defp maybe_stop_app_after_last_window(%{config: %{exit_on_last_window_closed: true}} = state) do
    if root_window_count(state.windows) == 0 do
      state = close_transient_windows(state)
      app_supervisor = state.app_supervisor
      Task.start(fn -> Supervisor.stop(app_supervisor, :normal) end)
      state
    else
      state
    end
  end

  defp maybe_stop_app_after_last_window(state), do: state

  defp root_window_count(windows) do
    Enum.count(windows, fn {_window_id, entry} -> not transient_window?(entry.spec) end)
  end

  defp refresh_windows(state) do
    supervised = supervised_window_pids(state.window_supervisor)

    live =
      Map.new(state.windows, fn {id, entry} ->
        pid = Map.get(supervised, id, entry.pid)
        {id, refresh_window_entry_monitor(entry, pid)}
      end)
      |> Enum.filter(fn {_id, %{pid: pid}} -> is_pid(pid) and Process.alive?(pid) end)
      |> Map.new()

    %{state | windows: live}
  end

  defp refresh_window_entry_monitor(%{pid: pid} = entry, pid), do: entry

  defp refresh_window_entry_monitor(entry, pid) do
    if is_reference(Map.get(entry, :monitor)) do
      Process.demonitor(entry.monitor, [:flush])
    end

    %{entry | pid: pid, monitor: Process.monitor(pid)}
  end

  defp supervised_window_pids(window_supervisor) do
    window_supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.reduce(%{}, fn
      {{:guppy_app_window, id}, pid, _type, _modules}, acc when is_binary(id) and is_pid(pid) ->
        Map.put(acc, id, pid)

      _child, acc ->
        acc
    end)
  catch
    :exit, _reason -> %{}
  end

  defp first_enabled_key_command(state, key) do
    Enum.find_value(state.config.keymap, fn
      %{key: ^key, command: command_id} ->
        case Map.fetch(state.config.commands, command_id) do
          {:ok, %Command{enabled: true}} -> command_id
          _missing_or_disabled -> nil
        end

      _entry ->
        nil
    end)
  end

  defp dispatch_command(state, command_id, payload) do
    case Map.fetch(state.config.commands, command_id) do
      {:ok, %Command{enabled: true}} ->
        apply_callback(
          state,
          invoke_callback(state.module, :handle_command, [command_id, payload, state])
        )
        |> elem(1)

      {:ok, %Command{enabled: false}} ->
        state

      :error ->
        state
    end
  end

  defp event_data(event), do: Map.drop(event, [:type])

  defp put_config(state, config), do: %{state | config: config}

  defp resolve_theme(state, theme_id) when is_binary(theme_id) or is_atom(theme_id) do
    theme_id = if is_atom(theme_id), do: Atom.to_string(theme_id), else: theme_id

    Enum.find_value(state.config.theme_families, {:error, {:unknown_theme, theme_id}}, fn {_id,
                                                                                           family} ->
      case ThemeFamily.get(family, theme_id) do
        {:ok, theme} -> {:ok, theme}
        {:error, _reason} -> false
      end
    end)
  end

  defp resolve_theme(_state, theme), do: Theme.validate(theme)

  defp invoke_callback(module, function, args) do
    apply(module, function, args)
  rescue
    error in FunctionClauseError ->
      if callback_error?(error, module, function, args) do
        {:noreply, List.last(args)}
      else
        reraise error, __STACKTRACE__
      end

    error in UndefinedFunctionError ->
      if callback_error?(error, module, function, args) do
        {:noreply, List.last(args)}
      else
        reraise error, __STACKTRACE__
      end
  end

  defp callback_error?(error, module, function, args) do
    error.module == module and error.function == function and error.arity == length(args)
  end

  defp apply_callback(_state, {:noreply, %__MODULE__{} = state}), do: {:noreply, state}
  defp apply_callback(_state, {:stop, reason, %__MODULE__{} = state}), do: {:stop, reason, state}
end
