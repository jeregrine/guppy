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

  Modules may also define `handle_info(message, window)` without marking it as a
  `Guppy.Window` callback; Guppy routes ordinary process messages there by convention.

  Missing optional handlers and unmatched handler clauses are treated as no-op
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

  @optional_callbacks handle_event: 3

  defmodule State do
    @moduledoc false
    defstruct module: nil,
              window: nil,
              server_monitor: nil,
              app: nil,
              app_window_id: nil,
              reopen_attempts: 0
  end

  @reopen_retry_base_delay_ms 50
  @reopen_retry_max_delay_ms 5_000

  @doc """
  Returns the reopen retry delay for a failed-reopen attempt count.

  Delays double from #{@reopen_retry_base_delay_ms}ms and cap at
  #{@reopen_retry_max_delay_ms}ms so a persistently failing runtime is not
  hammered with reopen attempts.
  """
  def reopen_retry_delay_ms(attempt) when is_integer(attempt) and attempt >= 0 do
    min(@reopen_retry_base_delay_ms * Integer.pow(2, attempt), @reopen_retry_max_delay_ms)
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

      def start_link(arg, opts \\ [])

      def start_link({:guppy_app_window, _app, _window_id, _arg} = arg, opts) do
        GenServer.start_link(__MODULE__, arg, opts)
      end

      def start_link(arg, opts) do
        GenServer.start_link(__MODULE__, {:guppy_window, arg}, opts)
      end

      def init({:guppy_window, arg}) do
        Guppy.Window.init_window(__MODULE__, arg)
      end

      def init({:guppy_app_window, app, window_id, arg}) do
        Guppy.Window.init_window(__MODULE__, arg, app: app, app_window_id: window_id)
      end

      def handle_info(message, %Guppy.Window.State{} = state) do
        Guppy.Window.handle_window_message(__MODULE__, message, state)
      end
    end
  end

  def init_window(module, arg, opts \\ []) do
    app = Keyword.get(opts, :app)
    app_window_id = Keyword.get(opts, :app_window_id)
    put_app_context(app, app_window_id)

    window = %__MODULE__{}

    case module.mount(arg, window) do
      {:ok, window} ->
        ir = render_with_context(module, window, app, app_window_id)
        window_options = Map.get(window.private, :window_options, [])

        case Guppy.open_window(ir, window_options) do
          {:ok, view_id} ->
            {:ok,
             %State{
               module: module,
               window: %{window | view_id: view_id},
               server_monitor: monitor_server(),
               app: app,
               app_window_id: app_window_id
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
        {:guppy_focus_window, _timeout},
        %State{window: %__MODULE__{view_id: nil}} = state
      ) do
    {:noreply, state}
  end

  def handle_window_message(
        _module,
        {:guppy_focus_window, timeout},
        %State{window: %__MODULE__{view_id: view_id}} = state
      ) do
    _ = Guppy.focus_window(view_id, timeout)
    {:noreply, state}
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
    put_app_context(state.app, state.app_window_id)

    callback_result =
      case event do
        %{type: :window_closed} ->
          {:noreply, window, :skip_render}

        %{type: :action, callback: callback, action: command_id}
        when is_binary(callback) and is_binary(command_id) ->
          route_action_event(module, callback, command_id, event, state, window)

        %{callback: callback} when is_binary(callback) ->
          invoke_callback(module, :handle_event, [callback, event_data(event), window])

        %{type: type}
        when type in [:window_focused, :window_blurred, :window_moved, :window_resized] ->
          invoke_callback(module, :handle_event, [Atom.to_string(type), event_data(event), window])

        _ ->
          {:noreply, window, :skip_render}
      end

    state
    |> apply_callback(callback_result, window_closed?(event))
  end

  def handle_window_message(module, message, state) do
    put_app_context(state.app, state.app_window_id)

    state
    |> apply_callback(invoke_callback(module, :handle_info, [message, state.window]), false)
  end

  def view_id(server) do
    %State{window: %__MODULE__{view_id: view_id}} = :sys.get_state(server)
    view_id
  end

  def focus(server, timeout \\ 5_000) do
    send(server, {:guppy_focus_window, timeout})
    :ok
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
    put_app_context(state.app, state.app_window_id)

    if is_reference(old_monitor) do
      Process.demonitor(old_monitor, [:flush])
    end

    ir = render_with_context(module, window, state.app, state.app_window_id)
    window_options = Map.get(window.private, :window_options, [])

    case safe_open_window(ir, window_options) do
      {:ok, view_id} ->
        {:noreply,
         %{
           state
           | window: %{window | view_id: view_id},
             server_monitor: monitor_server(),
             reopen_attempts: 0
         }}

      {:error, _reason} ->
        Process.send_after(
          self(),
          :guppy_reopen_after_server_restart,
          reopen_retry_delay_ms(state.reopen_attempts)
        )

        {:noreply,
         %{
           state
           | window: %{window | view_id: nil},
             server_monitor: monitor_server(),
             reopen_attempts: state.reopen_attempts + 1
         }}
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
    put_app_context(state.app, state.app_window_id)
    start_time = System.monotonic_time()

    result =
      Guppy.render(view_id, render_with_context(module, window, state.app, state.app_window_id))

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

  defp put_app_context(nil, _window_id), do: :ok

  defp put_app_context(app, window_id), do: Guppy.App.put_window_context(app, window_id)

  defp render_with_context(module, window, app, window_id) do
    put_app_context(app, window_id)
    module.render(window)
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

  defp route_action_event(module, callback, command_id, event, state, window) do
    if app_command_action?(callback, state.app) do
      :ok = Guppy.App.dispatch(state.app, command_id, app_command_payload(event, state))
      {:noreply, window, :skip_render}
    else
      invoke_callback(module, :handle_event, [callback, event_data(event), window])
    end
  end

  defp app_command_action?(callback, app) do
    not is_nil(app) and callback == Guppy.App.command_callback()
  end

  defp app_command_payload(event, state) do
    event
    |> event_data()
    |> Map.put_new(:source, :window_shortcut)
    |> maybe_put_window_id(state.app_window_id)
  end

  defp maybe_put_window_id(payload, window_id) when is_binary(window_id),
    do: Map.put(payload, :window_id, window_id)

  defp maybe_put_window_id(payload, _window_id), do: payload

  defp event_data(event) do
    Map.drop(event, [:type, :callback])
  end

  defp window_closed?(%{type: :window_closed}), do: true
  defp window_closed?(_event), do: false
end
