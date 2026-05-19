defmodule Guppy.App.Theme do
  @moduledoc """
  App-scoped theme metadata and semantic tokens.

  The first Guppy app theme layer is deliberately data-only. Apps can store an
  active theme, read it from windows, and compile semantic tokens to primitive IR
  styles on the Elixir side.
  """

  @enforce_keys [:id, :name]
  defstruct id: nil,
            name: nil,
            appearance: :system,
            colors: %{},
            styles: %{},
            metadata: %{}

  @type appearance :: :light | :dark | :system

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          appearance: appearance(),
          colors: %{optional(atom() | String.t()) => atom() | String.t()},
          styles: %{optional(atom() | String.t()) => list()},
          metadata: map()
        }

  @supported_keys [:id, :name, :appearance, :colors, :styles, :metadata]
  @appearances [:light, :dark, :system]

  @doc false
  def validate(nil), do: {:ok, nil}
  def validate(%__MODULE__{} = theme), do: validate(Map.from_struct(theme))
  def validate(theme) when is_list(theme), do: theme |> Map.new() |> validate()

  def validate(%{id: id, name: name} = theme)
      when is_binary(id) and id != "" and is_binary(name) and name != "" do
    with :ok <- validate_keys(theme),
         {:ok, appearance} <- validate_appearance(Map.get(theme, :appearance, :system)),
         {:ok, colors} <- validate_map(Map.get(theme, :colors, %{}), :invalid_theme_colors),
         {:ok, styles} <- validate_map(Map.get(theme, :styles, %{}), :invalid_theme_styles),
         {:ok, metadata} <- validate_map(Map.get(theme, :metadata, %{}), :invalid_theme_metadata) do
      {:ok,
       %__MODULE__{
         id: id,
         name: name,
         appearance: appearance,
         colors: colors,
         styles: styles,
         metadata: metadata
       }}
    end
  end

  def validate(theme), do: {:error, {:invalid_theme, theme}}

  defp validate_keys(theme) do
    case Map.keys(theme) -- @supported_keys do
      [] -> :ok
      _ -> {:error, {:invalid_theme, theme}}
    end
  end

  defp validate_appearance(value) when value in @appearances, do: {:ok, value}
  defp validate_appearance(_value), do: {:error, :invalid_theme_appearance}

  defp validate_map(value, _error) when is_map(value), do: {:ok, value}
  defp validate_map(_value, error), do: {:error, error}
end
