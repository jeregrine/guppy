defmodule Guppy.ThemeFamilyTest do
  use ExUnit.Case

  alias Guppy.App.{Theme, ThemeFamily}

  test "theme family validation stores themes by id and preserves metadata" do
    assert {:ok, family} =
             ThemeFamily.validate(%{
               id: "demo",
               name: "Demo Themes",
               author: "Guppy",
               themes: [Theme.default(:dark), Theme.default(:light)],
               metadata: %{source: :test}
             })

    assert family.id == "demo"
    assert family.name == "Demo Themes"
    assert family.author == "Guppy"
    assert family.metadata == %{source: :test}
    assert Map.keys(family.themes) == ["guppy.dark", "guppy.light"]
    assert {:ok, %Theme{id: "guppy.dark"}} = ThemeFamily.get(family, "guppy.dark")
    assert {:ok, %Theme{id: "guppy.light"}} = ThemeFamily.get(family, :"guppy.light")
  end

  test "theme family validation rejects duplicate and invalid themes" do
    dark = Theme.default(:dark)

    assert {:error, {:duplicate_theme_id, "guppy.dark"}} =
             ThemeFamily.validate(%{
               id: "duplicates",
               name: "Duplicates",
               themes: [dark, dark]
             })

    assert {:error, {:invalid_theme_family, %{name: "Missing id", themes: []}}} =
             ThemeFamily.validate(%{name: "Missing id", themes: []})

    assert {:error, {:invalid_theme, %{id: "bad", name: "Bad", colors: %{x: :not_a_color}}}} =
             ThemeFamily.validate(%{
               id: "invalid-theme",
               name: "Invalid Theme",
               themes: [%{id: "bad", name: "Bad", colors: %{x: :not_a_color}}]
             })
  end
end
