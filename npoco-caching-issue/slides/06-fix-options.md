---
marp: true
theme: default
---

# Fix Options

| Approach | Fixes root cause | Runtime overhead | Complexity |
|---|---|---|---|
| **1. Static mutex in `Fulfill`** | Indirectly | None (after first compile) | Low |
| **2. Startup pre-warming** | Indirectly | None (after startup) | Medium |
| **3. Separate `Fetch` calls** | ❌ Not fully | Extra DB round-trips | Medium |
| **4. Fork & patch NPoco** | ✅ Directly | None | Low + maintenance |

**Recommended:** Option 4 — fixes the root cause directly; fork already exists

**Alternative:** Option 1 — zero new dependencies, lowest code-change risk
