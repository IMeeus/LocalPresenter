---
name: render-presentation
description: Renders a presentation project into a video by converting slides to images with marp, generating audio with Kokoro-FastAPI, and combining them with ffmpeg. Use when a user asks to render, generate, build, or produce a video from a presentation project.
allowed-tools: shell
disable-model-invocation: true
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
2. **Kokoro-FastAPI** — calls the local Kokoro TTS server to convert each `slide-audio-scripts/NN-*.txt` to a WAV in `slide-audio/`
3. **ffmpeg** — combines each PNG + WAV into a per-slide MP4 segment
4. **ffmpeg** — concatenates all segments into `output/presentation.mp4`

## Configuration

Settings are split across two `config.json` files:

**Repo-root `config.json`** (global):
```json
{ "kokoroUrl": "http://localhost:8880" }
```

**Per-project `config.json`** (project-specific):
```json
{ "kokoroVoice": "af_heart" }
```

| Field | Scope | Default | Description |
|---|---|---|---|
| `kokoroUrl` | repo-root | `http://localhost:8880` | Base URL of the Kokoro-FastAPI server |
| `kokoroVoice` | per-project | `af_heart` | Kokoro voice name for this project |

The `-KokoroUrl` parameter on `render.ps1` overrides `kokoroUrl` from config.

### Pause tags in audio scripts

Audio scripts can embed timed pauses using `[pause:Xs]` syntax (Kokoro handles these natively):

```
Welcome to the demo. [pause:1.5s] Now let's get started.
```

## Dependencies

In addition to `marp`, `ffmpeg`, and the Kokoro-FastAPI server, the render script requires:

| Tool | Install | Required for |
|------|---------|--------------|
| **mmdc** (Mermaid CLI) | `npm install -g @mermaid-js/mermaid-cli` | Slides containing Mermaid diagrams |

`mmdc` must be on the system PATH. The render script will fail with a clear error if it is missing.

## Troubleshooting

- If a slide has no matching audio script, the render will skip narration and use 3 seconds as the slide duration
- Ensure the **Kokoro-FastAPI** server is running before rendering (`docker run -p 8880:8880 ghcr.io/remsky/kokoro-fastapi-cpu:latest` or GPU equivalent)
- Ensure **marp** and **ffmpeg** are available on the system PATH
- Check `kokoroUrl` in the repo-root `config.json` if the server is on a non-default host/port
