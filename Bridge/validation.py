"""Validate the small, local music-creation protocol before generation."""

import math
import re
from pathlib import Path
from urllib.parse import urlparse


def number(value, name, minimum, maximum, integer=False):
    """Return a finite bounded number or a readable validation error."""
    if isinstance(value, bool):
        raise ValueError(f"Nieprawidłowa wartość: {name}.")
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        raise ValueError(f"Nieprawidłowa wartość: {name}.") from None
    if not math.isfinite(parsed) or not minimum <= parsed <= maximum:
        raise ValueError(f"{name}: dozwolony zakres {minimum}–{maximum}.")
    if integer and parsed != int(parsed):
        raise ValueError(f"{name} musi być liczbą całkowitą.")
    return int(parsed) if integer else parsed


def validate_request(raw):
    """Normalize one generation request, rejecting ambiguous input types."""
    if not isinstance(raw, dict):
        raise ValueError("Żądanie musi być obiektem JSON.")
    data = {}
    for key, default, maximum in (
        ("title", "Nowy utwór", 160), ("caption", "", 12000),
        ("lyrics", "", 30000), ("language", "pl", 16),
        ("format", "mp3", 10), ("bitrate", "192k", 10),
    ):
        value = raw.get(key, default)
        if not isinstance(value, str) or len(value) > maximum:
            raise ValueError(f"Nieprawidłowe pole: {key}.")
        data[key] = value.strip()
    data["title"] = data["title"] or "Nowy utwór"
    if not data["caption"]:
        raise ValueError("Opisz styl muzyki przed rozpoczęciem generowania.")
    for key, default in (("instrumental", False), ("thinking", True)):
        value = raw.get(key, default)
        if not isinstance(value, bool):
            raise ValueError(f"Pole {key} wymaga wartości true lub false.")
        data[key] = value
    data["duration"] = number(raw.get("duration", 90), "Długość", 10, 600)
    data["bpm"] = number(raw.get("bpm", 0), "Tempo", 0, 300, True)
    if 0 < data["bpm"] < 30:
        raise ValueError("Tempo musi wynosić 30–300 BPM albo 0 (automatycznie).")
    data["steps"] = number(raw.get("steps", 8), "Kroki", 1, 20, True)
    data["seed"] = number(raw.get("seed", -1), "Ziarno", -1, 2147483647, True)
    if data["format"] not in {"mp3", "wav", "flac"}:
        raise ValueError("Wybierz format MP3, WAV lub FLAC.")
    if data["bitrate"] not in {"64k", "96k", "128k", "160k", "192k", "256k", "320k"}:
        raise ValueError("Nieobsługiwana jakość MP3.")
    if not re.fullmatch(r"[a-z]{2,7}", data["language"]):
        raise ValueError("Nieprawidłowy kod języka wokalu.")
    reference = raw.get("reference_audio")
    if reference:
        if not isinstance(reference, str) or len(reference) > 4096:
            raise ValueError("Nieprawidłowy plik wzorcowy.")
        path = Path(reference).expanduser()
        if not path.is_absolute() or not path.is_file() or path.suffix.lower() not in {".mp3", ".wav", ".flac", ".m4a", ".aif", ".aiff"}:
            raise ValueError("Wybierz dostępny plik audio MP3, WAV, FLAC, M4A lub AIFF.")
        data["reference_audio"] = str(path.resolve())
    if raw.get("job_id") is not None:
        if not isinstance(raw["job_id"], str) or not re.fullmatch(r"[a-zA-Z0-9-]{1,80}", raw["job_id"]):
            raise ValueError("Nieprawidłowy identyfikator pozycji kolejki.")
        data["job_id"] = raw["job_id"]
    return data


def validate_server(server):
    """Keep this bridge confined to the user's local ACE-Step instance."""
    parsed = urlparse(server)
    if (parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost"}
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or parsed.path not in {"", "/"}):
        raise ValueError("Silnik ACE-Step musi działać lokalnie na localhost.")
    return server.rstrip("/")
