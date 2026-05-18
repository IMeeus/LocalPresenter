---
marp: true
theme: default
---

# Recommended Fix: Static Mutex

A **non-generic** static guard class ensures process-wide serialisation:

```csharp
internal static class NPocoFactoryCompilationGuard {
    internal static readonly SemaphoreSlim Lock = new SemaphoreSlim(1, 1);
    internal static readonly ConcurrentDictionary<Type, bool> CompiledTypes = new();
}
```

Double-checked locking in `Fulfill` — zero overhead after first compile:

```csharp
protected IReadOnlyList<TRequestDto> Fulfill(QueryBuilder q, bool fromRead = true)
{
    if (NPocoFactoryCompilationGuard.CompiledTypes.ContainsKey(typeof(TRequestDto)))
        return FulfillInternal(q, fromRead);   // fast path — no lock ever touched

    NPocoFactoryCompilationGuard.Lock.Wait();
    try {
        if (NPocoFactoryCompilationGuard.CompiledTypes.ContainsKey(typeof(TRequestDto)))
            return FulfillInternal(q, fromRead);
        var result = FulfillInternal(q, fromRead);
        NPocoFactoryCompilationGuard.CompiledTypes[typeof(TRequestDto)] = true;
        return result;
    } finally { NPocoFactoryCompilationGuard.Lock.Release(); }
}
```

⚠️ The guard **must be non-generic** — statics on a generic class are per closed type.
