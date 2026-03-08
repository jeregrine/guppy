defmodule Examples.TextClicksWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(:ok, window) do
    {:ok,
     window
     |> put_window_opts(
       window_bounds: [width: 760, height: 620],
       titlebar: [title: "Guppy text clicks"]
     )
     |> assign(:status, "Waiting for a click")}
  end

  @impl Guppy.Window
  def handle_event("line_one", _event_data, window) do
    IO.puts("clicked line one")
    {:noreply, assign(window, :status, "Clicked the first line")}
  end

  def handle_event("line_two", _event_data, window) do
    IO.puts("clicked line two")
    {:noreply, assign(window, :status, "Clicked the second line")}
  end

  @impl Guppy.Window
  def render(window) do
    assigns =
      Map.merge(window.assigns, %{
        rows: [
          %{
            id: "line_one",
            title: "First line",
            body: "Use a clickable text node as the primary action."
          },
          %{
            id: "line_two",
            title: "Second line",
            body: "Wire a different callback through the same window process."
          }
        ]
      })

    ~G"""
    <div id="text_click_root" class="flex flex-col w-full h-full gap-4 p-6 bg-[#0f172a] text-[#f8fafc]">
      <div id="header_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md">
        <text id="title" class="text-3xl font-black">Text clicks</text>
        <text id="subtitle" class="text-base text-[#94a3b8]">
          Text nodes can emit click events, and the surrounding layout can still look like a proper sample app.
        </text>
      </div>

      <div id="status_panel" class="flex flex-col gap-2 p-4 rounded-xl border-1 border-[#2563eb] bg-[#172554] shadow-md">
        <text id="status_heading" class="text-sm font-semibold text-[#bfdbfe]">Status</text>
        <text id="status" class="text-2xl font-black">{@status}</text>
        <text id="status_help" class="text-base text-[#dbeafe]">
          Click either row below to update this state label.
        </text>
      </div>

      <div id="choices" class="flex flex-col gap-2">
        <div :for={row <- @rows} id={row.id <> "_row"} click={row.id} class="flex flex-col gap-1 p-4 rounded-xl border-1 border-[#334155] bg-[#111827] shadow-md cursor-pointer" hover_class="bg-[#1e293b]">
          <text id={row.id <> "_title"} class="text-lg font-bold">{row.title}</text>
          <text id={row.id} click={row.id}>{row.body}</text>
        </div>
      </div>
    </div>
    """
  end
end

{:ok, _} = Application.ensure_all_started(:guppy)

IO.puts("Guppy text clicks example")
IO.inspect(Guppy.Native.Nif.load_status(), label: "load_status")
IO.inspect(Guppy.native_build_info(), label: "native_build_info")
IO.inspect(Guppy.native_runtime_status(), label: "native_runtime_status")
IO.inspect(Guppy.native_gui_status(), label: "native_gui_status")

{:ok, pid} = Examples.TextClicksWindow.start_link(:ok)
IO.inspect(Guppy.Window.view_id(pid), label: "opened_view_id")

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, ^pid, _reason} ->
    :ok
end
