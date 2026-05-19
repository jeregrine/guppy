defmodule Guppy.ThemeTest do
  use ExUnit.Case

  alias Guppy.App.Theme

  test "theme validation normalizes semantic colors and resolves theme style refs" do
    assert {:ok, theme} =
             Theme.validate(%{
               id: "demo-dark",
               name: "Demo Dark",
               appearance: :dark,
               colors: %{
                 "surface" => "#0f172a",
                 text: :white,
                 accent: "#2563eb"
               },
               styles: %{
                 "card" => [
                   "p-4 rounded-lg",
                   {:theme_color, :bg, :surface},
                   {:theme_color, :text_color, "text"},
                   {:theme_color, :border_color, :accent}
                 ]
               }
             })

    assert theme.colors == %{"accent" => "#2563eb", "surface" => "#0f172a", "text" => :white}
    assert {:ok, "#0f172a"} = Theme.color(theme, :surface)
    assert {:ok, :white} = Theme.color(theme, "text")

    assert Guppy.Style.theme_color(:bg, :surface) == {:theme_color, :bg, :surface}

    assert {:ok, style} = Theme.style(theme, :card)
    assert {:padding, :all, {:rem, 1}} in style
    assert {:border_radius, :all, {:rem, 0.5}} in style
    assert {:bg_hex, "#0f172a"} in style
    assert {:text_color, :white} in style
    assert {:border_color_hex, "#2563eb"} in style
  end

  test "theme validation rejects invalid color and style references" do
    assert {:error, {:invalid_theme_color, {"surface", "blue-ish"}}} =
             Theme.validate(%{id: "bad", name: "Bad", colors: %{surface: "blue-ish"}})

    assert {:error, {:unknown_theme_color, "missing"}} =
             Theme.validate(%{
               id: "bad-style",
               name: "Bad Style",
               colors: %{surface: "#0f172a"},
               styles: %{card: [{:theme_color, :bg, :missing}]}
             })

    assert {:error, {:invalid_theme_color_role, :position}} =
             Theme.validate(%{
               id: "bad-role",
               name: "Bad Role",
               colors: %{surface: "#0f172a"},
               styles: %{card: [{:theme_color, :position, :surface}]}
             })
  end

  test "themes can refine defaults with explicit color and style overrides" do
    base = Theme.default(:dark)

    assert {:ok, refined} =
             Theme.refine(base,
               id: "custom-dark",
               name: "Custom Dark",
               colors: %{surface: "#111827", accent: :green},
               styles: %{badge: ["px-2", {:theme_color, :bg, :accent}]},
               metadata: %{source: :test}
             )

    assert refined.id == "custom-dark"
    assert refined.name == "Custom Dark"
    assert refined.appearance == :dark
    assert refined.metadata == %{source: :test}
    assert {:ok, "#111827"} = Theme.color(refined, :surface)
    assert {:ok, :green} = Theme.color(refined, :accent)
    assert {:ok, window_style} = Theme.style(refined, :window)
    assert {:bg_hex, "#0f172a"} in window_style
    assert {:ok, badge_style} = Theme.style(refined, :badge)
    assert {:bg, :green} in badge_style
  end

  test "built-in light and dark themes expose semantic defaults" do
    assert %Theme{id: "guppy.dark", appearance: :dark} = dark = Theme.default(:dark)
    assert %Theme{id: "guppy.light", appearance: :light} = light = Theme.default(:light)

    assert {:ok, "#0f172a"} = Theme.color(dark, :background)
    assert {:ok, "#ffffff"} = Theme.color(light, :background)

    assert {:ok, dark_window_style} = Theme.style(dark, :window)
    assert {:bg_hex, "#0f172a"} in dark_window_style
    assert {:text_color_hex, "#f8fafc"} in dark_window_style
  end
end
