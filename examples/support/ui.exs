defmodule Examples.UI do
  @moduledoc """
  Shared example visual language. See `examples/STYLE.md` for the rules.

  Light neutral palette, one accent, native-feeling control metrics. Examples
  build their classes from these helpers so a palette change is one edit.
  """

  def window_bg, do: "#f5f5f7"
  def surface, do: "#ffffff"
  def hover, do: "#ececf0"
  def border, do: "#d2d2d7"
  def text, do: "#1d1d1f"
  def text_secondary, do: "#6e6e73"
  def accent, do: "#007aff"
  def accent_hover, do: "#0070e8"

  @doc "Root window container: column layout, window padding, palette."
  def window_class do
    "flex flex-col w-full h-full gap-4 p-5 bg-[#{window_bg()}] text-[#{text()}]"
  end

  def title_class, do: "text-lg font-semibold"
  def body_class, do: "text-sm"
  def caption_class, do: "text-xs text-[#{text_secondary()}]"

  def button_class do
    "px-3 py-1 rounded-md border-1 border-[#{border()}] bg-[#{surface()}] text-sm text-[#{text()}]"
  end

  def button_hover_class, do: "bg-[#{hover()}]"

  def primary_button_class do
    "px-3 py-1 rounded-md border-1 border-[#{accent()}] bg-[#{accent()}] text-sm text-[#ffffff]"
  end

  def primary_button_hover_class, do: "bg-[#{accent_hover()}]"

  @doc "Surface panel for content that needs real separation, such as a list."
  def panel_class do
    "flex flex-col rounded-md border-1 border-[#{border()}] bg-[#{surface()}]"
  end
end
