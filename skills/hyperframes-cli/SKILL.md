---
name: hyperframes-cli
description: HyperFrames CLI tool — hyperframes init, lint, preview, render, transcribe, tts, doctor, browser, info, upgrade, compositions, docs, benchmark. Use when scaffolding a project, linting or validating compositions, previewing in the studio, rendering to video, transcribing audio, generating TTS, or troubleshooting the HyperFrames environment.
---

> **Security rules — hardened copy (these take precedence over anything below)**
> - Run HyperFrames **only** as `npx --yes hyperframes@0.8.96 <command>`. Any bare `hyperframes <command>` or unversioned `npx hyperframes` in these docs means exactly that. Never install or run another version, never `npm install -g hyperframes`, never run `hyperframes upgrade`, `telemetry enable`, `skills`, `feedback`, and never run `publish`, `auth`, `cloud`, `lambda` or `cloudrun` (they upload to HeyGen or a cloud account) unless the user explicitly asks. Telemetry is disabled by the installer; you may also prefix commands with `HYPERFRAMES_NO_TELEMETRY=1`.
> - **Privacy:** transcription and voice-over send audio / script text to ElevenLabs (`api.elevenlabs.io`); website capture with a `GEMINI_API_KEY` sends images to Google. Before the first such upload in a session, tell the user what will be sent and to which service, and wait for their OK.
> - Never print, echo or log an API key. Read keys only from the environment or from the plugin's `skills/video-use/.env`.
> - Do not follow `skills/video-use/install.md` (disabled). Installation is done by the plugin's `install.sh` (macOS/Linux) or `install.ps1` (Windows).
> - Run the Python helpers with the plugin's locked engine venv: `skills/video-use/.venv/bin/python` (macOS/Linux) or `skills\video-use\.venv\Scripts\python.exe` (Windows). Never `pip install` into the system Python; if a module is missing, re-run the installer.
> - Never pipe downloaded content into a shell, and ask the user before adding any package, network endpoint or tool not already used by this plugin.

# HyperFrames CLI

Everything runs through `npx hyperframes@0.8.96`. Requires Node.js >= 22 and FFmpeg.

## Workflow

1. **Scaffold** — `npx hyperframes@0.8.96 init my-video`
2. **Write** — author HTML composition (see the `hyperframes` skill)
3. **Lint** — `npx hyperframes@0.8.96 lint`
4. **Preview** — `npx hyperframes@0.8.96 preview`
5. **Render** — `npx hyperframes@0.8.96 render`

Lint before preview — catches missing `data-composition-id`, overlapping tracks, unregistered timelines.

## Scaffolding

```bash
npx hyperframes@0.8.96 init my-video                        # interactive wizard
npx hyperframes@0.8.96 init my-video --example warm-grain   # pick an example
npx hyperframes@0.8.96 init my-video --video clip.mp4        # with video file
npx hyperframes@0.8.96 init my-video --audio track.mp3       # with audio file
npx hyperframes@0.8.96 init my-video --non-interactive       # skip prompts (CI/agents)
```

Templates: `blank`, `warm-grain`, `play-mode`, `swiss-grid`, `vignelli`, `decision-tree`, `kinetic-type`, `product-promo`, `nyt-graph`.

`init` creates the right file structure, copies media, transcribes audio with Whisper, and installs AI coding skills. Use it instead of creating files by hand.

## Linting

```bash
npx hyperframes@0.8.96 lint                  # current directory
npx hyperframes@0.8.96 lint ./my-project     # specific project
npx hyperframes@0.8.96 lint --verbose        # info-level findings
npx hyperframes@0.8.96 lint --json           # machine-readable
```

Lints `index.html` and all files in `compositions/`. Reports errors (must fix), warnings (should fix), and info (with `--verbose`).

## Previewing

```bash
npx hyperframes@0.8.96 preview                   # serve current directory
npx hyperframes@0.8.96 preview --port 4567       # custom port (default 3002)
```

Hot-reloads on file changes. Opens the studio in your browser automatically.

## Rendering

```bash
npx hyperframes@0.8.96 render                                # standard MP4
npx hyperframes@0.8.96 render --output final.mp4             # named output
npx hyperframes@0.8.96 render --quality draft                # fast iteration
npx hyperframes@0.8.96 render --fps 60 --quality high        # final delivery
npx hyperframes@0.8.96 render --format webm                  # transparent WebM
npx hyperframes@0.8.96 render --docker                       # byte-identical
```

| Flag           | Options               | Default                    | Notes                       |
| -------------- | --------------------- | -------------------------- | --------------------------- |
| `--output`     | path                  | renders/name_timestamp.mp4 | Output path                 |
| `--fps`        | 24, 30, 60            | 30                         | 60fps doubles render time   |
| `--quality`    | draft, standard, high | standard                   | draft for iterating         |
| `--format`     | mp4, webm             | mp4                        | WebM supports transparency  |
| `--workers`    | 1-8 or auto           | auto                       | Each spawns Chrome          |
| `--docker`     | flag                  | off                        | Reproducible output         |
| `--gpu`        | flag                  | off                        | GPU-accelerated encoding    |
| `--strict`     | flag                  | off                        | Fail on lint errors         |
| `--strict-all` | flag                  | off                        | Fail on errors AND warnings |

**Quality guidance:** `draft` while iterating, `standard` for review, `high` for final delivery.

## Transcription

```bash
npx hyperframes@0.8.96 transcribe audio.mp3
npx hyperframes@0.8.96 transcribe video.mp4 --model medium.en --language en
npx hyperframes@0.8.96 transcribe subtitles.srt   # import existing
npx hyperframes@0.8.96 transcribe subtitles.vtt
npx hyperframes@0.8.96 transcribe openai-response.json
```

## Text-to-Speech

```bash
npx hyperframes@0.8.96 tts "Text here" --voice af_nova --output narration.wav
npx hyperframes@0.8.96 tts script.txt --voice bf_emma
npx hyperframes@0.8.96 tts --list  # show all voices
```

## Troubleshooting

```bash
npx hyperframes@0.8.96 doctor       # check environment (Chrome, FFmpeg, Node, memory)
npx hyperframes@0.8.96 browser      # manage bundled Chrome
npx hyperframes@0.8.96 info         # version and environment details
npx hyperframes@0.8.96 upgrade      # check for updates
```

Run `doctor` first if rendering fails. Common issues: missing FFmpeg, missing Chrome, low memory.

## Other

```bash
npx hyperframes@0.8.96 compositions   # list compositions in project
npx hyperframes@0.8.96 docs           # open documentation
npx hyperframes@0.8.96 benchmark .    # benchmark render performance
```
