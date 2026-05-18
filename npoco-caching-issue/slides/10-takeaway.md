---
marp: true
theme: default
---

# Takeaway

**The bug:** NPoco bakes converter indices into generated IL using a non-atomic read-then-append on a static list. Concurrent first-use compilations assign the same index to different converters → permanently broken factory, cached for 1 hour.

**The fix (Option 4):** A 5-line patch in our NPoco fork — add a lock object, make the read-then-append atomic. Protects every NPoco fetch path in the codebase.

**The lesson:** When a third-party library uses static mutable state for one-time initialisation, concurrent startup is a hidden risk — widest at exactly the moment traffic arrives on a fresh process.

**What's next:** Ship the NPoco fork patch. The fix was always five lines — finding *where* to look was the hard part.
