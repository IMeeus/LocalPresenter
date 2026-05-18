---
marp: true
theme: default
---

# NPoco's Mapping Factory

*Root cause: deep inside `MappingFactory` — the component responsible for turning database column values into .NET types.*

- **Simple types** (int, string, DateTime): direct, trivial mapping
- **Complex types** (e.g. `IAggregateReference<IUser,int>`): a **custom converter** function is used

On first use, NPoco generates a factory delegate via IL emission. Each custom converter is stored in a **static, process-wide list** — and its position in that list is **permanently baked** into the generated IL:

```csharp
static List<Func<object, object>> m_Converters = new List<Func<object, object>>();

private static void AddConverterToStack(ILGenerator il, Func<object, object> converter)
{
    int converterIndex = m_Converters.Count; // ← read current size
    m_Converters.Add(converter);              // ← append converter
    il.Emit(OpCodes.Ldc_I4, converterIndex);  // index baked into IL forever
}
```

Once built, the factory is cached in NPoco's process-wide **MemoryCache** — it will be reused for every subsequent request of that type.
