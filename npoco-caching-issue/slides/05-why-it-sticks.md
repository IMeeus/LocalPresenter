---
marp: true
theme: default
---

# Why It Sticks & Why Rolling Deploys

**Why it sticks**
- NPoco caches the generated factory in a **process-wide `MemoryCache`** with 1-hour sliding expiry
- Once the broken factory is cached, every request for that type hits the same broken IL
- Process restart clears the cache → explains why restarts "fix" it

**Why rolling deploys specifically**
- Race window only exists during the **first factory compilation** per type
- A fresh process receiving its first wave of concurrent traffic has nothing pre-compiled
- Multiple `FetchMultiple` calls for different request types race to compile simultaneously
- In steady-state, all factories are already cached — the race never fires
