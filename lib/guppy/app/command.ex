defmodule Guppy.App.Command do
  @moduledoc """
  Validated app command metadata.

  Commands are app-global. Native menu/keymap events dispatch command ids back to
  the app coordinator, which invokes `c:Guppy.App.handle_command/3`.
  """

  @enforce_keys [:id]
  defstruct id: nil,
            label: nil,
            enabled: true,
            metadata: %{}

  @type t :: %__MODULE__{
          id: String.t(),
          label: String.t() | nil,
          enabled: boolean(),
          metadata: map()
        }

  @supported_keys [:id, :label, :enabled, :metadata]

  @doc false
  def validate(%__MODULE__{} = command), do: validate(Map.from_struct(command))

  def validate(command) when is_list(command), do: command |> Map.new() |> validate()

  def validate(%{id: id} = command) when is_binary(id) and id != "" do
    with :ok <- validate_keys(command),
         {:ok, label} <- validate_label(Map.get(command, :label)),
         {:ok, enabled} <- validate_enabled(Map.get(command, :enabled, true)),
         {:ok, metadata} <- validate_metadata(Map.get(command, :metadata, %{})) do
      {:ok, %__MODULE__{id: id, label: label, enabled: enabled, metadata: metadata}}
    end
  end

  def validate(command), do: {:error, {:invalid_command, command}}

  defp validate_keys(command) do
    case Map.keys(command) -- @supported_keys do
      [] -> :ok
      _ -> {:error, {:invalid_command, command}}
    end
  end

  defp validate_label(nil), do: {:ok, nil}
  defp validate_label(label) when is_binary(label) and label != "", do: {:ok, label}
  defp validate_label(_label), do: {:error, :invalid_command_label}

  defp validate_enabled(value) when is_boolean(value), do: {:ok, value}
  defp validate_enabled(_value), do: {:error, :invalid_command_enabled}

  defp validate_metadata(metadata) when is_map(metadata), do: {:ok, metadata}
  defp validate_metadata(_metadata), do: {:error, :invalid_command_metadata}
end
