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

  def handle_info({:set_count, count}, window) do
    {:noreply, assign(window, :count, count)}
  end
end

defmodule Guppy.WindowAssignsTemplateExample do
  use Guppy.Window

  @impl Guppy.Window
  def mount(_arg, window), do: {:ok, assign(window, :title, "Mounted title")}

  @impl Guppy.Window
  def render(window) do
    ~GUI"""
    <div id="window_assigns_template">
      <text id="window_assigns_title">{@title}</text>
    </div>
    """
  end
end

defmodule Guppy.NilAssignsWindowTemplateExample do
  use Guppy.Window

  @impl Guppy.Window
  def mount(_arg, window), do: {:ok, assign(window, :title, "Mounted title")}

  @impl Guppy.Window
  def render(window) do
    assigns = nil

    ~GUI"""
    <div id="nil_assigns_window_template">
      <text id="nil_assigns_window_title">{@title}</text>
    </div>
    """
  end
end

defmodule Guppy.AppContextWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(parent, window) do
    send(parent, {:app_context_mount, Guppy.App.current_app(), Guppy.App.current_window_id()})
    {:ok, assign(window, :parent, parent)}
  end

  @impl Guppy.Window
  def render(window) do
    send(
      window.assigns.parent,
      {:app_context_render, Guppy.App.current_app(), Guppy.App.current_window_id()}
    )

    Guppy.IR.text("app context window")
  end
end

defmodule Guppy.AppPlainWindow do
  use GenServer

  def start_link({:guppy_app_window, app, window_id, arg}, opts) do
    GenServer.start_link(__MODULE__, {app, window_id, arg}, opts)
  end

  def init(state), do: {:ok, state}
end

defmodule Guppy.ExitOnLastWindowApp do
  use Guppy.App,
    windows: [%{id: "plain", module: Guppy.AppPlainWindow, start: false}],
    exit_on_last_window_closed: true
end

defmodule Guppy.KeepAliveOnLastWindowApp do
  use Guppy.App,
    windows: [%{id: "plain", module: Guppy.AppPlainWindow, start: false}]
end

defmodule Guppy.ContextMenuFocusApp do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  @impl GenServer
  def init(opts), do: {:ok, %{parent: Keyword.fetch!(opts, :parent)}}

  @impl GenServer
  def handle_call(:commands, _from, state) do
    commands = %{
      "new_file" => %Guppy.App.Command{id: "new_file", label: "New File", enabled: true}
    }

    {:reply, commands, state}
  end

  def handle_call({:focus_window, window_id}, _from, state) do
    send(state.parent, {:fake_app_focus_window, window_id})
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:dispatch_command, command_id, payload}, state) do
    send(state.parent, {:fake_app_command, command_id, payload})
    {:noreply, state}
  end
end

defmodule Guppy.TestApp do
  use Guppy.App,
    windows: [
      %{id: "main", module: Guppy.AppContextWindow, start: false}
    ],
    theme: %{id: "test-dark", name: "Test Dark", appearance: :dark},
    stylesheet: %{
      classes: %{
        "card" => %{style: "p-2 bg-blue", hover_style: "bg-red"}
      }
    },
    commands: [%{id: "new_file", label: "New File"}],
    keymap: [%{key: "cmd-n", command: "new_file"}],
    menus: [%{label: "File", items: [%{id: "new_file", label: "New", callback: "new_file"}]}],
    dock_menu: [%{id: "new_file", label: "New", callback: "new_file"}],
    metadata: %{name: "Test App"},
    package: %{bundle_id: "dev.guppy.test"}

  @impl Guppy.App
  def init(opts) do
    parent = Keyword.fetch!(opts, :parent)

    opts =
      opts
      |> Keyword.delete(:parent)
      |> Keyword.put(:metadata, %{parent: parent})

    {:ok, opts}
  end

  @impl Guppy.App
  def handle_command(command_id, payload, state) do
    send(state.config.metadata.parent, {:app_command, command_id, payload})
    {:noreply, state}
  end

  @impl Guppy.App
  def handle_event(event_name, payload, state) do
    send(state.config.metadata.parent, {:app_event, event_name, payload})
    {:noreply, state}
  end
