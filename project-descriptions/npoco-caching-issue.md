# NPoco Thread-Safety Race Condition — Fix Plan

## Problem Summary

`BaseRequestStateManager.Fulfill` calls:
```csharp
_dbContext.ReadOnlyDatabase.FetchMultiple<TRequestDto, WorkflowAction, RequestComment>(qbuilder.Query);
```

On rolling deploys, freshly-started servers occasionally produce persistent `InvalidCastException` or `NullReferenceException` from inside NPoco's generated factory (`poco_factory_0`). The error messages from the stacktraces are:

- `Unable to cast object of type 'AggregateReference`2[IWorkflow,Int32]' to type 'IAggregateReference`2[IUser,Int32]'`
- `NullReferenceException` at `poco_factory_0`

Both indicate the wrong property-to-column converter is being used for a type, and that the broken state is **sticky** (persists until process restart).

---

## Root Cause

### NPoco's `MappingFactory.AddConverterToStack` is not thread-safe

NPoco (v2.10.11) generates factory delegates on first use via IL emission (`ILGenerator`). For properties that require a custom converter — such as `IAggregateReference<IUser,int>` and `IAggregateReference<IWorkflow,int>` mapped in `Mapper.GetFromDbConverter` — it stores the converter in a **process-wide static list** and bakes the list index into the generated IL:

```csharp
// MappingFactory.cs (NPoco source)
static List<Func<object, object>> m_Converters = new List<Func<object, object>>();

private static void AddConverterToStack(ILGenerator il, Func<object, object> converter)
{
    if (converter != null)
    {
        int converterIndex = m_Converters.Count; // ← (1) read index
        m_Converters.Add(converter);              // ← (2) add converter
        // IL permanently bakes in `converterIndex`
        il.Emit(OpCodes.Ldc_I4, converterIndex);
        ...
    }
}
```

Steps (1) and (2) are **not atomic**. When two threads compile factories for different `TRequestDto` types concurrently, both can read the same `Count` value before either has called `Add`. Example:

| Thread A (`AbsenceRequestV3`)            | Thread B (`ClockingRemovalRequestV3`)        |
|------------------------------------------|----------------------------------------------|
| Reads `Count` → **5**                   | Reads `Count` → **5**                       |
| IL bakes in index **5** for IUser conv   | IL bakes in index **5** for IWorkflow conv   |
| `m_Converters.Add(UserConverter)`        | `m_Converters.Add(WorkflowConverter)`        |
| `m_Converters[5]` = UserConverter ✓      | IL for B uses index 5 → **UserConverter** ✗  |

Thread B's factory permanently uses the wrong converter. When it reads an int from the DB, converts it with the UserConverter (producing `AggregateReference<IUser,int>`), and then the IL tries to `Unbox_Any` to `IAggregateReference<IWorkflow,int>`, it throws `InvalidCastException`. The reverse ordering causes the opposite failure.

### Why it sticks

The generated factory is cached in NPoco's **process-wide `MemoryCache`** ("NPoco") with a 1-hour sliding expiry (`MappingFactory._pocoFactories` uses `CreateManagedCache()`). Once the wrong factory is cached, every subsequent request for that type hits the same broken factory. A process restart clears the cache, which is why restarting the affected server "fixes" it.

### Why it's rolling-deploy specific

The race window is tiny: only during the **first compilation** of each factory. On a fresh process, when the first wave of concurrent requests arrives (which is common during rolling deploys when traffic is forwarded to the new instance before it has served any requests), multiple `FetchMultiple` calls for different `TRequestDto` types can trigger concurrent factory compilation, opening the race window.

### Which types are affected

Any two `TRequestDto` types that both have `IAggregateReference<,>` properties will compete for converter slots. In this codebase, all V3 request types (`AbsenceRequestV3`, `ClockingRequestV3`, `ClockingRemovalRequestV3`, `ScheduleRequestV3`, `SpecialCounterRequestV3`, etc.) have `EvaluatedByPerson` (`IAggregateReference<IUser,int>`) and/or `EvaluatedByWorkflow` (`IAggregateReference<IWorkflow,int>`) fields. The two converter lambdas (one per concrete type argument) are the ones that race.

