---
marp: true
theme: default
---

# How We Found It

- Errors in Grafana: `InvalidCastException` / `NullReferenceException` inside `poco_factory_0`
- `poco_factory_0` is **generated code** — inside the NPoco package, not our codebase
- For years: no one knew the root cause; the alert simply said *"redeploy the affected server"*
- Breakthrough: deep analysis of `BaseRequestStateManager.Fulfill` — the single call site where all request types converge on NPoco
- Tracing from there into NPoco's internals finally exposed the race
