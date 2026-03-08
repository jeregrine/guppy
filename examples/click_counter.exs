defmodule Examples.ClickCounterWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 3, update: 3, put_window_opts: 2]

  @impl Guppy.Window
  def mount(initial_count, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 780, height: 620],
       titlebar: [title: "Guppy click counter"]
     )
     |> assign(:count, initial_count)}
  end

  @impl Guppy.Window
  def handle_event("increment", _event_data, window) do
    next_window = update(window, :count, &(&1 + 1))
    IO.puts("incremented to #{next_window.assigns.count}")
    {:noreply, next_window}
  end

  def handle_event("reset", _event_data, window) do
    IO.puts("reset counter")
    {:noreply, assign(window, :count, 0)}
  end

  @impl Guppy.Window
  def render(window) do
    count = window.assigns.count

    Guppy.IR.div(
      [
        panel(
          [
            Guppy.IR.div([Guppy.IR.text("Click counter", id: "title")],
              style: [:text_3xl, :font_black]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text(
                  "Buttons dispatch native click events back into the window process, which updates assigns and rerenders.",
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
            Guppy.IR.div([Guppy.IR.text("Clicks", id: "count_heading")],
              style: [:text_sm, :font_semibold, {:text_color_hex, "#bfdbfe"}]
            ),
            Guppy.IR.div([Guppy.IR.text(Integer.to_string(count), id: "count_label")],
              style: [:text_3xl, :font_black]
            ),
            Guppy.IR.div(
              [Guppy.IR.text(summary_text(count), id: "summary_text")],
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
        Guppy.IR.div(
          [
            action_button("Increment", "increment", "#2563eb", "#1d4ed8"),
            action_button("Reset", "reset", "#334155", "#475569")
          ],
          id: "controls",
          style: [:flex, :flex_row, :gap_2]
        ),
        panel(
          [
            info_row("Use the primary button to send click events", "info_primary"),
            info_row("Reset is wired through the same window callback path", "info_reset"),
            info_row("Close the window when you are done", "info_close")
          ],
          id: "info_panel"
        )
      ],
      id: "click_counter_root",
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

  defp summary_text(0), do: "No clicks yet — press the button to start."
  defp summary_text(1), do: "One click recorded."
  defp summary_text(count), do: "#{count} clicks recorded."

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

  defp action_button(label, callback, bg_hex, hover_hex) do
    Guppy.IR.button(label,
      id: "#{callback}_button",
      style: [
        :flex_1,
        :p_4,
        :rounded_lg,
        :border_1,
        {:border_color_hex, bg_hex},
        {:bg_hex, bg_hex},
        {:text_color_hex, "#f8fafc"},
        :shadow_sm
      ],
      hover_style: [{:bg_hex, hover_hex}],
      events: %{click: callback}
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

IO.puts("Guppy click counter example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.ClickCounterWindow.start_link(0)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
