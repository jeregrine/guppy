defmodule Guppy.App.WindowSpec do
  @moduledoc """
  Validated app-owned window configuration.

  App window ids are strings. A window spec points at a `Guppy.Window`
  module and the mount argument/options used when the app opens it.
  """

  @enforce_keys [:id, :module]
  defstruct id: nil,
            module: nil,
            arg: nil,
            opts: [],
            start: false,
            restart: :temporary,
            metadata: %{}

  @type t :: %__MODULE__{
          id: String.t(),
          module: module(),
          arg: term(),
          opts: keyword(),
          start: boolean(),
          restart: :temporary | :transient | :permanent,
          metadata: map()
        }

  @supported_keys [:id, :module, :arg, :opts, :start, :restart, :metadata]
  @restart_values [:temporary, :transient, :permanent]

  @doc false
  def validate(spec, default_start \\ false)

  def validate(%__MODULE__{} = spec, _default_start) do
    validate(Map.from_struct(spec), false)
  end

  def validate(spec, default_start) when is_list(spec) do
    spec
    |> Map.new()
    |> validate(default_start)
  end

  def validate(%{id: id, module: module} = spec, default_start)
      when is_binary(id) and id != "" and is_atom(module) do
    with :ok <- validate_keys(spec),
         {:ok, opts} <- validate_opts(Map.get(spec, :opts, [])),
         {:ok, start} <- validate_start(Map.get(spec, :start, default_start)),
         {:ok, restart} <- validate_restart(Map.get(spec, :restart, :temporary)),
         {:ok, metadata} <- validate_metadata(Map.get(spec, :metadata, %{})) do
      {:ok,
       %__MODULE__{
         id: id,
         module: module,
         arg: Map.get(spec, :arg),
         opts: opts,
         start: start,
         restart: restart,
         metadata: metadata
       }}
    end
  end

  def validate(spec, _default_start), do: {:error, {:invalid_window_spec, spec}}

  defp validate_keys(spec) do
    case Map.keys(spec) -- @supported_keys do
      [] -> :ok
      _ -> {:error, {:invalid_window_spec, spec}}
    end
  end

  defp validate_opts(opts) when is_list(opts), do: {:ok, opts}
  defp validate_opts(opts) when is_map(opts), do: {:ok, Map.to_list(opts)}
  defp validate_opts(_opts), do: {:error, :invalid_window_options}

  defp validate_start(value) when is_boolean(value), do: {:ok, value}
  defp validate_start(_value), do: {:error, :invalid_window_start}

  defp validate_restart(value) when value in @restart_values, do: {:ok, value}
  defp validate_restart(_value), do: {:error, :invalid_window_restart}

  defp validate_metadata(metadata) when is_map(metadata), do: {:ok, metadata}
  defp validate_metadata(_metadata), do: {:error, :invalid_window_metadata}
end
