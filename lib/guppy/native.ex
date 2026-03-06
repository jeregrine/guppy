defmodule Guppy.Native do
  @moduledoc """
  Behaviour for the native GPUI bridge.

  The default production direction is an in-VM NIF, following wx's overall
  integration model while keeping Guppy's own API and render architecture.
  """

  @type command :: term()
  @type response :: {:ok, term()} | {:error, term()}

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback request(GenServer.server(), command(), timeout()) :: response()
  @callback cast(GenServer.server(), command()) :: :ok
  @callback connected?(GenServer.server()) :: boolean()
end
