defmodule Guppy.Native.Nif do
  @moduledoc """
  NIF-backed native bridge wrapper.

  Rustler owns the NIF entrypoints and lifecycle. This module keeps the
  Elixir-facing dispatch and load-status normalization narrow.
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

  def native_performance_counters do
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
      :ok -> {:ok, native_build_info() |> native_string_to_string()}
      {:error, reason} -> {:error, reason}
    end
  end

  def runtime_status do
    case load_status() do
      :ok -> {:ok, native_runtime_status() |> native_string_to_string()}
      {:error, reason} -> {:error, reason}
    end
  end

  def gui_status do
    case load_status() do
      :ok -> {:ok, native_gui_status() |> native_string_to_string()}
      {:error, reason} -> {:error, reason}
    end
  end

  def performance_counters do
    case load_status() do
      :ok -> {:ok, native_performance_counters()}
      {:error, reason} -> {:error, reason}
    end
  end

  defp native_string_to_string(value) when is_binary(value), do: value
  defp native_string_to_string(value) when is_list(value), do: List.to_string(value)

  defp dispatch({:ping, []}) do
    with_loaded(fn -> native_call(:ping, fn -> {:ok, native_ping()} end) end)
  end

  defp dispatch({:open_window, [view_id, ir, opts]}) do
    with_loaded(fn ->
      native_call(:open_window, fn -> normalize_status(native_open_window(view_id, ir, opts)) end)
    end)
  end

  defp dispatch({:set_event_target, [pid]}) when is_pid(pid) do
    with_loaded(fn ->
      native_call(:set_event_target, fn -> normalize_status(native_set_event_target(pid)) end)
    end)
  end

  defp dispatch({:render, [view_id, ir]}) do
    with_loaded(fn ->
      native_call(:render, fn -> normalize_status(native_render(view_id, ir)) end)
    end)
  end

  defp dispatch({:close_window, [view_id]}) do
    with_loaded(fn ->
      native_call(:close_window, fn -> normalize_status(native_close_window(view_id)) end)
    end)
  end

  defp dispatch({:view_count, []}) do
    with_loaded(fn -> native_call(:view_count, fn -> {:ok, native_view_count()} end) end)
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

  defp native_call(command, fun) do
    start_time = System.monotonic_time()
    reply = fun.()
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:guppy, :native, :nif],
      %{duration: duration},
      %{command: command, status: telemetry_status(reply)}
    )

    reply
  end

  defp telemetry_status(:ok), do: :ok
  defp telemetry_status({:ok, _payload}), do: :ok
  defp telemetry_status({:error, reason}), do: {:error, reason}
  defp telemetry_status(other), do: other

  defp normalize_status({:error, reason}), do: {:error, reason}
  defp normalize_status(status) when is_atom(status), do: status
  defp normalize_status(other), do: {:ok, other}

  defp status_from_load_status(:ok), do: :loaded
  defp status_from_load_status(_), do: :not_loaded
end
