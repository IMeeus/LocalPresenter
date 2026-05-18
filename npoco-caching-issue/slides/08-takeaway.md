---
marp: true
theme: default
---

# Takeaway

**The bug:** NPoco bakes converter indices into generated IL using a non-atomic read-then-append on a static list. Concurrent first-use compilations assign the same index to different converters → permanently broken factory, cached for 1 hour.

**The fix (Option 1):** `NPocoFactoryCompilationGuard` — a non-generic static class with a `SemaphoreSlim` and a `ConcurrentDictionary`. Double-checked locking serialises first-time compilations; steady-state has zero overhead.

**Files to change:**
- `BaseRequestStateManager.cs` — extract `FulfillInternal`, wrap `Fulfill` with guard
- `NPocoFactoryCompilationGuard.cs` — new file, non-generic static class

**Testing:** Instantiate multiple manager subclasses, call `Fulfill` concurrently on a fresh process, assert no mapping exceptions.
