defmodule Guppy.Server do
  @moduledoc """
  Central Guppy runtime server.

  Owns view ids, window ownership, native request dispatch, event routing, menu
  ownership, and cleanup when owners or the native event target exit.
  """

  use GenServer

  defstruct native: nil,
            native_server: nil,
            native_request_timeout: 5_000,
            next_view_id: 1,
            views: %{},
            owners: %{},
            monitors: %{},
            menu_owner: nil,
            menu_monitor: nil,
            dock_menu_owner: nil,
            dock_menu_monitor: nil,
            app_badge_owner: nil,
            app_badge_monitor: nil,
            app_owner: nil,
            app_owner_monitor: nil

  @type view_id :: pos_integer()

  @type owner_entry :: %{
          monitor: reference(),
          views: MapSet.t(view_id())
        }

  @type state :: %__MODULE__{
          native: module(),
          native_server: GenServer.server(),
          native_request_timeout: timeout(),
          next_view_id: pos_integer(),
          views: %{optional(view_id()) => pid()},
          owners: %{optional(pid()) => owner_entry()},
          monitors: %{optional(reference()) => pid()},
          menu_owner: pid() | nil,
          menu_monitor: reference() | nil,
          dock_menu_owner: pid() | nil,
          dock_menu_monitor: reference() | nil,
          app_badge_owner: pid() | nil,
          app_badge_monitor: reference() | nil,
          app_owner: pid() | nil,
          app_owner_monitor: reference() | nil
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def info(server \\ __MODULE__) do
    GenServer.call(server, :info)
  end

  def ping(server \\ __MODULE__, timeout \\ 5_000) do
    GenServer.call(server, {:ping, timeout}, gen_call_timeout(timeout))
  end

  def open_window(server \\ __MODULE__, owner, ir, opts \\ [], timeout \\ 5_000) do
    GenServer.call(server, {:open_window, owner, ir, opts, timeout}, gen_call_timeout(timeout))
  end

  def render(server \\ __MODULE__, view_id, ir, timeout \\ 5_000) do
    GenServer.call(server, {:render, view_id, ir, timeout}, gen_call_timeout(timeout))
  end

  def close_window(server \\ __MODULE__, view_id, timeout \\ 5_000) do
    GenServer.call(server, {:close_window, view_id, timeout}, gen_call_timeout(timeout))
  end

  def focus_window(server \\ __MODULE__, view_id, timeout \\ 5_000) do
    GenServer.call(server, {:focus_window, view_id, timeout}, gen_call_timeout(timeout))
  end

  def set_menus(server \\ __MODULE__, owner, menus, timeout \\ 5_000) do
    GenServer.call(server, {:set_menus, owner, menus, timeout}, gen_call_timeout(timeout))
  end

  def set_dock_menu(server \\ __MODULE__, owner, items, timeout \\ 5_000) do
    GenServer.call(server, {:set_dock_menu, owner, items, timeout}, gen_call_timeout(timeout))
  end

  def set_app_badge(server \\ __MODULE__, owner, label, timeout \\ 5_000) do
    GenServer.call(server, {:set_app_badge, owner, label, timeout}, gen_call_timeout(timeout))
  end

  def open_file_dialog(server \\ __MODULE__, opts \\ [], timeout \\ 30_000) do
    GenServer.call(server, {:open_file_dialog, opts, timeout}, gen_call_timeout(timeout))
  end

  def choose_directory_dialog(server \\ __MODULE__, opts \\ [], timeout \\ 30_000) do
    GenServer.call(server, {:choose_directory_dialog, opts, timeout}, gen_call_timeout(timeout))
  end

  def save_file_dialog(server \\ __MODULE__, opts \\ [], timeout \\ 30_000) do
    GenServer.call(server, {:save_file_dialog, opts, timeout}, gen_call_timeout(timeout))
  end

  def read_clipboard_text(server \\ __MODULE__, timeout \\ 5_000) do
    GenServer.call(server, {:read_clipboard_text, timeout}, gen_call_timeout(timeout))
  end

  def write_clipboard_text(server \\ __MODULE__, text, timeout \\ 5_000) do
    GenServer.call(server, {:write_clipboard_text, text, timeout}, gen_call_timeout(timeout))
  end

  def claim_app_owner(server \\ __MODULE__, owner) when is_pid(owner) do
    GenServer.call(server, {:claim_app_owner, owner})
  end

  def release_app_owner(server \\ __MODULE__, owner) when is_pid(owner) do
    GenServer.call(server, {:release_app_owner, owner})
  end

  def view_count(server \\ __MODULE__, timeout \\ 5_000) do
    GenServer.call(server, {:view_count, timeout}, gen_call_timeout(timeout))
  end

  def validate_window_options_for_test(opts), do: validate_window_options(opts)

  @impl true
  def init(opts) do
    native = Keyword.get(opts, :native, Application.get_env(:guppy, :native))

    state = %__MODULE__{
      native: native,
      native_server: Keyword.get(opts, :native_server, native),
      native_request_timeout: Keyword.get(opts, :native_request_timeout, 5_000)
    }

    {:ok, state |> maybe_register_event_target() |> maybe_reset_native_views()}
  end

  @impl true
  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:ping, timeout}, _from, state) do
    reply = native_request(state, :ping, {:ping, []}, timeout)
    {:reply, reply, state}
  end

  def handle_call({:view_count, timeout}, _from, state) do
    reply = native_request(state, :view_count, {:view_count, []}, timeout)
    {:reply, reply, state}
  end

  def handle_call({:open_window, owner, ir, opts, timeout}, {caller, _tag}, state)
      when is_pid(owner) do
    {reply, state} = open_window_for_owner(state, owner, caller, ir, opts, timeout)
    {:reply, reply, state}
  end

  def handle_call({:render, view_id, ir, timeout}, {caller, _tag}, state) do
    case validate_owned_view_ir(state, caller, view_id, ir) do
      :ok ->
        reply = native_request(state, :render, {:render, [view_id, Guppy.IR.unwrap(ir)]}, timeout)
        {:reply, normalize_native_reply(reply), state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:close_window, view_id, timeout}, {caller, _tag}, state) do
    case validate_owned_view(state, caller, view_id) do
      :ok ->
        case native_request(state, :close_window, {:close_window, [view_id]}, timeout) do
          :ok -> {:reply, :ok, delete_view(state, view_id)}
          {:ok, _payload} -> {:reply, :ok, delete_view(state, view_id)}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:focus_window, view_id, timeout}, {caller, _tag}, state) do
    case validate_owned_view(state, caller, view_id) do
      :ok ->
        reply = native_request(state, :focus_window, {:focus_window, [view_id]}, timeout)
        {:reply, normalize_native_reply(reply), state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:open_file_dialog, opts, timeout}, {caller, _tag}, state) do
    case validate_open_file_dialog_options(state, caller, opts, files: true, directories: false) do
      {:ok, opts} ->
        reply = native_request(state, :open_file_dialog, {:open_file_dialog, [opts]}, timeout)
        {:reply, reply, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:choose_directory_dialog, opts, timeout}, {caller, _tag}, state) do
    case validate_open_file_dialog_options(state, caller, opts, files: false, directories: true) do
      {:ok, opts} ->
        reply = native_request(state, :open_file_dialog, {:open_file_dialog, [opts]}, timeout)
        {:reply, reply, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:save_file_dialog, opts, timeout}, {caller, _tag}, state) do
    case validate_save_file_dialog_options(state, caller, opts) do
      {:ok, opts} ->
        reply = native_request(state, :save_file_dialog, {:save_file_dialog, [opts]}, timeout)
        {:reply, reply, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:read_clipboard_text, timeout}, _from, state) do
    reply = native_request(state, :read_clipboard_text, {:read_clipboard_text, []}, timeout)
    {:reply, reply, state}
  end

  def handle_call({:write_clipboard_text, text, timeout}, _from, state) do
    if is_binary(text) do
      reply =
        native_request(state, :write_clipboard_text, {:write_clipboard_text, [text]}, timeout)

      {:reply, normalize_native_reply(reply), state}
    else
      {:reply, {:error, :invalid_clipboard_text}, state}
    end
  end

  def handle_call({:set_menus, owner, menus, timeout}, {caller, _tag}, state)
      when is_pid(owner) do
    {reply, state} = set_menus_for_owner(state, owner, caller, menus, timeout)
    {:reply, reply, state}
  end

  def handle_call({:set_dock_menu, owner, items, timeout}, {caller, _tag}, state)
      when is_pid(owner) do
    {reply, state} = set_dock_menu_for_owner(state, owner, caller, items, timeout)
    {:reply, reply, state}
  end

  def handle_call({:set_app_badge, owner, label, timeout}, {caller, _tag}, state)
      when is_pid(owner) do
    {reply, state} = set_app_badge_for_owner(state, owner, caller, label, timeout)
    {:reply, reply, state}
  end

  def handle_call({:claim_app_owner, owner}, {caller, _tag}, state) when is_pid(owner) do
    cond do
      owner != caller ->
        {:reply, {:error, :owner_mismatch}, state}

      state.app_owner == owner ->
        {:reply, :ok, state}

      is_pid(state.app_owner) ->
        {:reply, {:error, :native_app_owner_already_claimed}, state}

      true ->
        {:reply, :ok, put_app_owner(state, owner)}
    end
  end

  def handle_call({:release_app_owner, owner}, {caller, _tag}, state) when is_pid(owner) do
    cond do
      owner != caller -> {:reply, {:error, :owner_mismatch}, state}
      state.app_owner == owner -> {:reply, :ok, clear_app_owner(state)}
      true -> {:reply, :ok, state}
    end
  end

  defp open_window_for_owner(state, owner, caller, ir, opts, timeout) do
    with :ok <- validate_owner(owner, caller),
         :ok <- Guppy.IR.validate(ir),
         {:ok, opts} <- validate_window_options(opts) do
      view_id = state.next_view_id
      ir = Guppy.IR.unwrap(ir)

      case native_request(state, :open_window, {:open_window, [view_id, ir, opts]}, timeout) do
        :ok -> {{:ok, view_id}, put_open_view(state, view_id, owner)}
        {:ok, _payload} -> {{:ok, view_id}, put_open_view(state, view_id, owner)}
        {:error, reason} -> {{:error, reason}, state}
      end
    else
      error -> {error, state}
    end
  end

  defp set_menus_for_owner(state, owner, caller, menus, timeout) do
    with :ok <- validate_owner(owner, caller),
         :ok <- validate_no_app_owner_conflict(state, owner),
         {:ok, menus} <- validate_menus(menus) do
      case native_request(state, :set_menus, {:set_menus, [menus]}, timeout) do
        :ok -> {:ok, put_menu_owner(state, owner, menus)}
        {:ok, _payload} -> {:ok, put_menu_owner(state, owner, menus)}
        {:error, reason} -> {{:error, reason}, state}
      end
    else
      error -> {error, state}
    end
  end

  defp set_dock_menu_for_owner(state, owner, caller, items, timeout) do
    with :ok <- validate_owner(owner, caller),
         :ok <- validate_no_app_owner_conflict(state, owner),
         {:ok, items} <- validate_dock_menu(items) do
      case native_request(state, :set_dock_menu, {:set_dock_menu, [items]}, timeout) do
        :ok -> {:ok, put_dock_menu_owner(state, owner, items)}
        {:ok, _payload} -> {:ok, put_dock_menu_owner(state, owner, items)}
        {:error, reason} -> {{:error, reason}, state}
      end
    else
      error -> {error, state}
    end
  end

  defp set_app_badge_for_owner(state, owner, caller, label, timeout) do
    with :ok <- validate_owner(owner, caller),
         :ok <- validate_no_app_owner_conflict(state, owner),
         {:ok, label} <- validate_app_badge(label) do
      case native_request(state, :set_app_badge, {:set_app_badge, [label]}, timeout) do
        :ok -> {:ok, put_app_badge_owner(state, owner, label)}
        {:ok, _payload} -> {:ok, put_app_badge_owner(state, owner, label)}
        {:error, reason} -> {{:error, reason}, state}
      end
    else
      error -> {error, state}
    end
  end

  defp put_open_view(state, view_id, owner) do
    state
    |> put_view(view_id, owner)
    |> increment_view_id()
  end

  defp validate_owner(owner, owner), do: :ok
  defp validate_owner(_owner, _caller), do: {:error, :owner_mismatch}

  defp validate_no_app_owner_conflict(state, owner) do
    if app_owner_conflict?(state, owner) do
      {:error, :native_app_owner_already_claimed}
    else
      :ok
    end
  end

  @impl true
  def handle_info({:guppy_native_event, 0, type, payload}, state)
      when type in [:app_activated, :app_deactivated] do
    case state.app_owner do
      owner when is_pid(owner) ->
        send(owner, {:guppy_app_event, Map.put(window_lifecycle_payload(payload), :type, type)})
        emit_event_route_telemetry(0, type, :ok)
        {:noreply, state}

      nil ->
        emit_event_route_telemetry(0, type, :unknown_app_owner)
        {:noreply, state}
    end
  end

  def handle_info(
        {:guppy_native_event, 0, :menu_action, %{id: id, callback: callback_id} = payload},
        state
      )
      when is_binary(id) and is_binary(callback_id) do
    case state.menu_owner do
      owner when is_pid(owner) ->
        send(owner, {:guppy_menu_event, Map.put(payload, :type, :menu_action)})
        emit_event_route_telemetry(0, :menu_action, :ok)
        {:noreply, state}

      nil ->
        emit_event_route_telemetry(0, :menu_action, :unknown_menu_owner)
        {:noreply, state}
    end
  end

  def handle_info(
        {:guppy_native_event, 0, :dock_menu_action, %{id: id, callback: callback_id} = payload},
        state
      )
      when is_binary(id) and is_binary(callback_id) do
    case state.dock_menu_owner do
      owner when is_pid(owner) ->
        send(owner, {:guppy_menu_event, Map.put(payload, :type, :dock_menu_action)})
        emit_event_route_telemetry(0, :dock_menu_action, :ok)
        {:noreply, state}

      nil ->
        emit_event_route_telemetry(0, :dock_menu_action, :unknown_dock_menu_owner)
        {:noreply, state}
    end
  end

  def handle_info(
        {:guppy_native_event, view_id, type, %{id: node_id, callback: callback_id} = payload},
        state
      )
      when is_integer(view_id) and is_atom(type) and
             type in [
               :click,
               :close,
               :hover,
               :focus,
               :blur,
               :change,
               :key_down,
               :key_up,
               :action,
               :context_menu,
               :drag_start,
               :drag_move,
               :drop,
               :mouse_down,
               :mouse_up,
               :mouse_move,
               :scroll_wheel,
               :data_table_row_click,
               :data_table_cell_click,
               :data_table_sort,
               :data_table_column_reorder,
               :data_table_column_resize,
               :tree_select,
               :tree_toggle
             ] and
             is_binary(node_id) and is_binary(callback_id) do
    case Map.fetch(state.views, view_id) do
      {:ok, owner} ->
        send(owner, {:guppy_event, view_id, Map.put(payload, :type, type)})
        emit_event_route_telemetry(view_id, type, :ok)
        {:noreply, state}

      :error ->
        emit_event_route_telemetry(view_id, type, :unknown_view_id)
        {:noreply, state}
    end
  end

  def handle_info({:guppy_native_event, view_id, type, payload}, state)
      when is_integer(view_id) and
             type in [:window_focused, :window_blurred, :window_moved, :window_resized] do
    route_window_lifecycle_event(state, view_id, type, payload)
  end

  def handle_info({:guppy_native_event, view_id, :window_close_requested, _payload}, state)
      when is_integer(view_id) do
    case Map.fetch(state.views, view_id) do
      {:ok, owner} ->
        send(owner, {:guppy_event, view_id, %{type: :window_close_requested}})
        emit_event_route_telemetry(view_id, :window_close_requested, :ok)
        {:noreply, state}

      :error ->
        emit_event_route_telemetry(view_id, :window_close_requested, :unknown_view_id)
        {:noreply, state}
    end
  end

  def handle_info({:guppy_native_event, view_id, :window_closed, _payload}, state)
      when is_integer(view_id) do
    case Map.fetch(state.views, view_id) do
      {:ok, owner} ->
        send(owner, {:guppy_event, view_id, %{type: :window_closed}})
        emit_event_route_telemetry(view_id, :window_closed, :ok)
        {:noreply, delete_view(state, view_id)}

      :error ->
        emit_event_route_telemetry(view_id, :window_closed, :unknown_view_id)
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, monitor_ref, :process, owner, _reason}, state) do
    state = maybe_clear_dead_menu_owner(state, owner, monitor_ref)
    state = maybe_clear_dead_dock_menu_owner(state, owner, monitor_ref)
    state = maybe_clear_dead_app_badge_owner(state, owner, monitor_ref)
    state = maybe_clear_dead_app_owner(state, owner, monitor_ref)

    case Map.fetch(state.monitors, monitor_ref) do
      {:ok, ^owner} ->
        state = close_owned_views(state, owner)
        {:noreply, drop_owner(state, owner, monitor_ref)}

      _ ->
        {:noreply, state}
    end
  end

  defp gen_call_timeout(:infinity), do: :infinity
  defp gen_call_timeout(timeout) when is_integer(timeout) and timeout >= 0, do: timeout + 1_000

  defp validate_owned_view_ir(state, caller, view_id, ir) do
    with :ok <- validate_owned_view(state, caller, view_id) do
      Guppy.IR.validate(ir)
    end
  end

  defp validate_owned_view(state, caller, view_id) do
    case Map.fetch(state.views, view_id) do
      :error -> {:error, :unknown_view_id}
      {:ok, ^caller} -> :ok
      {:ok, _owner} -> {:error, :not_view_owner}
    end
  end

  defp maybe_register_event_target(state) do
    case native_request(
           state,
           :set_event_target,
           {:set_event_target, [self()]},
           state.native_request_timeout
         ) do
      :ok -> state
      {:ok, _payload} -> state
      {:error, _reason} -> state
    end
  end

  defp maybe_reset_native_views(state) do
    case native_request(state, :close_all, {:close_all, []}, state.native_request_timeout) do
      :ok -> state
      {:ok, _payload} -> state
      {:error, _reason} -> state
    end
  end

  defp native_request(state, command, request, timeout) do
    start_time = System.monotonic_time()

    task =
      Task.async(fn ->
        try do
          state.native.request(state.native_server, request, timeout)
        rescue
          _error in [ArgumentError, ErlangError, RuntimeError] -> {:error, :runtime_unavailable}
        catch
          _kind, _reason -> {:error, :runtime_unavailable}
        end
      end)

    reply =
      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, reply} -> reply
        nil -> {:error, :native_timeout}
      end

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:guppy, :native, :request],
      %{duration: duration},
      %{command: command, status: Guppy.Native.telemetry_status(reply)}
    )

    reply
  end

  defp route_window_lifecycle_event(state, view_id, type, payload) do
    case Map.fetch(state.views, view_id) do
      {:ok, owner} ->
        send(
          owner,
          {:guppy_event, view_id, Map.put(window_lifecycle_payload(payload), :type, type)}
        )

        emit_event_route_telemetry(view_id, type, :ok)
        {:noreply, state}

      :error ->
        emit_event_route_telemetry(view_id, type, :unknown_view_id)
        {:noreply, state}
    end
  end

  defp window_lifecycle_payload(payload) when is_map(payload), do: payload
  defp window_lifecycle_payload(_payload), do: %{}

  defp emit_event_route_telemetry(view_id, type, status) do
    :telemetry.execute(
      [:guppy, :event, :route],
      %{count: 1},
      %{view_id: view_id, type: type, status: status}
    )
  end

  defp normalize_native_reply(:ok), do: :ok
  defp normalize_native_reply({:ok, _payload}), do: :ok
  defp normalize_native_reply({:error, reason}), do: {:error, reason}

  defp increment_view_id(state) do
    %{state | next_view_id: state.next_view_id + 1}
  end

  defp put_view(state, view_id, owner) do
    {monitor_ref, owner_entry, owners, monitors} = ensure_owner(state, owner)

    updated_entry = %{owner_entry | views: MapSet.put(owner_entry.views, view_id)}

    %{
      state
      | views: Map.put(state.views, view_id, owner),
        owners: Map.put(owners, owner, updated_entry),
        monitors: Map.put(monitors, monitor_ref, owner)
    }
  end

  defp ensure_owner(state, owner) do
    case Map.fetch(state.owners, owner) do
      {:ok, owner_entry} ->
        {owner_entry.monitor, owner_entry, state.owners, state.monitors}

      :error ->
        monitor_ref = Process.monitor(owner)
        owner_entry = %{monitor: monitor_ref, views: MapSet.new()}
        {monitor_ref, owner_entry, state.owners, state.monitors}
    end
  end

  defp put_menu_owner(state, _owner, []) do
    clear_menu_owner_monitor(state)
  end

  defp put_menu_owner(%{menu_owner: owner} = state, owner, _menus)
       when is_pid(owner) do
    state
  end

  defp put_menu_owner(state, owner, _menus) do
    state = clear_menu_owner_monitor(state)
    %{state | menu_owner: owner, menu_monitor: Process.monitor(owner)}
  end

  defp put_dock_menu_owner(state, _owner, []) do
    clear_dock_menu_owner_monitor(state)
  end

  defp put_dock_menu_owner(%{dock_menu_owner: owner} = state, owner, _items)
       when is_pid(owner) do
    state
  end

  defp put_dock_menu_owner(state, owner, _items) do
    state = clear_dock_menu_owner_monitor(state)
    %{state | dock_menu_owner: owner, dock_menu_monitor: Process.monitor(owner)}
  end

  defp put_app_badge_owner(state, _owner, nil) do
    clear_app_badge_owner_monitor(state)
  end

  defp put_app_badge_owner(%{app_badge_owner: owner} = state, owner, _label)
       when is_pid(owner) do
    state
  end

  defp put_app_badge_owner(state, owner, _label) do
    state = clear_app_badge_owner_monitor(state)
    %{state | app_badge_owner: owner, app_badge_monitor: Process.monitor(owner)}
  end

  defp app_owner_conflict?(%{app_owner: nil}, _owner), do: false
  defp app_owner_conflict?(%{app_owner: owner}, owner), do: false
  defp app_owner_conflict?(%{app_owner: app_owner}, _owner) when is_pid(app_owner), do: true

  defp put_app_owner(state, owner) do
    state = clear_app_owner(state)
    %{state | app_owner: owner, app_owner_monitor: Process.monitor(owner)}
  end

  defp maybe_clear_dead_app_owner(
         %{app_owner: owner, app_owner_monitor: monitor_ref} = state,
         owner,
         monitor_ref
       )
       when is_pid(owner) do
    clear_app_owner(state)
  end

  defp maybe_clear_dead_app_owner(state, _owner, _monitor_ref), do: state

  defp clear_app_owner(%{app_owner_monitor: monitor_ref} = state)
       when is_reference(monitor_ref) do
    Process.demonitor(monitor_ref, [:flush])
    %{state | app_owner: nil, app_owner_monitor: nil}
  end

  defp clear_app_owner(state), do: %{state | app_owner: nil, app_owner_monitor: nil}

  defp maybe_clear_dead_menu_owner(
         %{menu_owner: owner, menu_monitor: monitor_ref} = state,
         owner,
         monitor_ref
       )
       when is_pid(owner) do
    _ = native_request(state, :set_menus, {:set_menus, [[]]}, state.native_request_timeout)
    %{state | menu_owner: nil, menu_monitor: nil}
  end

  defp maybe_clear_dead_menu_owner(state, _owner, _monitor_ref), do: state

  defp maybe_clear_dead_dock_menu_owner(
         %{dock_menu_owner: owner, dock_menu_monitor: monitor_ref} = state,
         owner,
         monitor_ref
       )
       when is_pid(owner) do
    _ =
      native_request(state, :set_dock_menu, {:set_dock_menu, [[]]}, state.native_request_timeout)

    %{state | dock_menu_owner: nil, dock_menu_monitor: nil}
  end

  defp maybe_clear_dead_dock_menu_owner(state, _owner, _monitor_ref), do: state

  defp maybe_clear_dead_app_badge_owner(
         %{app_badge_owner: owner, app_badge_monitor: monitor_ref} = state,
         owner,
         monitor_ref
       )
       when is_pid(owner) do
    _ =
      native_request(
        state,
        :set_app_badge,
        {:set_app_badge, [nil]},
        state.native_request_timeout
      )

    %{state | app_badge_owner: nil, app_badge_monitor: nil}
  end

  defp maybe_clear_dead_app_badge_owner(state, _owner, _monitor_ref), do: state

  defp clear_menu_owner_monitor(%{menu_monitor: monitor_ref} = state)
       when is_reference(monitor_ref) do
    Process.demonitor(monitor_ref, [:flush])
    %{state | menu_owner: nil, menu_monitor: nil}
  end

  defp clear_menu_owner_monitor(state), do: state

  defp clear_dock_menu_owner_monitor(%{dock_menu_monitor: monitor_ref} = state)
       when is_reference(monitor_ref) do
    Process.demonitor(monitor_ref, [:flush])
    %{state | dock_menu_owner: nil, dock_menu_monitor: nil}
  end

  defp clear_dock_menu_owner_monitor(state), do: state

  defp clear_app_badge_owner_monitor(%{app_badge_monitor: monitor_ref} = state)
       when is_reference(monitor_ref) do
    Process.demonitor(monitor_ref, [:flush])
    %{state | app_badge_owner: nil, app_badge_monitor: nil}
  end

  defp clear_app_badge_owner_monitor(state), do: state

  defp delete_view(state, view_id) do
    case Map.pop(state.views, view_id) do
      {nil, _views} ->
        state

      {owner, views} ->
        owner_entry = Map.fetch!(state.owners, owner)
        remaining_views = MapSet.delete(owner_entry.views, view_id)

        if MapSet.size(remaining_views) == 0 do
          Process.demonitor(owner_entry.monitor, [:flush])

          %{
            state
            | views: views,
              owners: Map.delete(state.owners, owner),
              monitors: Map.delete(state.monitors, owner_entry.monitor)
          }
        else
          updated_entry = %{owner_entry | views: remaining_views}
          %{state | views: views, owners: Map.put(state.owners, owner, updated_entry)}
        end
    end
  end

  defp close_owned_views(state, owner) do
    case Map.fetch(state.owners, owner) do
      {:ok, %{views: views}} ->
        Enum.reduce(views, state, fn view_id, acc_state ->
          _ =
            native_request(
              acc_state,
              :close_window,
              {:close_window, [view_id]},
              acc_state.native_request_timeout
            )

          %{acc_state | views: Map.delete(acc_state.views, view_id)}
        end)

      :error ->
        state
    end
  end

  @menu_action_os_actions [:cut, :copy, :paste, :select_all, :undo, :redo]

  defp validate_menus(menus) when is_list(menus) do
    with {:ok, _ids} <- validate_menu_list(menus, MapSet.new()) do
      {:ok, menus}
    end
  end

  defp validate_menus(_menus), do: {:error, :invalid_menus}

  defp validate_dock_menu(items) when is_list(items) do
    with {:ok, _ids} <- validate_menu_items(items, MapSet.new()) do
      {:ok, items}
    end
  end

  defp validate_dock_menu(_items), do: {:error, :invalid_dock_menu}

  defp validate_app_badge(nil), do: {:ok, nil}
  defp validate_app_badge(label) when is_binary(label), do: {:ok, label}
  defp validate_app_badge(_label), do: {:error, :invalid_app_badge}

  defp validate_open_file_dialog_options(state, caller, opts, mode) when is_list(opts),
    do: opts |> Map.new() |> validate_open_file_dialog_options(state, caller, mode)

  defp validate_open_file_dialog_options(opts, state, caller, mode) when is_map(opts) do
    with :ok <-
           validate_file_dialog_keys(opts, [
             :multiple,
             :prompt,
             :directory,
             :filters,
             :owner_view_id
           ]),
         {:ok, multiple} <- validate_optional_boolean(Map.get(opts, :multiple, false), :multiple),
         {:ok, prompt} <- validate_optional_string(Map.get(opts, :prompt), :prompt),
         {:ok, directory} <- validate_optional_string(Map.get(opts, :directory), :directory),
         {:ok, filters} <- validate_file_dialog_filters(Map.get(opts, :filters)),
         {:ok, owner_view_id} <- validate_file_dialog_owner_view_id(state, caller, opts) do
      {:ok,
       %{
         files: Keyword.fetch!(mode, :files),
         directories: Keyword.fetch!(mode, :directories),
         multiple: multiple
       }
       |> maybe_put_window_option(:prompt, prompt)
       |> maybe_put_window_option(:directory, directory)
       |> maybe_put_window_option(:filters, filters)
       |> maybe_put_window_option(:owner_view_id, owner_view_id)}
    else
      {:error, :unknown_view_id} -> {:error, :unknown_view_id}
      {:error, :not_view_owner} -> {:error, :not_view_owner}
      _error -> {:error, :invalid_file_dialog_options}
    end
  end

  defp validate_open_file_dialog_options(_opts, _state, _caller, _mode),
    do: {:error, :invalid_file_dialog_options}

  defp validate_save_file_dialog_options(state, caller, opts) when is_list(opts),
    do: opts |> Map.new() |> validate_save_file_dialog_options(state, caller)

  defp validate_save_file_dialog_options(opts, state, caller) when is_map(opts) do
    with :ok <-
           validate_file_dialog_keys(opts, [:directory, :default_name, :filters, :owner_view_id]),
         {:ok, directory} <- validate_optional_string(Map.get(opts, :directory), :directory),
         {:ok, default_name} <-
           validate_optional_string(Map.get(opts, :default_name), :default_name),
         {:ok, filters} <- validate_file_dialog_filters(Map.get(opts, :filters)),
         {:ok, owner_view_id} <- validate_file_dialog_owner_view_id(state, caller, opts) do
      {:ok,
       %{}
       |> maybe_put_window_option(:directory, directory)
       |> maybe_put_window_option(:default_name, default_name)
       |> maybe_put_window_option(:filters, filters)
       |> maybe_put_window_option(:owner_view_id, owner_view_id)}
    else
      {:error, :unknown_view_id} -> {:error, :unknown_view_id}
      {:error, :not_view_owner} -> {:error, :not_view_owner}
      _error -> {:error, :invalid_file_dialog_options}
    end
  end

  defp validate_save_file_dialog_options(_opts, _state, _caller),
    do: {:error, :invalid_file_dialog_options}

  defp validate_file_dialog_filters(nil), do: {:ok, nil}
  defp validate_file_dialog_filters([]), do: {:ok, nil}

  defp validate_file_dialog_filters(filters) when is_list(filters) do
    if Enum.all?(filters, &(is_binary(&1) and &1 != "")) do
      {:ok, filters}
    else
      {:error, :invalid_file_dialog_options}
    end
  end

  defp validate_file_dialog_filters(_filters), do: {:error, :invalid_file_dialog_options}

  defp validate_file_dialog_owner_view_id(state, caller, opts) do
    case Map.fetch(opts, :owner_view_id) do
      {:ok, view_id} when is_integer(view_id) and view_id > 0 ->
        case validate_owned_view(state, caller, view_id) do
          :ok -> {:ok, view_id}
          error -> error
        end

      {:ok, _view_id} ->
        {:error, :invalid_file_dialog_options}

      :error ->
        {:ok, nil}
    end
  end

  defp validate_file_dialog_keys(opts, allowed_keys) do
    case Map.keys(opts) -- allowed_keys do
      [] -> :ok
      _ -> {:error, :invalid_file_dialog_options}
    end
  end

  defp validate_menu_list(menus, seen_ids) do
    Enum.reduce_while(menus, {:ok, seen_ids}, fn menu, {:ok, ids} ->
      case validate_menu(menu, ids) do
        {:ok, next_ids} -> {:cont, {:ok, next_ids}}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_menu(%{label: label, items: items} = menu, seen_ids)
       when is_binary(label) and is_list(items) do
    with :ok <- validate_menu_keys(menu, [:label, :items], {:invalid_menu, menu}) do
      validate_menu_items(items, seen_ids)
    end
  end

  defp validate_menu(menu, _seen_ids), do: {:error, {:invalid_menu, menu}}

  defp validate_menu_items(items, seen_ids) do
    Enum.reduce_while(items, {:ok, seen_ids}, fn item, {:ok, ids} ->
      case validate_menu_item(item, ids) do
        {:ok, next_ids} -> {:cont, {:ok, next_ids}}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_menu_item(:separator, seen_ids), do: {:ok, seen_ids}

  defp validate_menu_item(%{separator: true} = item, seen_ids) do
    with :ok <- validate_menu_keys(item, [:separator], {:invalid_menu_item, item}) do
      {:ok, seen_ids}
    end
  end

  defp validate_menu_item(%{label: label, items: items} = item, seen_ids)
       when is_binary(label) and is_list(items) do
    with :ok <- validate_menu_keys(item, [:label, :items], {:invalid_menu_item, item}) do
      validate_menu_items(items, seen_ids)
    end
  end

  defp validate_menu_item(%{label: label, system_menu: :services} = item, seen_ids)
       when is_binary(label) do
    with :ok <- validate_menu_keys(item, [:label, :system_menu], {:invalid_menu_item, item}) do
      {:ok, seen_ids}
    end
  end

  defp validate_menu_item(%{id: id, label: label} = item, seen_ids)
       when is_binary(id) and is_binary(label) do
    with :ok <-
           validate_menu_keys(
             item,
             [:id, :label, :callback, :shortcut, :enabled, :os_action],
             {:invalid_menu_item, item}
           ),
         :ok <- validate_menu_action_target(item),
         :ok <- validate_menu_shortcut(Map.get(item, :shortcut), item),
         :ok <- validate_menu_enabled(Map.get(item, :enabled), item),
         :ok <- validate_menu_os_action(Map.get(item, :os_action), item) do
      track_menu_action_id(id, seen_ids)
    end
  end

  defp validate_menu_item(item, _seen_ids), do: {:error, {:invalid_menu_item, item}}

  defp validate_menu_keys(map, allowed_keys, error) do
    case Map.keys(map) -- allowed_keys do
      [] -> :ok
      _ -> {:error, error}
    end
  end

  defp validate_menu_action_target(%{callback: callback} = item) when is_binary(callback) do
    if Map.has_key?(item, :os_action) do
      {:error, {:invalid_menu_item, item}}
    else
      validate_non_empty_menu_callback(callback, item)
    end
  end

  defp validate_menu_action_target(%{os_action: action} = item)
       when action in @menu_action_os_actions do
    if Map.has_key?(item, :callback) do
      {:error, {:invalid_menu_item, item}}
    else
      :ok
    end
  end

  defp validate_menu_action_target(item), do: {:error, {:invalid_menu_item, item}}

  defp validate_non_empty_menu_callback("", item), do: {:error, {:invalid_menu_item, item}}
  defp validate_non_empty_menu_callback(_callback, _item), do: :ok

  defp validate_menu_shortcut(nil, _item), do: :ok

  defp validate_menu_shortcut(shortcut, _item) when is_binary(shortcut) and shortcut != "",
    do: :ok

  defp validate_menu_shortcut(_shortcut, item), do: {:error, {:invalid_menu_item, item}}

  defp validate_menu_enabled(nil, _item), do: :ok
  defp validate_menu_enabled(enabled, _item) when is_boolean(enabled), do: :ok
  defp validate_menu_enabled(_enabled, item), do: {:error, {:invalid_menu_item, item}}

  defp validate_menu_os_action(nil, _item), do: :ok
  defp validate_menu_os_action(action, _item) when action in @menu_action_os_actions, do: :ok
  defp validate_menu_os_action(_action, item), do: {:error, {:invalid_menu_item, item}}

  defp track_menu_action_id(id, seen_ids) do
    if MapSet.member?(seen_ids, id) do
      {:error, {:duplicate_menu_id, id}}
    else
      {:ok, MapSet.put(seen_ids, id)}
    end
  end

  @supported_window_options [
    :window_bounds,
    :titlebar,
    :focus,
    :show,
    :kind,
    :is_movable,
    :is_resizable,
    :is_minimizable,
    :display_id,
    :window_background,
    :app_id,
    :window_min_size,
    :window_decorations,
    :tabbing_identifier
  ]

  @supported_bounds_states [:windowed, :maximized, :fullscreen]
  @supported_window_kinds [:normal, :popup, :floating]
  @supported_window_backgrounds [:opaque, :transparent, :blurred]
  @supported_window_decorations [:server, :client]

  defp validate_window_options(opts) when is_list(opts),
    do: validate_window_options(Map.new(opts))

  defp validate_window_options(opts) when is_map(opts) do
    with :ok <- validate_window_option_keys(opts),
         {:ok, window_bounds} <- validate_window_bounds(Map.get(opts, :window_bounds)),
         {:ok, titlebar} <- validate_titlebar(Map.get(opts, :titlebar)),
         {:ok, focus} <- validate_optional_boolean(Map.get(opts, :focus), :focus),
         {:ok, show} <- validate_optional_boolean(Map.get(opts, :show), :show),
         {:ok, kind} <- validate_optional_atom_in(Map.get(opts, :kind), @supported_window_kinds),
         {:ok, is_movable} <- validate_optional_boolean(Map.get(opts, :is_movable), :is_movable),
         {:ok, is_resizable} <-
           validate_optional_boolean(Map.get(opts, :is_resizable), :is_resizable),
         {:ok, is_minimizable} <-
           validate_optional_boolean(Map.get(opts, :is_minimizable), :is_minimizable),
         {:ok, display_id} <- validate_optional_display_id(Map.get(opts, :display_id)),
         {:ok, window_background} <-
           validate_optional_atom_in(
             Map.get(opts, :window_background),
             @supported_window_backgrounds
           ),
         {:ok, app_id} <- validate_optional_string(Map.get(opts, :app_id), :app_id),
         {:ok, window_min_size} <- validate_size_map(Map.get(opts, :window_min_size)),
         {:ok, window_decorations} <-
           validate_optional_atom_in(
             Map.get(opts, :window_decorations),
             @supported_window_decorations
           ),
         {:ok, tabbing_identifier} <-
           validate_optional_string(Map.get(opts, :tabbing_identifier), :tabbing_identifier) do
      {:ok,
       %{}
       |> maybe_put_window_option(:window_bounds, window_bounds)
       |> maybe_put_window_option(:titlebar, titlebar)
       |> maybe_put_window_option(:focus, focus)
       |> maybe_put_window_option(:show, show)
       |> maybe_put_window_option(:kind, kind)
       |> maybe_put_window_option(:is_movable, is_movable)
       |> maybe_put_window_option(:is_resizable, is_resizable)
       |> maybe_put_window_option(:is_minimizable, is_minimizable)
       |> maybe_put_window_option(:display_id, display_id)
       |> maybe_put_window_option(:window_background, window_background)
       |> maybe_put_window_option(:app_id, app_id)
       |> maybe_put_window_option(:window_min_size, window_min_size)
       |> maybe_put_window_option(:window_decorations, window_decorations)
       |> maybe_put_window_option(:tabbing_identifier, tabbing_identifier)}
    end
  end

  defp validate_window_options(_opts), do: {:error, :invalid_window_options}

  defp validate_window_option_keys(opts) do
    case Map.keys(opts) -- @supported_window_options do
      [] -> :ok
      _ -> {:error, :invalid_window_options}
    end
  end

  defp validate_window_bounds(nil), do: {:ok, nil}

  defp validate_window_bounds(bounds) when is_list(bounds),
    do: validate_window_bounds(Map.new(bounds))

  defp validate_window_bounds(bounds) when is_map(bounds) do
    with :ok <- validate_nested_keys(bounds, [:x, :y, :width, :height, :state]),
         {:ok, width} <- validate_required_positive_integer(Map.get(bounds, :width)),
         {:ok, height} <- validate_required_positive_integer(Map.get(bounds, :height)),
         {:ok, x} <- validate_optional_integer_value(Map.get(bounds, :x)),
         {:ok, y} <- validate_optional_integer_value(Map.get(bounds, :y)),
         {:ok, state} <-
           validate_optional_atom_in(Map.get(bounds, :state), @supported_bounds_states) do
      case {x, y} do
        {nil, nil} ->
          {:ok, %{width: width, height: height, state: state || :windowed}}

        {x, y} when is_integer(x) and is_integer(y) ->
          {:ok, %{x: x, y: y, width: width, height: height, state: state || :windowed}}

        _ ->
          {:error, :invalid_window_options}
      end
    end
  end

  defp validate_window_bounds(_bounds), do: {:error, :invalid_window_options}

  defp validate_titlebar(nil), do: {:ok, nil}
  defp validate_titlebar(false), do: {:ok, false}

  defp validate_titlebar(titlebar) when is_list(titlebar),
    do: validate_titlebar(Map.new(titlebar))

  defp validate_titlebar(titlebar) when is_map(titlebar) do
    with :ok <-
           validate_nested_keys(titlebar, [:title, :appears_transparent, :traffic_light_position]),
         {:ok, title} <- validate_optional_string(Map.get(titlebar, :title), :title),
         {:ok, appears_transparent} <-
           validate_optional_boolean(
             Map.get(titlebar, :appears_transparent),
             :appears_transparent
           ),
         {:ok, traffic_light_position} <-
           validate_optional_point_map(Map.get(titlebar, :traffic_light_position)) do
      {:ok,
       %{}
       |> maybe_put_window_option(:title, title)
       |> maybe_put_window_option(:appears_transparent, appears_transparent)
       |> maybe_put_window_option(:traffic_light_position, traffic_light_position)}
    end
  end

  defp validate_titlebar(_titlebar), do: {:error, :invalid_window_options}

  defp validate_size_map(nil), do: {:ok, nil}
  defp validate_size_map(size) when is_list(size), do: validate_size_map(Map.new(size))

  defp validate_size_map(size) when is_map(size) do
    with :ok <- validate_nested_keys(size, [:width, :height]),
         {:ok, width} <- validate_required_positive_integer(Map.get(size, :width)),
         {:ok, height} <- validate_required_positive_integer(Map.get(size, :height)) do
      {:ok, %{width: width, height: height}}
    end
  end

  defp validate_size_map(_size), do: {:error, :invalid_window_options}

  defp validate_optional_point_map(nil), do: {:ok, nil}

  defp validate_optional_point_map(point) when is_list(point),
    do: validate_optional_point_map(Map.new(point))

  defp validate_optional_point_map(point) when is_map(point) do
    with :ok <- validate_nested_keys(point, [:x, :y]),
         {:ok, x} <- validate_required_non_neg_integer(Map.get(point, :x)),
         {:ok, y} <- validate_required_non_neg_integer(Map.get(point, :y)) do
      {:ok, %{x: x, y: y}}
    end
  end

  defp validate_optional_point_map(_point), do: {:error, :invalid_window_options}

  defp validate_optional_display_id(nil), do: {:ok, nil}

  defp validate_optional_display_id(value)
       when is_integer(value) and value >= 0 and value <= 4_294_967_295,
       do: {:ok, value}

  defp validate_optional_display_id(_value), do: {:error, :invalid_window_options}

  defp validate_optional_integer_value(nil), do: {:ok, nil}
  defp validate_optional_integer_value(value) when is_integer(value), do: {:ok, value}
  defp validate_optional_integer_value(_value), do: {:error, :invalid_window_options}

  defp validate_required_positive_integer(value) when is_integer(value) and value > 0,
    do: {:ok, value}

  defp validate_required_positive_integer(_value), do: {:error, :invalid_window_options}

  defp validate_required_non_neg_integer(value) when is_integer(value) and value >= 0,
    do: {:ok, value}

  defp validate_required_non_neg_integer(_value), do: {:error, :invalid_window_options}

  defp validate_optional_atom_in(nil, _allowed), do: {:ok, nil}

  defp validate_optional_atom_in(value, allowed) when is_atom(value) do
    if value in allowed do
      {:ok, value}
    else
      {:error, :invalid_window_options}
    end
  end

  defp validate_optional_atom_in(_value, _allowed), do: {:error, :invalid_window_options}

  defp validate_optional_string(nil, _field), do: {:ok, nil}
  defp validate_optional_string(value, _field) when is_binary(value), do: {:ok, value}
  defp validate_optional_string(_value, _field), do: {:error, :invalid_window_options}

  defp validate_optional_boolean(nil, _field), do: {:ok, nil}
  defp validate_optional_boolean(value, _field) when is_boolean(value), do: {:ok, value}
  defp validate_optional_boolean(_value, _field), do: {:error, :invalid_window_options}

  defp validate_nested_keys(map, allowed_keys) do
    case Map.keys(map) -- allowed_keys do
      [] -> :ok
      _ -> {:error, :invalid_window_options}
    end
  end

  defp maybe_put_window_option(map, _key, nil), do: map
  defp maybe_put_window_option(map, key, value), do: Map.put(map, key, value)

  defp drop_owner(state, owner, monitor_ref) do
    %{
      state
      | owners: Map.delete(state.owners, owner),
        monitors: Map.delete(state.monitors, monitor_ref)
    }
  end
end
