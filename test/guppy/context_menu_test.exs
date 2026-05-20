defmodule Guppy.ContextMenuTest do
  use ExUnit.Case

  test "validates and renders context menu items" do
    items = [
      %{id: "open", label: "Open", callback: "open_item"},
      :separator,
      %{id: "delete", label: "Delete", callback: "delete_item", disabled: true}
    ]

    assert {:ok, validated} = Guppy.ContextMenu.validate(items)
    assert Enum.map(validated, & &1.id) == ["open", nil, "delete"]

    ir = Guppy.ContextMenu.render(items, id: "row_menu")

    assert :ok = Guppy.IR.validate(ir)
    assert ir.kind == :div
    assert ir.id == "row_menu"

    assert [open, separator, delete] = ir.children
    assert open.kind == :button
    assert open.id == "row_menu.open"
    assert open.label == "Open"
    assert open.events == %{click: "open_item"}
    refute Map.get(open, :disabled, false)

    assert separator.kind == :div
    assert separator.id == "row_menu.separator.1"

    assert delete.kind == :button
    assert delete.id == "row_menu.delete"
    assert delete.disabled == true
    assert delete.events == %{click: "delete_item"}
  end

  test "rejects invalid context menu specs" do
    assert {:error, {:invalid_context_menu_item, %{label: "Missing id"}}} =
             Guppy.ContextMenu.validate([%{label: "Missing id"}])

    assert {:error, {:invalid_context_menu_item, %{id: "open", label: "Open", callback: ""}}} =
             Guppy.ContextMenu.validate([%{id: "open", label: "Open", callback: ""}])

    assert {:error, {:duplicate_context_menu_item_id, "open"}} =
             Guppy.ContextMenu.validate([
               %{id: "open", label: "Open", callback: "open"},
               %{id: "open", label: "Open Again", callback: "open_again"}
             ])
  end
end
