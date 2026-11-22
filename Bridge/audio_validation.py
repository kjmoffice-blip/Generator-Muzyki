"""Verify a completed audio export before commit or collection cleanup."""
from pathlib import Path
import json
import os
import shutil
import subprocess


def validate_audio(path, expected_duration=None, decode=False):
    """Require real readable audio with plausible duration, optionally decoding it fully."""
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size < 32:
        raise ValueError("Brakuje kompletnego pliku audio.")
    probe = os.environ.get("SOS_MUSIC_FFPROBE") or shutil.which("ffprobe")
    if not probe:
        raise ValueError("Instalacja nie zawiera narzędzia sprawdzania audio.")
    raw = subprocess.check_output([probe, "-v", "error", "-show_entries",
                                   "format=duration:stream=codec_type,sample_rate,channels",
                                   "-of", "json", str(path)], timeout=30)
    result = json.loads(raw)
    duration = float(result.get("format", {}).get("duration", 0))
    if duration <= 0 or not any(s.get("codec_type") == "audio" for s in result.get("streams", [])):
        raise ValueError("Wynik nie zawiera poprawnego dźwięku.")
    if expected_duration and abs(duration - expected_duration) > max(2, expected_duration * .02):
        raise ValueError("Długość nagrania nie odpowiada zadanej długości.")
    if decode:
        ffmpeg = os.environ.get("SOS_MUSIC_FFMPEG") or shutil.which("ffmpeg")
        subprocess.run([ffmpeg, "-v", "error", "-xerror", "-nostdin", "-i", str(path),
                        "-f", "null", "-"], check=True, capture_output=True, timeout=120)
    return duration
