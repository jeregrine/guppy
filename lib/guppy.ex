defmodule Guppy do
  @moduledoc """
  Public entry points for the Guppy runtime.

  The current direction is an OTP-supervised Elixir runtime coordinating a native
  GPUI bridge loaded as a NIF.
  """

  alias Guppy.Server

  @doc "Returns the configured native bridge module."
  def native do
    Application.get_env(:guppy, :native, Guppy.Native.Nif)
  end

  @doc "Returns the configured NIF library path."
  def nif_path do
    Application.get_env(:guppy, :nif_path)
  end

  @doc "Returns true when the Guppy server process is running."
  def started? do
    not is_nil(server())
  end

  @doc "Returns the Guppy server pid, if started."
  def server do
    Process.whereis(Server)
  end

  @doc "Returns runtime state for early bring-up and tests."
  def info do
    Server.info()
  end

  @doc "Pings the native bridge."
  def ping(timeout \\ 5_000) do
    Server.ping(Server, timeout)
  end

  @doc "Opens a native window owned by the calling process and renders its initial IR tree."
  def open_window(ir), do: Server.open_window(Server, self(), ir, [], 5_000)

  def open_window(ir, owner) when is_pid(owner),
    do: Server.open_window(Server, owner, ir, [], 5_000)

  def open_window(ir, owner, opts) when is_pid(owner) and is_list(opts) do
    Server.open_window(Server, owner, ir, opts, 5_000)
  end

  def open_window(ir, owner, timeout) when is_pid(owner) and is_integer(timeout) do
    Server.open_window(Server, owner, ir, [], timeout)
  end

  def open_window(ir, owner, opts, timeout)
      when is_pid(owner) and is_list(opts) and is_integer(timeout) do
    Server.open_window(Server, owner, ir, opts, timeout)
  end

  @doc "Renders a full IR tree into an open native window."
  def render(view_id, ir, timeout \\ 5_000) do
    Server.render(Server, view_id, ir, timeout)
  end

  @doc "Closes a previously opened native window."
  def close_window(view_id, timeout \\ 5_000) do
    Server.close_window(Server, view_id, timeout)
  end

  @doc "Returns the native-side open view count."
  def native_view_count(timeout \\ 5_000) do
    Server.view_count(Server, timeout)
  end

  @doc "Returns native build info when the NIF is loaded."
  def native_build_info do
    Guppy.Native.Nif.build_info()
  end

  @doc "Returns the native runtime status when the NIF is loaded."
  def native_runtime_status do
    Guppy.Native.Nif.runtime_status()
  end

  @doc "Returns the native GUI bootstrap status when the NIF is loaded."
  def native_gui_status do
    Guppy.Native.Nif.gui_status()
  end
end
