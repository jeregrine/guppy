defmodule Guppy do
  @moduledoc """
  Public entry points for the Guppy runtime.

  The current direction is an OTP-supervised Elixir runtime coordinating a native
  GPUI bridge loaded as a NIF.
  """

  alias Guppy.Server

  @doc "Returns the configured native bridge module."
  def native do
    Application.get_env(:guppy, :native, Guppy.Native.Nif)
  end

  @doc "Returns true when the Guppy server process is running."
  def started? do
    not is_nil(server())
  end

  @doc "Returns the Guppy server pid, if started."
  def server do
    Process.whereis(Server)
  end

  @doc "Returns runtime state for early bring-up and tests."
  def info do
    Server.info()
  end

  @doc "Pings the native bridge."
  def ping(timeout \\ 5_000) do
    Server.ping(Server, timeout)
  end

  @doc "Opens a native window owned by the calling process and renders its initial IR tree."
  def open_window(ir, opts \\ [], timeout \\ 5_000)

  def open_window(ir, opts, timeout) when is_list(opts) and is_integer(timeout) do
    Server.open_window(Server, self(), ir, opts, timeout)
  end

  @doc "Renders a full IR tree into an open native window."
  def render(view_id, ir, timeout \\ 5_000) do
    Server.render(Server, view_id, ir, timeout)
  end

  @doc "Closes a previously opened native window."
  def close_window(view_id, timeout \\ 5_000) do
    Server.close_window(Server, view_id, timeout)
  end

  @doc "Replaces the application menu bar for the calling process."
  def set_menus(menus, timeout \\ 5_000) do
    Server.set_menus(Server, self(), menus, timeout)
  end

  @doc "Replaces the Dock/app-icon menu for the calling process."
  def set_dock_menu(items, timeout \\ 5_000) do
    Server.set_dock_menu(Server, self(), items, timeout)
  end

  @doc "Opens a platform dialog for choosing one or more files."
  def open_file_dialog(opts \\ [], timeout \\ 30_000) do
    Server.open_file_dialog(Server, opts, timeout)
  end

  @doc "Opens a platform dialog for choosing one or more directories."
  def choose_directory_dialog(opts \\ [], timeout \\ 30_000) do
    Server.choose_directory_dialog(Server, opts, timeout)
  end

  @doc "Opens a platform dialog for choosing a save path."
  def save_file_dialog(opts \\ [], timeout \\ 30_000) do
    Server.save_file_dialog(Server, opts, timeout)
  end

  @doc "Reads text from the platform clipboard, returning `nil` when no text is available."
  def read_clipboard_text(timeout \\ 5_000) do
    Server.read_clipboard_text(Server, timeout)
  end

  @doc "Writes text to the platform clipboard."
  def write_clipboard_text(text, timeout \\ 5_000) do
    Server.write_clipboard_text(Server, text, timeout)
  end

  @doc "Returns the active theme for the current app context."
  def active_theme, do: Guppy.App.theme()

  @doc "Returns the active theme for an app."
  def active_theme(app), do: Guppy.App.theme(app)

  @doc "Replaces the active theme in the current app context."
  def set_theme(theme), do: Guppy.App.set_theme(nil, theme)

  @doc "Replaces the active theme for an app."
  def set_theme(app, theme), do: Guppy.App.set_theme(app, theme)

  @doc "Registers a theme family in the current app context."
  def register_theme_family(family), do: Guppy.App.register_theme_family(nil, family)

  @doc "Registers a theme family for an app."
  def register_theme_family(app, family), do: Guppy.App.register_theme_family(app, family)

  @doc "Returns registered theme families for the current app context."
  def theme_families, do: Guppy.App.theme_families()

  @doc "Returns registered theme families for an app."
  def theme_families(app), do: Guppy.App.theme_families(app)

  @doc "Looks up a semantic theme color in the current app context."
  def theme_color(token), do: Guppy.App.theme_color(token)

  @doc "Looks up a semantic theme color for an app."
  def theme_color(app, token), do: Guppy.App.theme_color(app, token)

  @doc "Looks up a semantic theme color or raises when unavailable."
  def theme_color!(token), do: Guppy.App.theme_color!(token)

  @doc "Looks up a semantic theme color for an app or raises when unavailable."
  def theme_color!(app, token), do: Guppy.App.theme_color!(app, token)

  @doc "Looks up a semantic theme style in the current app context."
  def theme_style(token), do: Guppy.App.theme_style(token)

  @doc "Looks up a semantic theme style for an app."
  def theme_style(app, token), do: Guppy.App.theme_style(app, token)

  @doc "Looks up a semantic theme style or raises when unavailable."
  def theme_style!(token), do: Guppy.App.theme_style!(token)

  @doc "Looks up a semantic theme style for an app or raises when unavailable."
  def theme_style!(app, token), do: Guppy.App.theme_style!(app, token)

  @doc "Returns the native-side open view count."
  def native_view_count(timeout \\ 5_000) do
    Server.view_count(Server, timeout)
  end

  @doc "Returns native build info when the NIF is loaded."
  def native_build_info do
    Guppy.Native.Nif.build_info()
  end

  @doc "Returns the native runtime status when the NIF is loaded."
  def native_runtime_status do
    Guppy.Native.Nif.runtime_status()
  end

  @doc "Returns the native GUI bootstrap status when the NIF is loaded."
  def native_gui_status do
    Guppy.Native.Nif.gui_status()
  end

  @doc "Returns native-side performance counters when the NIF is loaded."
  def native_performance_counters do
    Guppy.Native.Nif.performance_counters()
  end
end
