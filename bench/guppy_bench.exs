defmodule Guppy.Bench.Template do
  use Guppy.Component

  def render(assigns) do
    ~G"""
    <div id="bench_root" class="flex flex-col gap-1 p-2">
      <div :for={item <- @items} id={"bench_item_#{item}"} class="p-1 border-1 border-gray">
        <text>{"Item #{item}"}</text>
      </div>
    </div>
    """
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
      native_render_latency()
    else
      IO.puts("skip native render/request latency; rerun with --native to open a hidden GPUI window")
    end
  end

  defp static_scenarios do
    node_scenarios =
      [10, 100, 1_000]
      |> Enum.flat_map(fn count ->
        items = Enum.to_list(1..count)
        ir = tree(count)

        [
          {"~G template render #{count} nodes", fn ->
             Guppy.Bench.Template.render(%{items: items})
           end},
          {"IR validation #{count} nodes", fn ->
             :ok = Guppy.IR.validate(ir)
           end},
          {"ETF encode/decode proxy #{count} nodes", fn ->
             ir |> :erlang.term_to_binary() |> :erlang.binary_to_term()
           end}
        ]
      end)

    kanban = kanban_tree(columns: 4, cards: 40)

    kanban_scenarios = [
      {"kanban initial render tree build", fn ->
         kanban_tree(columns: 4, cards: 40)
       end},
      {"kanban add card tree build", fn ->
         add_kanban_card(kanban)
       end},
      {"kanban move card tree build", fn ->
         move_kanban_card(kanban)
       end},
      {"kanban edit card tree build", fn ->
         edit_kanban_card(kanban)
       end},
      {"event-to-rerender proxy latency", fn ->
         :change
         |> event_payload()
         |> apply_event_to_kanban(kanban)
       end},
      {"high-frequency event pressure: mouse_move payload encode", fn ->
         :mouse_move |> event_payload() |> :erlang.term_to_binary()
       end},
      {"high-frequency event pressure: drag_move payload encode", fn ->
         :drag_move |> event_payload() |> :erlang.term_to_binary()
       end},
      {"high-frequency event pressure: scroll_wheel payload encode", fn ->
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

    columns =
      for column <- 1..column_count do
        cards =
          for card <- 1..card_count do
            Guppy.IR.div(
              [
                Guppy.IR.text("Card #{column}.#{card}", id: "card_title_#{column}_#{card}"),
                Guppy.IR.text_input("", id: "card_edit_#{column}_#{card}", placeholder: "Edit card")
              ],
              id: "card_#{column}_#{card}",
              style: [:p_2, :rounded_md, :border_1],
              events: %{drag_move: "move_card", scroll_wheel: "scroll_card"}
            )
          end

        Guppy.IR.scroll(cards, id: "column_scroll_#{column}", axis: :y, style: [:flex_1])
      end

    Guppy.IR.div(columns, id: "kanban", style: [:flex, :flex_row, :gap_4])
  end

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

  defp native_render_latency do
    Benchee.run(
      %{
        "Guppy.render/2 native request latency" =>
          {fn {view_id, ir} ->
             :ok = Guppy.render(view_id, ir)
           end,
           before_scenario: fn _input ->
             ir = kanban_tree(columns: 4, cards: 40)
             {:ok, view_id} = Guppy.open_window(ir, self(), show: false)
             {view_id, ir}
           end,
           after_scenario: fn {view_id, _ir} ->
             :ok = Guppy.close_window(view_id)
           end}
      },
      benchee_opts()
    )
  rescue
    error ->
      IO.puts("skip native render/request latency; benchmark setup failed: #{Exception.message(error)}")
  end
end

Guppy.Bench.main(System.argv())
