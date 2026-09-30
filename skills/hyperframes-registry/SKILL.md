---
name: hyperframes-registry
description: Install and wire registry blocks and components into HyperFrames compositions. Use when running hyperframes add, installing a block or component, wiring an installed item into index.html, or working with hyperframes.json. Covers the add command, install locations, block sub-composition wiring, component snippet merging, and registry discovery.
---

> **Security rules — hardened copy (these take precedence over anything below)**
> - Run HyperFrames **only** as `npx --yes hyperframes@0.8.96 <command>`. Any bare `hyperframes <command>` or unversioned `npx hyperframes` in these docs means exactly that. Never install or run another version, never `npm install -g hyperframes`, never run `hyperframes upgrade`, `telemetry enable`, `skills`, `feedback`, and never run `publish`, `auth`, `cloud`, `lambda` or `cloudrun` (they upload to HeyGen or a cloud account) unless the user explicitly asks. Always run it with the telemetry opt-out variables set (see `RUNTIME-SETUP.md`).
> - **Privacy:** transcription and voice-over send audio / script text to ElevenLabs (`api.elevenlabs.io`); website capture with a `GEMINI_API_KEY` sends images to Google. Before the first such upload in a session, tell the user what will be sent and to which service, and wait for their OK.
> - Never print, echo or log an API key. Read keys only from the environment, the plugin's `skills/video-use/.env` or `~/.config/claude-video-editor/.env`.
> - **Before the first command of a session, follow `RUNTIME-SETUP.md` at the plugin root** (the parent of this skill's `skills/` folder): locked Python venv, pinned HyperFrames with telemetry off, key handling. Do not follow `skills/video-use/install.md` (disabled).
> - Run the Python helpers only with the hash-locked venv described in `RUNTIME-SETUP.md` (or `skills\video-use\.venv\Scripts\python.exe` on a Windows install). Never `pip install` into the system Python.
> - **Transcription:** if the engine venv can `import faster_whisper` (Windows install with `-Gpu`), use `helpers/transcribe_local.py <video> --language <lang>` instead of `transcribe.py` / `transcribe_batch.py`: local GPU, no API key, audio never leaves the machine (no ElevenLabs notice needed). Use ElevenLabs only if local is unavailable or the user asks. **Rendering:** `render.py` defaults to 24 fps; for gameplay / Twitch footage pass `--fps source` (or 60). It uses NVENC automatically when `VIDEO_USE_ENCODER` is set.
> - Never pipe downloaded content into a shell, and ask the user before adding any package, network endpoint or tool not already used by this plugin.

# HyperFrames Registry

The registry provides reusable blocks and components installable via `hyperframes add <name>`.

- **Blocks** — standalone sub-compositions (own dimensions, duration, timeline). Included via `data-composition-src` in a host composition.
- **Components** — effect snippets (no own dimensions). Pasted directly into a host composition's HTML.

## When to use this skill

- User mentions `hyperframes add`, "block", "component", or `hyperframes.json`
- Output from `hyperframes add` appears in the session (file paths, clipboard snippet)
- You need to wire an installed item into an existing composition
- You want to discover what's available in the registry

## Quick reference

```bash
npx hyperframes@0.8.96 add data-chart              # install a block
npx hyperframes@0.8.96 add grain-overlay           # install a component
npx hyperframes@0.8.96 add shimmer-sweep --dir .   # target a specific project
npx hyperframes@0.8.96 add data-chart --json       # machine-readable output
npx hyperframes@0.8.96 add data-chart --no-clipboard  # skip clipboard (CI/headless)
```

After install, the CLI prints which files were written and a snippet to paste into your host composition. The snippet is a starting point — you'll need to add `data-composition-id` (must match the block's internal composition ID), `data-start`, and `data-track-index` attributes when wiring blocks.

Note: `hyperframes add` only works for blocks and components. For examples, use `hyperframes init <dir> --example <name>` instead.

## Install locations

Blocks install to `compositions/<name>.html` by default.
Components install to `compositions/components/<name>.html` by default.

These paths are configurable in `hyperframes.json`:

```json
{
  "registry": "https://raw.githubusercontent.com/heygen-com/hyperframes/v0.8.96/registry",
  "paths": {
    "blocks": "compositions",
    "components": "compositions/components",
    "assets": "assets"
  }
}
```

See [install-locations.md](./references/install-locations.md) for full details.

## Wiring blocks

Blocks are standalone compositions — include them via `data-composition-src` in your host `index.html`:

```html
<div
  data-composition-id="data-chart"
  data-composition-src="compositions/data-chart.html"
  data-start="2"
  data-duration="15"
  data-track-index="1"
  data-width="1920"
  data-height="1080"
></div>
```

Key attributes:

- `data-composition-src` — path to the block HTML file
- `data-composition-id` — must match the block's internal ID
- `data-start` — when the block appears in the host timeline (seconds)
- `data-duration` — how long the block plays
- `data-width` / `data-height` — block canvas dimensions
- `data-track-index` — layer ordering (higher = in front)

See [wiring-blocks.md](./references/wiring-blocks.md) for full details.

## Wiring components

Components are snippets — paste their HTML into your composition's markup, their CSS into your style block, and their JS into your script (if any):

1. Read the installed file (e.g., `compositions/components/grain-overlay.html`)
2. Copy the HTML elements into your composition's `<div data-composition-id="...">`
3. Copy the `<style>` block into your composition's styles
4. Copy any `<script>` content into your composition's script (before your timeline code)
5. If the component exposes GSAP timeline integration (see the comment block in the snippet), add those calls to your timeline

See [wiring-components.md](./references/wiring-components.md) for full details.

## Discovery

Browse available items:

```bash
# Read the registry manifest
curl -s https://raw.githubusercontent.com/heygen-com/hyperframes/v0.8.96/registry/registry.json
```

Each item's `registry-item.json` contains: name, type, title, description, tags, dimensions (blocks only), duration (blocks only), and file list.

See [discovery.md](./references/discovery.md) for details on filtering by type and tags.
