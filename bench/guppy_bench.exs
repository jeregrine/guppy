defmodule Guppy.Bench.Template do
  use Guppy.Component

  def render(assigns) do
    ~GUI"""
    <div id="bench_root" class="flex flex-col gap-1 p-2">
      <div :for={item <- @items} id={"bench_item_#{item}"} class="p-1 border-1 border-gray">
        <text>{"Item #{item}"}</text>
      </div>
    </div>
    """
  end
end

defmodule Guppy.Bench.Telemetry do
  @moduledoc false

  def forward_window_rerender(_event, _measurements, metadata, parent) do
    send(parent, {:bench_rerender, metadata.view_id, metadata.status})
  end
end

defmodule Guppy.Bench.CounterWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(_arg, window) do
    {:ok,
     window
     |> put_window_opts(show: false)
     |> assign(:count, 0)}
  end

  @impl Guppy.Window
  def render(window) do
    Guppy.IR.div(
      [Guppy.IR.text("count = #{window.assigns.count}", id: "bench_counter_label")],
      id: "bench_counter_button",
      events: %{click: "increment"}
    )
  end

  @impl Guppy.Window
  def handle_event("increment", _event, window) do
    {:noreply, update(window, :count, &(&1 + 1))}
  end
end

defmodule Guppy.Bench do
  @moduledoc false

  def main(args) do
    include_native? = "--native" in args

    IO.puts("# Guppy benchmark snapshot")
    IO.puts("# elixir=#{System.version()} otp=#{System.otp_release()} native=#{include_native?}")
    IO.puts("")

    Benchee.run(static_scenarios(), benchee_opts())

    if include_native? do
      native_event_to_rerender_latency()
      native_render_latency()
    else
      IO.puts(
        "skip native event/rerender and render/request latency; rerun with --native to open a hidden GPUI window"
      )
    end
  end

  defp static_scenarios do
    node_scenarios =
      [10, 100, 1_000]
      |> Enum.flat_map(fn count ->
        items = Enum.to_list(1..count)
        ir = tree(count)

        [
          {"~GUI template render #{count} nodes",
           fn ->
             Guppy.Bench.Template.render(%{items: items})
           end},
          {"IR validation #{count} nodes",
           fn ->
             :ok = Guppy.IR.validate(ir)
           end},
          {"ETF encode/decode proxy #{count} nodes",
           fn ->
             ir |> :erlang.term_to_binary() |> :erlang.binary_to_term()
           end}
        ]
      end)

    kanban = kanban_tree(columns: 4, cards: 40)

    kanban_scenarios = [
      {"kanban initial render tree build",
       fn ->
         kanban_tree(columns: 4, cards: 40)
       end},
      {"kanban add card tree build",
       fn ->
         add_kanban_card(kanban)
       end},
      {"kanban move card tree build",
       fn ->
         move_kanban_card(kanban)
       end},
      {"kanban edit card tree build",
       fn ->
         edit_kanban_card(kanban)
       end},
      {"kanban scroll interaction tree build",
       fn ->
         kanban_tree(columns: 4, cards: 40, active_scroll_card: {1, 20})
       end},
      {"event-to-rerender proxy latency",
       fn ->
         :change
         |> event_payload()
         |> apply_event_to_kanban(kanban)
       end},
      {"high-frequency event pressure: mouse_move payload encode",
       fn ->
         :mouse_move |> event_payload() |> :erlang.term_to_binary()
       end},
      {"high-frequency event pressure: drag_move payload encode",
       fn ->
         :drag_move |> event_payload() |> :erlang.term_to_binary()
       end},
      {"high-frequency event pressure: scroll_wheel payload encode",
       fn ->
         :scroll_wheel |> event_payload() |> :erlang.term_to_binary()
       end}
    ]

    Map.new(node_scenarios ++ kanban_scenarios)
  end

  defp benchee_opts do
    [
      time: 1,
      warmup: 0.2,
      memory_time: 0,
      reduction_time: 0,
      percentiles: [50, 95, 99],
      print: [fast_warning: false]
    ]
  end

  defp tree(count) do
    children =
      for index <- 1..count do
        Guppy.IR.div(
          [Guppy.IR.text("Item #{index}", id: "bench_text_#{index}")],
          id: "bench_item_#{index}",
          style: [:p_1, :border_1, {:border_color, :gray}]
        )
      end

    Guppy.IR.div(children, id: "bench_root", style: [:flex, :flex_col, :gap_1])
  end

  defp kanban_tree(opts) do
    column_count = Keyword.fetch!(opts, :columns)
    card_count = Keyword.fetch!(opts, :cards)
    active_scroll_card = Keyword.get(opts, :active_scroll_card)

    columns =
      for column <- 1..column_count do
        cards =
          for card <- 1..card_count do
            active_scroll_card? = active_scroll_card == {column, card}

            Guppy.IR.div(
              [
                Guppy.IR.text("Card #{column}.#{card}", id: "card_title_#{column}_#{card}"),
                Guppy.IR.text_input("",
                  id: "card_edit_#{column}_#{card}",
                  placeholder: "Edit card"
                )
              ],
              id: "card_#{column}_#{card}",
              style: kanban_card_style(active_scroll_card?),
              events: %{drag_move: "move_card", scroll_wheel: "scroll_card"},
              track_scroll: true,
              anchor_scroll: active_scroll_card?
            )
          end

        Guppy.IR.scroll(cards, id: "column_scroll_#{column}", axis: :y, style: [:flex_1])
      end

    Guppy.IR.div(columns, id: "kanban", style: [:flex, :flex_row, :gap_4])
  end

  defp kanban_card_style(false), do: [:p_2, :rounded_md, :border_1]
  defp kanban_card_style(true), do: [:p_2, :rounded_md, :border_1, {:border_color, :blue}]

  defp add_kanban_card(kanban) do
    update_in(kanban, [:children, Access.at(0), :children], fn cards ->
      cards ++ [Guppy.IR.text("New card", id: "new_card")]
    end)
  end

  defp move_kanban_card(kanban) do
    [first | rest] = get_in(kanban, [:children, Access.at(0), :children])

    kanban
    |> put_in([:children, Access.at(0), :children], rest)
    |> update_in([:children, Access.at(1), :children], fn cards -> [first | cards] end)
  end

  defp edit_kanban_card(kanban) do
    put_in(
      kanban,
      [:children, Access.at(0), :children, Access.at(0), :children, Access.at(0), :content],
      "Edited card"
    )
  end

  defp apply_event_to_kanban(_event, kanban), do: edit_kanban_card(kanban)

  defp event_payload(kind) do
    %{
      id: "card_1_1",
      callback: Atom.to_string(kind),
      x: 120.0,
      y: 240.0,
      modifiers: %{control: false, alt: false, shift: false, platform: false, function: false}
    }
  end

  defp native_event_to_rerender_latency do
    Benchee.run(
      %{
        "Guppy.Window routed event-to-rerender latency" =>
          {fn {view_id, _pid, handler_id} ->
             send_counter_click(view_id)
             wait_for_rerenders(view_id, 1)
             handler_id
           end,
           before_scenario: &start_counter_window_scenario/1,
           after_scenario: &stop_counter_window_scenario/1},
        "Guppy.Window repeated routed event pressure (10 events)" =>
          {fn {view_id, _pid, handler_id} ->
             for _index <- 1..10, do: send_counter_click(view_id)
             wait_for_rerenders(view_id, 10)
             handler_id
           end,
           before_scenario: &start_counter_window_scenario/1,
           after_scenario: &stop_counter_window_scenario/1}
      },
      benchee_opts()
    )
  rescue
    error ->
      IO.puts(
        "skip native event-to-rerender latency; benchmark setup failed: #{Exception.message(error)}"
      )
  end

  defp start_counter_window_scenario(_input) do
    {:ok, pid} = Guppy.Bench.CounterWindow.start_link(nil)
    view_id = Guppy.Window.view_id(pid)
    handler_id = {__MODULE__, self(), :window_rerender, make_ref()}

    :ok =
      :telemetry.attach(
        handler_id,
        [:guppy, :window, :rerender],
        &Guppy.Bench.Telemetry.forward_window_rerender/4,
        self()
      )

    {view_id, pid, handler_id}
  end

  defp stop_counter_window_scenario({_view_id, pid, handler_id}) do
    :telemetry.detach(handler_id)
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)
  end

  defp send_counter_click(view_id) do
    send(Guppy.server(), {
      :guppy_native_event,
      view_id,
      :click,
      %{id: "bench_counter_button", callback: "increment"}
    })
  end

  defp wait_for_rerenders(_view_id, 0), do: :ok

  defp wait_for_rerenders(view_id, remaining) do
    receive do
      {:bench_rerender, ^view_id, :ok} -> wait_for_rerenders(view_id, remaining - 1)
    after
      1_000 -> raise "timed out waiting for window rerender telemetry"
    end
  end

  defp native_render_latency do
    Benchee.run(
      %{
        "Guppy.render/2 native request latency" =>
          {fn {view_id, ir} ->
             :ok = Guppy.render(view_id, ir)
           end,
           before_scenario: fn _input ->
             ir = kanban_tree(columns: 4, cards: 40)
             {:ok, view_id} = Guppy.open_window(ir, show: false)
             {view_id, ir}
           end,
           after_scenario: fn {view_id, _ir} ->
             :ok = Guppy.close_window(view_id)
           end},
        "Guppy.render/2 validated native request latency" =>
          {fn {view_id, validated_ir} ->
             :ok = Guppy.render(view_id, validated_ir)
           end,
           before_scenario: fn _input ->
             ir = kanban_tree(columns: 4, cards: 40)
             validated_ir = Guppy.IR.validated!(ir)
             {:ok, view_id} = Guppy.open_window(validated_ir, show: false)
             {view_id, validated_ir}
           end,
           after_scenario: fn {view_id, _ir} ->
             :ok = Guppy.close_window(view_id)
           end}
      },
      benchee_opts()
    )
  rescue
    error ->
      IO.puts(
        "skip native render/request latency; benchmark setup failed: #{Exception.message(error)}"
      )
  end
end

Guppy.Bench.main(System.argv())
