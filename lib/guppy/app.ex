defmodule Guppy.App do
  @moduledoc """
  Optional application-level coordinator for larger Guppy apps.

  `Guppy.Window` remains the per-window abstraction and can still be started on
  its own. `Guppy.App` adds one OTP boundary for app-global configuration,
  resource slots, command/menu dispatch, and app-supervised windows.

      defmodule MyApp do
        use Guppy.App,
          windows: [
            %{id: "main", module: MyApp.MainWindow, arg: %{}}
          ],
          commands: [%{id: "new_file", label: "New File"}],
          menus: [%{label: "File", items: [%{id: "new_file", label: "New", callback: "new_file"}]}]

        @impl Guppy.App
        def handle_command("new_file", _payload, state) do
          {:noreply, state}
        end
      end

  App modules usually start under the module name as the registered coordinator
  process, similar to `Ecto.Repo`. The process is non-rendering; windows remain
  `Guppy.Window` modules.
  """

  alias Guppy.App.{Config, Coordinator, Stylesheet}

  @type app_ref :: GenServer.server()

  @callback init(keyword()) ::
              map()
              | keyword()
              | Config.t()
              | {:ok, map() | keyword() | Config.t()}
              | {:stop, term()}
  @callback handle_command(String.t(), map(), Coordinator.state()) ::
              Coordinator.callback_result()
  @callback handle_info(term(), Coordinator.state()) :: Coordinator.callback_result()

  @optional_callbacks init: 1, handle_command: 3, handle_info: 2

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Guppy.App
      @guppy_app_defaults opts

      def child_spec(arg) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [arg]},
          type: :supervisor,
          restart: :permanent,
          shutdown: :infinity
        }
      end

      defoverridable child_spec: 1

      def start_link(opts \\ []) do
        Guppy.App.start_link(__MODULE__, Keyword.merge(@guppy_app_defaults, opts))
      end

      def __guppy_app_defaults__, do: @guppy_app_defaults
    end
  end

  @doc "Starts an app supervisor and a registered app coordinator."
  def start_link(module, opts \\ []) when is_atom(module) and is_list(opts) do
    supervisor_name = supervisor_name(module)
    window_supervisor_name = window_supervisor_name(module)

    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: window_supervisor_name},
      {Coordinator,
       module: module,
       name: Keyword.get(opts, :name, module),
       config: opts,
       app_supervisor: supervisor_name,
       window_supervisor: window_supervisor_name,
       runtime_server: Keyword.get(opts, :runtime_server, Guppy.Server)}
    ]

    Supervisor.start_link(children, strategy: :one_for_all, name: supervisor_name)
  end

  @doc "Returns the validated app configuration."
  def config(app \\ nil), do: call(app, :config)

  @doc "Returns known app window ids and pids."
  def windows(app \\ nil), do: call(app, :windows)

  @doc "Returns the pid for an app-owned window id, or nil."
  def window_pid(app, window_id), do: call(app, {:window_pid, window_id})

  @doc "Opens a configured or dynamic app window by string id."
  def open_window(app, window_id, overrides \\ [], timeout \\ 30_000)

  def open_window(app, window_id, overrides, timeout)
      when is_binary(window_id) and is_list(overrides) do
    call(app, {:open_window, window_id, overrides}, timeout)
  end

  @doc "Closes an app-owned window by string id."
  def close_window(app, window_id) when is_binary(window_id) do
    call(app, {:close_window, window_id})
  end

  @doc "Dispatches an app command asynchronously."
  def dispatch(app, command_id, payload \\ %{}) when is_binary(command_id) and is_map(payload) do
    GenServer.cast(app || current_app!(), {:dispatch_command, command_id, payload})
  end

  @doc "Dispatches the command bound to an app keymap entry, if any."
  def dispatch_key(app, key, payload \\ %{}) when is_binary(key) and is_map(payload) do
    GenServer.cast(app || current_app!(), {:dispatch_key, key, payload})
  end

  @doc "Opens the built-in command-palette overlay for an app."
  def open_command_palette(app \\ nil) do
    app = app || current_app!()

    open_window(
      app,
      "__command_palette__",
      [
        module: Guppy.App.CommandPalette,
        arg: app,
        opts: [kind: :popup, focus: true, show: true],
        restart: :temporary
      ],
      30_000
    )
  end

  @doc "Returns the active app theme."
  def theme(app \\ nil), do: call(app, :theme)

  @doc "Replaces the app theme after validation."
  def set_theme(app, theme), do: call(app, {:set_theme, theme})

  @doc "Returns the app stylesheet cache."
  def stylesheet(app \\ nil), do: call(app, :stylesheet)

  @doc "Replaces the app stylesheet cache after validation."
  def set_stylesheet(app, stylesheet), do: call(app, {:set_stylesheet, stylesheet})

  @doc "Resolves app stylesheet class references to style option keyword entries."
  def styles(app, class_refs), do: app |> stylesheet() |> Stylesheet.resolve(class_refs)

  @doc "Returns command registry entries keyed by id."
  def commands(app \\ nil), do: call(app, :commands)

  @doc "Replaces the app command registry after validation."
  def set_commands(app, commands), do: call(app, {:set_commands, commands})

  @doc "Returns app keymap entries."
  def keymap(app \\ nil), do: call(app, :keymap)

  @doc "Replaces app keymap entries after validation against commands."
  def set_keymap(app, keymap), do: call(app, {:set_keymap, keymap})

  @doc "Returns app-owned menus."
  def menus(app \\ nil), do: call(app, :menus)

  @doc "Installs app-owned native menus."
  def set_menus(app, menus), do: call(app, {:set_menus, menus})

  @doc "Returns packaging/signing metadata hooks stored in app config."
  def package(app \\ nil), do: call(app, :package)

  @doc false
  def put_window_context(app, window_id) do
    Process.put(:guppy_app, app)
    Process.put(:guppy_app_window_id, window_id)
    :ok
  end

  @doc "Returns the app ref for the current app-supervised window process, if any."
  def current_app, do: Process.get(:guppy_app)

  @doc "Returns the app window id for the current app-supervised window process, if any."
  def current_window_id, do: Process.get(:guppy_app_window_id)

  @doc false
  def supervisor_name(module), do: Module.concat(module, Supervisor)

  @doc false
  def window_supervisor_name(module), do: Module.concat(module, WindowSupervisor)

  defp call(app, message, timeout \\ 5_000)
  defp call(nil, message, timeout), do: GenServer.call(current_app!(), message, timeout)
  defp call(app, message, timeout), do: GenServer.call(app, message, timeout)

  defp current_app! do
    case current_app() do
      nil -> raise ArgumentError, "no current Guppy.App context; pass an app ref explicitly"
      app -> app
    end
  end
end
