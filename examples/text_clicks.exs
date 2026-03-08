defmodule Examples.TextClicksWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 3, put_window_opts: 2]

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 760, height: 620],
       titlebar: [title: "Guppy text clicks"]
     )
     |> assign(:status, "Waiting for a click")}
  end

  @impl Guppy.Window
  def handle_event("line_one", _event_data, window) do
    IO.puts("clicked line one")
    {:noreply, assign(window, :status, "Clicked the first line")}
  end

  def handle_event("line_two", _event_data, window) do
    IO.puts("clicked line two")
    {:noreply, assign(window, :status, "Clicked the second line")}
  end

  @impl Guppy.Window
  def render(window) do
    Guppy.IR.div(
      [
        panel(
          [
            Guppy.IR.div([Guppy.IR.text("Text clicks", id: "title")],
              style: [:text_3xl, :font_black]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text(
                  "Text nodes can emit click events, and the surrounding layout can still look like a proper sample app.",
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
            Guppy.IR.div([Guppy.IR.text("Status", id: "status_heading")],
              style: [:text_sm, :font_semibold, {:text_color_hex, "#bfdbfe"}]
            ),
            Guppy.IR.div([Guppy.IR.text(window.assigns.status, id: "status")],
              style: [:text_2xl, :font_black]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text("Click either row below to update this state label.",
                  id: "status_help"
                )
              ],
              style: [:text_base, {:text_color_hex, "#dbeafe"}]
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
            {:border_color_hex, "#2563eb"},
            {:bg_hex, "#172554"},
            :shadow_md
          ]
        ),
        Guppy.IR.div(
          [
            clickable_row(
              "line_one",
              "First line",
              "Use a clickable text node as the primary action."
            ),
            clickable_row(
              "line_two",
              "Second line",
              "Wire a different callback through the same window process."
            )
          ],
          id: "choices",
          style: [:flex, :flex_col, :gap_2]
        )
      ],
      id: "text_click_root",
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

  defp clickable_row(callback, title, body) do
    Guppy.IR.div(
      [
        Guppy.IR.div([Guppy.IR.text(title, id: "#{callback}_title")],
          style: [:text_lg, :font_bold]
        ),
        Guppy.IR.text(body, id: callback, events: %{click: callback})
      ],
      id: "#{callback}_row",
      style: [
        :flex,
        :flex_col,
        :gap_1,
        :p_4,
        :rounded_xl,
        :border_1,
        {:border_color_hex, "#334155"},
        {:bg_hex, "#111827"},
        :shadow_md,
        :cursor_pointer
      ],
      hover_style: [{:bg_hex, "#1e293b"}],
      events: %{click: callback}
    )
  end

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
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy text clicks example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.TextClicksWindow.start_link(:ok)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
