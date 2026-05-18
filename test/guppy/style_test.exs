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
    assert Enum.any?(operations, &(&1["name"] == "display"))
    assert Enum.any?(operations, &(&1["name"] == "visibility"))
    assert Enum.any?(operations, &(&1["name"] == "overflow"))
    assert Enum.any?(operations, &(&1["name"] == "cursor"))
    assert Enum.any?(operations, &(&1["name"] == "border_width"))
    assert Enum.any?(operations, &(&1["name"] == "border_radius"))
    assert Enum.any?(operations, &(&1["name"] == "border_style"))
    assert Enum.any?(operations, &(&1["name"] == "bg"))
    assert Enum.any?(operations, &(&1["name"] == "text_color"))
    assert Enum.any?(operations, &(&1["name"] == "border_color"))
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

    assert Guppy.Style.display(:flex) == {:display, :flex}
    assert Guppy.Style.flex() == {:display, :flex}
    assert Guppy.Style.hidden() == {:display, :none}
    assert Guppy.Style.visibility(:hidden) == {:visibility, :hidden}
    assert Guppy.Style.invisible() == {:visibility, :hidden}
    assert Guppy.Style.visible() == {:visibility, :visible}
    assert Guppy.Style.overflow(:x, :scroll) == {:overflow, :x, :scroll}
    assert Guppy.Style.overflow_hidden() == {:overflow, :all, :hidden}

    assert Guppy.Style.cursor(:pointer) == {:cursor, :pointer}
    assert Guppy.Style.cursor_pointer() == {:cursor, :pointer}
    assert Guppy.Style.cursor_not_allowed() == {:cursor, :not_allowed}

    assert Guppy.Style.border_width(:x, {:px, 1}) == {:border_width, :x, {:px, 1}}
    assert Guppy.Style.border(2) == {:border_width, :all, {:px, 2}}
    assert Guppy.Style.border_x(4) == {:border_width, :x, {:px, 4}}
    assert Guppy.Style.border_t("px") == {:border_width, :top, {:px, 1}}
    assert Guppy.Style.border_style(:dashed) == {:border_style, :dashed}
    assert Guppy.Style.border_dashed() == {:border_style, :dashed}
    assert Guppy.Style.border_solid() == {:border_style, :solid}

    assert Guppy.Style.border_radius(:top_left, {:px, 3}) ==
             {:border_radius, :top_left, {:px, 3}}

    assert Guppy.Style.rounded("sm") == {:border_radius, :all, {:rem, 0.25}}
    assert Guppy.Style.rounded_t("lg") == {:border_radius, :top, {:rem, 0.5}}
    assert Guppy.Style.rounded_br("full") == {:border_radius, :bottom_right, {:px, 9999}}

    assert Guppy.Style.bg(:red) == {:bg, :red}
    assert Guppy.Style.bg_gray() == {:bg, :gray}
    assert Guppy.Style.text_color(:blue) == {:text_color, :blue}
    assert Guppy.Style.text_color_white() == {:text_color, :white}
    assert Guppy.Style.border_color(:yellow) == {:border_color, :yellow}
    assert Guppy.Style.border_color_black() == {:border_color, :black}
  end
end
