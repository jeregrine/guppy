defmodule Guppy.Native.Nif do
  @moduledoc """
  NIF-backed native bridge scaffold.

  The long-term shape is expected to be:

  - a narrow Elixir wrapper for lifecycle and request routing
  - a small C shim that owns `ERL_NIF_INIT` and low-level bootstrap
  - a Rust core linked into the same final native library
  """

  @behaviour Guppy.Native
  @on_load :load_nif

  @load_status_key {__MODULE__, :load_status}

  @type load_status :: :ok | {:error, term()}

  @impl Guppy.Native
  def request(_server \\ __MODULE__, command, _timeout \\ 5_000) do
    dispatch(command)
  end

  @impl Guppy.Native
  def cast(server \\ __MODULE__, command) do
    _ = request(server, command)
    :ok
  end

  @impl Guppy.Native
  def connected?(_server \\ __MODULE__) do
    loaded?()
  end

  def info(_server \\ __MODULE__) do
    %{
      nif_path: Application.get_env(:guppy, :nif_path),
      status: status_from_load_status(load_status()),
      load_status: load_status()
    }
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

  def native_open_window(_view_id, _ir, _opts) do
    {:error, :nif_not_loaded}
  end

  def native_set_event_target(_pid) do
    {:error, :nif_not_loaded}
  end

  def native_render(_view_id, _ir) do
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

  defp dispatch({:ping, []}) do
    with_loaded(fn -> {:ok, native_ping()} end)
  end

  defp dispatch({:open_window, [view_id, ir, opts]}) do
    with_loaded(fn -> normalize_status(native_open_window(view_id, ir, opts)) end)
  end

  defp dispatch({:set_event_target, [pid]}) when is_pid(pid) do
    with_loaded(fn -> normalize_status(native_set_event_target(pid)) end)
  end

  defp dispatch({:render, [view_id, ir]}) do
    with_loaded(fn -> normalize_status(native_render(view_id, ir)) end)
  end

  defp dispatch({:close_window, [view_id]}) do
    with_loaded(fn -> normalize_status(native_close_window(view_id)) end)
  end

  defp dispatch({:view_count, []}) do
    with_loaded(fn -> {:ok, native_view_count()} end)
  end

  defp dispatch(_command) do
    {:error, :unsupported_command}
  end

  defp with_loaded(fun) do
    case load_status() do
      :ok -> fun.()
      {:error, _reason} -> {:error, :nif_not_loaded}
    end
  end

  defp normalize_status({:error, reason}), do: {:error, reason}
  defp normalize_status(status) when is_atom(status), do: status
  defp normalize_status(other), do: {:ok, other}

  defp status_from_load_status(:ok), do: :loaded
  defp status_from_load_status(_), do: :not_loaded
end
