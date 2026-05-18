---
marp: true
theme: default
---

# Root Cause: `AddConverterToStack`

NPoco's **MappingFactory** maps database rows to .NET objects. For complex types — like aggregate references — it generates factory delegates via IL emission. Custom converters go into a **static process-wide list**, with their index baked into the IL:

```csharp
static List<Func<object, object>> m_Converters = new List<Func<object, object>>();

private static void AddConverterToStack(ILGenerator il, Func<object, object> converter)
{
    int converterIndex = m_Converters.Count; // ← (1) read index
    m_Converters.Add(converter);              // ← (2) add converter
    il.Emit(OpCodes.Ldc_I4, converterIndex);  // IL permanently bakes in this index
}
```

Steps (1) and (2) are **not atomic** — no lock anywhere in this path.

> **Two threads race:** both read `Count = 5`, both bake index 5 into IL. One converter lands at `[5]`, the other at `[6]`. The factory with index 5 now permanently calls the **wrong converter** → `InvalidCastException` ❌
