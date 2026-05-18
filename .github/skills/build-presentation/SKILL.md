---
name: build-presentation
description: Sets up a new presentation project and authors or updates its slides and audio scripts. Use this when a user asks to create, set up, initialize, add slides to, or update a presentation project. Never renders the video — rendering is handled by the render-presentation skill.
allowed-tools: shell
---

# build-presentation skill

This skill combines project scaffolding and content authoring into a single workflow. It never renders the video — always tell the user to run `/render-presentation` when they are ready.

## 1. Identify the project

Determine the project name from the user's request or ask if it isn't clear. Project names should be lowercase with hyphens (e.g. `my-presentation`).

## 2. Scaffold the project folder (idempotent)

Run the setup script to create the required folder structure. It is safe to run even if the project already exists — it will skip any folders or files that are already present.

```powershell
& "$Env:SKILL_BASE_DIR\setup.ps1" -ProjectName "<project-name>" -RepoRoot "<repo-root>"
```

Where `<repo-root>` is the root of the presenter repository (the current working directory when `copilot` was launched).

## 3. Gather context

Content for slides and narration comes from the user's prompt — any description, notes, or instructions provided directly in their message. If there isn't enough detail to author the presentation, ask the user for the information you need before proceeding.

## 4. Author slides

Slides live in `<project-name>/slides/` and follow the naming convention `NN-description.md`:
- `NN` is a zero-padded number (`01`, `02`, `03` …)
- `description` is a short kebab-case label

Each slide file must begin with marp frontmatter:

```markdown
---
marp: true
theme: default
---

# Slide Title

Slide content here...
```

When adding new slides, pick the next available number in sequence. When updating existing slides, preserve their filenames.

## 5. Author audio scripts

Audio scripts live in `<project-name>/slide-audio-scripts/` with the **same base filename** as their slide but a `.txt` extension.

Example: `slides/02-overview.md` → `slide-audio-scripts/02-overview.txt`

Write scripts in natural spoken language — this is exactly what will be narrated. Do not use markdown.

Follow the rules in [`rules.md`](rules.md) for characters to avoid, generics/abbreviations, and pause tags.

## 6. Summarize and hand off

After completing all changes, list:
- Files created or modified
- Any slides without a matching audio script (gaps)

Then tell the user: **"Run `/render-presentation` when you're ready to generate the video."** Do not render the video yourself.
