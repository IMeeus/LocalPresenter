---
marp: true
theme: default
---

# Recommended Fix: Fork & Patch NPoco

Since we already maintain a fork, the cleanest fix is a **5-line patch** directly in NPoco's `MappingFactory`:

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
✅ Fork already exists — add a comment explaining why
