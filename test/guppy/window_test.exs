defmodule Guppy.DefaultCallbackWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(:ok, window), do: {:ok, window}

  @impl Guppy.Window
  def render(_window), do: Guppy.IR.text("default callback window")
end

defmodule Guppy.LifecycleCallbackWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(:ok, window), do: {:ok, window}

  @impl Guppy.Window
  def render(_window), do: Guppy.IR.text("lifecycle callback window")

  @impl Guppy.Window
  def handle_event(name, event_data, window) when name in ["window_focused", "window_resized"] do
    {:noreply, assign(window, :last_lifecycle, {name, event_data}), :skip_render}
  end
end

defmodule Guppy.WindowTest do
  use ExUnit.Case

  import Guppy.TestSupport

  test "Guppy.Window exposes HEEx-style assign and update helpers" do
    functions = Guppy.Window.__info__(:functions)

    assert {:assign, 2} in functions
    assert {:assign, 3} in functions
    assert {:update, 3} in functions

    window = %Guppy.Window{assigns: %{count: 1}}

    assert %{assigns: %{count: 2}} = Guppy.Window.update(window, :count, &(&1 + 1))
  end

  test "Guppy.Window modules expose a supervisor child spec" do
    assert %{
             id: Guppy.DefaultCallbackWindow,
             start: {Guppy.DefaultCallbackWindow, :start_link, [:ok]},
             type: :worker,
             restart: :permanent,
             shutdown: 5_000
           } = Guppy.DefaultCallbackWindow.child_spec(:ok)
  end

  test "Guppy.Window treats handle_info as an implicit message convention" do
    refute {:handle_info, 2} in Guppy.Window.behaviour_info(:callbacks)
    refute {:handle_info, 2} in Guppy.Window.behaviour_info(:optional_callbacks)
  end

  test "Guppy.Window default optional callbacks ignore unmatched events and messages" do
    state = %Guppy.Window.State{
      module: Guppy.DefaultCallbackWindow,
      window: %Guppy.Window{view_id: 123, assigns: %{mounted: true}},
      server_monitor: nil
    }

    assert {:noreply, event_state} =
             Guppy.Window.handle_window_message(
               Guppy.DefaultCallbackWindow,
               {:guppy_event, 123, %{type: :click, callback: "missing"}},
               state
             )

    assert event_state.window.assigns == %{mounted: true}

    assert {:noreply, message_state} =
             Guppy.Window.handle_window_message(Guppy.DefaultCallbackWindow, :ignored, state)

    assert message_state.window.assigns == %{mounted: true}
  end

  test "Guppy.Window routes window lifecycle events to handle_event by type name" do
    state = %Guppy.Window.State{
      module: Guppy.LifecycleCallbackWindow,
      window: %Guppy.Window{view_id: 123, assigns: %{}},
      server_monitor: nil
    }

    assert {:noreply, next_state} =
             Guppy.Window.handle_window_message(
               Guppy.LifecycleCallbackWindow,
               {:guppy_event, 123, %{type: :window_resized, width: 800.0, height: 600.0}},
               state
             )

    assert next_state.window.assigns.last_lifecycle ==
             {"window_resized", %{width: 800.0, height: 600.0}}
  end

  test "Guppy.Window skips rerender while reopen retry has no native view" do
    state = %Guppy.Window.State{
      module: Guppy.TestCounterWindow,
      window: %Guppy.Window{view_id: nil, assigns: %{count: 0}},
      server_monitor: nil
    }

    assert {:noreply, next_state} =
             Guppy.Window.handle_window_message(Guppy.TestCounterWindow, {:set_count, 7}, state)

    assert %Guppy.Window{view_id: nil, assigns: %{count: 7}} = next_state.window
  end

  test "Guppy.Window reopens after Guppy.Server restarts" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        {:ok, pid} = Guppy.TestCounterWindow.start_link(0)
        original_server = Guppy.server()
        assert is_pid(original_server)

        Process.exit(original_server, :kill)

        wait_until(fn ->
          server = Guppy.server()
          is_pid(server) and server != original_server and Map.has_key?(Guppy.info().owners, pid)
        end)

        assert Process.alive?(pid)
        assert %Guppy.Window{view_id: view_id, assigns: %{count: 0}} = Guppy.Window.state(pid)
        assert is_integer(view_id)
        assert Map.get(Guppy.info().views, view_id) == pid

        send(Guppy.server(), {:guppy_native_event, view_id, :window_closed, :undefined})
        wait_until(fn -> not Process.alive?(pid) end)

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.TestCounterWindow.start_link(0)
    end
  end

  test "Guppy.Window.focus routes focus through the owning window process" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        {:ok, pid} = Guppy.TestCounterWindow.start_link(0)
        on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)

        assert :ok = Guppy.Window.focus(pid)

      {:error, _reason} ->
        :ok
    end
  end

  test "Guppy.Window owns a window process and rerenders from events/messages" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        starting_count = native_view_count!()
        {:ok, pid} = Guppy.TestCounterWindow.start_link(0)
        on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)

        view_id = Guppy.Window.view_id(pid)
        assert Guppy.Window.state(pid).assigns.count == 0
        assert Map.get(Guppy.info().views, view_id) == pid
        assert Guppy.native_view_count() == {:ok, starting_count + 1}

        handler_id = {__MODULE__, self(), :window_rerender_telemetry}
        :ok = attach_forwarding_telemetry(handler_id, [:guppy, :window, :rerender])
        on_exit(fn -> :telemetry.detach(handler_id) end)

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :click,
          %{id: "increment_button", callback: "increment"}
        })

        wait_until(fn -> Guppy.Window.state(pid).assigns.count == 1 end)

        assert_receive {:telemetry_event, [:guppy, :window, :rerender], %{duration: duration},
                        %{module: Guppy.TestCounterWindow, view_id: ^view_id, status: :ok}}

        assert is_integer(duration)

        send(pid, {:set_count, 5})
        wait_until(fn -> Guppy.Window.state(pid).assigns.count == 5 end)

        send(Guppy.server(), {:guppy_native_event, view_id, :window_closed, :undefined})
        wait_until(fn -> not Process.alive?(pid) end)
        refute Map.has_key?(Guppy.info().views, view_id)

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.TestCounterWindow.start_link(0)
    end
  end
end
