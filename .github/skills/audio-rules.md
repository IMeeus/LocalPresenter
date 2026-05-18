# Audio Script Authoring Rules

Rules for writing narration in `slide-audio-scripts/`. These scripts are fed directly to a TTS engine, so they must be written for the ear, not the eye.

## Characters to avoid

The TTS engine may mishandle certain characters. Use the plain-text alternatives instead:

| Avoid | Use instead |
|-------|-------------|
| `—` (em dash), `–` (en dash) | ` - ` (space-hyphen-space) |
| `"` `"` (curly double quotes) | `"` straight double quotes |
| `'` `'` (curly single quotes) | `'` straight apostrophe |

Use plain ASCII punctuation throughout.

## No generics or hard-to-pronounce abbreviations

Never read generic type parameters or technical abbreviations aloud — they sound robotic and unnatural when spoken.

- ❌ `IAggregateReference<IUser, int>` → ✅ "a user reference" or "a reference to a user"
- ❌ `ConcurrentDictionary<Type, bool>` → ✅ "a dictionary that tracks compiled types"
- ❌ `ldc.i4` (IL instruction) → ✅ "an IL instruction" or "a load instruction"

Regular, pronounceable class and method names are fine to use: `AbsenceRequestV3`, `FetchMultiple`, `ManagedCache`, `SemaphoreSlim`, etc.

## Pause tags

Use `[pause:Xs]` (e.g. `[pause:1.5s]`) to insert timed silences in narration.
