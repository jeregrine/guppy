# Guppy Forward Plan

Operational rules, checks, and maintenance reminders live in `AGENTS.md`. This file tracks only the forward feature plan.

## Next work

1. Scope menu APIs against real application needs and current `gpui = 0.2.2` capabilities.
2. Scope gradient style primitives if examples or user-facing design needs require them.
3. Scope full data-table/tree virtualization separately from current grid/list support.
4. Scope custom painting/canvas/pattern painting after narrower compliance gaps matter in practice.

## Designed implementation candidates

- Retained controls inside generic `list` rows: identity/lifecycle design is recorded in [`docs/future-primitives.md`](docs/future-primitives.md#retained-controls-inside-generic-list-rows). Implementation remains deferred until explicitly prioritized.
