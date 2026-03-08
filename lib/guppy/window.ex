defmodule Guppy.Window do
  @moduledoc """
  Minimal LiveView-style per-window process abstraction for Guppy.

  Modules that `use Guppy.Window` own one native window per process.
  Guppy opens the window with the module's initial IR, routes native events
  back into the process, and rerenders automatically after window state changes.

  The window struct is the primary state carrier, similar to a socket-like view state.

  Required callbacks:

  - `c:mount/2`
  - `c:render/1`

  Optional callbacks:

  - `c:handle_event/3`
  - `c:handle_info/2`
  """

  @type t :: %__MODULE__{
          view_id: pos_integer() | nil,
          assigns: map(),
          private: map()
        }

  @type callback_result ::
          {:noreply, t()}
          | {:noreply, t(), :skip_render}
          | {:stop, term(), t()}

  defstruct view_id: nil, assigns: %{}, private: %{}

  @callback mount(term(), t()) :: {:ok, t()} | {:stop, term()}
  @callback render(t()) :: term()
  @callback handle_event(String.t(), map(), t()) :: callback_result()
  @callback handle_info(term(), t()) :: callback_result()

  @optional_callbacks handle_event: 3, handle_info: 2

  defmodule State do
    @moduledoc false
    defstruct module: nil, window: nil
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Guppy.Window

      def start_link(arg, opts \\ []) do
        GenServer.start_link(__MODULE__, {:guppy_window, arg}, opts)
      end

      def init({:guppy_window, arg}) do
        Guppy.Window.init_window(__MODULE__, arg)
      end

      def handle_info(message, %Guppy.Window.State{} = state) do
        Guppy.Window.handle_window_message(__MODULE__, message, state)
      end
    end
  end

  def init_window(module, arg) do
    window = %__MODULE__{}

    case module.mount(arg, window) do
      {:ok, window} ->
        ir = module.render(window)

        case Guppy.open_window(ir, self()) do
          {:ok, view_id} ->
            {:ok, %State{module: module, window: %{window | view_id: view_id}}}

          {:error, reason} ->
            {:stop, reason}
        end

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  def handle_window_message(
        module,
        {:guppy_event, view_id, event},
        %State{window: %__MODULE__{view_id: view_id} = window} = state
      )
      when is_map(event) do
    callback_result =
      case event do
        %{type: :window_closed} ->
          {:noreply, window, :skip_render}

        %{callback: callback} when is_binary(callback) ->
          invoke_callback(module, :handle_event, [callback, event_data(event), window])

        _ ->
          {:noreply, window, :skip_render}
      end

    state
    |> apply_callback(callback_result, window_closed?(event))
  end

  def handle_window_message(module, message, state) do
    state
    |> apply_callback(invoke_callback(module, :handle_info, [message, state.window]), false)
  end

  def view_id(server) do
    %State{window: %__MODULE__{view_id: view_id}} = :sys.get_state(server)
    view_id
  end

  def state(server) do
    %State{window: window} = :sys.get_state(server)
    window
  end

  def assign(%__MODULE__{} = window, key, value) when is_atom(key) do
    %{window | assigns: Map.put(window.assigns, key, value)}
  end

  def assign(%__MODULE__{} = window, attrs) when is_list(attrs) or is_map(attrs) do
    Enum.reduce(attrs, window, fn {key, value}, acc -> assign(acc, key, value) end)
  end

  def update(%__MODULE__{} = window, key, fun) when is_atom(key) and is_function(fun, 1) do
    current = Map.get(window.assigns, key)
    assign(window, key, fun.(current))
  end

  def put_private(%__MODULE__{} = window, key, value) when is_atom(key) do
    %{window | private: Map.put(window.private, key, value)}
  end

  defp apply_callback(state, {:noreply, window}, window_closed?) do
    next_state = %{state | window: window}

    if window_closed? do
      {:stop, :normal, next_state}
    else
      rerender(next_state)
    end
  end

  defp apply_callback(state, {:noreply, window, :skip_render}, window_closed?) do
    next_state = %{state | window: window}

    if window_closed? do
      {:stop, :normal, next_state}
    else
      {:noreply, next_state}
    end
  end

  defp apply_callback(state, {:stop, reason, window}, _window_closed?) do
    {:stop, reason, %{state | window: window}}
  end

  defp rerender(%State{window: %__MODULE__{view_id: view_id} = window, module: module} = state) do
    case Guppy.render(view_id, module.render(window)) do
      :ok -> {:noreply, state}
      {:error, :unknown_view_id} -> {:stop, :normal, state}
      {:error, reason} -> {:stop, {:render_failed, reason}, state}
    end
  end

  defp invoke_callback(module, function, args) do
    apply(module, function, args)
  rescue
    error in FunctionClauseError ->
      if error.module == module and error.function == function do
        {:noreply, List.last(args), :skip_render}
      else
        reraise error, __STACKTRACE__
      end
  end

  defp event_data(event) do
    Map.drop(event, [:type, :callback])
  end

  defp window_closed?(%{type: :window_closed}), do: true
  defp window_closed?(_event), do: false
end
