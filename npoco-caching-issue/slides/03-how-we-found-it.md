---
marp: true
theme: default
---

# How We Found It

- Alert fires in Grafana pointing to `poco_factory_0` — **generated code** inside the NPoco package, not our codebase
- For years: no one knew the root cause; the alert simply said *"redeploy the affected server"*
- Breakthrough: deep analysis of `BaseRequestStateManager.Fulfill` — the single call site where all request types converge on NPoco
- Tracing from there into NPoco's internals finally exposed the race
