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
| `~GUI` template render 10 nodes | 100.77 μs | 174.96 μs |
| `~GUI` template render 100 nodes | 908.40 μs | 1197.58 μs |
| `~GUI` template render 1,000 nodes | 8900.84 μs | 9745.56 μs |
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

## 2026-05-14 native cleanup spot-check

After the native IR/style cleanup pass that tightened native style validation, moved retained native payloads toward `Arc<[T]>`, decoded native hex colors to parsed values, shared child decode helpers, and reduced list render clones, `mix run bench/guppy_bench.exs` on the same local M1 Pro/macOS class machine reported these selected non-native scenarios. These numbers are a spot-check for regressions, not a release baseline.

| Scenario | Average | 99th percentile |
| --- | ---: | ---: |
| ETF encode/decode proxy 100 nodes | 77.55 μs | 99.32 μs |
| ETF encode/decode proxy 1,000 nodes | 777.02 μs | 897.25 μs |
| IR validation 100 nodes | 70.19 μs | 78.62 μs |
| IR validation 1,000 nodes | 716.15 μs | 989.07 μs |
| Canvas command encode/decode proxy 100 commands | 50.05 μs | 56.42 μs |
| Canvas command validation 100 commands | 68.97 μs | 83.38 μs |
| Data-table/tree build 100 rows | 26.08 μs | 29.67 μs |
| Data-table/tree validation 100 rows | 128.57 μs | 145.22 μs |
| List row controls tree build 100 rows | 93.30 μs | 144.15 μs |
| List row controls validation 100 rows | 136.25 μs | 151.95 μs |

## Release native snapshot

With an optimized native build, selected `GUPPY_NATIVE_RELEASE=1 mix run bench/guppy_bench.exs --native` results:

| Scenario | Average | 99th percentile |
| --- | ---: | ---: |
| `Guppy.Window` routed event-to-rerender latency | 0.150 ms | 4.32 ms |
| `Guppy.Window` repeated routed event pressure (10 events) | 12.19 ms | 88.19 ms |
| `Guppy.render/2` native request latency | 5.99 ms | 6.98 ms |
| `Guppy.render/2` validated native request latency | 5.76 ms | 7.70 ms |

## IR bridge stress-test snapshot

`examples/stress_test.exs` is the current manual stress probe for full-tree IR replacement, ETF encode/decode, retained scrolling, virtual lists, grid-heavy trees, and event routing. It prints per-sample fps/renders, Elixir IR build time, end-to-end `Guppy.render/3` call time, native ETF encode/decode counters, BEAM memory, mailbox depth, event deltas, and a stop summary.

Run it with an optimized native build:

```sh
MIX_ENV=prod mix run examples/stress_test.exs
```

The interactive stress probe runs continuously until the window is closed or the process is interrupted. `GUPPY_STRESS_TIMEOUT_MS` controls each native render request timeout, not total run duration. For bounded automated syntax/IR validation, use:

```sh
mix run --no-start examples/stress_test.exs -- --validate-only
```

Useful isolation/output knobs:

```sh
GUPPY_STRESS_UNIFORM_ITEMS=12000
GUPPY_STRESS_LIST_ROWS=1200
GUPPY_STRESS_SCROLL_ROWS=900
GUPPY_STRESS_GRID_CELLS=384
GUPPY_STRESS_SAMPLE_MS=1000
GUPPY_STRESS_FORMAT=jsonl
GUPPY_STRESS_MEASURE_IR=1
```

Current local shape from release/native prod stress runs after static generic-list row divs moved to the restricted native decode path:

| Scenario | Approx fps | Render call | Native decode | Notes |
| --- | ---: | ---: | ---: | --- |
| Minimal stress tree | 59 fps | 1.5 ms | 0.6 ms | Near 60 fps; baseline overhead looks acceptable. |
| 12k-row `uniform_list` isolation | 48 fps | 15 ms | 5 ms | Virtual text-row list is close to frame budget. |
| 1.2k-row generic `list` isolation | 34 fps | 26 ms | 11 ms | Static row decode fix made this much faster; still above 16 ms. |
| 384-cell grid isolation | 28 fps | 35 ms | 3 ms | Time is mostly GPUI/main-thread element/layout/paint work, not decode. |
| 900 real scroll rows + moving `anchor_scroll` | 10 fps | 97 ms | 9 ms | Dominated by dense non-virtualized scroll children. |
| Default mixed stress | 7 fps | 125 ms | 27 ms | Combined pressure from real scroll rows, grid/rich text, and virtual lists. |

Current interpretation:

- The duplicate native decode/validation path for static generic-list row divs has been fixed.
- Remaining stress-test pressure is mostly main-thread GPUI element construction, layout, and paint for dense real scroll/grid trees.
- The stress results do not currently point to native-to-Elixir event traffic, mailbox backlog, or `Guppy.Window` rerender batching as the main bottleneck.
- Do not add default scroll debounce, high-frequency event coalescing, keyed diffing, or `Guppy.Window` rerender batching without new evidence.

Performance-specific next steps:

1. Re-run and update this stress baseline after meaningful native renderer or style/layout changes.
2. Profile non-virtualized scroll rows and `anchor_scroll` before changing architecture.
3. Investigate scroll-heavy alternatives only with measurements: using existing `list`/`uniform_list` where possible, a narrow scroll-to-index/anchor API, or native retained scroll positioning.
4. Profile dense grid/rich-text element construction and style application before ETF micro-optimizations.
5. Keep generic `list` row controls static/layout-only until retained row-control identity and lifecycle semantics are explicitly designed.

## Notes

- This is a baseline, not a promise of stable performance yet.
- Runtime telemetry is available at `[:guppy, :native, :nif]` for direct Rustler NIF call latency, `[:guppy, :native, :request]` for server-mediated native request latency, `[:guppy, :event, :route]` for native event routing, and `[:guppy, :window, :rerender]` for `Guppy.Window` rerender latency.
- Native request timeouts are a containment mechanism, not a performance optimization: timed-out queued main-thread requests carry deadlines and expire before mutating native state.
- `Guppy.native_performance_counters/0` exposes native-side counters for Rust boundary IR/options encode-decode timing and native event send timing/failures.
- `Guppy.IR.validated!/1` can wrap static or trusted trees after one validation pass so repeated `open_window`/`render` calls skip Elixir-side validation while still unwrapping before native decode.
- `bench/native_event_probe.exs` provides a manual GPUI-generated event probe. It measures route-to-rerender latency after actual native click delivery; it does not include OS input latency before GPUI emits the event.
- Native tests include automated GPUI simulated-click coverage for the event bridge. That coverage verifies delivery into the native event bridge, but does not measure BEAM/NIF end-to-end timing.
- The repeated routed-event snapshot is measurement-only; current release results do not justify default `Guppy.Window` batching/debounce without stronger evidence of user-visible pressure.
- Current high-frequency payload encode measurements for mouse move, drag move, and scroll wheel are sub-microsecond and do not justify adding default event coalescing without native delivery evidence.
- Use release native builds for interactive/manual performance checks:

```sh
GUPPY_NATIVE_RELEASE=1 mix run examples/kanban_todo.exs
```
