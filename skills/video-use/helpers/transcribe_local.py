"""Transcribe a video LOCALLY with faster-whisper (NVIDIA GPU if available).

Hardened-copy addition. A drop-in alternative to transcribe.py (ElevenLabs
Scribe): no API key, the audio never leaves the machine. Writes the same
Scribe-shaped JSON to <edit_dir>/transcripts/<video_stem>.json, so
pack_transcripts.py, render.py (subtitles) and the rest of the pipeline work
unchanged:

    {"language_code": "fr", "text": "...", "source": "faster-whisper",
     "words": [{"text": "Salut", "start": 0.52, "end": 0.81,
                "type": "word", "speaker_id": "speaker_0"},
               {"text": " ", "start": 0.81, "end": 0.95, "type": "spacing",
                "speaker_id": "speaker_0"}, ...]}

Limits vs Scribe: no speaker diarization (everyone is speaker_0) and no
audio-event tags such as (laughs).

GPU notes: RTX 50-series (Blackwell) must use float16 (int8 crashes with older
CTranslate2 builds); float16 is the default on CUDA. On Windows the CUDA
libraries come from the nvidia-cublas-cu12 / nvidia-cudnn-cu12 wheels in the
venv (installed by `install.ps1 -Gpu`); their DLL folders are registered below.

Cached: if the output file already exists, nothing is redone.

Usage:
    python helpers/transcribe_local.py <video> [--edit-dir DIR] [--language fr]
        [--model large-v3-turbo] [--device auto|cuda|cpu] [--compute-type auto]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path


def _register_windows_cuda_dlls() -> None:
    """Make the pip-installed CUDA DLLs (cublas, cudnn) loadable on Windows."""
    if os.name != "nt":
        return
    try:
        import nvidia  # namespace package from nvidia-*-cu12 wheels
    except ImportError:
        return
    for root in getattr(nvidia, "__path__", []):
        for sub in ("cublas", "cudnn", "cuda_runtime", "cuda_nvrtc"):
            bin_dir = Path(root) / sub / "bin"
            if bin_dir.is_dir():
                os.add_dll_directory(str(bin_dir))
                os.environ["PATH"] = str(bin_dir) + os.pathsep + os.environ.get("PATH", "")


def pick_device(requested: str) -> str:
    if requested != "auto":
        return requested
    try:
        import ctranslate2
        return "cuda" if ctranslate2.get_cuda_device_count() > 0 else "cpu"
    except Exception:
        return "cpu"


def to_scribe_words(segments) -> tuple[list[dict], str]:
    """Convert faster-whisper segments into Scribe-style word/spacing entries."""
    words: list[dict] = []
    texts: list[str] = []
    prev_end: float | None = None
    for seg in segments:
        texts.append(seg.text.strip())
        for w in seg.words or []:
            token = w.word.strip()
            if not token:
                continue
            start, end = round(float(w.start), 3), round(float(w.end), 3)
            if end < start:
                end = start
            if prev_end is not None and start > prev_end:
                words.append({"text": " ", "start": prev_end, "end": start,
                              "type": "spacing", "speaker_id": "speaker_0"})
            words.append({"text": token, "start": start, "end": end,
                          "type": "word", "speaker_id": "speaker_0"})
            prev_end = end
    return words, " ".join(t for t in texts if t)


def transcribe(video: Path, edit_dir: Path, model_name: str, language: str | None,
               device: str, compute_type: str, beam_size: int) -> Path:
    out_dir = edit_dir / "transcripts"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{video.stem}.json"
    if out_path.exists():
        print(f"cached: {out_path}")
        return out_path

    _register_windows_cuda_dlls()
    from faster_whisper import WhisperModel

    device = pick_device(device)
    if compute_type == "auto":
        compute_type = "float16" if device == "cuda" else "int8"
    print(f"loading {model_name} on {device} ({compute_type})…", flush=True)
    model = WhisperModel(model_name, device=device, compute_type=compute_type)

    t0 = time.time()
    segments, info = model.transcribe(
        str(video),
        language=language,
        beam_size=beam_size,
        word_timestamps=True,
        vad_filter=True,                       # skip long silences / AFK
        vad_parameters={"min_silence_duration_ms": 500},
        condition_on_previous_text=False,      # limits hallucination loops on long streams
    )
    total = float(info.duration or 0.0)
    collected = []
    last_print = 0.0
    for seg in segments:                       # generator: runs as we iterate
        collected.append(seg)
        if total and time.time() - last_print > 5:
            pct = 100.0 * seg.end / total
            print(f"  {seg.end/60:6.1f} / {total/60:.1f} min  ({pct:4.1f}%)", flush=True)
            last_print = time.time()

    words, text = to_scribe_words(collected)
    data = {
        "language_code": info.language,
        "language_probability": round(float(info.language_probability or 0), 3),
        "text": text,
        "words": words,
        "source": f"faster-whisper:{model_name}:{device}:{compute_type}",
    }
    tmp = out_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    tmp.replace(out_path)
    dt = time.time() - t0
    speed = f" ({total/dt:.1f}x realtime)" if dt > 0 and total else ""
    print(f"done: {out_path}  {sum(w['type']=='word' for w in words)} words, "
          f"{total/60:.1f} min of audio in {dt/60:.1f} min{speed}")
    return out_path


def main() -> None:
    ap = argparse.ArgumentParser(description="Local (GPU) transcription → Scribe-shaped JSON")
    ap.add_argument("video", type=Path)
    ap.add_argument("--edit-dir", type=Path, default=None,
                    help="default: <video_dir>/edit")
    ap.add_argument("--language", default=None, help="e.g. fr, en (default: auto-detect)")
    ap.add_argument("--model", default="large-v3-turbo",
                    help="large-v3-turbo (fast, default), large-v3 (more accurate), small, …")
    ap.add_argument("--device", default="auto", choices=["auto", "cuda", "cpu"])
    ap.add_argument("--compute-type", default="auto",
                    help="auto = float16 on GPU (required on RTX 50), int8 on CPU")
    ap.add_argument("--beam-size", type=int, default=5)
    a = ap.parse_args()
    video = a.video.resolve()
    if not video.exists():
        sys.exit(f"not found: {video}")
    edit_dir = (a.edit_dir or video.parent / "edit").resolve()
    transcribe(video, edit_dir, a.model, a.language, a.device, a.compute_type, a.beam_size)


if __name__ == "__main__":
    main()