---

## Proposed Fix

Since NPoco is used as a compiled NuGet package (not source), patching it directly is not possible without forking.

### Approach: Serialize first-use factory compilation per `TRequestDto`

Add a **static mutex** in `BaseRequestStateManager` that ensures only one `FetchMultiple` call per `TRequestDto` type runs while that type's factory has not yet been compiled and cached by NPoco.

- **Before** the factory is cached: at most one thread runs `FetchMultiple` for any uncompiled type at a time (lock held). All other uncompiled types queue up and compile sequentially.
- **After** the factory is cached: the fast path (`_compiledTypes.ContainsKey`) short-circuits immediately, no locking at all, zero performance impact.

This pattern is **double-checked locking** using a `SemaphoreSlim(1,1)` and a `ConcurrentDictionary<Type, bool>`.

### Code change — `BaseRequestStateManager.Fulfill`

File: `Protime.Fusion.SqlServer/Domain/Request/BaseRequestStateManager.cs`

**Step 1: Add using directives**
```csharp
using System.Collections.Concurrent;
using System.Threading;
```

**Step 2: Add static fields inside `BaseRequestStateManager<TRequest, TRequestDto>`**
```csharp
// Serializes first-ever FetchMultiple call per TRequestDto to work around a thread-safety
// race condition in NPoco 2.10.11's MappingFactory.AddConverterToStack. The static
// m_Converters list in NPoco is not lock-protected: concurrent factory compilations for
// different types can bake in the same converter index, causing InvalidCastException or
// NullReferenceException from the generated poco_factory. Once a type's factory is cached
// by NPoco the fast-path (ContainsKey) is taken and the semaphore is never touched.
private static readonly SemaphoreSlim _npocoFactoryCompilationLock = new SemaphoreSlim(1, 1);
private static readonly ConcurrentDictionary<Type, bool> _compiledTypes = new ConcurrentDictionary<Type, bool>();
```

**Step 3: Replace `Fulfill` implementation**

Current implementation:
```csharp
protected IReadOnlyList<TRequestDto> Fulfill(QueryBuilder qbuilder, bool fromRead = true)
{
    var dbResult =
        (fromRead ? _dbContext.ReadOnlyDatabase : _dbContext.Database)
        .FetchMultiple<TRequestDto, WorkflowAction, RequestComment>(qbuilder.Query);
    var result = new List<TRequestDto>();
    foreach (var request in dbResult.Item1)
    {
        // ... assembly of result
    }
    return result.Select(Materialize).ToList();
}
```

New implementation:
```csharp
protected IReadOnlyList<TRequestDto> Fulfill(QueryBuilder qbuilder, bool fromRead = true)
{
    // Fast path: factory already compiled and cached by NPoco.
    if (_compiledTypes.ContainsKey(typeof(TRequestDto)))
        return FulfillInternal(qbuilder, fromRead);

    // Slow path: serialize factory compilation to avoid NPoco's m_Converters race.
    _npocoFactoryCompilationLock.Wait();
    try
    {
        if (_compiledTypes.ContainsKey(typeof(TRequestDto)))
            return FulfillInternal(qbuilder, fromRead);

        var result = FulfillInternal(qbuilder, fromRead);
        _compiledTypes[typeof(TRequestDto)] = true;
        return result;
    }
    finally
    {
        _npocoFactoryCompilationLock.Release();
    }
}

private IReadOnlyList<TRequestDto> FulfillInternal(QueryBuilder qbuilder, bool fromRead)
{
    var dbResult =
        (fromRead ? _dbContext.ReadOnlyDatabase : _dbContext.Database)
        .FetchMultiple<TRequestDto, WorkflowAction, RequestComment>(qbuilder.Query);
    var result = new List<TRequestDto>();
    foreach (var request in dbResult.Item1)
    {
        request.Actions = dbResult
            .Item2
            .Where(x => x.Subject == request.Scope.Id && x.Request == request.Id)
            .Select(
                a =>
                {
                    a.Comment = dbResult.Item3.SingleOrDefault(c =>
                        c.Subject == request.Scope.Id && c.Request == request.Id && a.Id == c.WorkflowAction);
                    return a;
                })
            .Cast<IWorkflowAction>().ToList();

        request.Comments = dbResult.Item3.Where(y => y.Subject == request.Scope.Id && y.Request == request.Id)
            .Cast<IComment>().ToList();

        result.Add(request);
    }
    return result.Select(Materialize).ToList();
}
```

