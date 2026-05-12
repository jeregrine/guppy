defmodule Guppy.NativeEventProbe.Window do
  use Guppy.Window

  @impl Guppy.Window
  def mount(target_count, window) do
    {:ok, assign(window, count: 0, target_count: target_count)}
  end

  @impl Guppy.Window
  def render(window) do
    count = window.assigns.count
    target_count = window.assigns.target_count

    Guppy.IR.div(
      [
        Guppy.IR.text("Native event probe", id: "probe_title"),
        Guppy.IR.text("Click the bordered target until #{target_count} events are recorded."),
        Guppy.IR.div(
          [Guppy.IR.text("Click target: #{count} / #{target_count}")],
          id: "probe_click_target",
          style: [:p_4, :border_1, :rounded_md],
          events: %{click: "increment"}
        )
      ],
      id: "probe_root",
      style: [:p_4, :gap_4]
    )
  end

  @impl Guppy.Window
  def handle_event("increment", _event, window) do
    {:noreply, update(window, :count, &(&1 + 1))}
  end
end

defmodule Guppy.NativeEventProbe do
  @moduledoc false

  def main(args) do
    target_count = parse_int_arg(args, "--events", 20)
    timeout_ms = parse_int_arg(args, "--timeout", 30_000)
    parent = self()

    route_handler = {__MODULE__, self(), :route}
    rerender_handler = {__MODULE__, self(), :rerender}

    :ok =
      :telemetry.attach(
        route_handler,
        [:guppy, :event, :route],
        &__MODULE__.forward_route/4,
        parent
      )

    :ok =
      :telemetry.attach(
        rerender_handler,
        [:guppy, :window, :rerender],
        &__MODULE__.forward_rerender/4,
        parent
      )

    try do
      {:ok, pid} = Guppy.NativeEventProbe.Window.start_link(target_count)
      view_id = Guppy.Window.view_id(pid)

      IO.puts("# Guppy native event probe")
      IO.puts("# click probe_click_target #{target_count} times; timeout=#{timeout_ms}ms")
      IO.puts("# view_id=#{view_id}")

      results = collect(view_id, target_count, timeout_ms, [], [])
      print_results(results)

      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    after
      :telemetry.detach(route_handler)
      :telemetry.detach(rerender_handler)
    end
  end

  def forward_route(_event, _measurements, %{view_id: view_id, type: :click, status: :ok}, parent) do
    send(parent, {:probe_route, view_id, System.monotonic_time()})
  end

  def forward_route(_event, _measurements, _metadata, _parent), do: :ok

  def forward_rerender(_event, _measurements, %{view_id: view_id, status: :ok}, parent) do
    send(parent, {:probe_rerender, view_id, System.monotonic_time()})
  end

  def forward_rerender(_event, _measurements, _metadata, _parent), do: :ok

  defp collect(_view_id, target_count, _timeout_ms, _route_times, results)
       when length(results) >= target_count do
    Enum.reverse(results)
  end

  defp collect(view_id, target_count, timeout_ms, route_times, results) do
    receive do
      {:probe_route, ^view_id, routed_at} ->
        collect(view_id, target_count, timeout_ms, route_times ++ [routed_at], results)

      {:probe_rerender, ^view_id, rerendered_at} ->
        case route_times do
          [routed_at | rest] ->
            duration = System.convert_time_unit(rerendered_at - routed_at, :native, :microsecond)
            collect(view_id, target_count, timeout_ms, rest, [duration | results])

          [] ->
            collect(view_id, target_count, timeout_ms, route_times, results)
        end
    after
      timeout_ms ->
        raise "timed out waiting for #{target_count} click/rerender measurements"
    end
  end

  defp print_results(results) do
    sorted = Enum.sort(results)
    count = length(sorted)
    average = Enum.sum(sorted) / max(count, 1)
    p50 = percentile(sorted, 50)
    p95 = percentile(sorted, 95)
    p99 = percentile(sorted, 99)

    IO.puts("")
    IO.puts("events=#{count}")
    IO.puts("route_to_rerender_avg_us=#{Float.round(average, 2)}")
    IO.puts("route_to_rerender_p50_us=#{p50}")
    IO.puts("route_to_rerender_p95_us=#{p95}")
    IO.puts("route_to_rerender_p99_us=#{p99}")
  end

  defp percentile([], _percentile), do: 0

  defp percentile(sorted, percentile) do
    index =
      sorted
      |> length()
      |> Kernel.*(percentile / 100)
      |> Float.ceil()
      |> trunc()
      |> Kernel.-(1)
      |> max(0)
      |> min(length(sorted) - 1)

    Enum.at(sorted, index)
  end

  defp parse_int_arg(args, name, default) do
    case Enum.find_value(args, &parse_int_arg(&1, name)) do
      nil -> default
      value -> value
    end
  end

  defp parse_int_arg(arg, name) do
    prefix = name <> "="

    if String.starts_with?(arg, prefix) do
      arg |> String.replace_prefix(prefix, "") |> String.to_integer()
    end
  end
end

Guppy.NativeEventProbe.main(System.argv())
