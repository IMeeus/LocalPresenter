---
marp: true
theme: default
---

# Takeaway

**The bug:** NPoco bakes converter indices into generated IL using a non-atomic read-and-write on a static list. Concurrent first-use compilations assign the same index to different converters → permanently broken factory, cached indefinitely.

**The fix:** A 5-line patch in a dedicated NPoco fork — add a lock object, make the read-and-write atomic. Protects every NPoco fetch path in the codebase.

**The lesson:** When a third-party library uses static mutable state for one-time initialisation, concurrent startup is a hidden risk — widest at exactly the moment traffic arrives on a fresh process.

**What's next:** Team Bravas will create a dedicated NPoco fork and apply the patch to ship the fix as soon as possible.
