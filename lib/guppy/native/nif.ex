defmodule Guppy.Native.Nif do
  @moduledoc """
  NIF-backed native bridge wrapper.

  Rustler owns the NIF entrypoints and lifecycle. This module keeps the
  Elixir-facing dispatch and load-status normalization narrow.
  """

  @behaviour Guppy.Native

  @version Mix.Project.config()[:version]

  @native_mode if Mix.env() == :prod or
                    System.get_env("GUPPY_NATIVE_RELEASE") in ["1", "true", "TRUE", "yes"],
                  do: :release,
                  else: :debug

  # Consumers get the precompiled artifact by default; set
  # GUPPY_NATIVE_FORCE_BUILD=1 to build the crate from source (required when
  # developing Guppy itself — the repo's mise.toml exports it).
  @force_build System.get_env("GUPPY_NATIVE_FORCE_BUILD") in ["1", "true", "TRUE", "yes"]

  @precompiled_targets [
    "aarch64-apple-darwin"
  ]

  use RustlerPrecompiled,
    otp_app: :guppy,
    crate: "guppy_nif",
    base_url: "https://github.com/jeregrine/guppy/releases/download/v#{@version}",
    version: @version,
    targets: @precompiled_targets,
    nif_versions: ["2.15"],
    mode: @native_mode,
    force_build: @force_build

  @type load_status :: :ok | {:error, term()}

  @impl Guppy.Native
  def request(_server \\ __MODULE__, command, timeout \\ 5_000) do
    dispatch(command, timeout)
  end

  @load_status_cache_key {__MODULE__, :load_status}

  # A loaded NIF stays loaded for the VM lifetime, so a successful check is
  # cached and dispatches skip the per-call ping. Failures are re-checked.
  @doc "Returns `:ok` once the NIF is loaded, caching the successful check."
  def load_status do
    case :persistent_term.get(@load_status_cache_key, :unknown) do
      :ok -> :ok
      :unknown -> check_and_cache_load_status()
    end
  end

  defp check_and_cache_load_status do
    case checked_load_status() do
      :ok ->
        :persistent_term.put(@load_status_cache_key, :ok)
        :ok

      error ->
        error
    end
  end

  defp checked_load_status do
    case apply(__MODULE__, :native_ping, []) do
      :pong -> :ok
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  rescue
    UndefinedFunctionError -> {:error, :nif_not_loaded}
    ErlangError -> {:error, :nif_not_loaded}
  end

  @doc "Returns true when the NIF is loaded."
  def loaded? do
    load_status() == :ok
  end

  @doc false
  def native_ping do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_build_info do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_runtime_status do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_gui_status do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_performance_counters do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_open_window(_view_id, _ir, _opts, _timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_set_event_target(_pid) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_set_menus(_menus, _timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_set_dock_menu(_items, _timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_set_app_badge(_label, _timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_open_file_dialog(
        _files,
        _directories,
        _multiple,
        _prompt,
        _directory,
        _filters,
        _owner_view_id,
        _timeout
      ) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_save_file_dialog(_directory, _default_name, _filters, _owner_view_id, _timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_read_clipboard_text(_timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_write_clipboard_text(_text, _timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_event_target_status do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_render(_view_id, _ir, _timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_close_window(_view_id, _timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_focus_window(_view_id, _timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_close_all(_timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc false
  def native_view_count(_timeout) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc "Returns native build info when the NIF is loaded."
  def build_info do
    case load_status() do
      :ok -> {:ok, native_build_info() |> native_string_to_string()}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Returns the native runtime status when the NIF is loaded."
  def runtime_status do
    case load_status() do
      :ok -> {:ok, native_runtime_status() |> native_string_to_string()}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Returns the native GUI bootstrap status when the NIF is loaded."
  def gui_status do
    case load_status() do
      :ok -> {:ok, native_gui_status() |> native_string_to_string()}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Returns native performance counters when the NIF is loaded."
  def performance_counters do
    case load_status() do
      :ok -> {:ok, native_performance_counters()}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Returns the registered native event target generation, for diagnostics."
  def event_target_status do
    case load_status() do
      :ok -> {:ok, native_event_target_status()}
      {:error, reason} -> {:error, reason}
    end
  end

  defp native_string_to_string(value) when is_binary(value), do: value
  defp native_string_to_string(value) when is_list(value), do: List.to_string(value)

  defp dispatch({:ping, []}, _timeout) do
    with_loaded(fn -> native_call(:ping, fn -> {:ok, native_ping()} end) end)
  end

  defp dispatch({:open_window, [view_id, ir, opts]}, timeout) do
    with_loaded(fn ->
      native_call(:open_window, fn ->
        normalize_status(native_open_window(view_id, ir, opts, timeout))
      end)
    end)
  end

  defp dispatch({:set_event_target, [pid]}, _timeout) when is_pid(pid) do
    with_loaded(fn ->
      native_call(:set_event_target, fn -> normalize_status(native_set_event_target(pid)) end)
    end)
  end

  defp dispatch({:set_menus, [menus]}, timeout) do
    with_loaded(fn ->
      native_call(:set_menus, fn -> normalize_status(native_set_menus(menus, timeout)) end)
    end)
  end

  defp dispatch({:set_dock_menu, [items]}, timeout) do
    with_loaded(fn ->
      native_call(:set_dock_menu, fn -> normalize_status(native_set_dock_menu(items, timeout)) end)
    end)
  end

  defp dispatch({:set_app_badge, [label]}, timeout) when is_binary(label) or is_nil(label) do
    with_loaded(fn ->
      native_call(:set_app_badge, fn -> normalize_status(native_set_app_badge(label, timeout)) end)
    end)
  end

  defp dispatch({:open_file_dialog, [opts]}, timeout) when is_map(opts) do
    with_loaded(fn ->
      native_call(:open_file_dialog, fn ->
        normalize_file_dialog_paths(
          native_open_file_dialog(
            Map.fetch!(opts, :files),
            Map.fetch!(opts, :directories),
            Map.fetch!(opts, :multiple),
            Map.get(opts, :prompt),
            Map.get(opts, :directory),
            Map.get(opts, :filters, []),
            Map.get(opts, :owner_view_id),
            timeout
          )
        )
      end)
    end)
  end

  defp dispatch({:save_file_dialog, [opts]}, timeout) when is_map(opts) do
    with_loaded(fn ->
      native_call(:save_file_dialog, fn ->
        normalize_file_dialog_path(
          native_save_file_dialog(
            Map.get(opts, :directory),
            Map.get(opts, :default_name),
            Map.get(opts, :filters, []),
            Map.get(opts, :owner_view_id),
            timeout
          )
        )
      end)
    end)
  end

  defp dispatch({:read_clipboard_text, []}, timeout) do
    with_loaded(fn ->
      native_call(:read_clipboard_text, fn ->
        normalize_clipboard_text(native_read_clipboard_text(timeout))
      end)
    end)
  end

  defp dispatch({:write_clipboard_text, [text]}, timeout) when is_binary(text) do
    with_loaded(fn ->
      native_call(:write_clipboard_text, fn ->
        normalize_status(native_write_clipboard_text(text, timeout))
      end)
    end)
  end

  defp dispatch({:event_target_status, []}, _timeout) do
    with_loaded(fn ->
      native_call(:event_target_status, fn -> {:ok, native_event_target_status()} end)
    end)
  end

  defp dispatch({:render, [view_id, ir]}, timeout) do
    with_loaded(fn ->
      native_call(:render, fn -> normalize_status(native_render(view_id, ir, timeout)) end)
    end)
  end

  defp dispatch({:close_window, [view_id]}, timeout) do
    with_loaded(fn ->
      native_call(:close_window, fn -> normalize_status(native_close_window(view_id, timeout)) end)
    end)
  end

  defp dispatch({:focus_window, [view_id]}, timeout) do
    with_loaded(fn ->
      native_call(:focus_window, fn -> normalize_status(native_focus_window(view_id, timeout)) end)
    end)
  end

  defp dispatch({:close_all, []}, timeout) do
    with_loaded(fn ->
      native_call(:close_all, fn -> normalize_status(native_close_all(timeout)) end)
    end)
  end

  defp dispatch({:view_count, []}, timeout) do
    with_loaded(fn ->
      native_call(:view_count, fn -> normalize_status(native_view_count(timeout)) end)
    end)
  end

  defp dispatch(_command, _timeout) do
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
      %{command: command, status: Guppy.Native.telemetry_status(reply)}
    )

    reply
  end

  defp normalize_status({:error, reason}), do: {:error, reason}
  defp normalize_status(status) when is_atom(status), do: status
  defp normalize_status(other), do: {:ok, other}

  defp normalize_clipboard_text({:error, reason}), do: {:error, reason}
  defp normalize_clipboard_text(value) when is_nil(value), do: {:ok, nil}
  defp normalize_clipboard_text(text) when is_binary(text), do: {:ok, text}
  defp normalize_clipboard_text(_other), do: {:error, :runtime_unavailable}

  defp normalize_file_dialog_paths({:error, reason}), do: {:error, reason}
  defp normalize_file_dialog_paths(value) when is_nil(value), do: {:ok, nil}
  defp normalize_file_dialog_paths(paths) when is_list(paths), do: {:ok, paths}
  defp normalize_file_dialog_paths(_other), do: {:error, :runtime_unavailable}

  defp normalize_file_dialog_path({:error, reason}), do: {:error, reason}
  defp normalize_file_dialog_path(value) when is_nil(value), do: {:ok, nil}
  defp normalize_file_dialog_path(path) when is_binary(path), do: {:ok, path}
  defp normalize_file_dialog_path(_other), do: {:error, :runtime_unavailable}
end
