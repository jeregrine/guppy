# Guppy Forward Plan

Operational rules, checks, and maintenance reminders live in `AGENTS.md`. This file tracks only the forward feature plan.

## Next work

1. Make template/window authoring feel HEEx-like:
   - Replace `~G` with `~GUI`.
   - Align assignment/update naming with HEEx/LiveView expectations; prefer `assign` ergonomics over the current `update` shape.
   - Support HEEx-style assigns in `~GUI`, so `@my_var` reads from the render assigns/window assigns context like `assigns.my_var`.
   - Make `handle_info/2` an implicit optional callback in the window API, like LiveView/GenServer usage, not something authors have to think about as explicit ceremony.
   - Call local function components as `<.my_fun>` instead of `<my_fun>`.
2. Design retained row-control identity/lifecycle so stateful controls can be supported inside generic `list` rows.
3. Scope menu APIs against real application needs and current `gpui = 0.2.2` capabilities.
4. Scope gradient style primitives if examples or user-facing design needs require them.
5. Scope full data-table/tree virtualization separately from current grid/list support.
6. Scope custom painting/canvas/pattern painting after narrower compliance gaps matter in practice.
