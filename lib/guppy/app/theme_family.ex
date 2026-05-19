defmodule Guppy.App.ThemeFamily do
  @moduledoc """
  Validated collection of related themes.

  Theme families are app/user data. They mirror Zed's idea of a named family with
  light/dark variants, but Guppy stores already-validated Elixir theme structs and
  resolves them by stable theme id.
  """

  alias Guppy.App.Theme

  @enforce_keys [:id, :name]
  defstruct id: nil,
            name: nil,
            author: nil,
            themes: %{},
            metadata: %{}

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          author: String.t() | nil,
          themes: %{optional(String.t()) => Theme.t()},
          metadata: map()
        }

  @supported_keys [:id, :name, :author, :themes, :metadata]

  @doc false
  def validate(%__MODULE__{} = family), do: validate(Map.from_struct(family))
  def validate(family) when is_list(family), do: family |> Map.new() |> validate()

  def validate(%{id: id, name: name, themes: themes} = family)
      when is_binary(id) and id != "" and is_binary(name) and name != "" and is_list(themes) do
    with :ok <- validate_keys(family),
         {:ok, author} <- validate_author(Map.get(family, :author)),
         {:ok, themes} <- validate_themes(themes),
         {:ok, metadata} <- validate_metadata(Map.get(family, :metadata, %{})) do
      {:ok, %__MODULE__{id: id, name: name, author: author, themes: themes, metadata: metadata}}
    end
  end

  def validate(family), do: {:error, {:invalid_theme_family, family}}

  @doc "Looks up a validated theme by id within a family."
  @spec get(t(), atom() | String.t()) :: {:ok, Theme.t()} | {:error, term()}
  def get(%__MODULE__{themes: themes}, theme_id) do
    with {:ok, theme_id} <- normalize_id(theme_id) do
      case Map.fetch(themes, theme_id) do
        {:ok, theme} -> {:ok, theme}
        :error -> {:error, {:unknown_theme, theme_id}}
      end
    end
  end

  def get(_family, theme_id), do: {:error, {:invalid_theme_id, theme_id}}

  defp validate_keys(family) do
    case Map.keys(family) -- @supported_keys do
      [] -> :ok
      _ -> {:error, {:invalid_theme_family, family}}
    end
  end

  defp validate_author(nil), do: {:ok, nil}
  defp validate_author(author) when is_binary(author) and author != "", do: {:ok, author}
  defp validate_author(_author), do: {:error, :invalid_theme_family_author}

  defp validate_themes(themes) do
    Enum.reduce_while(themes, {:ok, %{}}, fn theme, {:ok, acc} ->
      with {:ok, theme} <- validate_theme(theme),
           :ok <- validate_unique_theme_id(theme.id, acc) do
        {:cont, {:ok, Map.put(acc, theme.id, theme)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp validate_theme(%Theme{} = theme), do: {:ok, theme}

  defp validate_theme(theme) do
    case Theme.validate(theme) do
      {:ok, %Theme{} = theme} -> {:ok, theme}
      {:error, _reason} -> {:error, {:invalid_theme, theme}}
    end
  end

  defp validate_unique_theme_id(id, themes) do
    if Map.has_key?(themes, id) do
      {:error, {:duplicate_theme_id, id}}
    else
      :ok
    end
  end

  defp validate_metadata(metadata) when is_map(metadata), do: {:ok, metadata}
  defp validate_metadata(_metadata), do: {:error, :invalid_theme_family_metadata}

  defp normalize_id(id) when is_atom(id), do: {:ok, Atom.to_string(id)}
  defp normalize_id(id) when is_binary(id) and id != "", do: {:ok, id}
  defp normalize_id(id), do: {:error, {:invalid_theme_id, id}}
end
