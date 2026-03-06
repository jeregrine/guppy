defmodule Guppy.Native.Nif do
  @moduledoc """
  NIF-backed native bridge scaffold.

  The long-term shape is expected to be:

  - a narrow Elixir wrapper for lifecycle and request routing
  - a small C shim that owns `ERL_NIF_INIT` and low-level bootstrap
  - a Rust core linked into the same final native library
  """

  use GenServer

  @behaviour Guppy.Native
  @on_load :load_nif

  @load_status_key {__MODULE__, :load_status}

  defstruct nif_path: nil, status: :not_loaded, load_status: {:error, :not_loaded}

  @type load_status :: :ok | {:error, term()}

  @type state :: %__MODULE__{
          nif_path: String.t() | nil,
          status: :not_loaded | :loaded,
          load_status: load_status()
        }

  @impl Guppy.Native
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl Guppy.Native
  def request(server \\ __MODULE__, command, timeout \\ 5_000) do
    GenServer.call(server, {:request, command}, timeout)
  end

  @impl Guppy.Native
  def cast(server \\ __MODULE__, command) do
    GenServer.cast(server, {:cast, command})
  end

  @impl Guppy.Native
  def connected?(server \\ __MODULE__) do
    GenServer.call(server, :connected?)
  end

  def info(server \\ __MODULE__) do
    GenServer.call(server, :info)
  end

  def load_status do
    :persistent_term.get(@load_status_key, {:error, :not_loaded})
  end

  def loaded? do
    load_status() == :ok
  end

  def load_nif do
    nif_path = Application.get_env(:guppy, :nif_path)

    status =
      case nif_path do
        nil ->
          {:error, :nif_path_not_configured}

        path ->
          case :erlang.load_nif(String.to_charlist(path), 0) do
            :ok -> :ok
            {:error, {:reload, _}} -> :ok
            {:error, reason} -> {:error, reason}
          end
      end

    :persistent_term.put(@load_status_key, status)
    :ok
  end

  @impl true
  def init(opts) do
    load_status = load_status()

    state = %__MODULE__{
      nif_path: Keyword.get(opts, :nif_path, Application.get_env(:guppy, :nif_path)),
      status: status_from_load_status(load_status),
      load_status: load_status
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:connected?, _from, state) do
    {:reply, state.status == :loaded, state}
  end

  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:request, {:ping, []}}, _from, state) do
    {:reply, with_loaded(state, fn -> {:ok, native_ping()} end), state}
  end

  def handle_call({:request, {:open_window, [view_id]}}, _from, state) do
    {:reply, with_loaded(state, fn -> normalize_status(native_open_window(view_id)) end), state}
  end

  def handle_call({:request, {:set_event_target, [pid]}}, _from, state) when is_pid(pid) do
    {:reply, with_loaded(state, fn -> normalize_status(native_set_event_target(pid)) end), state}
  end

  def handle_call({:request, {:mount, [view_id, ir]}}, _from, state) do
    {:reply, with_loaded(state, fn -> normalize_status(native_mount(view_id, ir)) end), state}
  end

  def handle_call({:request, {:update, [view_id, ir]}}, _from, state) do
    {:reply, with_loaded(state, fn -> normalize_status(native_update(view_id, ir)) end), state}
  end

  def handle_call({:request, {:update_window_text, [view_id, text]}}, _from, state)
      when is_binary(text) do
    {:reply,
     with_loaded(state, fn -> normalize_status(native_update_window_text(view_id, text)) end),
     state}
  end

  def handle_call({:request, {:close_window, [view_id]}}, _from, state) do
    {:reply, with_loaded(state, fn -> normalize_status(native_close_window(view_id)) end), state}
  end

  def handle_call({:request, {:view_count, []}}, _from, state) do
    {:reply, with_loaded(state, fn -> {:ok, native_view_count()} end), state}
  end

  def handle_call({:request, _command}, _from, state) do
    {:reply, {:error, :unsupported_command}, state}
  end

  @impl true
  def handle_cast({:cast, _command}, state) do
    {:noreply, state}
  end

  def native_ping do
    {:error, :nif_not_loaded}
  end

  def native_build_info do
    {:error, :nif_not_loaded}
  end

  def native_runtime_status do
    {:error, :nif_not_loaded}
  end

  def native_gui_status do
    {:error, :nif_not_loaded}
  end

  def native_open_window(_view_id) do
    {:error, :nif_not_loaded}
  end

  def native_set_event_target(_pid) do
    {:error, :nif_not_loaded}
  end

  def native_mount(_view_id, _ir) do
    {:error, :nif_not_loaded}
  end

  def native_update(_view_id, _ir) do
    {:error, :nif_not_loaded}
  end

  def native_update_window_text(_view_id, _text) do
    {:error, :nif_not_loaded}
  end

  def native_close_window(_view_id) do
    {:error, :nif_not_loaded}
  end

  def native_view_count do
    {:error, :nif_not_loaded}
  end

  def build_info do
    case load_status() do
      :ok -> {:ok, native_build_info() |> List.to_string()}
      {:error, reason} -> {:error, reason}
    end
  end

  def runtime_status do
    case load_status() do
      :ok -> {:ok, native_runtime_status() |> List.to_string()}
      {:error, reason} -> {:error, reason}
    end
  end

  def gui_status do
    case load_status() do
      :ok -> {:ok, native_gui_status() |> List.to_string()}
      {:error, reason} -> {:error, reason}
    end
  end

  defp with_loaded(%__MODULE__{status: :loaded}, fun), do: fun.()
  defp with_loaded(%__MODULE__{status: :not_loaded}, _fun), do: {:error, :nif_not_loaded}

  defp normalize_status({:error, reason}), do: {:error, reason}
  defp normalize_status(status) when is_atom(status), do: status
  defp normalize_status(other), do: {:ok, other}

  defp status_from_load_status(:ok), do: :loaded
  defp status_from_load_status(_), do: :not_loaded
end
