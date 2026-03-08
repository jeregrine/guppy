{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy style gallery example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

contrast_text_color = fn
  color when color in [:yellow, :white, :green] -> :black
  _color -> :white
end

contrast_border_color = fn
  color when color in [:white, :yellow] -> :black
  _color -> :white
end

render = fn selected ->
  swatch = fn id, label, color ->
    Guppy.IR.div(
      [
        Guppy.IR.text(label, id: "#{id}_label", events: %{click: id})
      ],
      id: id,
      style: [
        :flex,
        :flex_col,
        :p_4,
        :rounded_md,
        :border_1,
        {:border_color, contrast_border_color.(color)},
        {:bg, color},
        {:text_color, contrast_text_color.(color)},
        :cursor_pointer
      ],
      events: %{click: id}
    )
  end

  Guppy.IR.div(
    [
      Guppy.IR.text("Style gallery", id: "title"),
      Guppy.IR.text("selected = #{selected}", id: "selected_label"),
      Guppy.IR.div(
        [
          swatch.("select_red", "Red", :red),
          swatch.("select_green", "Green", :green),
          swatch.("select_blue", "Blue", :blue)
        ],
        id: "swatch_list",
        style: [:flex, :flex_col, :gap_2]
      ),
      Guppy.IR.div(
        [
          Guppy.IR.text("Preview area", id: "preview_title"),
          Guppy.IR.text("Click a swatch above to change this block.", id: "preview_text")
        ],
        id: "preview",
        style: [
          :p_6,
          :rounded_md,
          :border_1,
          {:border_color, contrast_border_color.(selected)},
          {:bg, selected},
          {:text_color, contrast_text_color.(selected)}
        ]
      )
    ],
    id: "style_gallery_root",
    style: [:flex, :flex_col, :gap_2, :p_4]
  )
end

{:ok, view_id} = Guppy.open_window(render.(:gray), self())
IO.inspect(view_id, label: "opened_view_id")

loop = fn loop, selected ->
  receive do
    {:guppy_event, ^view_id, %{type: :click, callback: callback}}
    when callback in ["select_red", "select_green", "select_blue"] ->
      next_selected =
        case callback do
          "select_red" -> :red
          "select_green" -> :green
          "select_blue" -> :blue
        end

      :ok = Guppy.render(view_id, render.(next_selected))
      IO.puts("selected #{next_selected}")
      loop.(loop, next_selected)

    {:guppy_event, ^view_id, %{type: :window_closed}} ->
      IO.puts("window was closed manually")

    other ->
      IO.inspect(other, label: "unexpected_message")
      loop.(loop, selected)
  end
end

loop.(loop, :gray)