end

defmodule Guppy.CrashingNative do
  def request(_server, _request, _timeout), do: exit(:native_down)
end

defmodule Guppy.BlockingNative do
  # Models the Guppy.Native timeout contract: a request that cannot complete
  # in time returns {:error, :native_timeout} within its timeout instead of
  # blocking the caller indefinitely.
  def request(_server, _request, timeout) do
    Process.sleep(timeout)
    {:error, :native_timeout}
  end
end

defmodule Guppy.BrokenRenderWindow do
  use Guppy.Window

  @impl Guppy.Window
  def mount(:ok, window), do: {:ok, window}

  @impl Guppy.Window
  def render(_window), do: %{kind: :not_a_real_node}
end

defmodule Guppy.BuggyNative do
  # Raises a raw :badkey erlang error (not a struct raise) so the server's
  # ErlangError rescue/reraise branch is what gets exercised. The map comes
  # from the process dictionary to keep the type checker from proving the
  # lookup always fails and warning on every compile.
  def request(_server, {:ping, []}, _timeout) do
    Map.fetch!(Process.get(:guppy_buggy_native_map, %{}), :missing)
  end

  def request(_server, _request, _timeout), do: :ok
end

defmodule Guppy.TimeoutOpenNative do
  def request(test_pid, {:open_window, [view_id, _ir, _opts]}, _timeout) do
    send(test_pid, {:guppy_test_open_window, view_id})
    {:error, :native_timeout}
  end

  def request(test_pid, {:close_window, [view_id]}, _timeout) do
    send(test_pid, {:guppy_test_close_window, view_id})
    :ok
  end

  def request(_test_pid, _request, _timeout), do: :ok
end

defmodule Guppy.DialogBlockingNative do
  def request(test_pid, {dialog, [_opts]}, _timeout)
      when dialog in [:open_file_dialog, :save_file_dialog] do
    send(test_pid, {:guppy_test_dialog_started, dialog, self()})

    receive do
      {:guppy_test_dialog_release, reply} -> reply
    end
  end

  def request(_test_pid, _request, _timeout), do: :ok
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
    ~GUI"""
    <div id="root" tooltip="Template root" animation={@root_animation} class="flex flex-col gap-4 p-4 bg-[#0f172a] text-[#f8fafc]">
      <text id="title" class="text-3xl font-black">{@title}</text>
      <rich_text id="rich_intro" runs={@rich_runs} class="text-base col-span-[3] row-span-[2]" />
      <button id="save_button" click="save" class="p-2 rounded-lg border-1 border-blue bg-blue text-[#ffffff] col-span-full" focus_visible_class="border-yellow shadow-lg">
        Save
      </button>
      <checkbox id="tos_checkbox" checked="true" change="toggle_tos" class="gap-2 items-center">
        Accept terms
      </checkbox>
      <radio id="priority_high" value="high" checked={@priority == "high"} change="priority_changed" class="gap-2 items-center">
        High priority
      </radio>
      <icon id="release_icon" embedded="icons/release.svg" class="w-[24px] h-[24px]" />
      <image id="hero_image" uri="https://example.com/demo.png" class="w-[240px] h-[120px] rounded-lg object-cover grayscale" />
      <scroll id="items" axis="y" class="flex-1 gap-2">
        <div :for={item <- @items} id={"item_#{item.id}"} class="rounded-md border-1 border-white p-2">
          <text>{item.label}</text>
        </div>
      </scroll>
      <uniform_list id="virtual_items" items={@uniform_items} class="h-[120px]" item_class="p-2" click="uniform_item_clicked" context_menu="uniform_item_context" />
      <list id="generic_items" items={@generic_items} class="h-[140px]" item_class="p-2 border-b-1" click="generic_item_clicked" context_menu="generic_item_context" />
      <data_table id="task_table" columns={@table_columns} rows={@table_rows} selected_row_id={@selected_row_id} selected_cell={@selected_cell} sort_state={@table_sort} class="h-[140px]" header_class="p-2" row_class="border-b-1" cell_class="p-2" row_click="table_row_clicked" cell_click="table_cell_clicked" sort="table_sorted" column_reorder="table_column_reordered" column_resize="table_column_resized" row_context_menu="table_row_context" cell_context_menu="table_cell_context" />
      <tree id="task_tree" nodes={@tree_nodes} selected_id={@selected_tree_id} class="h-[140px]" row_class="p-2" select="tree_selected" toggle="tree_toggled" context_menu="tree_context_menu" />
      <canvas id="summary_canvas" commands={@canvas_commands} class="w-[120px] h-[80px]" click="canvas_clicked" context_menu="canvas_context_menu" />
      <popover id="help_popover" label="Help" open={@popover_open} click="open_help" close="close_help" popover_class="p-4" anchor="bottom_right" anchor_position_mode="local" anchor_fit="snap_to_window_with_margin" anchor_offset={{0, 12}} snap_margin="12" close_on_click_outside="false" stack_priority="2">
        <text>Popover content</text>
      </popover>
      <select id="status_select" value={@status} open={@status_open} options={@status_options} placeholder="Pick status" click="toggle_status" change="status_changed" close="close_status" class="w-[240px]" list_class="p-1 shadow-lg" option_class="p-2" anchor="bottom_left" anchor_offset={{0, 10}} anchor_fit="snap_to_window_with_margin" snap_margin="10" />
      <text_input id="name_input" value={@value} placeholder="Type here" class="w-[240px]" actions={@input_actions} shortcuts={@input_shortcuts} change="name_changed" focus="name_focused" blur="name_blurred" context_menu="name_context" />
      <textarea id="notes_input" value={@notes} placeholder="Notes" class="w-[240px] h-[120px]" change="notes_changed" focus="notes_focused" blur="notes_blurred" context_menu="notes_context" />
      {if @show_footer, do: Guppy.IR.text("Footer ready", id: "footer")}
    </div>
    """
  end
