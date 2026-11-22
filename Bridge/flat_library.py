"""Export audio to one folder while retaining recovery data privately."""
from datetime import datetime, timezone
from pathlib import Path
import json
import os
import re
import shutil
import uuid

from audio_validation import validate_audio
from library import library_root, numeric
from storage_index import atomic_json, file_hash, read_record, record_directory, record_path


def find_flat_job(root, job_id, output_dir):
    """Recover a committed or crash-interrupted commit without regenerating audio."""
    if not job_id:
        return None
    output = library_root(root, output_dir)
    path = record_path(root, output, job_id)
    record = read_record(path)
    if not record or record.get("output") != str(output) or not isinstance(record.get("song"), dict):
        return None
    audio = Path(record["song"].get("audioPath", ""))
    if audio.parent != output or audio.is_symlink() or not audio.is_file():
        return None
    if file_hash(audio) != record.get("audioSHA256"):
        raise ValueError("Zapisany plik audio został zmieniony. Nie nadpisano go.")
    validate_audio(audio, record["song"]["duration"])
    if record.get("state") == "prepared":
        record["state"] = "committed"
        atomic_json(path, record)
    return record["song"] if record.get("state") == "committed" else None


def list_flat(root, output_dir):
    """Return metadata for flat exports without rewriting existing or legacy audio."""
    output = library_root(root, output_dir)
    results = []
    for path in record_directory(root, output).glob("*.json"):
        record = read_record(path)
        if not record or record.get("state") != "committed" or record.get("output") != str(output):
            continue
        song = record.get("song", {})
        audio = Path(song.get("audioPath", ""))
        if audio.parent == output and audio.is_file() and not audio.is_symlink():
            results.append(song)
    return results


def save_flat(root, request, source, parameters=None, output_dir=None):
    """Commit one unique audio file and register only helper files created by this job."""
    output = library_root(root, output_dir)
    output.mkdir(parents=True, exist_ok=True)
    usage = shutil.disk_usage(output)
    if usage.free / usage.total <= .01:
        raise ValueError("Wstrzymano zapis: na wybranym dysku pozostał najwyżej 1% wolnego miejsca.")
    job_id = request.get("job_id") or str(uuid.uuid4())
    recovered = find_flat_job(root, job_id, output)
    if recovered:
        return recovered
    source = Path(source)
    measured = validate_audio(source, request["duration"], decode=True)
    slug = re.sub(r"\s+", " ", re.sub(r"[^\w .-]", "", request["title"], flags=re.UNICODE)).strip(" .")
    slug = slug.encode("utf-8")[:150].decode("utf-8", errors="ignore").strip(" .") or "Utwór"
    stem = f"{slug} — {job_id[:8]}"
    destination = output / (stem + source.suffix.lower())
    if destination.exists() or destination.is_symlink():
        raise FileExistsError("Plik o tej nazwie już istnieje. Zachowano go bez zmian.")
    metadata = {**request, **(parameters or {}), "title": request["title"], "id": job_id,
                "job_id": job_id, "duration": measured,
                "createdAt": datetime.now(timezone.utc).isoformat()}
    if request.get("reference_audio"):
        metadata["reference_audio"] = request["reference_audio"]
    song = {"id": job_id, "title": request["title"], "caption": request["caption"],
            "lyrics": request["lyrics"], "duration": measured, "bpm": request["bpm"],
            "language": request["language"], "seed": int(numeric(metadata.get("seed"), -1)),
            "audioPath": str(destination), "createdAt": metadata["createdAt"],
            "format": source.suffix.lstrip(".").lower(), "jobID": job_id}
    path = record_path(root, output, job_id)
    record = {"kind": "sos-flat-song", "version": 1, "state": "prepared", "song": song,
              "output": str(output), "audioSHA256": file_hash(source),
              "parameters": metadata, "artifacts": []}
    atomic_json(path, record)
    # A prepared record also recovers a crash after audio copy but before commit.
    with destination.open("xb") as target, source.open("rb") as audio:
        shutil.copyfileobj(audio, target)
        target.flush()
        os.fsync(target.fileno())
    # The durable committed record is independent of removable sidecars.
    record["state"] = "committed"
    atomic_json(path, record)
    helpers = {
        stem + ".parametry.json": json.dumps(metadata, ensure_ascii=False, indent=2),
        stem + ".song.json": json.dumps(song, ensure_ascii=False, indent=2),
        stem + ".tekst.txt": request["title"] + "\n\n" + song["lyrics"] + "\n",
    }
    for name, contents in helpers.items():
        helper = output / name
        data = contents.encode("utf-8")
        # An existing unrelated file is left intact and never registered for cleanup.
        try:
            with helper.open("xb") as stream:
                stream.write(data)
        except FileExistsError:
            continue
        record["artifacts"].append({"name": name, "sha256": file_hash(helper)})
        atomic_json(path, record)
    return song
