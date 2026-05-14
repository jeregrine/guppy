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

  Missing optional callbacks and unmatched callback clauses are treated as no-op
  handlers that skip rerendering. `use Guppy.Window` also defines `child_spec/1`,
  so window modules can be supervised directly.
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
    defstruct module: nil, window: nil, server_monitor: nil
  end

  defmacro __using__(_opts) do
    quote do
      use Guppy.Component

      @behaviour Guppy.Window

      def child_spec(arg) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [arg]},
          type: :worker,
          restart: :permanent,
          shutdown: 5_000
        }
      end

      defoverridable child_spec: 1

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
        window_options = Map.get(window.private, :window_options, [])

        case Guppy.open_window(ir, window_options) do
          {:ok, view_id} ->
            {:ok,
             %State{
               module: module,
               window: %{window | view_id: view_id},
               server_monitor: monitor_server()
             }}

          {:error, reason} ->
            {:stop, reason}
        end

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  def handle_window_message(
        _module,
        {:DOWN, monitor_ref, :process, _pid, _reason},
        %State{server_monitor: monitor_ref} = state
      ) do
    reopen(state)
  end

  def handle_window_message(_module, :guppy_reopen_after_server_restart, %State{} = state) do
    reopen(state)
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

  def put_private(%__MODULE__{} = window, key, value) when is_atom(key) do
    %{window | private: Map.put(window.private, key, value)}
  end

  def put_window_opts(%__MODULE__{} = window, opts) when is_list(opts) or is_map(opts) do
    current = Map.get(window.private, :window_options, [])

    merged_opts =
      current
      |> Keyword.merge(Keyword.new(opts))

    put_private(window, :window_options, merged_opts)
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

  defp reopen(%State{module: module, window: window, server_monitor: old_monitor} = state) do
    if is_reference(old_monitor) do
      Process.demonitor(old_monitor, [:flush])
    end

    ir = module.render(window)
    window_options = Map.get(window.private, :window_options, [])

    case safe_open_window(ir, window_options) do
      {:ok, view_id} ->
        {:noreply,
         %{state | window: %{window | view_id: view_id}, server_monitor: monitor_server()}}

      {:error, _reason} ->
        Process.send_after(self(), :guppy_reopen_after_server_restart, 50)
        {:noreply, %{state | window: %{window | view_id: nil}, server_monitor: monitor_server()}}
    end
  end

  defp safe_open_window(ir, window_options) do
    Guppy.open_window(ir, window_options)
  catch
    :exit, _reason -> {:error, :server_unavailable}
  end

  defp monitor_server do
    case Guppy.server() do
      pid when is_pid(pid) -> Process.monitor(pid)
      nil -> nil
    end
  end

  defp rerender(%State{window: %__MODULE__{view_id: nil}} = state) do
    {:noreply, state}
  end

  defp rerender(%State{window: %__MODULE__{view_id: view_id} = window, module: module} = state) do
    start_time = System.monotonic_time()
    result = Guppy.render(view_id, module.render(window))
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:guppy, :window, :rerender],
      %{duration: duration},
      %{module: module, view_id: view_id, status: telemetry_status(result)}
    )

    case result do
      :ok -> {:noreply, state}
      {:error, :unknown_view_id} -> {:stop, :normal, state}
      {:error, reason} -> {:stop, {:render_failed, reason}, state}
    end
  end

  defp telemetry_status(:ok), do: :ok
  defp telemetry_status({:error, reason}), do: {:error, reason}
  defp telemetry_status(other), do: other

  defp invoke_callback(module, function, args) do
    apply(module, function, args)
  rescue
    error in FunctionClauseError ->
      if callback_error?(error, module, function, args) do
        {:noreply, List.last(args), :skip_render}
      else
        reraise error, __STACKTRACE__
      end

    error in UndefinedFunctionError ->
      if callback_error?(error, module, function, args) do
        {:noreply, List.last(args), :skip_render}
      else
        reraise error, __STACKTRACE__
      end
  end

  defp callback_error?(error, module, function, args) do
    error.module == module and error.function == function and error.arity == length(args)
  end

  defp event_data(event) do
    Map.drop(event, [:type, :callback])
  end

  defp window_closed?(%{type: :window_closed}), do: true
  defp window_closed?(_event), do: false
end
