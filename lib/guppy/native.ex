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

  @doc false
  def telemetry_status(:ok), do: :ok
  def telemetry_status({:ok, _payload}), do: :ok
  def telemetry_status({:error, reason}), do: {:error, reason}
  def telemetry_status(other), do: other
end
