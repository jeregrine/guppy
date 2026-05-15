defmodule Examples.MarkdownViewWindow do
  use Guppy.Window

  @history_limit 30
  @heading_id_prefix "markdown_heading"
  @metadata_path "/tmp/guppy_markdownview_metadata.etf"
  @plus_icon_path "/tmp/guppy_markdownview_plus.svg"

  # Flexoki light palette: https://github.com/kepano/flexoki
  @base_800 "#403E3C"
  @blue_400 "#4385BE"

  @impl Guppy.Window
  def mount(argv, window) do
    ensure_plus_icon!()
    metadata = load_metadata()
    history = Map.fetch!(metadata, :history)
    initial_path = initial_path(argv, metadata)

    window =
      window
      |> put_window_opts(
        window_bounds: [width: 1320, height: 820],
        window_min_size: [width: 960, height: 640],
        titlebar: [
          title: "MarkdownView",
          appears_transparent: true,
          traffic_light_position: [x: 14, y: 13]
        ]
      )
      |> assign(:history, history)
      |> assign(:current_path, nil)
      |> assign(:plus_icon_path, @plus_icon_path)
      |> assign(:source, welcome_source())
      |> assign(:outline_headings, [])
      |> assign(:selected_heading_id, nil)
      |> assign(:scroll_target_id, nil)
      |> assign(:status, nil)
      |> maybe_open_initial_path(initial_path)

    _ = Guppy.set_menus(menu_spec())
    {:ok, window}
  end

  @impl Guppy.Window
  def handle_event("open_history:" <> index_text, _event, window) do
    with {index, ""} <- Integer.parse(index_text),
         %{path: path} <- Enum.at(window.assigns.history, index) do
      {:noreply, open_path(window, path)}
    else
      _ -> {:noreply, assign(window, :status, "That history item is no longer available.")}
    end
  end

  def handle_event("open_file", _event, window) do
    {:noreply, open_file(window)}
  end

  def handle_event("select_outline:" <> heading_id, _event, window) do
    Process.send_after(self(), {:clear_scroll_target, heading_id}, 100)

    {:noreply,
     window
     |> assign(:selected_heading_id, heading_id)
     |> assign(:scroll_target_id, heading_id)}
  end

  def handle_info({:guppy_menu_event, %{callback: "open_file"}}, window) do
    {:noreply, open_file(window)}
  end

  def handle_info({:clear_scroll_target, heading_id}, window) do
    if window.assigns.scroll_target_id == heading_id do
      {:noreply, assign(window, :scroll_target_id, nil)}
    else
      {:noreply, window, :skip_render}
    end
  end

  @impl Guppy.Window
  def render(window) do
    assigns =
      Map.merge(window.assigns, %{
        filename: filename(window.assigns.current_path),
        path_label: path_label(window.assigns.current_path),
        history_entries: history_entries(window.assigns.history, window.assigns.current_path),
        history_count_label: count_label(window.assigns.history, "file"),
        heading_id_prefix: @heading_id_prefix,
        outline_rows:
          outline_rows(window.assigns.outline_headings, window.assigns.selected_heading_id),
        outline_title:
          outline_title(window.assigns.current_path, window.assigns.outline_headings),
        outline_count_label: count_label(window.assigns.outline_headings, "heading")
      })

    ~GUI"""
    <div id="markdownview_root" class="flex flex-col w-full h-full bg-[#FFFCF0] text-[#403E3C]">
      <div id="top_header" class="flex flex-row items-center justify-between p-1 border-b-1 border-[#E6E4D9] bg-[#FFFCF0]">
        <div id="traffic_light_spacer" class="w-[74px] flex-shrink-0" />
        <div id="title_block" class="flex flex-col gap-1 flex-1 w-[0px]">
          <text id="current_filename" class="text-lg font-black text-[#100F0F]">{@filename}</text>
          <text id="current_path" class="text-xs text-[#6F6E69]">{@path_label}</text>
        </div>
        <div id="open_file_button" click="open_file" tooltip="Open Markdown file" class="w-[36px] h-[36px] rounded-full border-1 border-[#DAD8CE] bg-[#F2F0E5] cursor-pointer flex items-center justify-center" hover_class="bg-[#E6E4D9]">
          <icon id="open_file_plus_icon" path={@plus_icon_path} class="w-[18px] h-[18px]" />
        </div>
      </div>

      <div id="workspace" class="flex flex-row flex-1 min-h-0">
        <div id="history_column" class="flex flex-col flex-shrink-0 w-[300px] min-h-0 p-4 gap-2 border-r-1 border-[#E6E4D9] bg-[#F2F0E5]">
          <div id="history_header" class="flex flex-row items-center justify-between">
            <text class="text-sm font-bold text-[#878580]">HISTORY</text>
            <text class="text-xs text-[#9F9D96]">{@history_count_label}</text>
          </div>

          <scroll id="history_scroll" axis="y" class="flex-1 min-h-0">
            <div id="history_rows" class="flex flex-col gap-1">
              <div :if={@history_entries == []} id="empty_history" class="p-2 rounded-lg border-1 border-[#DAD8CE] bg-[#FFFCF0]">
                <text class="text-sm text-[#6F6E69]">Open a Markdown file to build history.</text>
              </div>

              <div :for={entry <- @history_entries} id={entry.id} click={entry.callback} class={entry.row_class}>
                <text class={entry.title_class}>{entry.title}</text>
                <text class={entry.path_class}>{entry.path_label}</text>
              </div>
            </div>
          </scroll>
        </div>

        <div id="viewer_column" class="flex flex-col flex-1 flex-shrink w-[0px] min-h-0 overflow-hidden bg-[#FFFCF0]">
          <scroll id="markdown_scroll" axis="y" class="flex-1 min-h-0 p-6">
            <div id="markdown_page" class="flex flex-col gap-4 w-full max-w-full overflow-hidden">
              <div :if={@status != nil} id="status_banner" class="p-4 rounded-lg border-1 border-[#DAD8CE] bg-[#F2F0E5]">
                <text class="text-sm text-[#AF3029]">{@status}</text>
              </div>

              {Guppy.Markdown.render(%{source: @source, id: "markdown_document", style: markdown_style(), selected_heading_id: @selected_heading_id, scroll_target_id: @scroll_target_id, heading_id_prefix: @heading_id_prefix})}
            </div>
          </scroll>
        </div>

        <div id="outline_column" class="flex flex-col flex-shrink-0 w-[280px] min-h-0 p-4 gap-2 border-l-1 border-[#E6E4D9] bg-[#F2F0E5]">
          <div id="outline_header" class="flex flex-row items-center justify-between">
            <text class="text-sm font-bold text-[#878580]">ON THIS PAGE</text>
            <text class="text-xs text-[#9F9D96]">{@outline_count_label}</text>
          </div>

          <div id="outline_document_header" class="p-2 rounded-lg border-1 border-[#DAD8CE] bg-[#FFFCF0]">
            <text id="outline_document_title" class="text-sm font-bold text-[#403E3C]">{@outline_title}</text>
          </div>

          <scroll :if={@outline_rows != []} id="outline_scroll" axis="y" class="flex-1 min-h-0">
            <div id="outline_rows" class="flex flex-col gap-1">
              <div :for={row <- @outline_rows} id={row.id} click={row.callback} class={row.row_class} hover_class="bg-[#E6E4D9]">
                <div id={row.indent_id} style={row.indent_style} />
                <text id={row.label_id} class={row.label_class}>{row.label}</text>
              </div>
            </div>
          </scroll>

          <div :if={@outline_rows == []} id="empty_outline" class="p-4 rounded-lg border-1 border-[#DAD8CE] bg-[#FFFCF0]">
            <text class="text-sm text-[#6F6E69]">No headings found.</text>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp menu_spec do
    [
      %{label: "MarkdownView", items: []},
      %{
        label: "File",
        items: [
          %{id: "open_markdown", label: "Open...", callback: "open_file", shortcut: "cmd-o"}
        ]
      }
    ]
  end

  defp ensure_plus_icon! do
    File.write!(@plus_icon_path, """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#403E3C" stroke-width="2.5" stroke-linecap="round">
      <path d="M12 5v14"/>
      <path d="M5 12h14"/>
    </svg>
    """)
  end

  defp maybe_open_initial_path(window, nil), do: window

  defp maybe_open_initial_path(window, path) do
    if File.regular?(Path.expand(path)) do
      open_path(window, path)
    else
      window
    end
  end

  defp open_file(window) do
    case choose_markdown_file() do
      {:ok, path} ->
        open_path(window, path)

      :cancel ->
        assign(window, :status, "Open cancelled.")

      {:error, reason} ->
        assign(window, :status, "Could not open file picker: #{reason}")
    end
  end

  defp open_path(window, path) do
    path = Path.expand(path)

    case File.read(path) do
      {:ok, source} ->
        headings = outline_headings(source)
        selected = headings |> List.first() |> then(&if(&1, do: &1.id, else: nil))
        history = remember_path(window.assigns.history, path)

        window =
          window
          |> assign(:current_path, path)
          |> assign(:source, source)
          |> assign(:outline_headings, headings)
          |> assign(:selected_heading_id, selected)
          |> assign(:scroll_target_id, nil)
          |> assign(:history, history)
          |> assign(:status, nil)

        save_metadata(window)
        window

      {:error, reason} ->
        assign(window, :status, "Could not read #{compact_path(path)}: #{file_error(reason)}")
    end
  end

  defp choose_markdown_file do
    with osascript when is_binary(osascript) <- System.find_executable("osascript") do
      args = [
        "-e",
        ~S(set theFile to choose file with prompt "Open Markdown file"),
        "-e",
        "POSIX path of theFile"
      ]

      case System.cmd(osascript, args, stderr_to_stdout: true) do
        {path, 0} ->
          path = String.trim(path)
          if path == "", do: :cancel, else: {:ok, path}

        {message, _status} ->
          message = String.trim(message)

          if String.contains?(message, "User canceled") do
            :cancel
          else
            {:error, message}
          end
      end
    else
      _ -> {:error, "osascript is not available on this machine"}
    end
  end

  defp initial_path(argv, metadata) do
    case argv do
      [path | _] -> path
      _ -> metadata.current_path || first_history_path(metadata.history) || default_path()
    end
  end

  defp first_history_path([%{path: path} | _]), do: path
  defp first_history_path(_), do: nil

  defp default_path do
    Path.expand("README.md")
  end

  defp load_metadata do
    with {:ok, binary} <- File.read(@metadata_path),
         %{history: history} = metadata <- :erlang.binary_to_term(binary, [:safe]) do
      %{
        history: normalize_history(history),
        current_path: normalize_path(metadata[:current_path])
      }
    else
      _ -> %{history: [], current_path: nil}
    end
  rescue
    _ -> %{history: [], current_path: nil}
  end

  defp save_metadata(window) do
    metadata = %{
      current_path: window.assigns.current_path,
      history: Enum.map(window.assigns.history, &Map.take(&1, [:path, :opened_at]))
    }

    File.write(@metadata_path, :erlang.term_to_binary(metadata))
  end

  defp normalize_history(history) when is_list(history) do
    history
    |> Enum.flat_map(fn
      %{path: path} = entry when is_binary(path) ->
        [%{path: Path.expand(path), opened_at: Map.get(entry, :opened_at)}]

      path when is_binary(path) ->
        [%{path: Path.expand(path), opened_at: nil}]

      _ ->
        []
    end)
    |> Enum.uniq_by(& &1.path)
    |> Enum.take(@history_limit)
  end

  defp normalize_history(_), do: []

  defp normalize_path(path) when is_binary(path), do: Path.expand(path)
  defp normalize_path(_), do: nil

  defp remember_path(history, path) do
    entry = %{
      path: path,
      opened_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }

    [entry | Enum.reject(history, &same_path?(&1.path, path))]
    |> Enum.take(@history_limit)
  end

  defp outline_headings(source) do
    source
    |> parse_markdown_blocks()
    |> Enum.flat_map(&heading_from_block/1)
    |> Enum.with_index(1)
    |> Enum.map(fn {heading, index} ->
      Map.put(heading, :id, "#{@heading_id_prefix}_#{index}")
    end)
  end

  defp parse_markdown_blocks(source) do
    :shell_docs_markdown.parse_md(source)
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  defp heading_from_block({tag, _attrs, children}) when tag in [:h1, :h2, :h3, :h4, :h5, :h6] do
    [%{level: heading_level(tag), label: inline_plain_text(children)}]
  end

  defp heading_from_block(_), do: []

  defp heading_level(tag) do
    tag |> Atom.to_string() |> String.trim_leading("h") |> String.to_integer()
  end

  defp inline_plain_text(children) when is_list(children) do
    children
    |> Enum.map_join("", &inline_plain_text/1)
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp inline_plain_text(text) when is_binary(text), do: text

  defp inline_plain_text({_tag, _attrs, children}) when is_list(children),
    do: inline_plain_text(children)

  defp inline_plain_text(_), do: ""

  defp outline_rows(headings, selected_id) do
    Enum.map(headings, fn heading ->
      selected? = heading.id == selected_id

      %{
        id: "outline_row_#{heading.id}",
        indent_id: "outline_indent_#{heading.id}",
        label_id: "outline_label_#{heading.id}",
        callback: "select_outline:#{heading.id}",
        label: heading.label,
        indent_style: [{:w_px, outline_indent_px(heading.level)}, :flex_shrink_0],
        row_class: outline_row_class(selected?),
        label_class: outline_label_class(heading, selected?)
      }
    end)
  end

  defp outline_indent_px(level), do: max(level - 1, 0) * 12

  defp outline_row_class(true),
    do: "flex flex-row items-center gap-2 p-2 rounded-md cursor-pointer bg-[#E6E4D9]"

  defp outline_row_class(false),
    do: "flex flex-row items-center gap-2 p-2 rounded-md cursor-pointer bg-[#F2F0E5]"

  defp outline_label_class(%{level: level}, true) when level <= 2,
    do: "text-sm font-bold text-[#205EA6] line-clamp-2"

  defp outline_label_class(_heading, true),
    do: "text-sm font-semibold text-[#205EA6] line-clamp-2"

  defp outline_label_class(%{level: level}, false) when level <= 2,
    do: "text-sm font-bold text-[#575653] line-clamp-2"

  defp outline_label_class(_heading, false),
    do: "text-sm font-medium text-[#6F6E69] line-clamp-2"

  defp history_entries(history, current_path) do
    history
    |> Enum.with_index()
    |> Enum.map(fn {%{path: path}, index} ->
      selected? = same_path?(path, current_path)

      %{
        id: "history_#{index}",
        callback: "open_history:#{index}",
        title: Path.basename(path),
        path_label: compact_path(path),
        row_class: history_row_class(selected?),
        title_class: history_title_class(selected?),
        path_class: history_path_class(selected?)
      }
    end)
  end

  defp history_row_class(true),
    do: "flex flex-col gap-1 p-2 rounded-lg cursor-pointer bg-[#{@blue_400}]"

  defp history_row_class(false),
    do: "flex flex-col gap-1 p-2 rounded-lg cursor-pointer bg-[#F2F0E5]"

  defp history_title_class(true), do: "text-sm font-bold text-[#FFFCF0] truncate"
  defp history_title_class(false), do: "text-sm font-bold text-[#403E3C] truncate"
  defp history_path_class(true), do: "text-xs text-[#FFFCF0] truncate"
  defp history_path_class(false), do: "text-xs text-[#6F6E69] truncate"

  defp markdown_style do
    [
      :flex,
      :flex_col,
      :gap_4,
      :w_full,
      :max_w_full,
      :overflow_hidden,
      {:text_color_hex, @base_800}
    ]
  end

  defp filename(nil), do: "MarkdownView"
  defp filename(path), do: Path.basename(path)

  defp outline_title(_path, [%{label: label} | _]) when is_binary(label) and label != "",
    do: label

  defp outline_title(path, _headings) when is_binary(path), do: Path.basename(path)
  defp outline_title(_path, _headings), do: "Document tree"

  defp path_label(nil), do: "Use File > Open to choose a Markdown file"
  defp path_label(path), do: compact_path(path)

  defp compact_path(path) do
    path = path |> Path.expand() |> abbreviate_home()
    max = 58

    if String.length(path) > max do
      "..." <> String.slice(path, String.length(path) - max + 3, max - 3)
    else
      path
    end
  end

  defp abbreviate_home(path) do
    home = System.user_home!()
    String.replace_prefix(path, home, "~")
  end

  defp same_path?(a, b) when is_binary(a) and is_binary(b), do: Path.expand(a) == Path.expand(b)
  defp same_path?(_, _), do: false

  defp count_label(items, singular) do
    count = length(items)
    if count == 1, do: "1 #{singular}", else: "#{count} #{singular}s"
  end

  defp file_error(reason) when is_atom(reason),
    do: reason |> :file.format_error() |> List.to_string()

  defp file_error(reason), do: inspect(reason)

  defp welcome_source do
    """
    # MarkdownView

    Use **File > Open** to choose a Markdown file.

    The left column keeps recent files in `/tmp`, this center column renders Markdown with `Guppy.Markdown`, and the right column shows the document heading tree.
    """
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy MarkdownView")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.MarkdownViewWindow.start_link(System.argv())
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")
IO.puts("metadata: /tmp/guppy_markdownview_metadata.etf")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    # _ = Guppy.set_menus([])
    :ok
end
