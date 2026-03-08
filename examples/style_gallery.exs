defmodule Examples.StyleGalleryWindow do
  use Guppy.Window
  use Guppy.Component

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

    swatches =
      Enum.map(@swatches, fn {name, swatch_label, swatch_bg, swatch_text, swatch_border} ->
        selected? = name == window.assigns.selected

        %{
          name: name,
          label: swatch_label,
          hint: if(selected?, do: "Selected", else: "Click to preview"),
          card_class:
            Enum.join(
              [
                "flex flex-col gap-1 p-4 rounded-xl border-2 shadow-sm cursor-pointer w-[156px]",
                "bg-[#{swatch_bg}]",
                "text-[#{swatch_text}]",
                "border-[#{if(selected?, do: "#f8fafc", else: swatch_border)}]"
              ],
              " "
            )
        }
      end)

    assigns =
      Map.merge(window.assigns, %{
        preview_label: label,
        preview_class:
          "flex flex-col gap-2 p-6 rounded-xl border-1 shadow-md border-[#{border_hex}] bg-[#{bg_hex}] text-[#{text_hex}]",
        swatches: swatches,
        info_rows: [
          %{
            id: "info_consistency",
            label: "Swatches use the same spacing and surface language as the other samples"
          },
          %{id: "info_preview", label: "The preview uses the selected color as a panel theme"},
          %{
            id: "info_window",
            label: "This example now uses Guppy.Window instead of a manual receive loop"
          }
        ]
      })

    ~G"""
    <div id="style_gallery_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="header_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="title" class="text-3xl font-black">Style gallery</text>
        <text id="subtitle" class="text-base text-[#94a3b8]">
          A consistent sample shell, clickable swatches, and a preview surface driven by window assigns.
        </text>
      </div>

      <div id="swatch_list" class="flex flex-row flex-wrap gap-2">
        <div :for={swatch <- @swatches} id={"swatch_#{swatch.name}"} click={"select:#{swatch.name}"} class={swatch.card_class} hover_style={[opacity: 0.9]}>
          <text id={"swatch_label_#{swatch.name}"} class="text-lg font-bold">{swatch.label}</text>
          <text id={"swatch_hint_#{swatch.name}"} class="text-sm">{swatch.hint}</text>
        </div>
      </div>

      <div id="preview" class={@preview_class}>
        <text id="preview_heading" class="text-sm font-semibold">Preview</text>
        <text id="selected_label" class="text-2xl font-black">{@preview_label}</text>
        <text id="preview_text" class="text-base">
          This panel inherits the selected swatch colors and rerenders immediately on click.
        </text>
      </div>

      <div id="info_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <div :for={row <- @info_rows} id={row.id <> "_row"} class="flex flex-row items-center gap-2">
          <div id={row.id <> "_dot"} class="w-[10px] h-[10px] rounded-full bg-[#60a5fa]"></div>
          <text id={row.id} class="flex-1 text-base">{row.label}</text>
        </div>
      </div>
    </div>
    """
  end

  defp selected_palette(name) do
    {^name, label, bg_hex, text_hex, border_hex} =
      Enum.find(@swatches, fn {swatch, _, _, _, _} -> swatch == name end)

    {label, bg_hex, text_hex, border_hex}
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
