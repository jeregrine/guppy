defmodule GuppyTest do
  use ExUnit.Case

  test "boots the guppy supervision tree" do
    assert Guppy.started?()

    state = Guppy.info()

    assert state.native == Guppy.Native.Nif
    assert state.native_server == Guppy.Native.Nif
    assert state.next_view_id >= 1
    assert is_binary(Guppy.nif_path())
  end

  test "ir validation accepts ids/styles and rejects invalid values" do
    assert :ok = Guppy.IR.validate(Guppy.IR.text("hello", id: "greeting"))
    assert :ok = Guppy.IR.validate(Guppy.IR.text("hello", events: %{click: "open"}))

    assert :ok =
             Guppy.IR.validate(
               Guppy.IR.div(
                 [Guppy.IR.text("hello")],
                 id: "root",
                 style: %{
                   flex: true,
                   flex_col: true,
                   gap_2: true,
                   bg: :gray,
                   border_1: true,
                   border_color: :white
                 }
               )
             )

    assert {:error, {:invalid_id, 123}} = Guppy.IR.validate(Guppy.IR.text("hello", id: 123))

    assert {:error, {:invalid_style, :bogus, true}} =
             Guppy.IR.validate(Guppy.IR.div([], style: %{bogus: true}))
  end

  test "native ping is wired through the server" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        assert {:ok, :pong} = Guppy.ping()
        assert {:ok, "guppy_nif_rust_core"} = Guppy.native_build_info()
        assert {:ok, "started"} = Guppy.native_runtime_status()

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.ping()
    end
  end

  test "window lifecycle, bridge view IR, native event routing, and owner cleanup are tracked" do
    case Guppy.Native.Nif.load_status() do
      :ok ->
        starting_count = native_view_count!()

        {:ok, view_id} = Guppy.open_window()
        on_exit(fn -> maybe_close(view_id) end)

        assert :ok =
                 Guppy.mount(
                   view_id,
                   Guppy.IR.div(
                     [
                       Guppy.IR.text("Hello from IR", id: "greeting"),
                       Guppy.IR.text("Rendered as a nested tree")
                     ],
                     id: "root",
                     style: %{flex: true, flex_col: true, gap_2: true, p_4: true, bg: :gray}
                   )
                 )

        assert :ok =
                 Guppy.update(
                   view_id,
                   Guppy.IR.div([
                     Guppy.IR.text("Hello again from IR"),
                     Guppy.IR.div([
                       Guppy.IR.text("Nested div rerender")
                     ])
                   ])
                 )

        assert :ok =
                 Guppy.update(
                   view_id,
                   Guppy.IR.div(
                     [
                       Guppy.IR.text("Clickable IR tree"),
                       Guppy.IR.text("Simulated click should roundtrip",
                         id: "increment_text",
                         events: %{click: "increment"}
                       )
                     ],
                     id: "increment_button",
                     events: %{click: "increment"}
                   )
                 )

        send(Guppy.server(), {
          :guppy_native_event,
          view_id,
          :click,
          %{id: "increment_text", callback: "increment"}
        })

        assert_receive {:guppy_event, ^view_id,
                        %{type: :click, id: "increment_text", callback: "increment"}}

        assert :ok = Guppy.update_window_text(view_id, "Hello again from Elixir")
        assert Guppy.native_view_count() == {:ok, starting_count + 1}

        send(Guppy.server(), {:guppy_native_event, view_id, :window_closed, :undefined})

        assert_receive {:guppy_event, ^view_id, %{type: :window_closed}}
        refute Map.has_key?(Guppy.info().views, view_id)

        assert :ok =
                 Guppy.Native.Nif.request(Guppy.Native.Nif, {:close_window, [view_id]})

        assert Guppy.native_view_count() == {:ok, starting_count}

        owner = self()
        {:ok, owned_view_id} = Guppy.open_window(owner)
        on_exit(fn -> maybe_close(owned_view_id) end)

        assert Map.get(Guppy.info().views, owned_view_id) == owner

        pid =
          spawn(fn ->
            {:ok, transient_view_id} = Guppy.open_window(self())
            send(owner, {:opened_view, transient_view_id})
            Process.sleep(:infinity)
          end)

        transient_view_id =
          receive do
            {:opened_view, view_id} -> view_id
          after
            1_000 -> flunk("timed out waiting for transient window")
          end

        assert Map.get(Guppy.info().views, transient_view_id) == pid
        assert Guppy.native_view_count() == {:ok, starting_count + 2}

        Process.exit(pid, :kill)
        wait_until(fn -> not Map.has_key?(Guppy.info().views, transient_view_id) end)

        assert Guppy.native_view_count() == {:ok, starting_count + 1}

        :ok = Guppy.close_window(owned_view_id)
        assert Guppy.native_view_count() == {:ok, starting_count}

      {:error, _reason} ->
        assert {:error, :nif_not_loaded} = Guppy.open_window()
    end
  end

  defp native_view_count! do
    case Guppy.native_view_count() do
      {:ok, count} -> count
      other -> flunk("expected native view count, got: #{inspect(other)}")
    end
  end

  defp maybe_close(view_id) do
    case Guppy.close_window(view_id) do
      :ok -> :ok
      {:error, :unknown_view_id} -> :ok
      {:error, :nif_not_loaded} -> :ok
    end
  end

  defp wait_until(fun, timeout \\ 1_000) do
    started_at = System.monotonic_time(:millisecond)
    do_wait_until(fun, timeout, started_at)
  end

  defp do_wait_until(fun, timeout, started_at) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) - started_at > timeout do
        flunk("condition not met within #{timeout}ms")
      else
        Process.sleep(10)
        do_wait_until(fun, timeout, started_at)
      end
    end
  end
end
