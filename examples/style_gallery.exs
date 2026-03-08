defmodule Examples.StyleGalleryWindow do
  use Guppy.Window

  import Guppy.Window, only: [assign: 3, put_window_opts: 2]

  @swatches [
    {:slate, "Slate", "#475569", "#f8fafc", "#64748b"},
    {:red, "Red", "#dc2626", "#fef2f2", "#ef4444"},
    {:green, "Green", "#16a34a", "#f0fdf4", "#22c55e"},
    {:blue, "Blue", "#2563eb", "#eff6ff", "#3b82f6"},
    {:amber, "Amber", "#d97706", "#fffbeb", "#f59e0b"}
  ]

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 960, height: 760],
       titlebar: [title: "Guppy style gallery"]
     )
     |> assign(:selected, :slate)}
  end

  @impl Guppy.Window
  def handle_event("select:" <> color_name, _event_data, window) do
    selected = String.to_existing_atom(color_name)
    IO.puts("selected #{selected}")
    {:noreply, assign(window, :selected, selected)}
  end

  @impl Guppy.Window
  def render(window) do
    {label, bg_hex, text_hex, border_hex} = selected_palette(window.assigns.selected)

    Guppy.IR.div(
      [
        panel(
          [
            Guppy.IR.div([Guppy.IR.text("Style gallery", id: "title")],
              style: [:text_3xl, :font_black]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text(
                  "A consistent sample shell, clickable swatches, and a preview surface driven by window assigns.",
                  id: "subtitle"
                )
              ],
              style: [:text_base, {:text_color_hex, "#94a3b8"}]
            )
          ],
          id: "header_panel"
        ),
        Guppy.IR.div(
          Enum.map(@swatches, &swatch_card(&1, window.assigns.selected)),
          id: "swatch_list",
          style: [:flex, :flex_row, :flex_wrap, :gap_2]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.div([Guppy.IR.text("Preview", id: "preview_heading")],
              style: [:text_sm, :font_semibold]
            ),
            Guppy.IR.div([Guppy.IR.text(label, id: "selected_label")],
              style: [:text_2xl, :font_black]
            ),
            Guppy.IR.div(
              [
                Guppy.IR.text(
                  "This panel inherits the selected swatch colors and rerenders immediately on click.",
                  id: "preview_text"
                )
              ],
              style: [:text_base]
            )
          ],
          id: "preview",
          style: [
            :flex,
            :flex_col,
            :gap_2,
            :p_6,
            :rounded_xl,
            :border_1,
            {:border_color_hex, border_hex},
            {:bg_hex, bg_hex},
            {:text_color_hex, text_hex},
            :shadow_md
          ]
        ),
        panel(
          [
            info_row(
              "Swatches use the same spacing and surface language as the other samples",
              "info_consistency"
            ),
            info_row("The preview uses the selected color as a panel theme", "info_preview"),
            info_row(
              "This example now uses Guppy.Window instead of a manual receive loop",
              "info_window"
            )
          ],
          id: "info_panel"
        )
      ],
      id: "style_gallery_root",
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

  defp swatch_card({name, label, bg_hex, text_hex, border_hex}, selected) do
    selected? = name == selected

    Guppy.IR.div(
      [
        Guppy.IR.div([Guppy.IR.text(label, id: "swatch_label_#{name}")],
          style: [:text_lg, :font_bold]
        ),
        Guppy.IR.div(
          [
            Guppy.IR.text(if(selected?, do: "Selected", else: "Click to preview"),
              id: "swatch_hint_#{name}"
            )
          ],
          style: [:text_sm]
        )
      ],
      id: "swatch_#{name}",
      style: [
        :flex,
        :flex_col,
        :gap_1,
        :p_4,
        :rounded_xl,
        :border_2,
        {:border_color_hex, if(selected?, do: "#f8fafc", else: border_hex)},
        {:bg_hex, bg_hex},
        {:text_color_hex, text_hex},
        :shadow_sm,
        :cursor_pointer,
        {:w_px, 156}
      ],
      hover_style: [{:opacity, 0.9}],
      events: %{click: "select:#{name}"}
    )
  end

  defp selected_palette(name) do
    {^name, label, bg_hex, text_hex, border_hex} =
      Enum.find(@swatches, fn {swatch, _, _, _, _} -> swatch == name end)

    {label, bg_hex, text_hex, border_hex}
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

IO.puts("Guppy style gallery example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.StyleGalleryWindow.start_link(:ok)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
