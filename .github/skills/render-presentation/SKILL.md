---
name: render-presentation
description: Renders a presentation project into a video by converting slides to images with marp, generating audio with piper, and combining them with ffmpeg. Use when a user asks to render, generate, build, or produce a video from a presentation project.
allowed-tools: shell
---

# render-presentation skill

When asked to render a presentation project into a video:

1. Ask the user for the project name if not already provided.

2. Verify the project folder exists and contains slides. The folder should be at `<repo-root>/<project-name>/`.

3. Run the render script from this skill's directory:

   ```powershell
   & "$Env:SKILL_BASE_DIR\render.ps1" -ProjectPath "<repo-root>\<project-name>"
   ```

   Where `<repo-root>` is the root of the presenter repository (current working directory when `copilot` was launched).

4. Report the result to the user:
   - On success: tell them the output video is at `<project-name>/output/presentation.mp4`
   - On failure: show the error output and help diagnose the issue

## What the render script does

The `render.ps1` script runs the full pipeline:
1. **marp** — converts each `slides/NN-*.md` to a PNG in `slide-images/`
2. **piper** — converts each `slide-audio-scripts/NN-*.txt` to a WAV in `slide-audio/`
3. **ffmpeg** — combines each PNG + WAV into a per-slide MP4 segment
4. **ffmpeg** — concatenates all segments into `output/presentation.mp4`

## Troubleshooting

- If a slide has no matching audio script, the render will skip narration and use 3 seconds as the slide duration
- Ensure piper and marp are on the system PATH
- Ensure ffmpeg is available on the system PATH
- The piper voice model must be present at `.piper/models/en_US-lessac-medium.onnx` in the repo root
