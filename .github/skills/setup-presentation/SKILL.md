---
name: setup-presentation
description: Initializes a new presentation project with the required folder structure. Use this when a user asks to set up, create, or initialize a new presentation project.
allowed-tools: shell
---

# setup-presentation skill

When asked to set up or initialize a new presentation project:

1. Ask the user for the project name if not already provided. The name should be lowercase with hyphens (e.g. `my-presentation`).

2. Run the setup script from this skill's directory:

   ```powershell
   & "$Env:SKILL_BASE_DIR\setup.ps1" -ProjectName "<project-name>" -RepoRoot "<repo-root>"
   ```

   Where:
   - `<project-name>` is the name the user provided
   - `<repo-root>` is the root of the presenter repository (the current working directory when `copilot` was launched)

3. Confirm to the user that the project has been created and describe the folder structure that was set up.

4. Tell the user what to do next:
   - Drop any source material (docs, notes, articles) into `<project-name>/context/` — Copilot will use these as the basis for slide and narration content
   - Add slides to `<project-name>/slides/` as markdown files named `NN-description.md` (e.g. `01-intro.md`)
   - Add matching audio scripts to `<project-name>/slide-audio-scripts/` as `.txt` files with the same base name
   - Run the `/render-presentation` skill when ready to generate the video

## Notes

- The script creates placeholder files (`01-title.md` and `01-title.txt`) so the project is ready to use immediately
- Generated folders (`slide-audio/`, `slide-images/`, `output/`) are already listed in `.gitignore`
- The `context/` folder holds source material (e.g. markdown docs, notes) that informs the presentation content
