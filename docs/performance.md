# Performance Baseline

Benchmarks use [`Benchee`](https://hex.pm/packages/benchee):

```sh
mix run bench/guppy_bench.exs
mix run bench/guppy_bench.exs --native
```

`--native` additionally opens a hidden GPUI window and measures `Guppy.render/2` request latency when the local platform can run the native runtime.

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
| Kanban initial render tree build | 131.41 μs | 213.25 μs |
| High-frequency scroll payload encode | 0.49 μs | 0.54 μs |

## Notes

- This is a baseline, not a promise of stable performance yet.
- Native request latency and event-to-rerender latency still need more realistic end-to-end coverage.
- Use release native builds for interactive/manual performance checks:

```sh
mix guppy.native.build --release
mix run examples/kanban_todo.exs
```
