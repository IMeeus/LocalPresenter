---
marp: true
theme: default
---

# Root Cause: `AddConverterToStack`

NPoco generates factory delegates via IL emission. Custom converters go into a **static process-wide list**, with their index baked into the IL:

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

> **The race lives here:** read `Count` and `Add` are two separate operations. Any thread can step in between them.
