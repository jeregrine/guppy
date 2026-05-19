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
    assert Enum.any?(operations, &(&1["name"] == "aspect_ratio"))
    assert Enum.any?(operations, &(&1["name"] == "position"))
    assert Enum.any?(operations, &(&1["name"] == "inset"))
    assert Enum.any?(operations, &(&1["name"] == "display"))
    assert Enum.any?(operations, &(&1["name"] == "visibility"))
    assert Enum.any?(operations, &(&1["name"] == "overflow"))
    assert Enum.any?(operations, &(&1["name"] == "allow_concurrent_scroll"))
    assert Enum.any?(operations, &(&1["name"] == "restrict_scroll_to_axis"))
    assert Enum.any?(operations, &(&1["name"] == "cursor"))
    assert Enum.any?(operations, &(&1["name"] == "border_width"))
    assert Enum.any?(operations, &(&1["name"] == "border_radius"))
    assert Enum.any?(operations, &(&1["name"] == "border_style"))
    assert Enum.any?(operations, &(&1["name"] == "bg"))
    assert Enum.any?(operations, &(&1["name"] == "text_color"))
    assert Enum.any?(operations, &(&1["name"] == "text_bg"))
    assert Enum.any?(operations, &(&1["name"] == "border_color"))
    assert Enum.any?(operations, &(&1["name"] == "bg_hex"))
    assert Enum.any?(operations, &(&1["name"] == "text_color_hex"))
    assert Enum.any?(operations, &(&1["name"] == "text_bg_hex"))
    assert Enum.any?(operations, &(&1["name"] == "border_color_hex"))
    assert Enum.any?(operations, &(&1["name"] == "bg_linear_gradient"))
    assert Enum.any?(operations, &(&1["name"] == "opacity"))
    assert Enum.any?(operations, &(&1["name"] == "scrollbar_width"))
    assert Enum.any?(operations, &(&1["name"] == "shadow"))
    assert Enum.any?(operations, &(&1["name"] == "flex_direction"))
    assert Enum.any?(operations, &(&1["name"] == "flex_wrap"))
    assert Enum.any?(operations, &(&1["name"] == "flex_item"))
    assert Enum.any?(operations, &(&1["name"] == "flex_basis"))
    assert Enum.any?(operations, &(&1["name"] == "flex_grow"))
    assert Enum.any?(operations, &(&1["name"] == "flex_shrink"))
    assert Enum.any?(operations, &(&1["name"] == "align_items"))
    assert Enum.any?(operations, &(&1["name"] == "align_self"))
    assert Enum.any?(operations, &(&1["name"] == "justify_content"))
    assert Enum.any?(operations, &(&1["name"] == "align_content"))
    assert Enum.any?(operations, &(&1["name"] == "text_align"))
    assert Enum.any?(operations, &(&1["name"] == "white_space"))
    assert Enum.any?(operations, &(&1["name"] == "text_overflow"))
    assert Enum.any?(operations, &(&1["name"] == "font_size"))
    assert Enum.any?(operations, &(&1["name"] == "text_size"))
    assert Enum.any?(operations, &(&1["name"] == "line_height"))
    assert Enum.any?(operations, &(&1["name"] == "font_weight"))
    assert Enum.any?(operations, &(&1["name"] == "font_style"))
    assert Enum.any?(operations, &(&1["name"] == "font_family"))
    assert Enum.any?(operations, &(&1["name"] == "font_fallbacks"))
    assert Enum.any?(operations, &(&1["name"] == "font_features"))
    assert Enum.any?(operations, &(&1["name"] == "text_decoration"))
    assert Enum.any?(operations, &(&1["name"] == "text_decoration_color"))
    assert Enum.any?(operations, &(&1["name"] == "text_decoration_color_hex"))
    assert Enum.any?(operations, &(&1["name"] == "text_decoration_style"))
    assert Enum.any?(operations, &(&1["name"] == "text_decoration_thickness"))
    assert Enum.any?(operations, &(&1["name"] == "line_clamp"))
    assert Enum.any?(operations, &(&1["name"] == "grid_cols"))
    assert Enum.any?(operations, &(&1["name"] == "grid_rows"))
    assert Enum.any?(operations, &(&1["name"] == "col_start"))
    assert Enum.any?(operations, &(&1["name"] == "col_end"))
    assert Enum.any?(operations, &(&1["name"] == "row_start"))
    assert Enum.any?(operations, &(&1["name"] == "row_end"))
    assert Enum.any?(operations, &(&1["name"] == "col_span"))
    assert Enum.any?(operations, &(&1["name"] == "row_span"))
    assert Enum.any?(operations, &(&1["name"] == "object_fit"))
    assert Enum.any?(operations, &(&1["name"] == "grayscale"))
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
    assert Guppy.Style.aspect_ratio(1.5) == {:aspect_ratio, 1.5}
    assert_raise ArgumentError, fn -> Guppy.Style.aspect_ratio(0) end

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
    assert Guppy.Style.overflow(:y, :clip) == {:overflow, :y, :clip}
    assert Guppy.Style.overflow_hidden() == {:overflow, :all, :hidden}
    assert Guppy.Style.overflow_visible() == {:overflow, :all, :visible}
    assert Guppy.Style.overflow_x_clip() == {:overflow, :x, :clip}
    assert Guppy.Style.allow_concurrent_scroll(true) == {:allow_concurrent_scroll, true}
    assert Guppy.Style.allow_concurrent_scroll() == {:allow_concurrent_scroll, true}
    assert Guppy.Style.disallow_concurrent_scroll() == {:allow_concurrent_scroll, false}
    assert Guppy.Style.restrict_scroll_to_axis(true) == {:restrict_scroll_to_axis, true}
    assert Guppy.Style.restrict_scroll_to_axis() == {:restrict_scroll_to_axis, true}
    assert Guppy.Style.allow_cross_axis_scroll() == {:restrict_scroll_to_axis, false}
    assert_raise ArgumentError, fn -> Guppy.Style.allow_concurrent_scroll(:yes) end

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
    assert Guppy.Style.text_bg(:yellow) == {:text_bg, :yellow}
    assert Guppy.Style.text_bg_gray() == {:text_bg, :gray}
    assert Guppy.Style.border_color(:yellow) == {:border_color, :yellow}
    assert Guppy.Style.border_color_black() == {:border_color, :black}
    assert Guppy.Style.bg_hex("#0f172a") == {:bg_hex, "#0f172a"}
    assert Guppy.Style.text_color_hex("445566") == {:text_color_hex, "445566"}
    assert Guppy.Style.text_bg_hex("112233") == {:text_bg_hex, "112233"}
    assert Guppy.Style.border_color_hex("#abcdef") == {:border_color_hex, "#abcdef"}

    gradient = [angle: 90, from: {"#0f172a", 0}, to: {:blue, 1}]
    assert Guppy.Style.bg_linear_gradient(gradient) == {:bg_linear_gradient, gradient}

    assert Guppy.Style.opacity(0.5) == {:opacity, 0.5}
    assert_raise ArgumentError, fn -> Guppy.Style.opacity(1.5) end
    assert Guppy.Style.scrollbar_width({:px, 12}) == {:scrollbar_width_px, 12}
    assert Guppy.Style.scrollbar_width({:rem, 1.0}) == {:scrollbar_width_rem, 1.0}
    assert_raise ArgumentError, fn -> Guppy.Style.scrollbar_width({:fraction, 1}) end

    assert Guppy.Style.shadow(:md) == {:shadow, :md}
    assert Guppy.Style.shadow_md() == {:shadow, :md}
    assert Guppy.Style.shadow_2xs() == {:shadow, :"2xs"}
    assert Guppy.Style.shadow_none() == {:shadow, :none}

    assert Guppy.Style.flex_direction(:column) == {:flex_direction, :column}
    assert Guppy.Style.flex_col() == {:flex_direction, :column}
    assert Guppy.Style.flex_row_reverse() == {:flex_direction, :row_reverse}
    assert Guppy.Style.flex_wrap(:wrap) == {:flex_wrap, :wrap}
    assert Guppy.Style.flex_wrap() == {:flex_wrap, :wrap}
    assert Guppy.Style.flex_nowrap() == {:flex_wrap, :nowrap}
    assert Guppy.Style.flex_item(:one) == {:flex_item, :one}
    assert Guppy.Style.flex_1() == {:flex_item, :one}
    assert Guppy.Style.flex_initial() == {:flex_item, :initial}
    assert Guppy.Style.flex_basis(:auto) == {:flex_basis, :auto}
    assert Guppy.Style.basis("1/2") == {:flex_basis, {:fraction, 0.5}}
    assert Guppy.Style.flex_grow(2) == {:flex_grow, 2}
    assert Guppy.Style.flex_shrink(0.5) == {:flex_shrink, 0.5}
    assert_raise ArgumentError, fn -> Guppy.Style.flex_grow(-1) end
    assert Guppy.Style.items_baseline() == {:align_items, :baseline}
    assert Guppy.Style.items_stretch() == {:align_items, :stretch}
    assert Guppy.Style.align_self(:start) == {:align_self, :start}
    assert Guppy.Style.self_stretch() == {:align_self, :stretch}
    assert Guppy.Style.justify_between() == {:justify_content, :between}
    assert Guppy.Style.justify_evenly() == {:justify_content, :evenly}
    assert Guppy.Style.justify_stretch() == {:justify_content, :stretch}
    assert Guppy.Style.content_evenly() == {:align_content, :evenly}

    assert Guppy.Style.text_align(:center) == {:text_align, :center}
    assert Guppy.Style.text_center() == {:text_align, :center}
    assert Guppy.Style.white_space(:nowrap) == {:white_space, :nowrap}
    assert Guppy.Style.whitespace_nowrap() == {:white_space, :nowrap}
    assert Guppy.Style.text_overflow(:truncate) == {:text_overflow, :truncate}
    assert Guppy.Style.truncate() == {:text_overflow, :truncate}
    assert Guppy.Style.text_ellipsis() == {:text_overflow, :ellipsis}
    assert Guppy.Style.font_size(:xl) == {:font_size, :xl}
    assert Guppy.Style.text_2xl() == {:font_size, :"2xl"}
    assert Guppy.Style.text_size({:px, 14}) == {:text_size, {:px, 14}}
    assert Guppy.Style.text_size({:rem, 1.25}) == {:text_size, {:rem, 1.25}}
    assert_raise ArgumentError, fn -> Guppy.Style.text_size({:fraction, 1}) end
    assert Guppy.Style.line_height(:tight) == {:line_height, :tight}
    assert Guppy.Style.leading_relaxed() == {:line_height, :relaxed}
    assert Guppy.Style.font_weight(:bold) == {:font_weight, :bold}
    assert Guppy.Style.font_black() == {:font_weight, :black}
    assert Guppy.Style.font_style(:italic) == {:font_style, :italic}
    assert Guppy.Style.italic() == {:font_style, :italic}
    assert Guppy.Style.not_italic() == {:font_style, :normal}
    assert Guppy.Style.font_family("Monaco") == {:font_family, "Monaco"}
    assert_raise ArgumentError, fn -> Guppy.Style.font_family("") end

    assert Guppy.Style.font_fallbacks(["Monaco", "Menlo"]) ==
             {:font_fallbacks, ["Monaco", "Menlo"]}

    assert_raise ArgumentError, fn -> Guppy.Style.font_fallbacks([]) end
    assert_raise ArgumentError, fn -> Guppy.Style.font_fallbacks([""]) end

    assert Guppy.Style.font_features([{"calt", 0}, {"kern", 1}]) ==
             {:font_features, [{"calt", 0}, {"kern", 1}]}

    assert Guppy.Style.disable_ligatures() == {:font_features, [{"calt", 0}]}
    assert_raise ArgumentError, fn -> Guppy.Style.font_features([]) end
    assert_raise ArgumentError, fn -> Guppy.Style.font_features([{"bad", 1}]) end
    assert Guppy.Style.text_decoration(:underline) == {:text_decoration, :underline}
    assert Guppy.Style.underline() == {:text_decoration, :underline}
    assert Guppy.Style.no_underline() == {:text_decoration, :none}
    assert Guppy.Style.text_decoration_color(:red) == {:text_decoration_color, :red}
    assert Guppy.Style.decoration_blue() == {:text_decoration_color, :blue}

    assert Guppy.Style.text_decoration_color_hex("#abcdef") ==
             {:text_decoration_color_hex, "#abcdef"}

    assert Guppy.Style.text_decoration_style(:wavy) == {:text_decoration_style, :wavy}
    assert Guppy.Style.decoration_wavy() == {:text_decoration_style, :wavy}
    assert Guppy.Style.text_decoration_thickness(2) == {:text_decoration_thickness, 2}
    assert_raise ArgumentError, fn -> Guppy.Style.text_decoration_thickness(-1) end
    assert Guppy.Style.line_clamp(2) == {:line_clamp, 2}
    assert_raise ArgumentError, fn -> Guppy.Style.line_clamp(0) end

    assert Guppy.Style.grid_cols(3) == {:grid_cols, 3}
    assert Guppy.Style.grid_rows(2) == {:grid_rows, 2}
    assert Guppy.Style.col_start(2) == {:col_start, 2}
    assert Guppy.Style.col_end(:auto) == {:col_end, :auto}
    assert Guppy.Style.row_start(-1) == {:row_start, -1}
    assert Guppy.Style.row_end(:auto) == {:row_end, :auto}
    assert_raise ArgumentError, fn -> Guppy.Style.col_start(40_000) end
    assert Guppy.Style.col_span(4) == {:col_span, 4}
    assert Guppy.Style.row_span(5) == {:row_span, 5}

    assert Guppy.Style.object_fit(:cover) == {:object_fit, :cover}
    assert Guppy.Style.object_cover() == {:object_fit, :cover}
    assert Guppy.Style.object_scale_down() == {:object_fit, :scale_down}
    assert Guppy.Style.grayscale() == {:grayscale, true}
    assert Guppy.Style.grayscale(false) == {:grayscale, false}
    assert Guppy.Style.not_grayscale() == {:grayscale, false}
  end

  test "image-only catalog class tokens normalize to image options" do
    assert Guppy.Style.class_token_to_image_option("object-contain") ==
             {:ok, {:object_fit, :contain}}

    assert Guppy.Style.class_token_to_image_option("grayscale") == {:ok, {:grayscale, true}}
    assert Guppy.Style.class_token_to_image_option("grayscale-0") == {:ok, {:grayscale, false}}
    assert Guppy.Style.class_token_to_image_option("p-2") == :error
  end

  test "hex color classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("bg-[#0f172a]") == {:ok, {:bg_hex, "#0f172a"}}

    assert Guppy.Style.class_token_to_style("text-[#445566]") ==
             {:ok, {:text_color_hex, "#445566"}}

    assert Guppy.Style.class_token_to_style("text-bg-[#112233]") ==
             {:ok, {:text_bg_hex, "#112233"}}

    assert Guppy.Style.class_token_to_style("border-[#abcdef]") ==
             {:ok, {:border_color_hex, "#abcdef"}}

    assert Guppy.Style.class_token_to_style("bg-[#12]") == :error
  end

  test "background gradient classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("bg-linear-gradient-[90,#0f172a:0,#2563eb:1]") ==
             {:ok, {:bg_linear_gradient, [angle: 90, from: {"#0f172a", 0}, to: {"#2563eb", 1}]}}

    assert Guppy.Style.class_token_to_style("bg-linear-gradient-[90,red:0,blue:1]") ==
             {:ok, {:bg_linear_gradient, [angle: 90, from: {:red, 0}, to: {:blue, 1}]}}

    assert Guppy.Style.class_token_to_style("bg-linear-gradient-[bad]") == :error
  end

  test "opacity classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("opacity-50") == {:ok, {:opacity, 0.5}}
    assert Guppy.Style.class_token_to_style("opacity-[0.42]") == {:ok, {:opacity, 0.42}}
    assert Guppy.Style.class_token_to_style("opacity-[1.5]") == :error
  end

  test "line-clamp classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("line-clamp-2") == {:ok, {:line_clamp, 2}}
    assert Guppy.Style.class_token_to_style("line-clamp-[4]") == {:ok, {:line_clamp, 4}}
    assert Guppy.Style.class_token_to_style("line-clamp-0") == :error
  end

  test "scrollbar width classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("scrollbar-w-[12px]") ==
             {:ok, {:scrollbar_width_px, 12}}

    assert Guppy.Style.class_token_to_style("scrollbar-w-[1.5rem]") ==
             {:ok, {:scrollbar_width_rem, 1.5}}

    assert Guppy.Style.class_token_to_style("scrollbar-w-2") == :error
  end

  test "grid line placement classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("col-start-2") == {:ok, {:col_start, 2}}
    assert Guppy.Style.class_token_to_style("-col-end-1") == {:ok, {:col_end, -1}}
    assert Guppy.Style.class_token_to_style("row-start-auto") == {:ok, {:row_start, :auto}}
    assert Guppy.Style.class_token_to_style("row-end-[-1]") == {:ok, {:row_end, -1}}
    assert Guppy.Style.class_token_to_style("col-start-[40000]") == :error
  end

  test "flex basis classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("basis-1/2") == {:ok, {:flex_basis, {:fraction, 0.5}}}
    assert Guppy.Style.class_token_to_style("basis-[12px]") == {:ok, {:flex_basis, {:px, 12}}}
    assert Guppy.Style.class_token_to_style("basis-auto") == {:ok, {:flex_basis, :auto}}
    assert Guppy.Style.class_token_to_style("-basis-1") == :error
  end

  test "font family classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("font-family-[Monaco]") ==
             {:ok, {:font_family, "Monaco"}}

    assert Guppy.Style.class_token_to_style("font-family-[]") == :error
  end

  test "arbitrary text size classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("text-[14px]") == {:ok, {:text_size, {:px, 14}}}
    assert Guppy.Style.class_token_to_style("text-[1.25rem]") == {:ok, {:text_size, {:rem, 1.25}}}
    assert Guppy.Style.class_token_to_style("text-[50%]") == :error
    assert Guppy.Style.class_token_to_style("text-[-1px]") == :error
  end

  test "font fallback classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("font-fallbacks-[Monaco,Menlo]") ==
             {:ok, {:font_fallbacks, ["Monaco", "Menlo"]}}

    assert Guppy.Style.class_token_to_style("font-fallbacks-[Monaco]") ==
             {:ok, {:font_fallbacks, ["Monaco"]}}

    assert Guppy.Style.class_token_to_style("font-fallbacks-[]") == :error
    assert Guppy.Style.class_token_to_style("font-fallbacks-[Monaco,]") == :error
  end

  test "font feature classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("font-features-[calt=0,kern=1]") ==
             {:ok, {:font_features, [{"calt", 0}, {"kern", 1}]}}

    assert Guppy.Style.class_token_to_style("font-features-[liga=false]") ==
             {:ok, {:font_features, [{"liga", 0}]}}

    assert Guppy.Style.class_token_to_style("font-ligatures-none") ==
             {:ok, {:font_features, [{"calt", 0}]}}

    assert Guppy.Style.class_token_to_style("font-features-[]") == :error
    assert Guppy.Style.class_token_to_style("font-features-[bad=1]") == :error
  end

  test "aspect ratio classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("aspect-square") == {:ok, {:aspect_ratio, 1}}

    assert Guppy.Style.class_token_to_style("aspect-video") ==
             {:ok, {:aspect_ratio, 16 / 9}}

    assert Guppy.Style.class_token_to_style("aspect-[1.5]") == {:ok, {:aspect_ratio, 1.5}}
    assert Guppy.Style.class_token_to_style("aspect-[0]") == :error
  end

  test "alignment edge classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("items-stretch") == {:ok, {:align_items, :stretch}}
    assert Guppy.Style.class_token_to_style("self-start") == {:ok, {:align_self, :start}}
    assert Guppy.Style.class_token_to_style("self-stretch") == {:ok, {:align_self, :stretch}}

    assert Guppy.Style.class_token_to_style("justify-evenly") ==
             {:ok, {:justify_content, :evenly}}

    assert Guppy.Style.class_token_to_style("justify-stretch") ==
             {:ok, {:justify_content, :stretch}}
  end

  test "overflow edge classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("overflow-visible") ==
             {:ok, {:overflow, :all, :visible}}

    assert Guppy.Style.class_token_to_style("overflow-x-clip") == {:ok, {:overflow, :x, :clip}}

    assert Guppy.Style.class_token_to_style("scroll-concurrent") ==
             {:ok, {:allow_concurrent_scroll, true}}

    assert Guppy.Style.class_token_to_style("scroll-concurrent-off") ==
             {:ok, {:allow_concurrent_scroll, false}}

    assert Guppy.Style.class_token_to_style("scroll-axis-restricted") ==
             {:ok, {:restrict_scroll_to_axis, true}}

    assert Guppy.Style.class_token_to_style("scroll-axis-free") ==
             {:ok, {:restrict_scroll_to_axis, false}}
  end

  test "flex grow and shrink classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("grow") == {:ok, {:flex_grow, 1}}
    assert Guppy.Style.class_token_to_style("grow-0") == {:ok, {:flex_grow, 0}}
    assert Guppy.Style.class_token_to_style("grow-[2]") == {:ok, {:flex_grow, 2}}
    assert Guppy.Style.class_token_to_style("shrink") == {:ok, {:flex_shrink, 1}}
    assert Guppy.Style.class_token_to_style("shrink-0") == {:ok, {:flex_shrink, 0}}
    assert Guppy.Style.class_token_to_style("shrink-[0.5]") == {:ok, {:flex_shrink, 0.5}}
    assert Guppy.Style.class_token_to_style("grow-[-1]") == :error
  end

  test "text decoration detail classes normalize through the catalog parser" do
    assert Guppy.Style.class_token_to_style("decoration-red") ==
             {:ok, {:text_decoration_color, :red}}

    assert Guppy.Style.class_token_to_style("decoration-[#abcdef]") ==
             {:ok, {:text_decoration_color_hex, "#abcdef"}}

    assert Guppy.Style.class_token_to_style("decoration-wavy") ==
             {:ok, {:text_decoration_style, :wavy}}

    assert Guppy.Style.class_token_to_style("decoration-2") ==
             {:ok, {:text_decoration_thickness, 2}}

    assert Guppy.Style.class_token_to_style("decoration-[3.5]") ==
             {:ok, {:text_decoration_thickness, 3.5}}

    assert Guppy.Style.class_token_to_style("decoration-[bad]") == :error
  end
end
