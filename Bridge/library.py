"""Preserve generated audio and discover existing local song folders."""

from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import uuid


def library_root(root, output_dir=None):
    """Resolve the library and reject symlinks that escape the selected root."""
    if output_dir is not None:
        selected = Path(output_dir).expanduser()
        if not selected.is_absolute() or not selected.is_dir():
            raise ValueError("Wybrany folder zapisu jest niedostępny. Podłącz dysk lub wybierz inny folder.")
        return selected.resolve()
    root = Path(root).resolve()
    base = root / "Piosenki"
    if not base.resolve().is_relative_to(root):
        raise ValueError("Biblioteka Piosenki prowadzi poza folder ACE.")
    return base


def read_json(path):
    """Read object metadata; malformed legacy metadata leaves audio intact."""
    try:
        data = path.read_text(encoding="utf-8")
        result = json.loads(data)
        return result if isinstance(result, dict) else {}
    except (OSError, ValueError):
        return {}


def numeric(value, default=0):
    """Return finite metadata numbers suitable for the app's JSON model."""
    try:
        result = float(value)
        return result if abs(result) < 1e15 else default
    except (TypeError, ValueError):
        return default


def song_record(audio, metadata, base):
    """Normalize imported or newly created songs into one stable protocol."""
    audio = audio.resolve()
    if not audio.is_relative_to(base.resolve()) or not audio.is_file():
        raise ValueError("Plik audio znajduje się poza biblioteką.")
    relative = str(audio.relative_to(base.resolve()))
    created = datetime.fromtimestamp(audio.stat().st_mtime, timezone.utc).isoformat()
    return {
        "id": str(metadata.get("id") or uuid.uuid5(uuid.NAMESPACE_URL, relative)),
        "title": str(metadata.get("title") or audio.stem),
        "caption": str(metadata.get("caption") or ""),
        "lyrics": str(metadata.get("lyrics") or ""),
        "duration": numeric(metadata.get("duration", metadata.get("audio_duration"))),
        "bpm": int(numeric(metadata.get("bpm"))),
        "language": str(metadata.get("language") or metadata.get("vocal_language") or "pl"),
        "seed": int(numeric(metadata.get("seed"), -1)),
        "audioPath": str(audio), "createdAt": str(metadata.get("createdAt") or created),
        "format": audio.suffix.lstrip(".").lower(),
        "jobID": metadata.get("job_id") or metadata.get("jobID"),
    }


def list_songs(root, output_dir=None):
    """Discover existing audio without modifying or renaming legacy files."""
    base = library_root(root, output_dir)
    if not base.exists():
        return []
    songs = []
    for audio in sorted(base.rglob("*")):
        if audio.suffix.lower() not in {".mp3", ".wav", ".flac"} or not audio.is_file():
            continue
        if not audio.resolve().is_relative_to(base.resolve()):
            continue
        metadata = read_json(audio.parent / "song.json")
        if not metadata:
            metadata = read_json(audio.parent / "parametry.json")
        if not metadata:
            metadata = read_json(audio.with_suffix(".json"))
        songs.append(song_record(audio, metadata, base))
    return sorted(songs, key=lambda song: song["createdAt"], reverse=True)


def find_completed_job(root, job_id, output_dir=None):
    """Only a committed song.json with existing audio proves a completed job."""
    if not job_id:
        return None
    base = library_root(root, output_dir)
    if not base.exists():
        return None
    for marker in base.rglob("song.json"):
        data = read_json(marker)
        if data.get("jobID") == job_id and isinstance(data.get("audioPath"), str):
            try:
                return song_record(Path(data["audioPath"]), data, base)
            except ValueError:
                continue
    return None


def save_song(root, request, audio, parameters=None, output_dir=None):
    """Commit a fresh song folder; never overwrite a previous recording."""
    base = library_root(root, output_dir)
    base.mkdir(parents=True, exist_ok=True)
    identifier = str(uuid.uuid4())
    slug = re.sub(r"[^\w .-]", "", request["title"], flags=re.UNICODE).strip(" .")
    folder = base / f"{slug[:80] or 'Nowy utwór'} — {identifier[:8]}"
    folder.mkdir(exist_ok=False)
    audio = Path(audio)
    destination = folder / f"{slug[:80] or 'utwor'}{audio.suffix.lower()}"
    shutil.copy2(audio, destination)
    metadata = {**request, **(parameters or {}), "title": request["title"], "id": identifier,
                "createdAt": datetime.now(timezone.utc).isoformat()}
    if request.get("reference_audio"):
        metadata["reference_audio"] = request["reference_audio"]
    if request.get("job_id"):
        metadata["job_id"] = request["job_id"]
    record = song_record(destination, metadata, base)
    (folder / "parametry.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2),
                                          encoding="utf-8")
    (folder / "tekst.txt").write_text(request["title"] + "\n\n" + record["lyrics"] + "\n",
                                     encoding="utf-8")
    pending = folder / "song.json.tmp"
    pending.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    pending.replace(folder / "song.json")
    return record
