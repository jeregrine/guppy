# Guppy Forward Plan

Operational rules, checks, and maintenance reminders live in `AGENTS.md`. This file tracks only the forward feature plan.

## Next work

No new feature or scoping item is active. Keep stabilization, bug fixes, verification paths, docs, examples, and compliance tracking ahead of speculative surface area. Pick one of the designed implementation candidates below only when explicitly prioritized by a real use case.

## Designed implementation candidates

- Retained controls inside generic `list` rows: identity/lifecycle design is recorded in [`docs/future-primitives.md`](docs/future-primitives.md#retained-controls-inside-generic-list-rows). Implementation remains deferred until explicitly prioritized.
- App-level menu APIs: scope is recorded in [`docs/future-primitives.md`](docs/future-primitives.md#menu-apis). Implementation waits for a real app need and macOS/native verification.
- Gradient style primitives: background-linear-gradient scope is recorded in [`docs/future-primitives.md`](docs/future-primitives.md#gradient-style-primitives). Implementation waits for a real visual need.
- Data-table and tree virtualization: dedicated primitive scope is recorded in [`docs/future-primitives.md`](docs/future-primitives.md#data-table-and-tree-virtualization). Implementation waits for a concrete app use case and separate benchmarks/tests.
- Custom painting, canvas, and pattern painting: retained drawing primitive scope is recorded in [`docs/future-primitives.md`](docs/future-primitives.md#custom-painting-canvas-and-pattern-painting). Implementation waits until narrower compliance gaps matter in practice.
