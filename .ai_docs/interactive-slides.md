# Interactive Slides

To add synchronized annotations (e.g. circles) to slides during narration, two problems need to be solved first.

## Problem 1: Knowing when to show the annotation (audio timing)

The pipeline needs to know the exact timestamp in the audio when a word or phrase is spoken, so the annotation can be shown at the right moment via ffmpeg's overlay filter.

**Solution: Kokoro FastAPI**
Kokoro FastAPI returns per-word timestamps alongside the generated audio in a single API call. This allows the pipeline to look up when a specific word or phrase is spoken and pass those timestamps directly to ffmpeg — no post-processing or forced alignment needed.

## Problem 2: Knowing where to show the annotation (slide coordinates)

The pipeline needs the pixel coordinates of a specific element on a slide (e.g. a code token or bullet point) so it knows where to draw the annotation on the 1920×1080 image.

**Solution: Marp HTML output + Playwright**
Marp can export slides as HTML in addition to PNG. A headless browser (Playwright) can load that HTML, query an element by text or CSS selector, and return its bounding box via `getBoundingClientRect()`. This resolves human-readable targets like `"AddConverterToStack"` to pixel coordinates without any manual measurement — the CSS layout engine does the work.
