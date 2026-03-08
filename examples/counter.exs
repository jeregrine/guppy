defmodule Examples.TimerCounterWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 3, update: 3, put_window_opts: 2]

  @impl Guppy.Window
  def mount(initial_count, window) do
    Process.send_after(self(), :tick, 1_000)

    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 760, height: 560],
       titlebar: [title: "Guppy timer counter"]
     )
     |> assign(:count, initial_count)}
  end

  @impl Guppy.Window
  def render(window) do
    count = window.assigns.count

    Guppy.IR.div(
      [
        panel(
          [
            Guppy.IR.div([Guppy.IR.text("Timer counter", id: "title")],
              style: [:text_3xl, :font_black]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text(
                  "This window rerenders from Elixir state once per second and stops after five updates.",
                  id: "subtitle"
                )
              ],
              style: [:text_base, {:text_color_hex, "#94a3b8"}]
            )
          ],
          id: "header_panel"
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [Guppy.IR.text("Current count", id: "count_heading")],
              style: [:text_sm, :font_semibold, {:text_color_hex, "#bfdbfe"}]
            ),
            Guppy.IR.div(
              [Guppy.IR.text(Integer.to_string(count), id: "count_label")],
              style: [:text_3xl, :font_black]
            ),
            Guppy.IR.div(
              [Guppy.IR.text(progress_text(count), id: "progress_text")],
              style: [:text_base, {:text_color_hex, "#dbeafe"}]
            )
          ],
          id: "count_panel",
          style: [
            :flex,
            :flex_col,
            :items_center,
            :gap_2,
            :p_6,
            :rounded_xl,
            :border_1,
            {:border_color_hex, "#2563eb"},
            {:bg_hex, "#172554"},
            :shadow_md,
            :text_center
          ]
        ),
        panel(
          [
            info_row("State lives in the window process", "info_state"),
            info_row("Each tick updates assigns and triggers a fresh render", "info_tick"),
            info_row("The example exits once the count reaches five", "info_stop")
          ],
          id: "info_panel"
        )
      ],
      id: "counter_root",
      style: [
        :flex,
        :flex_col,
        :w_full,
        :h_full,
        :gap_4,
        :p_6,
        {:bg_hex, "#0f172a"},
        {:text_color_hex, "#f8fafc"}
      ]
    )
  end

  @impl Guppy.Window
  def handle_info(:tick, window) when window.assigns.count < 5 do
    next_window = update(window, :count, &(&1 + 1))
    IO.puts("updated count to #{next_window.assigns.count}")
    Process.send_after(self(), :tick, 1_000)
    {:noreply, next_window}
  end

  @impl Guppy.Window
  def handle_info(:tick, window) do
    IO.puts("stopping window process after 5 updates")
    {:stop, :normal, window}
  end

  defp progress_text(count) when count < 5, do: "Waiting for the next timer tick..."
  defp progress_text(_count), do: "Done. The process will shut down now."

  defp panel(children, opts) do
    id = Keyword.get(opts, :id)

    Guppy.IR.div(
      children,
      id: id,
      style: [
        :flex,
        :flex_col,
        :gap_2,
        :p_4,
        :rounded_xl,
        :border_1,
        {:border_color_hex, "#334155"},
        {:bg_hex, "#111827"},
        :shadow_md
      ]
    )
  end

  defp info_row(label, id) do
    Guppy.IR.div(
      [
        Guppy.IR.div([],
          id: "#{id}_dot",
          style: [{:w_px, 10}, {:h_px, 10}, :rounded_full, {:bg_hex, "#60a5fa"}]
        ),
        Guppy.IR.div([Guppy.IR.text(label, id: id)], style: [:flex_1, :text_base])
      ],
      id: "#{id}_row",
      style: [:flex, :flex_row, :items_center, :gap_2]
    )
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy counter example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.TimerCounterWindow.start_link(0)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
