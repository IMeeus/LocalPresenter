---
marp: true
theme: default
---

# The Race Condition

`m_Converters` is a plain `List<>` with **no locking**. Reading its size and appending to it are two separate, unprotected operations.

When two threads compile factories concurrently, they can both read the same `Count` before either calls `Add`:

```mermaid
sequenceDiagram
    participant A as Thread A<br/>(AbsenceRequest)
    participant L as m_Converters [ ]
    participant B as Thread B<br/>(ClockingRequest)

    A->>L: Count → 5 (bake index 5 for UserConverter)
    B->>L: Count → 5 (bake index 5 for WorkflowConverter)
    A->>L: Add(UserConverter)     → [5] = UserConverter ✓
    B->>L: Add(WorkflowConverter) → [6] = WorkflowConverter
    Note over B,L: Thread B's IL uses index 5 → UserConverter ✗
```

Thread B's factory permanently looks up index **5** expecting a workflow converter — but finds the user converter instead → `InvalidCastException` on every call.

> **Why it sticks:** the broken factory is stored in NPoco's process-wide **MemoryCache**. Every subsequent request for that type hits the same corrupt factory — until the process restarts and the cache is cleared.
