---
marp: true
theme: default
---

# The Race

Two threads compile factories for different types concurrently:

1. **Thread A** reads `Count` → **5** &nbsp;&nbsp;&nbsp; **Thread B** reads `Count` → **5** ← *same value, same moment*
2. Thread A bakes **index 5** into IL (IUser converter) &nbsp;&nbsp; Thread B bakes **index 5** into IL (IWorkflow converter)
3. Thread A calls `m_Converters.Add(UserConverter)` → lands at **[5]**
4. Thread B calls `m_Converters.Add(WorkflowConverter)` → lands at **[6]**

**Thread B's factory permanently reads `m_Converters[5]` — the UserConverter**

→ Reads an int, converts it as a user reference, IL tries to cast to `IAggregateReference<IWorkflow,int>` → `InvalidCastException` ❌
