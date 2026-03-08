defmodule Guppy.Window do
  @moduledoc """
  Minimal per-window process abstraction for Guppy.

  Modules that `use Guppy.Window` own one native window per process.
  Guppy opens the window with the module's initial IR, routes native events
  back into the process, and rerenders automatically after state changes.

  Required callbacks:

  - `c:mount/1`
  - `c:render/1`

  Optional callbacks:

  - `c:handle_event/2`
  - `c:handle_message/2`
  """

  @type callback_result(state) ::
          {:noreply, state}
          | {:noreply, state, :skip_render}
          | {:stop, term(), state}

  @callback mount(term()) :: {:ok, term()} | {:stop, term()}
  @callback render(term()) :: term()
  @callback handle_event(map(), term()) :: callback_result(term())
  @callback handle_message(term(), term()) :: callback_result(term())

  @optional_callbacks handle_event: 2, handle_message: 2

  defmodule State do
    @moduledoc false
    defstruct module: nil, view_id: nil, data: nil
  end

  defmacro __using__(_opts) do
    quote do
      use GenServer
      @behaviour Guppy.Window

      def start_link(arg, opts \\ []) do
        GenServer.start_link(__MODULE__, {:guppy_window, arg}, opts)
      end

      @impl true
      def init({:guppy_window, arg}) do
        Guppy.Window.init_window(__MODULE__, arg)
      end

      @impl true
      def handle_info(message, state) do
        Guppy.Window.handle_window_message(__MODULE__, message, state)
      end

      @impl Guppy.Window
      def handle_event(_event, state), do: {:noreply, state, :skip_render}

      @impl Guppy.Window
      def handle_message(_message, state), do: {:noreply, state, :skip_render}

      defoverridable handle_event: 2, handle_message: 2
    end
  end

  def init_window(module, arg) do
    case module.mount(arg) do
      {:ok, data} ->
        ir = module.render(data)

        case Guppy.open_window(ir, self()) do
          {:ok, view_id} ->
            {:ok, %State{module: module, view_id: view_id, data: data}}

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
        %State{view_id: view_id} = state
      )
      when is_map(event) do
    state
    |> apply_callback(
      invoke_callback(module, :handle_event, [event, state.data]),
      window_closed?(event)
    )
  end

  def handle_window_message(module, message, state) do
    state
    |> apply_callback(invoke_callback(module, :handle_message, [message, state.data]), false)
  end

  def view_id(server) do
    %State{view_id: view_id} = :sys.get_state(server)
    view_id
  end

  def state(server) do
    %State{data: data} = :sys.get_state(server)
    data
  end

  defp apply_callback(state, {:noreply, data}, window_closed?) do
    next_state = %{state | data: data}

    if window_closed? do
      {:stop, :normal, next_state}
    else
      rerender(next_state)
    end
  end

  defp apply_callback(state, {:noreply, data, :skip_render}, window_closed?) do
    next_state = %{state | data: data}

    if window_closed? do
      {:stop, :normal, next_state}
    else
      {:noreply, next_state}
    end
  end

  defp apply_callback(state, {:stop, reason, data}, _window_closed?) do
    {:stop, reason, %{state | data: data}}
  end

  defp rerender(%State{view_id: view_id, module: module, data: data} = state) do
    case Guppy.render(view_id, module.render(data)) do
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

  defp window_closed?(%{type: :window_closed}), do: true
  defp window_closed?(_event), do: false
end
