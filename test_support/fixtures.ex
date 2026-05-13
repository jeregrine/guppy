defmodule Guppy.TestCounterWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(initial_count, window) do
    {:ok, assign(window, :count, initial_count)}
  end

  @impl Guppy.Window
  def render(window) do
    count = window.assigns.count

    Guppy.IR.div(
      [
        Guppy.IR.text("count = #{count}", id: "count_label"),
        Guppy.IR.text("increment", id: "increment_text", events: %{click: "increment"})
      ],
      id: "increment_button",
      events: %{click: "increment"}
    )
  end

  @impl Guppy.Window
  def handle_event("increment", _event_data, window) do
    {:noreply, update(window, :count, &(&1 + 1))}
  end

  @impl Guppy.Window
  def handle_info({:set_count, count}, window) do
    {:noreply, assign(window, :count, count)}
  end
end

defmodule Guppy.CrashingNative do
  def request(_server, _request, _timeout), do: exit(:native_down)
end

defmodule Guppy.BlockingNative do
  def request(_server, _request, _timeout) do
    receive do
      :never -> :ok
    after
      :infinity -> :ok
    end
  end
end

defmodule Guppy.TimeoutRecordingNative do
  def request(server, request, timeout) do
    send(server, {:guppy_test_native_request, request, timeout})
    {:ok, :pong}
  end
end

defmodule Guppy.RestartRecordingNative do
  def request(agent, request, _timeout) do
    Agent.update(agent, fn state -> update_state(state, request) end)

    case request do
      {:ping, []} -> {:ok, :pong}
      {:view_count, []} -> {:ok, Agent.get(agent, &map_size(&1.views))}
      _ -> :ok
    end
  end

  defp update_state(state, {:set_event_target, [pid]}) do
    %{state | event_targets: state.event_targets ++ [pid], current_event_target: pid}
  end

  defp update_state(state, {:open_window, [view_id, _ir, _opts]}) do
    %{state | views: Map.put(state.views, view_id, true)}
  end

  defp update_state(state, {:render, [view_id, _ir]}) do
    %{state | renders: [view_id | state.renders]}
  end

  defp update_state(state, {:close_window, [view_id]}) do
    %{state | views: Map.delete(state.views, view_id)}
  end

  defp update_state(state, {:close_all, []}) do
    %{state | views: %{}, close_all_count: state.close_all_count + 1}
  end

  defp update_state(state, request) do
    %{state | unknown_requests: [request | state.unknown_requests]}
  end
end

defmodule Guppy.TemplateExample do
  use Guppy.Component

  def render(assigns) do
    ~G"""
    <div id="root" tooltip="Template root" class="flex flex-col gap-4 p-4 bg-[#0f172a] text-[#f8fafc]">
      <text id="title" class="text-3xl font-black">{@title}</text>
      <rich_text id="rich_intro" runs={@rich_runs} class="text-base" />
      <button id="save_button" click="save" class="p-2 rounded-lg border-1 border-blue bg-blue text-[#ffffff]" focus_visible_class="border-yellow shadow-lg">
        Save
      </button>
      <checkbox id="tos_checkbox" checked="true" change="toggle_tos" class="gap-2 items-center">
        Accept terms
      </checkbox>
      <radio id="priority_high" value="high" checked={@priority == "high"} change="priority_changed" class="gap-2 items-center">
        High priority
      </radio>
      <icon id="release_icon" embedded="icons/release.svg" class="w-[24px] h-[24px]" />
      <image id="hero_image" uri="https://example.com/demo.png" object_fit="cover" grayscale="true" class="w-[240px] h-[120px] rounded-lg" />
      <scroll id="items" axis="y" class="flex-1 gap-2">
        <div :for={item <- @items} id={"item_#{item.id}"} class="rounded-md border-1 border-white p-2">
          <text>{item.label}</text>
        </div>
      </scroll>
      <uniform_list id="virtual_items" items={@uniform_items} class="h-[120px]" item_class="p-2" click="uniform_item_clicked" />
      <list id="generic_items" items={@generic_items} class="h-[140px]" item_class="p-2 border-b-1" click="generic_item_clicked" />
      <popover id="help_popover" label="Help" open={@popover_open} click="open_help" close="close_help" popover_class="p-4" anchor="bottom_right" anchor_position_mode="local" anchor_fit="snap_to_window_with_margin" anchor_offset={{0, 12}} snap_margin="12" close_on_click_outside="false" stack_priority="2">
        <text>Popover content</text>
      </popover>
      <select id="status_select" value={@status} open={@status_open} options={@status_options} placeholder="Pick status" click="toggle_status" change="status_changed" close="close_status" class="w-[240px]" list_class="p-1 shadow-lg" option_class="p-2" />
      <text_input id="name_input" value={@value} placeholder="Type here" class="w-[240px]" change="name_changed" focus="name_focused" blur="name_blurred" />
      <textarea id="notes_input" value={@notes} placeholder="Notes" class="w-[240px] h-[120px]" change="notes_changed" focus="notes_focused" blur="notes_blurred" />
      {if @show_footer, do: Guppy.IR.text("Footer ready", id: "footer")}
    </div>
    """
  end
