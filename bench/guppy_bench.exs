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
    IO.puts("# times are microseconds per operation unless noted")
    IO.puts("")

    [10, 100, 1_000]
    |> Enum.each(fn count ->
      items = Enum.to_list(1..count)
      ir = tree(count)

      bench("~G template render #{count} nodes", fn ->
        Guppy.Bench.Template.render(%{items: items})
      end)

      bench("IR validation #{count} nodes", fn ->
        :ok = Guppy.IR.validate(ir)
      end)

      bench("ETF encode/decode proxy #{count} nodes", fn ->
        ir |> :erlang.term_to_binary() |> :erlang.binary_to_term()
      end)
    end)

    kanban = kanban_tree(columns: 4, cards: 40)

    bench("kanban initial render tree build", fn ->
      kanban_tree(columns: 4, cards: 40)
    end)

    bench("kanban add card tree build", fn ->
      add_kanban_card(kanban)
    end)

    bench("kanban move card tree build", fn ->
      move_kanban_card(kanban)
    end)

    bench("kanban edit card tree build", fn ->
      edit_kanban_card(kanban)
    end)

    bench("high-frequency event pressure: mouse_move payload", fn ->
      event_payload(:mouse_move)
    end)

    bench("high-frequency event pressure: drag_move payload", fn ->
      event_payload(:drag_move)
    end)

    bench("high-frequency event pressure: scroll_wheel payload", fn ->
      event_payload(:scroll_wheel)
    end)

    if include_native? do
      native_render_latency(kanban)
    else
      IO.puts("skip native render/request latency; rerun with --native to open a hidden GPUI window")
    end
  end

  defp bench(name, fun) do
    {sample_count, inner_count, samples} = sample(fun)
    sorted = Enum.sort(samples)

    IO.puts(
      Enum.join(
        [
          name,
          "samples=#{sample_count}",
          "inner=#{inner_count}",
          "p50=#{format_micros(percentile(sorted, 50))}",
          "p95=#{format_micros(percentile(sorted, 95))}",
          "p99=#{format_micros(percentile(sorted, 99))}"
        ],
        "\t"
      )
    )
  end

  defp sample(fun) do
    sample_count = 200
    inner_count = inner_count(fun)

    samples =
      for _ <- 1..sample_count do
        start = System.monotonic_time(:nanosecond)

        for _ <- 1..inner_count do
          fun.()
        end

        stop = System.monotonic_time(:nanosecond)
        (stop - start) / inner_count / 1_000
      end

    {sample_count, inner_count, samples}
  end

  defp inner_count(fun) do
    start = System.monotonic_time(:nanosecond)

    for _ <- 1..10 do
      fun.()
    end

    elapsed = System.monotonic_time(:nanosecond) - start
    per_op = max(elapsed / 10, 1)
    max(1, min(1_000, round(5_000_000 / per_op)))
  end

  defp percentile(sorted, pct) do
    index = max(0, ceil(length(sorted) * pct / 100) - 1)
    Enum.at(sorted, index)
  end

  defp format_micros(value), do: :erlang.float_to_binary(value, decimals: 2)

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
    put_in(kanban, [:children, Access.at(0), :children, Access.at(0), :children, Access.at(0), :content], "Edited card")
  end

  defp event_payload(kind) do
    %{
      id: "card_1_1",
      callback: Atom.to_string(kind),
      x: 120.0,
      y: 240.0,
      modifiers: %{control: false, alt: false, shift: false, platform: false, function: false}
    }
  end

  defp native_render_latency(ir) do
    case Guppy.open_window(ir, self(), show: false) do
      {:ok, view_id} ->
        bench("Guppy.render/2 native request latency", fn ->
          :ok = Guppy.render(view_id, ir)
        end)

        :ok = Guppy.close_window(view_id)

      {:error, reason} ->
        IO.puts("skip native render/request latency; open_window failed: #{inspect(reason)}")
    end
  end
end

Guppy.Bench.main(System.argv())
