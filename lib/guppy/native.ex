defmodule Guppy.Native do
  @moduledoc """
  Behaviour for the native GPUI bridge.

  The default production direction is an in-VM NIF, following wx's overall
  integration model while keeping Guppy's own API and render architecture.
  """

  @type command :: term()
  @type response :: {:ok, term()} | {:error, term()}

  @doc """
  Performs a native request.

  Implementations own timeout enforcement: `request/3` must return within the
  given timeout (returning `{:error, :native_timeout}` when the underlying
  work cannot complete in time) rather than blocking the caller indefinitely.
  The NIF implementation bounds every request with a deadline-aware wait.
  """
  @callback request(GenServer.server(), command(), timeout()) :: response()

  @doc false
  def telemetry_status(:ok), do: :ok
  def telemetry_status({:ok, _payload}), do: :ok
  def telemetry_status({:error, reason}), do: {:error, reason}
  def telemetry_status(other), do: other
end