### Why this works

- The `SemaphoreSlim(1,1)` ensures at most **one thread is inside `FulfillInternal` for an uncompiled type** at any given moment.
- Thread A compiles TypeX, thread B is blocked on `Wait()`. After A releases, B acquires, double-checks (TypeX is compiled but TypeY is not), compiles TypeY. TypeX and TypeY factories are **never compiled concurrently** → no race on `m_Converters`.
- Once all types are compiled, `_compiledTypes.ContainsKey` returns `true` and the entire lock mechanism is bypassed. No performance regression for steady-state operation.
- If `FulfillInternal` throws (e.g., SQL error after factory compilation), the type is not added to `_compiledTypes`. The next call goes through the slow path again, which is safe — NPoco will return the already-cached (correct) factory, and the query will be retried.

### Note on `static` field placement

`_npocoFactoryCompilationLock` and `_compiledTypes` must be `static` on the **generic class** `BaseRequestStateManager<TRequest, TRequestDto>`. In C#, statics on a generic type are **per closed generic instantiation**, meaning each concrete `<TRequest, TRequestDto>` pair gets its own lock. This is fine — what we need to serialize is compilations of *different TRequestDto* types, and having per-`TRequestDto` locks is sufficient: two threads for the *same* `TRequestDto` will share the same lock and dictionary, while compilations of genuinely different types are also serialized because they share the same `SemaphoreSlim` instance per closed generic type.

Wait — actually re-reading: statics on a generic class are per closed type. So `BaseRequestStateManager<AbsenceRequest, AbsenceRequestV3>._npocoFactoryCompilationLock` is a *different* instance from `BaseRequestStateManager<ClockingRequest, ClockingRequestV3>._npocoFactoryCompilationLock`. **This means the lock does NOT serialize compilations between different `TRequestDto` pairs.**

To correctly serialize across ALL `TRequestDto` types, the lock must be defined in a **non-generic base class or a static helper class**, not on the generic class itself.

**Corrected approach:** Extract the static fields into a non-generic sibling class:

```csharp
// New file or nested class — non-generic so statics are truly process-wide
internal static class NPocoFactoryCompilationGuard
{
    // See: NPoco 2.10.11 MappingFactory.AddConverterToStack race condition.
    // m_Converters is a static List<> with no locking. Concurrent first-compilations
    // for different types corrupt the converter index baked into generated IL.
    internal static readonly SemaphoreSlim Lock = new SemaphoreSlim(1, 1);
    internal static readonly ConcurrentDictionary<Type, bool> CompiledTypes =
        new ConcurrentDictionary<Type, bool>();
}
```

And in `BaseRequestStateManager`:
```csharp
protected IReadOnlyList<TRequestDto> Fulfill(QueryBuilder qbuilder, bool fromRead = true)
{
    if (NPocoFactoryCompilationGuard.CompiledTypes.ContainsKey(typeof(TRequestDto)))
        return FulfillInternal(qbuilder, fromRead);

    NPocoFactoryCompilationGuard.Lock.Wait();
    try
    {
        if (NPocoFactoryCompilationGuard.CompiledTypes.ContainsKey(typeof(TRequestDto)))
            return FulfillInternal(qbuilder, fromRead);

        var result = FulfillInternal(qbuilder, fromRead);
        NPocoFactoryCompilationGuard.CompiledTypes[typeof(TRequestDto)] = true;
        return result;
    }
    finally
    {
        NPocoFactoryCompilationGuard.Lock.Release();
    }
}
```

