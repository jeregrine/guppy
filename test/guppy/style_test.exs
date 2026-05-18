defmodule Guppy.StyleTest do
  use ExUnit.Case

  test "GPUI style catalog is checked in and included in package files" do
    catalog_path = Path.expand("../../data/gpui_style_catalog.json", __DIR__)

    assert File.exists?(catalog_path)

    assert %{"gpui_version" => "0.2.2", "operations" => operations} =
             catalog_path |> File.read!() |> JSON.decode!()

    assert Enum.any?(operations, &(&1["name"] == "padding"))
    assert Enum.any?(operations, &(&1["name"] == "margin"))
    assert Enum.any?(operations, &(&1["name"] == "gap"))
    assert Enum.any?(operations, &(&1["name"] == "width"))
    assert Enum.any?(operations, &(&1["name"] == "max_height"))
    assert Enum.any?(operations, &(&1["name"] == "position"))
    assert Enum.any?(operations, &(&1["name"] == "inset"))
    assert "data" in Mix.Project.config()[:package][:files]
  end

  test "length helpers are generated from the catalog as canonical tuple style ops" do
    assert Guppy.Style.padding(:y, {:rem, 0.25}) == {:padding, :y, {:rem, 0.25}}
    assert Guppy.Style.py(1) == {:padding, :y, {:rem, 0.25}}
    assert Guppy.Style.p(0.5) == {:padding, :all, {:rem, 0.125}}
    assert Guppy.Style.p("0p5") == {:padding, :all, {:rem, 0.125}}
    assert Guppy.Style.px("px") == {:padding, :x, {:px, 1}}

    assert Guppy.Style.margin(:x, :auto) == {:margin, :x, :auto}
    assert Guppy.Style.m(1) == {:margin, :all, {:rem, 0.25}}
    assert Guppy.Style.mx(-2) == {:margin, :x, {:rem, -0.5}}
    assert Guppy.Style.mt(:auto) == {:margin, :top, :auto}

    assert Guppy.Style.gap(:x, {:rem, 0.25}) == {:gap, :x, {:rem, 0.25}}
    assert Guppy.Style.gap(1) == {:gap, :all, {:rem, 0.25}}
    assert Guppy.Style.gap_x("px") == {:gap, :x, {:px, 1}}

    assert Guppy.Style.width({:px, 42}) == {:width, {:px, 42}}
    assert Guppy.Style.w("full") == {:width, {:fraction, 1}}
    assert Guppy.Style.w(:auto) == {:width, :auto}
    assert Guppy.Style.height({:rem, 2}) == {:height, {:rem, 2}}
    assert Guppy.Style.h(32) == {:height, {:rem, 8}}
    assert Guppy.Style.size(4) == {:size, {:rem, 1}}
    assert Guppy.Style.min_h(0) == {:min_height, {:px, 0}}
    assert Guppy.Style.max_w("1/2") == {:max_width, {:fraction, 0.5}}

    assert Guppy.Style.position(:relative) == {:position, :relative}
    assert Guppy.Style.relative() == {:position, :relative}
    assert Guppy.Style.absolute() == {:position, :absolute}
    assert Guppy.Style.inset(:all, {:px, 0}) == {:inset, :all, {:px, 0}}
    assert Guppy.Style.inset(1) == {:inset, :all, {:rem, 0.25}}
    assert Guppy.Style.top(-2) == {:inset, :top, {:rem, -0.5}}
    assert Guppy.Style.right(:auto) == {:inset, :right, :auto}
  end
end
