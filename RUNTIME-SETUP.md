# Runtime setup (read before the first command of a session)

This plugin may run in a sandboxed Linux session (Claude app) where nobody ran
`install.sh`, the plugin folder may be read-only, and shell state (env vars,
cwd) does not persist between commands. Do the steps below once per session,
silently, before the first helper or HyperFrames command. Do not tell the user
about paths or env vars unless something fails.

**Plugin root** = the parent of the `skills/` folder that contains the skill you
loaded (the skill's base directory is `<root>/skills/<skill-name>`).

## 1. Python engine (hash-locked)

Use `<root>/skills/video-use/.venv/bin/python` if it exists. Otherwise build a
venv in a writable place, from the lock file only:

```bash
V="$HOME/.cache/claude-video-editor/venv"
[ -x "$V/bin/python" ] || { python3 -m venv "$V" && "$V/bin/python" -m pip install -q \
  --disable-pip-version-check --require-hashes --only-binary=:all: \
  -r "<root>/skills/video-use/requirements.lock"; }
"$V/bin/python" -c 'import requests, numpy, PIL' && echo engine-ok
```

Run every helper with that interpreter (`"$V/bin/python" <root>/skills/video-use/helpers/render.py …`).
Never `pip install` anything else, never install into the system Python, never
drop `--require-hashes`. If the lock install fails, stop and tell the user.

## 2. HyperFrames (pinned, telemetry off)

Prefix **every** HyperFrames command with the opt-out variables (they do not
persist between shell calls), and point it at a Chromium if Chrome is missing:

```bash
export HYPERFRAMES_NO_TELEMETRY=1 DO_NOT_TRACK=1 HYPERFRAMES_NO_UPDATE_CHECK=1 HYPERFRAMES_NO_AUTO_INSTALL=1
for c in "$(command -v google-chrome)" "$(command -v chromium)" /opt/pw-browsers/chromium; do
  [ -n "$c" ] && [ -x "$c" ] && export HYPERFRAMES_BROWSER_PATH="$c" && break; done
npx --yes hyperframes@0.8.96 <command> …
```

Once per session, before the first render: `npx --yes hyperframes@0.8.96 telemetry disable`.
Requires Node 22+ (`node -v`); if older, tell the user rendering is unavailable here.

## 3. Transcription: local GPU first

On a Windows install made with `install.ps1 -Gpu` (NVIDIA), the venv is
`<root>\skills\video-use\.venv\Scripts\python.exe` and contains faster-whisper.
Check with `<venv python> -c "import faster_whisper"`. If it succeeds:

```bash
<venv python> <root>/skills/video-use/helpers/transcribe_local.py <video> --language fr
```

- Writes `<video_dir>/edit/transcripts/<stem>.json` in the same format as
  ElevenLabs Scribe, so `pack_transcripts.py` and `render.py --build-subtitles`
  work unchanged. The EDL source key must equal the video file stem.
- float16 on the GPU (required on RTX 50-series); ~1.6 GB model download on
  first use. No speaker labels, no audio-event tags.
- Long VODs: run it on the whole file once (cached); never re-transcribe.
- Renders: `VIDEO_USE_ENCODER=h264_nvenc` is set by the installer when NVENC
  works; pass `--fps source` for gameplay (default is 24 fps).

Only if local transcription is unavailable, use ElevenLabs (next section).

## 4. ElevenLabs key

Look for it in this order and stop at the first hit; never print it:

1. `$ELEVENLABS_API_KEY`
2. `<root>/skills/video-use/.env`
3. `~/.config/claude-video-editor/.env`

If none exists and the task needs transcription or voice-over:

- Tell the user, once: the key will be sent in this conversation (so it stays in
  the chat history); recommend a **restricted** ElevenLabs key (only
  Speech-to-Text / Text-to-Speech permissions, with a credit limit) that they can
  revoke later; and that audio / script text will be sent to ElevenLabs.
- When they paste it, write it without echoing it back:

  ```bash
  umask 077; mkdir -p ~/.config/claude-video-editor
  printf 'ELEVENLABS_API_KEY=%s\n' '<key>' > ~/.config/claude-video-editor/.env
  chmod 600 ~/.config/claude-video-editor/.env
  ```

- Never repeat the key in a message, a file name, a log or a command output.
  The helpers read that file on their own; do not pass the key on the command line.

## 5. Footage and outputs

Work on copies of the user's files in a working directory, never on the originals.
Deliver `final.mp4` (and any other deliverable) to the user as a file at the end.
