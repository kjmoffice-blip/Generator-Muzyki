"""Durable private records for flat audio exports and owned helper files."""
from pathlib import Path
import hashlib
import json
import os
import re
import tempfile


def file_hash(path):
    """Hash a regular file without loading audio into memory."""
    with Path(path).open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def atomic_json(path, value):
    """Commit metadata before reporting success to the native queue."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".record-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2, allow_nan=False)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def record_directory(root, output):
    """Separate records for each canonical output folder."""
    key = hashlib.sha256(str(Path(output).resolve()).encode()).hexdigest()[:24]
    return Path(root).resolve() / "Biblioteka" / key


def record_path(root, output, job_id):
    """Reject identifiers that could escape the private metadata directory."""
    if not re.fullmatch(r"[A-Za-z0-9-]{1,80}", job_id):
        raise ValueError("Nieprawidłowy identyfikator utworu.")
    return record_directory(root, output) / (job_id + ".json")


def read_record(path):
    """Load one owned record; missing or malformed metadata is not a result."""
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else None
    except (OSError, ValueError):
        return None


def owned_path(output, name):
    """Only direct regular children of the chosen folder can be maintained."""
    if not isinstance(name, str) or Path(name).name != name or name in {"", ".", ".."}:
        raise ValueError("Nieprawidłowa ścieżka pliku pomocniczego.")
    result = Path(output).resolve() / name
    if result.is_symlink() or result.parent != Path(output).resolve():
        raise ValueError("Plik pomocniczy prowadzi poza folder wynikowy.")
    return result
