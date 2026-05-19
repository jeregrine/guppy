defmodule Guppy.App.Theme do
  @moduledoc """
  App-scoped theme metadata and semantic tokens.

  Themes are plain Elixir data. They validate semantic color tokens and resolve
  style definitions to canonical primitive IR style tuples before native render.
  """

  @catalog_path Path.expand("../../../data/gpui_style_catalog.json", __DIR__)
  @external_resource @catalog_path
  @catalog @catalog_path |> File.read!() |> JSON.decode!()
  @named_color_tokens @catalog["color_tokens"] |> Enum.map(&String.to_atom/1) |> MapSet.new()

  @enforce_keys [:id, :name]
  defstruct id: nil,
            name: nil,
            appearance: :system,
            colors: %{},
            styles: %{},
            metadata: %{}

  @type appearance :: :light | :dark | :system
  @type color_value :: atom() | String.t()
  @type color_role ::
          :bg
          | :text_color
          | :text_bg
          | :border_color
          | :text_decoration_color
          | :strikethrough_color

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          appearance: appearance(),
          colors: %{optional(String.t()) => color_value()},
          styles: %{optional(String.t()) => list()},
          metadata: map()
        }

  @supported_keys [:id, :name, :appearance, :colors, :styles, :metadata]
  @appearances [:light, :dark, :system]
  @hex_color_pattern ~r/^#?[0-9A-Fa-f]{6}$/

  @theme_color_roles %{
    bg: {:bg, :bg_hex},
    text_color: {:text_color, :text_color_hex},
    text_bg: {:text_bg, :text_bg_hex},
    border_color: {:border_color, :border_color_hex},
    text_decoration_color: {:text_decoration_color, :text_decoration_color_hex},
    strikethrough_color: {:strikethrough_color, :strikethrough_color_hex}
  }

  @dark_theme %{
    id: "guppy.dark",
    name: "Guppy Dark",
    appearance: :dark,
    colors: %{
      background: "#0f172a",
      surface: "#1e293b",
      elevated_surface: "#334155",
      text: "#f8fafc",
      text_muted: "#cbd5e1",
      border: "#475569",
      accent: "#2563eb"
    },
    styles: %{
      window: [
        {:theme_color, :bg, :background},
        {:theme_color, :text_color, :text}
      ],
      card: [
        "rounded-lg border-1 p-4",
        {:theme_color, :bg, :surface},
        {:theme_color, :border_color, :border},
        {:theme_color, :text_color, :text}
      ]
    }
  }

  @light_theme %{
    id: "guppy.light",
    name: "Guppy Light",
    appearance: :light,
    colors: %{
      background: "#ffffff",
      surface: "#f8fafc",
      elevated_surface: "#e2e8f0",
      text: "#0f172a",
      text_muted: "#475569",
      border: "#cbd5e1",
      accent: "#2563eb"
    },
    styles: %{
      window: [
        {:theme_color, :bg, :background},
        {:theme_color, :text_color, :text}
      ],
      card: [
        "rounded-lg border-1 p-4",
        {:theme_color, :bg, :surface},
        {:theme_color, :border_color, :border},
        {:theme_color, :text_color, :text}
      ]
    }
  }

  @doc "Returns one of Guppy's built-in default themes."
  @spec default(:dark | :light) :: t()
  def default(:dark), do: validate_default!(@dark_theme)
  def default(:light), do: validate_default!(@light_theme)

  @doc false
  def validate(nil), do: {:ok, nil}
  def validate(%__MODULE__{} = theme), do: validate(Map.from_struct(theme))
  def validate(theme) when is_list(theme), do: theme |> Map.new() |> validate()

  def validate(%{id: id, name: name} = theme)
      when is_binary(id) and id != "" and is_binary(name) and name != "" do
    with :ok <- validate_keys(theme),
         {:ok, appearance} <- validate_appearance(Map.get(theme, :appearance, :system)),
         {:ok, colors} <- validate_colors(Map.get(theme, :colors, %{})),
         {:ok, styles} <- validate_styles(Map.get(theme, :styles, %{}), colors),
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

  @doc "Looks up a semantic color token in a validated theme."
  @spec color(t(), atom() | String.t()) :: {:ok, color_value()} | {:error, term()}
  def color(%__MODULE__{colors: colors}, token) do
    with {:ok, key} <- normalize_token_key(token),
         {:ok, value} <- fetch_theme_color(colors, key) do
      {:ok, value}
    end
  end

  def color(_theme, token), do: {:error, {:invalid_theme_color_token, token}}

  @doc "Looks up a resolved semantic style token in a validated theme."
  @spec style(t(), atom() | String.t()) :: {:ok, list()} | {:error, term()}
  def style(%__MODULE__{styles: styles}, token) do
    with {:ok, key} <- normalize_token_key(token) do
      case Map.fetch(styles, key) do
        {:ok, style} -> {:ok, style}
        :error -> {:error, {:unknown_theme_style, key}}
      end
    end
  end

  def style(_theme, token), do: {:error, {:invalid_theme_style_token, token}}

  @doc "Returns a theme color reference for use inside theme style definitions."
  @spec color_ref(color_role(), atom() | String.t()) ::
          {:theme_color, color_role(), atom() | String.t()}
  def color_ref(role, token), do: {:theme_color, role, token}

  defp validate_default!(theme) do
    {:ok, theme} = validate(theme)
    theme
  end

  defp validate_keys(theme) do
    case Map.keys(theme) -- @supported_keys do
      [] -> :ok
      _ -> {:error, {:invalid_theme, theme}}
    end
  end

  defp validate_appearance(value) when value in @appearances, do: {:ok, value}
  defp validate_appearance(_value), do: {:error, :invalid_theme_appearance}

  defp validate_colors(colors) when is_map(colors) do
    Enum.reduce_while(colors, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case normalize_token_key(key) do
        {:ok, key} ->
          case validate_color_value(value) do
            {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
            :error -> {:halt, {:error, {:invalid_theme_color, {key, value}}}}
          end

        {:error, _reason} ->
          {:halt, {:error, {:invalid_theme_color, {key, value}}}}
      end
    end)
  end

  defp validate_colors(_colors), do: {:error, :invalid_theme_colors}

  defp validate_color_value(value) when is_atom(value) do
    if MapSet.member?(@named_color_tokens, value) do
      {:ok, value}
    else
      :error
    end
  end

  defp validate_color_value(value) when is_binary(value) do
    if Regex.match?(@hex_color_pattern, value) do
      {:ok, value}
    else
      :error
    end
  end

  defp validate_color_value(_value), do: :error

  defp validate_styles(styles, colors) when is_map(styles) do
    Enum.reduce_while(styles, {:ok, %{}}, fn {key, style_def}, {:ok, acc} ->
      with {:ok, key} <- normalize_token_key(key),
           {:ok, style} <- normalize_style_def(style_def, colors),
           :ok <- validate_ir_style(style) do
        {:cont, {:ok, Map.put(acc, key, style)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
        _error -> {:halt, {:error, {:invalid_theme_style, {key, style_def}}}}
      end
    end)
  end

  defp validate_styles(_styles, _colors), do: {:error, :invalid_theme_styles}

  defp normalize_style_def(style_def, _colors) when is_binary(style_def) do
    {:ok, Guppy.Component.class_to_style!(style_def)}
  rescue
    error in ArgumentError -> {:error, {:invalid_theme_style, Exception.message(error)}}
  end

  defp normalize_style_def(style_def, colors) when is_list(style_def) do
    Enum.reduce_while(style_def, {:ok, []}, fn item, {:ok, acc} ->
      case normalize_style_item(item, colors) do
        {:ok, style} -> {:cont, {:ok, acc ++ List.wrap(style)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_style_def(style_def, _colors), do: {:error, {:invalid_theme_style, style_def}}

  defp normalize_style_item(nil, _colors), do: {:ok, []}
  defp normalize_style_item(false, _colors), do: {:ok, []}

  defp normalize_style_item(class_tokens, _colors) when is_binary(class_tokens) do
    {:ok, Guppy.Component.class_to_style!(class_tokens)}
  rescue
    error in ArgumentError -> {:error, {:invalid_theme_style, Exception.message(error)}}
  end

  defp normalize_style_item({:theme_color, role, token}, colors),
    do: resolve_theme_color_style(colors, role, token)

  defp normalize_style_item(style_tuple, _colors) when is_tuple(style_tuple),
    do: {:ok, style_tuple}

  defp normalize_style_item(style_item, _colors), do: {:error, {:invalid_theme_style, style_item}}

  defp resolve_theme_color_style(colors, role, token) do
    with {:ok, {named_role, hex_role}} <- fetch_theme_color_role(role),
         {:ok, key} <- normalize_token_key(token),
         {:ok, value} <- fetch_theme_color(colors, key) do
      case value do
        value when is_atom(value) -> {:ok, {named_role, value}}
        value when is_binary(value) -> {:ok, {hex_role, value}}
      end
    end
  end

  defp fetch_theme_color_role(role) do
    case Map.fetch(@theme_color_roles, role) do
      {:ok, role_ops} -> {:ok, role_ops}
      :error -> {:error, {:invalid_theme_color_role, role}}
    end
  end

  defp fetch_theme_color(colors, key) do
    case Map.fetch(colors, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:unknown_theme_color, key}}
    end
  end

  defp validate_ir_style(style) do
    case Guppy.IR.validate(Guppy.IR.div([], style: style)) do
      :ok -> :ok
      {:error, reason} -> {:error, {:invalid_theme_style, reason}}
    end
  end

  defp normalize_token_key(key) when is_atom(key), do: {:ok, Atom.to_string(key)}
  defp normalize_token_key(key) when is_binary(key) and key != "", do: {:ok, key}
  defp normalize_token_key(key), do: {:error, {:invalid_theme_token, key}}

  defp validate_map(value, _error) when is_map(value), do: {:ok, value}
  defp validate_map(_value, error), do: {:error, error}
end
