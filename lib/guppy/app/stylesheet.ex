defmodule Guppy.App.Stylesheet do
  @moduledoc """
  App-scoped stylesheet cache for reusable class references.

  Stylesheet class names are strings and may contain base styles plus supported
  state variants. Resolution is Elixir-side and returns IR style keyword entries
  (`:style`, `:hover_style`, `:focus_style`, and friends) that can be merged into
  node options.
  """

  require Logger

  @enforce_keys []
  defstruct classes: %{}, metadata: %{}

  @type state_key ::
          :style
          | :hover_style
          | :focus_style
          | :focus_visible_style
          | :in_focus_style
          | :active_style
          | :disabled_style

  @type class_def :: %{optional(state_key()) => list()} | keyword() | String.t() | list()

  @type t :: %__MODULE__{
          classes: %{optional(String.t()) => %{optional(state_key()) => list()}},
          metadata: map()
        }

  @supported_keys [:classes, :metadata]
  @state_keys [
    :style,
    :hover_style,
    :focus_style,
    :focus_visible_style,
    :in_focus_style,
    :active_style,
    :disabled_style
  ]
  @variant_to_key %{
    "hover" => :hover_style,
    "focus" => :focus_style,
    "focus-visible" => :focus_visible_style,
    "in-focus" => :in_focus_style,
    "active" => :active_style,
    "disabled" => :disabled_style
  }

  @doc false
  def validate(nil), do: {:ok, %__MODULE__{}}
  def validate(%__MODULE__{} = stylesheet), do: {:ok, stylesheet}
  def validate(stylesheet) when is_list(stylesheet), do: stylesheet |> Map.new() |> validate()

  def validate(%{} = stylesheet) do
    with :ok <- validate_keys(stylesheet),
         {:ok, classes} <- validate_classes(Map.get(stylesheet, :classes, %{})),
         {:ok, metadata} <- validate_metadata(Map.get(stylesheet, :metadata, %{})) do
      {:ok, %__MODULE__{classes: classes, metadata: metadata}}
    end
  end

  def validate(stylesheet), do: {:error, {:invalid_stylesheet, stylesheet}}

  @doc "Resolves one or more app stylesheet class references to style option entries."
  def resolve(%__MODULE__{} = stylesheet, class_refs) do
    class_refs
    |> normalize_class_refs()
    |> Enum.reduce(%{}, fn class_ref, acc ->
      case resolve_token(stylesheet, class_ref) do
        {:ok, style_map} ->
          merge_style_maps(acc, style_map)

        {:error, reason} ->
          Logger.warning(
            "unknown Guppy app stylesheet class ref #{inspect(class_ref)}: #{inspect(reason)}"
          )

          acc
      end
    end)
    |> Enum.reject(fn {_key, value} -> value == [] end)
  end

  @doc false
  def resolve_token(%__MODULE__{classes: classes}, token) when is_binary(token) do
    case Map.fetch(classes, token) do
      {:ok, style_map} -> {:ok, style_map}
      :error -> parse_variant_token(token)
    end
  end

  def resolve_token(_stylesheet, token), do: {:error, {:invalid_class_ref, token}}

  defp validate_keys(stylesheet) do
    case Map.keys(stylesheet) -- @supported_keys do
      [] -> :ok
      _ -> {:error, {:invalid_stylesheet, stylesheet}}
    end
  end

  defp validate_classes(classes) when is_map(classes) do
    Enum.reduce_while(classes, {:ok, %{}}, fn {name, class_def}, {:ok, acc} ->
      with {:ok, name} <- validate_class_name(name),
           {:ok, style_map} <- validate_class_def(class_def) do
        {:cont, {:ok, Map.put(acc, name, style_map)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp validate_classes(_classes), do: {:error, :invalid_stylesheet_classes}

  defp validate_class_name(name) when is_binary(name) and name != "", do: {:ok, name}
  defp validate_class_name(name), do: {:error, {:invalid_class_name, name}}

  defp validate_class_def(value) when is_binary(value) or is_list(value) do
    value
    |> Guppy.Component.class_to_style!()
    |> then(&{:ok, %{style: &1}})
  rescue
    error in ArgumentError -> {:error, {:invalid_class_style, Exception.message(error)}}
  end

  defp validate_class_def(%{} = value) do
    Enum.reduce_while(value, {:ok, %{}}, fn {key, class_value}, {:ok, acc} ->
      with {:ok, key} <- validate_state_key(key),
           {:ok, styles} <- validate_style_value(class_value) do
        {:cont, {:ok, Map.put(acc, key, styles)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp validate_class_def(value), do: {:error, {:invalid_class_def, value}}

  defp validate_state_key(key) when key in @state_keys, do: {:ok, key}
  defp validate_state_key(key), do: {:error, {:invalid_state_variant, key}}

  defp validate_style_value(value) when is_binary(value) or is_list(value) do
    {:ok, Guppy.Component.class_to_style!(value)}
  rescue
    error in ArgumentError -> {:error, {:invalid_class_style, Exception.message(error)}}
  end

  defp validate_style_value(value), do: {:error, {:invalid_class_style, value}}

  defp validate_metadata(metadata) when is_map(metadata), do: {:ok, metadata}
  defp validate_metadata(_metadata), do: {:error, :invalid_stylesheet_metadata}

  defp normalize_class_refs(nil), do: []
  defp normalize_class_refs(false), do: []

  defp normalize_class_refs(class_refs) when is_binary(class_refs),
    do: String.split(class_refs, ~r/\s+/, trim: true)

  defp normalize_class_refs(class_refs) when is_list(class_refs) do
    Enum.flat_map(class_refs, &normalize_class_refs/1)
  end

  defp normalize_class_refs(_class_refs), do: []

  defp parse_variant_token(token) do
    with [variant, class_token] <- String.split(token, ":", parts: 2),
         {:ok, state_key} <- Map.fetch(@variant_to_key, variant),
         style when is_list(style) <- Guppy.Component.class_to_style!(class_token) do
      {:ok, %{state_key => style}}
    else
      _ -> {:error, {:unknown_class_ref, token}}
    end
  rescue
    _error in ArgumentError -> {:error, {:unknown_class_ref, token}}
  end

  defp merge_style_maps(left, right) do
    Map.merge(left, right, fn _key, old, new -> old ++ new end)
  end
end
