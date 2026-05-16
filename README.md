# presenter

A local presentation-video generator that combines **marp**, **piper**, and **ffmpeg** into a simple workflow — driven by Copilot CLI skills.

Write your slides in markdown. Write your narration in plain text. Run a skill to get a presentation video.

---

## How it works

```
slides/NN-name.md          ──marp──▶  slide-images/NN-name.png  ─┐
slide-audio-scripts/NN-name.txt  ──piper──▶  slide-audio/NN-name.wav  ─┤──ffmpeg──▶ output/presentation.mp4
```

Each slide gets its own PNG image and its own WAV audio file. The duration of the audio determines how long that slide appears in the video.

---

## Prerequisites

| Tool | Install |
|------|---------|
| **ffmpeg** | [ffmpeg.org/download.html](https://ffmpeg.org/download.html) — add to PATH |
| **marp-cli** | `npm install -g @marp-team/marp-cli` |
| **piper** (TTS) | `pip install piper-tts` |
| **piper voice model** | Download `en_US-lessac-medium.onnx` + `.onnx.json` from [github.com/rhasspy/piper/releases](https://github.com/rhasspy/piper/releases) and place them in `.piper/models/` in the repo root |

---

## Project layout

Each presentation is a self-contained folder under the repo root:

```
{project-name}/
├── slides/                   ← one .md file per slide, named NN-description.md
├── slide-audio-scripts/      ← one .txt file per slide, same base name as the slide
├── slide-audio/              ← (generated) WAV files produced by piper
├── slide-images/             ← (generated) PNG files produced by marp
└── output/                   ← (generated) final presentation.mp4
```

### Slide naming convention

Use a zero-padded number prefix to control slide order:

```
slides/
├── 01-intro.md
├── 02-main-topic.md
└── 03-conclusion.md

slide-audio-scripts/
├── 01-intro.txt
├── 02-main-topic.txt
└── 03-conclusion.txt
```

### Slide format

Each slide file must start with marp frontmatter:

```markdown
---
marp: true
theme: default
---

# Your Slide Title

Content goes here...
```

### Audio script format

Plain text — written as natural spoken language. This is what piper will read aloud:

```
Welcome, everyone. Today I'll be talking about ...
```

---

## Copilot CLI Skills

This repo ships three Copilot CLI project skills. Launch `copilot` from this repo root to use them.

### `/setup-presentation` — Create a new project

Scaffolds the folder structure for a new presentation project.

**Example prompt:**
```
Use the /setup-presentation skill to create a project called "my-talk"
```

This creates `my-talk/` with all required folders and placeholder files ready to edit.

---

### `/update-presentation` — Add or update slides and scripts

Adds or updates markdown slides and their matching audio scripts in a project.

**Example prompt:**
```
Use the /update-presentation skill to add two slides to my-talk:
  1. An intro slide about AI
  2. A conclusion slide with a call to action
```

Copilot will create the correctly numbered files in `slides/` and matching scripts in `slide-audio-scripts/`.

---

### `/render-presentation` — Generate the video

Runs the full pipeline: marp → piper → ffmpeg → MP4.

**Example prompt:**
```
Use the /render-presentation skill to render my-talk
```

The final video will be at `my-talk/output/presentation.mp4`.

---

## Hello-world example

A proof-of-concept project is included in the `hello-world/` folder:

```
hello-world/
├── slides/
│   └── 01-hello.md          ← "Hello World" title slide
└── slide-audio-scripts/
    └── 01-hello.txt         ← "Hello world. Welcome to my first presentation!"
```

To render it, run:

```
Use the /render-presentation skill to render the hello-world project
```

Or run the script directly:

```powershell
& ".github\skills\render-presentation\render.ps1" -ProjectPath ".\hello-world"
```

The output video will be at `hello-world/output/presentation.mp4`.

---

## Running scripts directly

You can also call the PowerShell scripts without Copilot:

```powershell
# Set up a new project
& ".github\skills\setup-presentation\setup.ps1" -ProjectName "my-talk"

# Render a project
& ".github\skills\render-presentation\render.ps1" -ProjectPath ".\my-talk"
```

---

## Configuration

The render script resolves the piper model automatically from `.piper\models\en_US-lessac-medium.onnx` in the repo root. You can override this with the `-ModelPath` parameter:

```powershell
& ".github\skills\render-presentation\render.ps1" -ProjectPath ".\my-talk" -ModelPath "C:\models\custom.onnx"
```