end

defmodule Guppy.RemoteBadgeComponent do
  use Guppy.Component

  prop(:render, :id, :string, required: true)
  prop(:render, :label, :string, required: true)

  def render(assigns) do
    ~G"""
    <div id={@id} class="rounded-md border-1 border-blue p-2 bg-[#172554] text-[#dbeafe]">
      <text id={@id <> "_label"}>{@label}</text>
    </div>
    """
  end
end

defmodule Guppy.FunctionComponentExample do
  use Guppy.Component

  prop(:render, :items, :list, required: true)
  prop(:stat_card, :id, :string, required: true)
  prop(:stat_card, :title, :string, required: true)
  prop(:stat_card, :value, :string, required: true)
  prop(:panel, :id, :string, required: true)

  def render(assigns) do
    ~G"""
    <div id="component_root" class="flex flex-col gap-2 p-2 bg-[#0f172a] text-[#f8fafc]">
      <stat_card :for={item <- @items} id={"stat_#{item.id}"} title={item.title} value={item.value} />
      <panel id="activity_panel">
        <text id="activity_text">Inner activity feed</text>
      </panel>
      <Guppy.RemoteBadgeComponent id="release_badge" label="Beta ready" />
    </div>
    """
  end

  defp stat_card(assigns) do
    ~G"""
    <div id={@id} class="rounded-md border-1 border-white p-2">
      <text id={@id <> "_title"} class="text-sm font-bold">{@title}</text>
      <text id={@id <> "_value"}>{@value}</text>
    </div>
    """
  end

  defp panel(assigns) do
    ~G"""
    <div id={@id} class="rounded-md border-1 border-gray p-2">
      {@children}
    </div>
    """
  end
end

defmodule Guppy.ComponentPropsExample do
  use Guppy.Component

  prop(:render, :title, :string, required: true)
  prop(:render, :tone, {:one_of, [:info, :warning]}, default: :info)

  def render(assigns) do
    ~G"""
    <div id="props_root" class="flex flex-col gap-2 p-2 bg-[#0f172a] text-[#f8fafc]">
      <text id="props_title">{@title}</text>
      <text id="props_tone">{@tone}</text>
    </div>
    """
  end
end

defmodule Guppy.ComponentPropsTagCaller do
  use Guppy.Component

  def render(assigns) do
    ~G"""
    <Guppy.ComponentPropsExample title={@title} />
    """
  end
end

defmodule Guppy.TestSupport do
  @moduledoc false

  import ExUnit.Assertions

  def forward_telemetry(event, measurements, metadata, parent) do
    send(parent, {:telemetry_event, event, measurements, metadata})
  end

  def attach_forwarding_telemetry(handler_id, event_name, parent \\ self()) do
    :telemetry.attach(handler_id, event_name, &__MODULE__.forward_telemetry/4, parent)
  end

  def native_view_count! do
    case Guppy.native_view_count() do
      {:ok, count} -> count
      other -> flunk("expected native view count, got: #{inspect(other)}")
    end
  end

  def maybe_close(view_id) do
    case Guppy.close_window(view_id) do
      :ok -> :ok
      {:error, :unknown_view_id} -> :ok
      {:error, :nif_not_loaded} -> :ok
    end
  end

  def wait_until(fun, timeout \\ 1_000) do
    started_at = System.monotonic_time(:millisecond)
    do_wait_until(fun, timeout, started_at)
  end

  defp do_wait_until(fun, timeout, started_at) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) - started_at > timeout do
        flunk("condition not met within #{timeout}ms")
      else
        Process.sleep(10)
        do_wait_until(fun, timeout, started_at)
      end
    end
  end
end
