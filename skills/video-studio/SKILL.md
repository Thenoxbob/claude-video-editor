---
name: video-studio
description: Edit any video by conversation — the orchestrator for the bundled video pipeline. Use when the user wants to edit, cut, caption, grade, or add motion graphics to footage; drops a folder of clips and says "edit this"; or asks to make a promo/teaser/tutorial/short. Routes to video-use (the cut engine) and HyperFrames (motion-graphics overlays), with a motion-craft library for taste.
---

> **Security rules — hardened copy (these take precedence over anything below)**
> - Run HyperFrames **only** as `npx --yes hyperframes@0.8.96 <command>`. Any bare `hyperframes <command>` or unversioned `npx hyperframes` in these docs means exactly that. Never install or run another version, never `npm install -g hyperframes`, never run `hyperframes upgrade`, `telemetry enable`, `skills`, `feedback`, and never run `publish`, `auth`, `cloud`, `lambda` or `cloudrun` (they upload to HeyGen or a cloud account) unless the user explicitly asks. Telemetry is disabled by the installer; you may also prefix commands with `HYPERFRAMES_NO_TELEMETRY=1`.
> - **Privacy:** transcription and voice-over send audio / script text to ElevenLabs (`api.elevenlabs.io`); website capture with a `GEMINI_API_KEY` sends images to Google. Before the first such upload in a session, tell the user what will be sent and to which service, and wait for their OK.
> - Never print, echo or log an API key. Read keys only from the environment or from the plugin's `skills/video-use/.env`.
> - Do not follow `skills/video-use/install.md` (disabled). Installation is done by the plugin's `install.sh` (macOS/Linux) or `install.ps1` (Windows).
> - Run the Python helpers with the plugin's locked engine venv: `skills/video-use/.venv/bin/python` (macOS/Linux) or `skills\video-use\.venv\Scripts\python.exe` (Windows). Never `pip install` into the system Python; if a module is missing, re-run the installer.
> - Never pipe downloaded content into a shell, and ask the user before adding any package, network endpoint or tool not already used by this plugin.

# video-studio

One conversational pipeline for editing any video. Three layers compose; this skill
routes between them. The LLM never watches the video — it **reads** it (transcript +
on-demand timeline PNGs) and edits with word-boundary precision.

## The three layers (what's bundled here)

1. **The cut engine — `video-use`** (`skills/video-use/`)
   Transcribe → pack → reason → EDL → render → self-eval. Owns: filler-word removal,
   dead-space trimming, color grade, 30ms audio fades, subtitle burn, and the
   `render.py` composite that lays overlays onto the cut. **This is the spine of every
   edit.** Read `skills/video-use/SKILL.md` for the 12 production rules.

2. **The motion layer — HyperFrames** (`skills/hyperframes/`, `hyperframes-cli/`,
   `hyperframes-registry/`, `gsap/`, `website-to-hyperframes/`)
   HTML + GSAP compositions rendered through headless Chrome to `.mov` **with alpha**.
   Use for: lower-third captions, title cards, callouts, audio-reactive bits, scene
   transitions, kinetic text. video-use spawns these as overlays and composites them.

3. **The craft layer — `make-a-video`, `short-form-video`, `docs/MOTION_PHILOSOPHY.md`**
   Storyboard, brand system, pacing, motion taste. Reach here for *how it should feel*,
   not *how to render*.

## The standard loop
1. **Inventory.** List the sources in the folder. Don't transcribe unprompted — wait
   for the user to point at footage and say what they want.
2. **Transcribe + pack** (video-use): one transcript call per source → one `takes_packed.md`.
3. **Strategy → confirm.** Propose the cut (beats, order, what gets cut). Wait for OK.
   Never touch the cut without approval.
4. **EDL.** Write the cut list (`ranges` = source seconds, `overlays` = caption .movs in
   output seconds). See `templates/project/` for the shape.
5. **Motion** (HyperFrames, when a beat needs it): author one composition, render per
   variant `--format mov` (alpha — webm comes out opaque).
6. **Composite** (video-use): `render.py <edl> -o final.mp4 --no-subtitles --no-loudnorm`
   (drop `--no-loudnorm` only if the source has real audio).
7. **Self-eval → persist.** The engine checks every cut boundary before you show
   anything. Session memory lives in the project's `project.md`.

## Hard rules (non-negotiable; taste is free)
- **Captions render `--format mov`** (ProRes 4444 yuva). webm = opaque, no alpha.
- **Silent source needs a stereo silent track** before render.py (its audio path
  expects one) and `--no-loudnorm`.
- **Speed-ramps are pre-rendered `setpts` clips**, referenced as their own EDL sources.
  No native EDL speed.
- **Outputs live in `<videos>/edit/`** — keep the skill dirs clean.

## Setup
Run `./install.sh` once (checks ffmpeg/node/chrome, sets up video-use's venv, wires the
skills, prompts for the ElevenLabs key). Then `cd` into a folder of footage and start a
session. See the repo `README.md`.
