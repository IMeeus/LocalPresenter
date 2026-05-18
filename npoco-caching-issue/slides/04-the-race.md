---
marp: true
theme: default
---

# The Race

Two threads compile factories for different types concurrently:

| Thread A (`AbsenceRequestV3`) | Thread B (`ClockingRemovalRequestV3`) |
|-------------------------------|---------------------------------------|
| Reads `Count` → **5** | Reads `Count` → **5** |
| IL bakes index **5** (IUser conv.) | IL bakes index **5** (IWorkflow conv.) |
| `m_Converters.Add(UserConverter)` | `m_Converters.Add(WorkflowConverter)` |
| `m_Converters[5]` = UserConverter ✓ | IL for B uses index 5 → **UserConverter ✗** |

Thread B's factory **permanently** applies the wrong converter → `InvalidCastException` on every call.
