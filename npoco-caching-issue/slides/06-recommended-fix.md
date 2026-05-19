---
marp: true
theme: default
---

# Recommended Fix: Fork & Patch NPoco

The cleanest fix is to create a **dedicated NPoco fork** and apply a **small patch** directly in `MappingFactory`:

```csharp
static readonly object _convertersLock = new object();
static List<Func<object, object>> m_Converters = new List<Func<object, object>>();

private static void AddConverterToStack(ILGenerator il, Func<object, object> converter)
{
    lock (_convertersLock) // <- lock
    {
        int converterIndex = m_Converters.Count;
        m_Converters.Add(converter);
        il.Emit(OpCodes.Ldc_I4, converterIndex);
    }
}
```