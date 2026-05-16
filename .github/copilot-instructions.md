# Presenter — Copilot Instructions

This repository contains the **presenter** tool: a local presentation-video pipeline that combines:
- **marp** — converts markdown files in `slides/` into PNG images
- **piper** — converts text scripts in `slide-audio-scripts/` into WAV audio (one file per slide)
- **ffmpeg** — combines slide images and audio into a final MP4 video

## Project layout

Each presentation project lives in its own folder under the repo root:

```
{project-name}/
├── slides/                  ← markdown files named NN-description.md (e.g. 01-intro.md)
├── slide-audio-scripts/     ← plain text files matching slide names (e.g. 01-intro.txt)
├── slide-audio/             ← (generated) WAV audio per slide
├── slide-images/            ← (generated) PNG images per slide
└── output/                  ← (generated) final presentation.mp4
```

## Skills available

- `/setup-presentation` — initialize a new project folder structure
- `/update-presentation` — add or update slides and audio scripts
- `/render-presentation` — run the full pipeline to generate the video

## Conventions

- Slide files: `NN-description.md` where NN is a zero-padded number (01, 02, ...)
- Audio script files: same base name as the slide, with `.txt` extension
- Slides must begin with marp frontmatter (`marp: true`)
- Audio scripts are plain text; they become the spoken narration for that slide
