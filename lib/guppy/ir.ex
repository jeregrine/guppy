defmodule Guppy.IR do
  @moduledoc """
  Minimal IR helpers for the Phase 1 tracer shot.

  This starts with just enough structure to prove:

  - Elixir owns UI state
  - Elixir sends a tree description
  - native GPUI renders that description
  - Elixir sends full-tree replacement updates
  """

  @type text_node :: %{kind: :text, content: String.t()}
  @type div_node :: %{kind: :div, children: [ir_node()]}
  @type ir_node :: text_node() | div_node()

  @spec text(String.t()) :: text_node()
  def text(content) when is_binary(content) do
    %{kind: :text, content: content}
  end

  @spec div([ir_node()]) :: div_node()
  def div(children) when is_list(children) do
    %{kind: :div, children: children}
  end

  @spec validate(ir_node()) :: :ok | {:error, term()}
  def validate(%{kind: :text, content: content}) when is_binary(content), do: :ok

  def validate(%{kind: :div, children: children}) when is_list(children) do
    Enum.reduce_while(children, :ok, fn child, :ok ->
      case validate(child) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  def validate(other), do: {:error, {:invalid_ir, other}}
end
