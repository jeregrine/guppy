# Performance Baseline

Benchmarks use [`Benchee`](https://hex.pm/packages/benchee):

```sh
mix run bench/guppy_bench.exs
mix run bench/guppy_bench.exs --native
mix run bench/native_event_probe.exs --events=20
```

`--native` additionally opens a hidden GPUI window and measures `Guppy.render/2` request latency when the local platform can run the native runtime. `bench/native_event_probe.exs` opens a visible probe window for manual GPUI-generated click-to-rerender measurement.

## 2026-05-12 local snapshot

Environment:

- macOS
- Apple M1 Pro
- Elixir 1.19.5
- OTP 28.4.2
- JIT enabled

Selected results from `mix run bench/guppy_bench.exs`:

| Scenario | Average | 99th percentile |
| --- | ---: | ---: |
| `~G` template render 10 nodes | 100.77 μs | 174.96 μs |
| `~G` template render 100 nodes | 908.40 μs | 1197.58 μs |
| `~G` template render 1,000 nodes | 8900.84 μs | 9745.56 μs |
| IR validation 10 nodes | 8.61 μs | 15.96 μs |
| IR validation 100 nodes | 57.52 μs | 89.99 μs |
| IR validation 1,000 nodes | 593.31 μs | 863.59 μs |
| ETF encode/decode proxy 10 nodes | 8.62 μs | 13.13 μs |
| ETF encode/decode proxy 100 nodes | 82.19 μs | 122.68 μs |
| ETF encode/decode proxy 1,000 nodes | 842.63 μs | 1033.59 μs |
| `Guppy.Window` routed event-to-rerender latency | 0.23 ms | 0.37 ms |
| `Guppy.Window` repeated routed event pressure (10 events) | 5.21 ms | 8.79 ms |
| `Guppy.render/2` native request latency | 49.32 ms | 51.21 ms |
| Kanban initial render tree build | 149.42 μs | 231.22 μs |
| Kanban scroll interaction tree build | 150.01 μs | 228.91 μs |
| High-frequency mouse move payload encode | 0.46 μs | 0.50 μs |
| High-frequency drag move payload encode | 0.46 μs | 0.50 μs |
| High-frequency scroll wheel payload encode | 0.46 μs | 0.50 μs |

## Release native snapshot

After `mix guppy.native.build --release`, selected `mix run bench/guppy_bench.exs --native` results:

| Scenario | Average | 99th percentile |
| --- | ---: | ---: |
| `Guppy.Window` routed event-to-rerender latency | 0.150 ms | 4.32 ms |
| `Guppy.Window` repeated routed event pressure (10 events) | 12.19 ms | 88.19 ms |
| `Guppy.render/2` native request latency | 5.99 ms | 6.98 ms |
| `Guppy.render/2` validated native request latency | 5.76 ms | 7.70 ms |

## Notes

- This is a baseline, not a promise of stable performance yet.
- Runtime telemetry is available at `[:guppy, :native, :nif]` for direct Rustler NIF call latency, `[:guppy, :native, :request]` for server-mediated native request latency, `[:guppy, :event, :route]` for native event routing, and `[:guppy, :window, :rerender]` for `Guppy.Window` rerender latency.
- `Guppy.native_performance_counters/0` exposes native-side counters for Rust boundary IR/options encode-decode timing and native event send timing/failures.
- `Guppy.IR.validated!/1` can wrap static or trusted trees after one validation pass so repeated `open_window`/`render` calls skip Elixir-side validation while still unwrapping before native decode.
- `bench/native_event_probe.exs` provides a manual GPUI-generated event probe. It measures route-to-rerender latency after actual native click delivery; it does not include OS input latency before GPUI emits the event.
- Native tests include automated GPUI simulated-click coverage for the event bridge. That coverage verifies delivery into the native event bridge, but does not measure BEAM/NIF end-to-end timing.
- The repeated routed-event snapshot is measurement-only; current release results do not justify default `Guppy.Window` batching/debounce without stronger evidence of user-visible pressure.
- Current high-frequency payload encode measurements for mouse move, drag move, and scroll wheel are sub-microsecond and do not justify adding default event coalescing without native delivery evidence.
- Use release native builds for interactive/manual performance checks:

```sh
mix guppy.native.build --release
mix run examples/kanban_todo.exs
```
