---
marp: true
theme: default
---

# The Cost

- This bug has lived in the codebase **undetected for years**
- Each incident: exceptions fire mid-event in a **non-transactional event-sourced flow** — the event persists but its state changes are rolled back, leaving requests in an inconsistent state
- Requests stuck this way **cannot self-recover** — they stay broken even after the bug is resolved
- Team Bravas fixes them by replaying the failed events — **in bulk**, across hundreds or thousands of affected requests per incident
- Workaround: Grafana alert fires on `poco_factory_0` → manual redeploy of the affected server
- **Team Bravas** spends significant time resolving stuck requests instead of building features
- **5 incidents in the past month** — and the frequency is increasing
