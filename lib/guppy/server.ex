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

  def open_window(server \\ __MODULE__, owner, ir, opts \\ [], timeout \\ 5_000) do
    GenServer.call(server, {:open_window, owner, ir, opts}, timeout)
  end

  def render(server \\ __MODULE__, view_id, ir, timeout \\ 5_000) do
    GenServer.call(server, {:render, view_id, ir}, timeout)
  end

  def close_window(server \\ __MODULE__, view_id, timeout \\ 5_000) do
    GenServer.call(server, {:close_window, view_id}, timeout)
  end

  def view_count(server \\ __MODULE__, timeout \\ 5_000) do
    GenServer.call(server, :view_count, timeout)
  end

  def validate_window_options_for_test(opts), do: validate_window_options(opts)

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

  def handle_call({:open_window, owner, ir, opts}, {caller, _tag}, state) when is_pid(owner) do
    if owner != caller do
      {:reply, {:error, :owner_mismatch}, state}
    else
      with :ok <- Guppy.IR.validate(ir),
           {:ok, opts} <- validate_window_options(opts) do
        view_id = state.next_view_id

        case state.native.request(state.native_server, {:open_window, [view_id, ir, opts]}) do
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
      else
        error ->
          {:reply, error, state}
      end
    end
  end

  def handle_call({:render, view_id, ir}, {caller, _tag}, state) do
    case validate_owned_view_ir(state, caller, view_id, ir) do
      :ok ->
        reply = state.native.request(state.native_server, {:render, [view_id, ir]})
        {:reply, normalize_native_reply(reply), state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:close_window, view_id}, {caller, _tag}, state) do
    case validate_owned_view(state, caller, view_id) do
      :ok ->
        case state.native.request(state.native_server, {:close_window, [view_id]}) do
          :ok -> {:reply, :ok, delete_view(state, view_id)}
          {:ok, _payload} -> {:reply, :ok, delete_view(state, view_id)}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end

      error ->
        {:reply, error, state}
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
