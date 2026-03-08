defmodule Examples.HelloWorldWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 3, put_window_opts: 2]

  @impl Guppy.Window
  def mount(:ok, window) do
    Process.send_after(self(), :update_text, 1_000)
    Process.send_after(self(), :shutdown, 5_000)

    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 760, height: 560],
       titlebar: [title: "Guppy hello world"]
     )
     |> assign(:phase, :initial)}
  end

  @impl Guppy.Window
  def render(window) do
    {accent_bg, accent_border, status_label, message} = phase_content(window.assigns.phase)

    Guppy.IR.div(
      [
        surface(
          [
            Guppy.IR.div(
              [Guppy.IR.text("Guppy hello world", id: "title")],
              style: [:text_3xl, :font_black]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text(
                  "A small window process renders a full replacement IR tree and updates itself after a timer.",
                  id: "subtitle"
                )
              ],
              style: [:text_base, {:text_color_hex, "#94a3b8"}]
            )
          ],
          id: "hero_panel"
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div(
              [Guppy.IR.text("Window lifecycle", id: "status_heading")],
              style: [:text_sm, :font_semibold, {:text_color_hex, "#cbd5e1"}]
            ),
            Guppy.IR.div(
              [Guppy.IR.text(status_label, id: "status_label")],
              style: [
                :p_2,
                :rounded_lg,
                :border_1,
                {:border_color_hex, accent_border},
                {:bg_hex, accent_bg},
                :shadow_sm,
                :text_lg,
                :font_semibold
              ]
            ),
            Guppy.IR.div(
              [Guppy.IR.text(message, id: "status_message")],
              style: [:text_base, {:text_color_hex, "#e2e8f0"}]
            )
          ],
          id: "status_panel",
          style: [
            :flex,
            :flex_col,
            :gap_2,
            :p_4,
            :rounded_xl,
            :border_1,
            {:border_color_hex, accent_border},
            {:bg_hex, accent_bg},
            :shadow_md
          ]
        ),
        surface(
          [
            Guppy.IR.div(
              [Guppy.IR.text("What this example shows", id: "details_heading")],
              style: [:text_sm, :font_semibold, {:text_color_hex, "#cbd5e1"}]
            ),
            feature_row("Window process owns assigns and timers", "feature_process"),
            feature_row("Render returns a declarative tree each time", "feature_render"),
            feature_row("Native side swaps the visible UI from that tree", "feature_native")
          ],
          id: "details_panel"
        )
      ],
      id: "hello_root",
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
  def handle_info(:update_text, window) do
    IO.puts("updated window via IR")
    {:noreply, assign(window, :phase, :updated)}
  end

  @impl Guppy.Window
  def handle_info(:shutdown, window) do
    IO.puts("stopping window process")
    {:stop, :normal, window}
  end

  defp phase_content(:initial) do
    {"#172554", "#3b82f6", "Initial render",
     "The first frame is mounted immediately when the window process starts."}
  end

  defp phase_content(:updated) do
    {"#14532d", "#22c55e", "Updated render",
     "A timer fired, the assign changed, and the whole tree rerendered cleanly."}
  end

  defp surface(children, opts) do
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

  defp feature_row(label, id) do
    Guppy.IR.div(
      [
        Guppy.IR.div([],
          id: "#{id}_dot",
          style: [{:w_px, 10}, {:h_px, 10}, :rounded_full, {:bg_hex, "#38bdf8"}]
        ),
        Guppy.IR.div([Guppy.IR.text(label, id: id)], style: [:flex_1, :text_base])
      ],
      id: "#{id}_row",
      style: [:flex, :flex_row, :items_center, :gap_2]
    )
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy hello world")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")
IO.inspect(Guppy.ping(), label: "ping")

{:ok, pid} = Examples.HelloWorldWindow.start_link(:ok)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")
IO.inspect(Guppy.native_view_count(), label: "native_view_count")
IO.puts("opened and asked GPUI to activate/focus the window")
IO.puts("rendered IR tree")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    IO.inspect(Guppy.native_view_count(), label: "native_view_count")
end
