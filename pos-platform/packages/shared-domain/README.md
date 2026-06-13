# shared-domain

Language-agnostic domain knowledge: invariants, derived-quantity rules, lookup tables, glossary.

This package holds **no code** — only markdown, JSON, and YAML that is consumed by both Go and Dart sides (and by humans).

## What lives here
- `glossary.md` — terms with one canonical meaning across the codebase (e.g. "operation", "event", "batch")
- `invariants.md` — the never-violate list (mirrors Development Guide §16, kept here for code-adjacency)
- `derived/` — how to derive state from the append-only event log (e.g. current stock from `inventory_movements`)
- `enums/` — canonical enums (payment methods, inventory reasons, etc.) in YAML, consumed by codegen

## Status
Scaffold. Files will be added as Phase 1 firms up the data model.
