defmodule Guppy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    native = Application.get_env(:guppy, :native, Guppy.Native.Nif)

    Supervisor.start_link(
      [{Guppy.Server, native: native, native_server: native}],
      strategy: :one_for_one,
      name: Guppy.Supervisor
    )
  end
end
