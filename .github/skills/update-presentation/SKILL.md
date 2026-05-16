---
name: update-presentation
description: Adds or updates slides and audio scripts in an existing presentation project. Use this when a user asks to add, create, update, or refine slides or narration scripts for a project.
---

# update-presentation skill

When asked to add or update content in a presentation project, follow these steps:

## 1. Identify the project

Ask the user for the project name if it isn't clear from context. Verify that the project folder exists under the repo root.

## 2. Determine what to change

Ask the user what they want to add or update:
- New slides
- Updated slide content
- New audio scripts
- Updated narration

## 3. Work on the slides folder

Slides live in `<project-name>/slides/` and follow the naming convention `NN-description.md` where:
- `NN` is a zero-padded number (e.g. `01`, `02`, `03`)
- `description` is a short kebab-case description of the slide

Each markdown file must start with marp frontmatter:

```markdown
---
marp: true
theme: default
---

# Slide Title

Slide content here...
```

When adding a new slide, pick the next available number in sequence. When updating an existing slide, preserve its filename.

## 4. Work on the audio scripts folder

Audio scripts live in `<project-name>/slide-audio-scripts/` and have the **same base filename** as their corresponding slide, but with a `.txt` extension.

For example: `slides/02-overview.md` → `slide-audio-scripts/02-overview.txt`

The text in the script is exactly what will be spoken aloud for that slide. Write it in natural spoken language (not markdown).

## 5. Summarize changes

After making all changes, list what was added or updated:
- Files created
- Files modified
- Any gaps (e.g. slides without matching audio scripts)

Remind the user to run `/render-presentation` when they're ready to generate the video.
