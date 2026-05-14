# Guppy Forward Plan

Operational rules, checks, and maintenance reminders live in `AGENTS.md`. This file tracks only the forward feature plan.

## Next work

1. Scope gradient style primitives if examples or user-facing design needs require them.
2. Scope full data-table/tree virtualization separately from current grid/list support.
3. Scope custom painting/canvas/pattern painting after narrower compliance gaps matter in practice.

## Designed implementation candidates

- Retained controls inside generic `list` rows: identity/lifecycle design is recorded in [`docs/future-primitives.md`](docs/future-primitives.md#retained-controls-inside-generic-list-rows). Implementation remains deferred until explicitly prioritized.
- App-level menu APIs: scope is recorded in [`docs/future-primitives.md`](docs/future-primitives.md#menu-apis). Implementation waits for a real app need and macOS/native verification.
