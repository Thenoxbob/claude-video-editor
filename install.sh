#!/usr/bin/env bash
# video-studio installer (hardened) — verifies runtime deps, builds the video-use
# engine venv from a hash-locked requirements file, and stores the ElevenLabs key
# with owner-only permissions. Idempotent: safe to re-run.
# Windows: use install.ps1 instead.
set -euo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HF_VERSION="0.8.96"   # single pinned HyperFrames version used everywhere in this plugin
say() { printf "\033[36m▸ %s\033[0m\n" "$*"; }
warn() { printf "\033[33m!  %s\033[0m\n" "$*"; }

# ---------------------------------------------------------------------------
# 1) Runtime deps (checked only — this script never installs system packages).
# ---------------------------------------------------------------------------
PKG=""
if command -v brew  >/dev/null 2>&1; then PKG="brew install"
elif command -v apt-get >/dev/null 2>&1; then PKG="sudo apt-get install -y"; fi

MISSING=0
need() {  # need <bin> <install-name> <required|optional>
  if command -v "$1" >/dev/null 2>&1; then
    say "$1 ok ($("$1" --version 2>&1 | head -1 | cut -c1-40))"
  elif [ "$3" = required ]; then
    warn "$1 MISSING — install with:  ${PKG:-<your package manager>} $2"; MISSING=1
  else
    warn "$1 missing (optional) — ${PKG:-pkg} $2"
  fi
}
say "Checking runtime…"
need ffmpeg  ffmpeg  required
need ffprobe ffmpeg  required
need node    node    required
need npx     node    required
need python3 python  required
need yt-dlp  yt-dlp  optional       # only for downloading online sources

if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
  [ "$NODE_MAJOR" -ge 22 ] || { warn "Node $NODE_MAJOR found — HyperFrames needs Node 22+"; MISSING=1; }
fi
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' \
    || { warn "Python 3.10+ required"; MISSING=1; }
fi
if [ -d "/Applications/Google Chrome.app" ] || command -v google-chrome >/dev/null 2>&1 \
   || command -v chromium >/dev/null 2>&1; then say "chrome ok"
else warn "Chrome/Chromium not found — HyperFrames renders need it."; fi
[ "$MISSING" = 1 ] && { warn "Install the required deps above, then re-run."; exit 1; }

# ---------------------------------------------------------------------------
# 2) video-use engine venv — exact versions, every file checked against its hash.
# ---------------------------------------------------------------------------
VU="$ROOT/skills/video-use"
say "Building the engine venv from requirements.lock (hash-verified)…"
[ -d "$VU/.venv" ] || python3 -m venv "$VU/.venv"
"$VU/.venv/bin/python" -m pip install --quiet --disable-pip-version-check \
  --require-hashes --only-binary=:all: -r "$VU/requirements.lock"
"$VU/.venv/bin/python" -c 'import requests, numpy, PIL' && say "engine ready: $VU/.venv"

# ---------------------------------------------------------------------------
# 3) ElevenLabs key — typed without echo, file readable by you only.
# ---------------------------------------------------------------------------
ENV="$VU/.env"
if [ -n "${ELEVENLABS_API_KEY:-}" ]; then
  say "ELEVENLABS_API_KEY found in your environment — nothing written to disk"
elif [ -f "$ENV" ] && grep -q '^ELEVENLABS_API_KEY=.' "$ENV" 2>/dev/null; then
  chmod 600 "$ENV"; say "ElevenLabs key already set (permissions tightened to 600)"
else
  printf "\nElevenLabs API key — get one at elevenlabs.io/app/settings/api-keys\n"
  printf "Paste it (input hidden; Enter to skip): "
  read -rs KEY || true; echo
  if [ -n "${KEY:-}" ]; then
    printf 'ELEVENLABS_API_KEY=%s\n' "$KEY" > "$ENV"; chmod 600 "$ENV"; unset KEY
    say "key saved to $ENV (mode 600)"
  else
    warn "skipped — add ELEVENLABS_API_KEY=... to $ENV (chmod 600) before transcribing"
  fi
fi

# ---------------------------------------------------------------------------
# 4) HyperFrames CLI sanity (pinned version).
# ---------------------------------------------------------------------------
export HYPERFRAMES_NO_TELEMETRY=1 HYPERFRAMES_NO_UPDATE_CHECK=1 HYPERFRAMES_NO_AUTO_INSTALL=1
say "Disabling HyperFrames usage telemetry (on by default upstream; sent to PostHog)…"
npx --yes "hyperframes@${HF_VERSION}" telemetry disable >/dev/null 2>&1 \
  && say "telemetry disabled (persisted in ~/.hyperframes/config.json)" \
  || warn "could not disable telemetry — run: npx hyperframes@${HF_VERSION} telemetry disable"
say "Checking HyperFrames $HF_VERSION render path…"
npx --yes "hyperframes@${HF_VERSION}" doctor || warn "hyperframes doctor reported issues (see above)"

cat <<EOF

$(say "Claude video editor (hardened) installed.")
  Skills:   $ROOT/skills
  Engine:   $VU/.venv
  Template: $ROOT/templates/project  (copy it next to your footage)
  Security: see SECURITY-HARDENING.md

Next: register the plugin with Claude Code (see README), then:
  cp -r "$ROOT/templates/project" ~/my-video && cd ~/my-video
EOF