---

## Alternative Approaches

### Option 2: Startup pre-warming (serial warmup before traffic arrives)

Instead of serialising at call-time, you can compile every factory **before the process accepts any HTTP requests** by running one 0-row `FetchMultiple` per `TRequestDto` type during startup. Because startup is single-threaded (or at least controlled), `m_Converters` is never accessed concurrently and the race never fires.

**How it works:**

1. Add a `protected virtual void Warmup()` method to `BaseRequestStateManager` that calls `Fulfill` with a query guaranteed to return 0 rows:
   ```csharp
   protected virtual void Warmup()
   {
       var qbuilder = BuildQuery();
       qbuilder.Builder.Where("1 = 0");
       Fulfill(qbuilder);
   }
   ```
2. Add an `IWarmable` interface (single method `void Warmup()`) and have `BaseRequestStateManager` implement it.
3. Register all managers in DI as `IWarmable` in addition to their existing service registrations (or use `IEnumerable<IWarmable>` resolution).
4. Create a `NPocoWarmupHostedService : IHostedService` whose `StartAsync` enumerates all `IWarmable` services and calls `Warmup()` **sequentially** (not in parallel).

**Timing guarantee:** In ASP.NET Core, `IHostedService.StartAsync` for all hosted services is called sequentially by the generic host's `StartAsync`, which runs to completion *before* Kestrel starts accepting connections. This means as long as `NPocoWarmupHostedService` is registered before the `IWebHostBuilder` service (which it always is, because the web server is the last hosted service added), warmup is guaranteed to finish before any HTTP request arrives.

**Trade-offs:**
- ✅ No runtime locking overhead whatsoever once started
- ✅ Completely eliminates the race — factories compiled before any concurrent traffic
- ✅ No change to `Fulfill` hot path
- ❌ Requires a real DB connection during startup (minor — the DB must be reachable at startup anyway)
- ❌ Requires enumerating all `IWarmable` registrations, which means touching `SqlServerServiceCollectionExtensions`
- ❌ If a new `BaseRequestStateManager` subclass is added and not registered as `IWarmable`, it would be silently unprotected until the first concurrent hit
- ❌ The warmup adds a small startup latency (one 0-row query per type, typically < 50 ms total)
- ❌ Slightly more moving parts: new interface, new hosted service, registration in DI

**Note:** If you add the `IWarmable` interface on `BaseRequestStateManager` itself (so the `Warmup()` call is automatically available), and enumerate all instances via DI, new subclasses are protected automatically as long as they're registered in the container.

---

### Option 3: Replace `FetchMultiple` with three separate `Fetch` calls

The `QueryBuilder` already generates three `SELECT` statements separated by semicolons. You can split these into three independent SQL strings and make three separate `Fetch<>` calls instead of one `FetchMultiple`. Since each `Fetch<T>` call involves only ONE type per call, concurrent calls for different types can no longer race on the same factory-compilation path.

**How it works:**

Refactor `Fulfill` to use:
```csharp
var requests = db.Fetch<TRequestDto>(requestSql);
var actions  = db.Fetch<WorkflowAction>(actionSql);
var comments = db.Fetch<RequestComment>(commentSql);
```
instead of:
```csharp
var dbResult = db.FetchMultiple<TRequestDto, WorkflowAction, RequestComment>(combinedSql);
```

The `QueryBuilder` would need to expose its three SQL parts separately.

**Why this avoids the race:**  
`Fetch<T>` (single result set) also goes through `MappingFactory.GetFactory` → `AddConverterToStack`. The race can still happen if two requests for *different request types* hit concurrently. So **this option does NOT fully eliminate the race** — it just slightly narrows the window (one factory per call instead of three). The race on `m_Converters` between `AbsenceRequestV3` and `ClockingRemovalRequestV3` can still occur.

