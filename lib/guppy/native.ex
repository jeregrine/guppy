defmodule Guppy.Native do
  @moduledoc """
  Behaviour for the native GPUI bridge.

  The default production direction is an in-VM NIF, following wx's overall
  integration model while keeping Guppy's own API and render architecture.
  """

  @type command :: term()
  @type response :: {:ok, term()} | {:error, term()}

  @callback request(GenServer.server(), command(), timeout()) :: response()
  @callback cast(GenServer.server(), command()) :: :ok
  @callback connected?(GenServer.server()) :: boolean()
end
