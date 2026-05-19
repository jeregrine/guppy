defmodule Guppy.App.Config do
  @moduledoc """
  Validated configuration for a `Guppy.App` coordinator.

  Configuration is plain Elixir data. `use Guppy.App` may provide defaults and
  an app module may implement `c:Guppy.App.init/1` to return the final config;
  Guppy validates the final shape instead of owning complex merge semantics.
  """

  alias Guppy.App.{Command, Stylesheet, Theme, WindowSpec}

  @enforce_keys [:id]
  defstruct id: nil,
            windows: [],
            theme: nil,
            stylesheet: %Stylesheet{},
            commands: %{},
            keymap: [],
            menus: [],
            exit_on_last_window_closed: false,
            metadata: %{},
            package: %{}

  @type t :: %__MODULE__{
          id: String.t(),
          windows: [WindowSpec.t()],
          theme: Theme.t() | nil,
          stylesheet: Stylesheet.t(),
          commands: %{optional(String.t()) => Command.t()},
          keymap: [map()],
          menus: [map()],
          exit_on_last_window_closed: boolean(),
          metadata: map(),
          package: map()
        }

  @supported_keys [
    :id,
    :windows,
    :theme,
    :stylesheet,
    :commands,
    :keymap,
    :menus,
    :exit_on_last_window_closed,
    :metadata,
    :package
  ]

  @doc false
  def validate(config, app_module \\ nil)

  def validate(%__MODULE__{} = config, app_module),
    do: validate(Map.from_struct(config), app_module)

  def validate(config, app_module) when is_list(config),
    do: config |> Map.new() |> validate(app_module)

  def validate(%{} = config, app_module) do
    with :ok <- validate_keys(config),
         {:ok, id} <- validate_id(Map.get(config, :id, default_id(app_module))),
         {:ok, windows} <- validate_windows(Map.get(config, :windows, [])),
         {:ok, theme} <- Theme.validate(Map.get(config, :theme)),
         {:ok, stylesheet} <- Stylesheet.validate(Map.get(config, :stylesheet)),
         {:ok, commands} <- validate_commands(Map.get(config, :commands, %{})),
         {:ok, keymap} <- validate_keymap(Map.get(config, :keymap, []), commands),
         {:ok, menus} <- validate_list(Map.get(config, :menus, []), :invalid_menus),
         {:ok, exit_on_last_window_closed} <-
           validate_boolean(
             Map.get(config, :exit_on_last_window_closed, false),
             :invalid_exit_on_last_window_closed
           ),
         {:ok, metadata} <- validate_map(Map.get(config, :metadata, %{}), :invalid_app_metadata),
         {:ok, package} <- validate_map(Map.get(config, :package, %{}), :invalid_package_metadata) do
      {:ok,
       %__MODULE__{
         id: id,
         windows: windows,
         theme: theme,
         stylesheet: stylesheet,
         commands: commands,
         keymap: keymap,
         menus: menus,
         exit_on_last_window_closed: exit_on_last_window_closed,
         metadata: metadata,
         package: package
       }}
    end
  end

  def validate(config, _app_module), do: {:error, {:invalid_app_config, config}}

  defp default_id(nil), do: "guppy_app"
  defp default_id(module), do: module |> Module.split() |> Enum.join(".")

  defp validate_keys(config) do
    case Map.keys(config) -- @supported_keys do
      [] -> :ok
      _ -> {:error, {:invalid_app_config, config}}
    end
  end

  defp validate_id(id) when is_binary(id) and id != "", do: {:ok, id}
  defp validate_id(id), do: {:error, {:invalid_app_id, id}}

  defp validate_windows(windows) when is_list(windows) do
    windows
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, [], MapSet.new()}, fn {spec, index}, {:ok, acc, ids} ->
      default_start = index == 0

      with {:ok, spec} <- WindowSpec.validate(spec, default_start),
           :ok <- validate_unique_window_id(spec.id, ids) do
        {:cont, {:ok, [spec | acc], MapSet.put(ids, spec.id)}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, specs, _ids} -> {:ok, Enum.reverse(specs)}
      error -> error
    end
  end

  defp validate_windows(_windows), do: {:error, :invalid_windows}

  defp validate_unique_window_id(id, ids) do
    if MapSet.member?(ids, id) do
      {:error, {:duplicate_window_id, id}}
    else
      :ok
    end
  end

  defp validate_commands(commands) when is_map(commands) do
    commands
    |> Enum.map(fn
      {id, command} when is_binary(id) and is_map(command) ->
        Map.put(command, :id, Map.get(command, :id, id))

      {_id, %Command{} = command} ->
        command

      {id, label} when is_binary(id) and is_binary(label) ->
        %{id: id, label: label}

      {_id, command} ->
        command
    end)
    |> validate_commands()
  end

  defp validate_commands(commands) when is_list(commands) do
    Enum.reduce_while(commands, {:ok, %{}}, fn command, {:ok, acc} ->
      with {:ok, command} <- Command.validate(command),
           :ok <- validate_unique_command_id(command.id, acc) do
        {:cont, {:ok, Map.put(acc, command.id, command)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp validate_commands(_commands), do: {:error, :invalid_commands}

  defp validate_unique_command_id(id, commands) do
    if Map.has_key?(commands, id) do
      {:error, {:duplicate_command_id, id}}
    else
      :ok
    end
  end

  defp validate_keymap(keymap, commands) when is_list(keymap) do
    Enum.reduce_while(keymap, {:ok, []}, fn entry, {:ok, acc} ->
      case validate_keymap_entry(entry, commands) do
        {:ok, entry} -> {:cont, {:ok, [entry | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  defp validate_keymap(_keymap, _commands), do: {:error, :invalid_keymap}

  defp validate_keymap_entry(entry, commands) when is_list(entry),
    do: entry |> Map.new() |> validate_keymap_entry(commands)

  defp validate_keymap_entry(%{key: key, command: command} = entry, commands)
       when is_binary(key) and key != "" and is_binary(command) and command != "" do
    cond do
      Map.keys(entry) -- [:key, :command, :when] != [] ->
        {:error, {:invalid_keymap_entry, entry}}

      not Map.has_key?(commands, command) ->
        {:error, {:unknown_command, command}}

      true ->
        {:ok, entry}
    end
  end

  defp validate_keymap_entry(entry, _commands), do: {:error, {:invalid_keymap_entry, entry}}

  defp validate_list(value, _error) when is_list(value), do: {:ok, value}
  defp validate_list(_value, error), do: {:error, error}

  defp validate_boolean(value, _error) when is_boolean(value), do: {:ok, value}
  defp validate_boolean(_value, error), do: {:error, error}

  defp validate_map(value, _error) when is_map(value), do: {:ok, value}
  defp validate_map(_value, error), do: {:error, error}
end