**Trade-offs:**
- ❌ Does NOT fully fix the race — only reduces the surface area slightly
- ❌ Three round-trips to the database instead of one (or one round-trip if sent as a batch, but then you're back to multi-result sets)
- ❌ Significant refactor of `QueryBuilder` and `Fulfill`
- ✅ No external dependency changes needed

> **Verdict: not recommended as a standalone fix.** Could be combined with Option 1 or 2.

---

### Option 4: Fork and patch NPoco source

The actual bug is a 5-line fix in NPoco's `MappingFactory.AddConverterToStack`. Add a lock object and synchronise the read+write on `m_Converters`:

```csharp
// In NPoco's MappingFactory.cs
private static readonly object _convertersLock = new object();

private static void AddConverterToStack(ILGenerator il, Func<object, object> converter)
{
    if (converter != null)
    {
        int converterIndex;
        lock (_convertersLock)
        {
            converterIndex = m_Converters.Count;
            m_Converters.Add(converter);
        }
        il.Emit(OpCodes.Ldsfld, fldConverters);
        il.Emit(OpCodes.Ldc_I4, converterIndex);
        il.Emit(OpCodes.Callvirt, fnListGetItem);
    }
}
```

The NuGet package at `packages/npoco/2.10.11/lib/net45/NPoco.dll` would be replaced with a locally-built patched version.

**Trade-offs:**
- ✅ Fixes the root cause directly and completely, with minimal code
- ✅ No application code changes needed
- ✅ All other NPoco multi-fetch paths (not just `FetchMultiple`) are also protected
- ❌ You own a fork — you must maintain, build, and distribute the patched DLL
- ❌ Any future NPoco upgrade must re-apply the patch (though the fix is trivial)
- ❌ Slightly increases startup/warmup time for concurrent scenarios (lock contention is negligible — factory compilation happens once per type per process lifetime)

> This is the most correct fix. It makes sense to combine it with a note in the codebase about why the fork exists.

---

### Comparison table

| Approach | Fixes root cause | Runtime overhead | Code changes | Complexity | Risk |
|---|---|---|---|---|---|
| **1. Static mutex in `Fulfill`** | Indirectly (serialises compilation) | None (after warmup) | Small, isolated | Low | Low |
| **2. Startup pre-warming** | Indirectly (prevents concurrency during init) | None (after startup) | Moderate (DI, hosted service) | Medium | Low if all types registered |
| **3. Separate `Fetch` calls** | ❌ Does not fully fix it | Extra DB round-trips | Moderate | Medium | Low |
| **4. Fork/patch NPoco** | ✅ Yes, directly | None | Fork + 5-line patch | Low (but maintenance cost) | Low |

**Recommendation:** Option 1 (static mutex) is the safest, lowest-risk change with no new dependencies. Option 4 (fork+patch) is the most correct fix if you're willing to maintain a forked NPoco. Option 2 (pre-warming) is a good complement to Option 1 for removing any remaining startup latency.

---

## Files to Change

| File | Change |
|------|--------|
| `Protime.Fusion.SqlServer/Domain/Request/BaseRequestStateManager.cs` | Add `using System.Collections.Concurrent; using System.Threading;` · Extract `FulfillInternal` · Replace `Fulfill` with the locking wrapper |
| `Protime.Fusion.SqlServer/Domain/Request/NPocoFactoryCompilationGuard.cs` | New file — non-generic static class holding the process-wide lock and compiled-types dictionary |

---

## Testing

- The bug is a race condition and is hard to reproduce deterministically. The existing integration tests should continue to pass.
- To manually verify the fix: run the service under concurrent load against a fresh process (simulating a rolling deploy) and confirm no `InvalidCastException` from `poco_factory_0` in the logs.
- Consider adding a test that instantiates multiple `BaseRequestStateManager` subclasses and calls `Fulfill` on them concurrently in a test environment, verifying no mapping exceptions occur.
