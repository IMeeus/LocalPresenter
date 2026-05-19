---
marp: true
theme: default
---

# Recommended Fix: Fork & Patch NPoco

The cleanest fix is to create a **dedicated NPoco fork** and apply a **5-line patch** directly in `MappingFactory`:

```csharp
// MappingFactory.cs (NPoco fork)
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

✅ Fixes the root cause — no more race on the converter list  
✅ Protects **all** NPoco fetch paths, not just our call site  