end

defmodule Guppy.TemplateTextExpressionExample do
  use Guppy.Component

  def render(assigns) do
    ~GUI"""
    <div id="text_expression_root">
      <text id="equals_spaced">count = {@count}</text>
      <text id="equals_tight">x={@x}</text>
    </div>
    """
  end
end

defmodule Guppy.GradientTemplateExample do
  use Guppy.Component

  def render(_assigns) do
    ~GUI"""
    <div id="gradient_template_root" class="bg-linear-gradient-[90,#0f172a:0,#2563eb:1] text-white">
      <text id="gradient_template_label">Gradient template</text>
    </div>
    """
  end
end

defmodule Guppy.DynamicClassTemplateExample do
  use Guppy.Component

  def render(assigns) do
    ~GUI"""
    <div id="dynamic_class_root" class={@classes} style={@style}>
      <text id="dynamic_class_label">Dynamic classes</text>
    </div>
    """
  end
end

defmodule Guppy.RemoteBadgeComponent do
  use Guppy.Component

  prop(:render, :id, :string, required: true)
  prop(:render, :label, :string, required: true)

  def render(assigns) do
    ~GUI"""
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
    ~GUI"""
    <div id="component_root" class="flex flex-col gap-2 p-2 bg-[#0f172a] text-[#f8fafc]">
      <.stat_card :for={item <- @items} id={"stat_#{item.id}"} title={item.title} value={item.value} />
      <.panel id="activity_panel">
        <text id="activity_text">Inner activity feed</text>
      </.panel>
      <Guppy.RemoteBadgeComponent id="release_badge" label="Beta ready" />
    </div>
    """
  end

  defp stat_card(assigns) do
    ~GUI"""
    <div id={@id} class="rounded-md border-1 border-white p-2">
      <text id={@id <> "_title"} class="text-sm font-bold">{@title}</text>
      <text id={@id <> "_value"}>{@value}</text>
    </div>
    """
  end

  defp panel(assigns) do
    ~GUI"""
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
    ~GUI"""
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
    ~GUI"""
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
