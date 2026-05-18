---
marp: true
theme: default
---

# The Symptom

- `InvalidCastException` deep inside `poco_factory_0`:
  > *Unable to cast `AggregateReference<IWorkflow,int>` to `IAggregateReference<IUser,int>`*
- Or: `NullReferenceException` at `poco_factory_0`
- Only fires on **rolling deploys** — fresh process, first concurrent requests
- **Sticky** — every subsequent request for that type throws the same error
- Resolves with a **process restart**
