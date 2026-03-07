defmodule Guppy.Server do
  @moduledoc """
  Central Guppy runtime server.

  Phase 1 starts with ownership, native request routing, and cleanup scaffolding
  before the real GPUI runtime is attached.
  """

  use GenServer

  defstruct native: nil,
            native_server: nil,
            nif_path: nil,
            next_view_id: 1,
            views: %{},
            owners: %{},
            monitors: %{}

  @type view_id :: pos_integer()

  @type owner_entry :: %{
          monitor: reference(),
          views: MapSet.t(view_id())
        }

  @type state :: %__MODULE__{
          native: module(),
          native_server: GenServer.server(),
          nif_path: String.t() | nil,
          next_view_id: pos_integer(),
          views: %{optional(view_id()) => pid()},
          owners: %{optional(pid()) => owner_entry()},
          monitors: %{optional(reference()) => pid()}
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def info(server \\ __MODULE__) do
    GenServer.call(server, :info)
  end

  def ping(server \\ __MODULE__, timeout \\ 5_000) do
    GenServer.call(server, :ping, timeout)
  end

  def open_window(server \\ __MODULE__, owner \\ self(), timeout \\ 5_000) do
    GenServer.call(server, {:open_window, owner}, timeout)
  end

  def mount(server \\ __MODULE__, view_id, ir, timeout \\ 5_000) do
    GenServer.call(server, {:mount, view_id, ir}, timeout)
  end

  def update(server \\ __MODULE__, view_id, ir, timeout \\ 5_000) do
    GenServer.call(server, {:update, view_id, ir}, timeout)
  end

  def close_window(server \\ __MODULE__, view_id, timeout \\ 5_000) do
    GenServer.call(server, {:close_window, view_id}, timeout)
  end

  def view_count(server \\ __MODULE__, timeout \\ 5_000) do
    GenServer.call(server, :view_count, timeout)
  end

  @impl true
  def init(opts) do
    native = Keyword.get(opts, :native, Application.get_env(:guppy, :native))

    state = %__MODULE__{
      native: native,
      native_server: Keyword.get(opts, :native_server, native),
      nif_path: Keyword.get(opts, :nif_path, Application.get_env(:guppy, :nif_path))
    }

    {:ok, maybe_register_event_target(state)}
  end

  @impl true
  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:ping, _from, state) do
    reply = state.native.request(state.native_server, {:ping, []})
    {:reply, reply, state}
  end

  def handle_call(:view_count, _from, state) do
    reply = state.native.request(state.native_server, {:view_count, []})
    {:reply, reply, state}
  end

  def handle_call({:open_window, owner}, _from, state) when is_pid(owner) do
    view_id = state.next_view_id

    case state.native.request(state.native_server, {:open_window, [view_id]}) do
      :ok ->
        state =
          state
          |> put_view(view_id, owner)
          |> increment_view_id()

        {:reply, {:ok, view_id}, state}

      {:ok, _payload} ->
        state =
          state
          |> put_view(view_id, owner)
          |> increment_view_id()

        {:reply, {:ok, view_id}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:mount, view_id, ir}, _from, state) do
    case validate_view_ir(state, view_id, ir) do
      :ok ->
        reply = state.native.request(state.native_server, {:mount, [view_id, ir]})
        {:reply, normalize_native_reply(reply), state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:update, view_id, ir}, _from, state) do
    case validate_view_ir(state, view_id, ir) do
      :ok ->
        reply = state.native.request(state.native_server, {:update, [view_id, ir]})
        {:reply, normalize_native_reply(reply), state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:close_window, view_id}, _from, state) do
    case Map.has_key?(state.views, view_id) do
      true ->
        case state.native.request(state.native_server, {:close_window, [view_id]}) do
          :ok -> {:reply, :ok, delete_view(state, view_id)}
          {:ok, _payload} -> {:reply, :ok, delete_view(state, view_id)}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end

      false ->
        {:reply, {:error, :unknown_view_id}, state}
    end
  end

  @impl true
  def handle_info(
        {:guppy_native_event, view_id, type, %{id: node_id, callback: callback_id} = payload},
        state
      )
      when is_integer(view_id) and is_atom(type) and
             type in [
               :click,
               :hover,
               :focus,
               :blur,
               :key_down,
               :key_up,
               :mouse_down,
               :mouse_up,
               :mouse_move,
               :scroll_wheel
             ] and
             is_binary(node_id) and is_binary(callback_id) do
    case Map.fetch(state.views, view_id) do
      {:ok, owner} ->
        send(owner, {:guppy_event, view_id, Map.put(payload, :type, type)})
        {:noreply, state}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:guppy_native_event, view_id, :window_closed, _payload}, state)
      when is_integer(view_id) do
    case Map.fetch(state.views, view_id) do
      {:ok, owner} ->
        send(owner, {:guppy_event, view_id, %{type: :window_closed}})
        {:noreply, delete_view(state, view_id)}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, monitor_ref, :process, owner, _reason}, state) do
    case Map.fetch(state.monitors, monitor_ref) do
      {:ok, ^owner} ->
        state = close_owned_views(state, owner)
        {:noreply, drop_owner(state, owner, monitor_ref)}

      _ ->
        {:noreply, state}
    end
  end

  defp validate_view_ir(state, view_id, ir) do
    cond do
      not Map.has_key?(state.views, view_id) -> {:error, :unknown_view_id}
      true -> Guppy.IR.validate(ir)
    end
  end

  defp maybe_register_event_target(state) do
    case state.native.request(state.native_server, {:set_event_target, [self()]}) do
      :ok -> state
      {:ok, _payload} -> state
      {:error, _reason} -> state
    end
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
          _ = acc_state.native.request(acc_state.native_server, {:close_window, [view_id]})
          %{acc_state | views: Map.delete(acc_state.views, view_id)}
        end)

      :error ->
        state
    end
  end

  defp drop_owner(state, owner, monitor_ref) do
    %{
      state
      | owners: Map.delete(state.owners, owner),
        monitors: Map.delete(state.monitors, monitor_ref)
    }
  end
end
