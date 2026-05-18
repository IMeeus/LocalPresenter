---
name: review-presentation
description: Reviews all slides and audio scripts in a presentation project for inconsistencies, stale references, formatting gaps, and audio rule violations. Use after making changes to a presentation or on demand to check quality before rendering.
---

# review-presentation skill

Audit every slide and audio script in a presentation project for consistency issues. Read all files first, then work through the checklist below. Report every issue found, then fix them — no confirmation needed unless a fix requires a judgment call about content.

## 1. Identify the project

Determine the project name from the user's request, or ask if it isn't clear.

## 2. Read all files

Read every file in:
- `<project-name>/slides/` — all `NN-*.md` files
- `<project-name>/slide-audio-scripts/` — all `NN-*.txt` files

Read them all before starting the checklist. Do not review one file at a time.

## 3. Consistency checklist

Work through each check in order. Note every issue found.

### 3.1 Slide-audio pairing
Every `slides/NN-name.md` must have a matching `slide-audio-scripts/NN-name.txt` with the **exact same base name**. Flag any slide without a matching audio script and any audio script without a matching slide.

### 3.2 Sequential numbering
The NN prefixes must form a complete sequence with no gaps and no duplicates (e.g. 01, 02, 03 — not 01, 03, 04). Flag any gap or duplicate across both the `slides/` and `slide-audio-scripts/` directories independently.

### 3.3 Stale enumeration references
Search all slides and audio scripts for references to numbered options or steps that no longer exist — for example:
- "Option 1 / Option 2 / Option 3 / Option 4"
- "Option one / Option two / Option three / Option four"
- "Step 1 / Step 2" (only flag if no numbered step list is visible in any slide)

If such a reference exists but no corresponding option list appears in any slide, it is stale and must be rewritten.

### 3.4 Stale cross-slide references
Search all audio scripts for phrases that reference other slides by number or relative position, such as:
- "as shown in slide 3", "in the previous slide", "on the next slide", "as we saw earlier"

Verify that the referenced slide still exists and still contains the referenced content. Flag any that are outdated or point to deleted slides.

### 3.5 Terminology consistency
Identify all proper nouns, type names, team names, and technical terms used across the deck. Flag any term that is referred to by different names in different files (e.g. a type called `AbsenceRequest` in one place and `AbsenceRequestV3` in another; a team called "Bravas" in one place and "Team Bravas" in another). Pick the correct name and apply it consistently everywhere.

### 3.6 Formatting consistency
Look for recurring terms that are formatted inconsistently — for example, a team name that is bold in one slide bullet but plain text in another. Flag cases where the same term should clearly receive the same treatment throughout the deck.

### 3.7 Deleted concept references
After any slide deletion or merging, check whether remaining audio scripts or slides still mention concepts that were removed. Examples:
- Audio that says "as mentioned on the previous slide" when that slide was deleted
- Audio that describes fix options that no longer have a dedicated slide
- A takeaway slide that references a section that was cut

### 3.8 Audio script rules (per `rules.md`)
Check every audio script for violations of the TTS rules:

| Rule | What to check |
|------|--------------|
| No em dash (`—`) or en dash (`–`) | Replace with ` - ` (space-hyphen-space) |
| No curly quotes (`"` `"` `'` `'`) | Replace with straight `"` or `'` |
| No generic type parameters | e.g. `IEnumerable<T>` → "a sequence of items" |
| No hard-to-pronounce abbreviations | e.g. `ldc.i4` → "a load instruction" |

Regular class and method names that are pronounceable are fine (e.g. `FetchMultiple`, `ManagedCache`).

### 3.9 Narrative arc
Read the deck as a whole. Flag slides that:
- Substantially repeat content already covered by another slide
- Assume context that hasn't been established yet
- Leave a concept introduced but never resolved

## 4. Report findings

After completing the checklist, produce a report:

```
## Consistency review

### Issues found
- [3.3] Audio 06: stale "Option four" reference — no option list exists in any slide
- [3.6] Slide 02: "Team Bravas" bold in bullet 5 but not bullet 4
- ...

### No issues
- [3.1] All slides have matching audio scripts ✓
- [3.2] Numbering is sequential ✓
- ...
```

If no issues are found at all, say so clearly.

## 5. Fix issues

Fix all clearly mechanical issues immediately (stale references, formatting inconsistencies, rule violations). For issues that require a content judgment call (e.g. a narrative gap that could be resolved multiple ways), describe the options and ask the user to decide.

After fixing, re-read the affected files to confirm the fixes are correct.
