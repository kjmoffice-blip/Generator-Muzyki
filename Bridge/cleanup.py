"""Remove only unchanged registered helper files after every requested song succeeds."""
from pathlib import Path

from audio_validation import validate_audio
from library import library_root
from storage_index import atomic_json, file_hash, owned_path, read_record, record_path


def cleanup_collection(root, output_dir, job_ids):
    """Preflight all audio and owned artifacts before deleting any helper file."""
    if not isinstance(job_ids, list) or not 1 <= len(job_ids) <= 1000:
        raise ValueError("Brak poprawnej listy utworów do porządkowania.")
    if len(set(job_ids)) != len(job_ids):
        raise ValueError("Powtórzone identyfikatory porządkowania.")
    output = library_root(root, output_dir)
    records = []
    for job_id in job_ids:
        path = record_path(root, output, job_id)
        record = read_record(path)
        if not record or record.get("state") != "committed" or record.get("output") != str(output):
            raise ValueError("Kolekcja nie ma kompletu zapisanych wyników. Zachowano pliki pomocnicze.")
        audio = Path(record.get("song", {}).get("audioPath", ""))
        if audio.parent != output or audio.is_symlink() or file_hash(audio) != record.get("audioSHA256"):
            raise ValueError("Nie potwierdzono pliku audio. Zachowano pliki pomocnicze.")
        validate_audio(audio, record["song"]["duration"], decode=True)
        artifacts = []
        allowed = {audio.stem + ending for ending in [".parametry.json", ".song.json", ".tekst.txt"]}
        for artifact in record.get("artifacts", []):
            if artifact.get("name") not in allowed:
                raise ValueError("Rejestr zawiera obcy plik. Zachowano pliki pomocnicze.")
            helper = owned_path(output, artifact.get("name"))
            if helper.exists():
                if helper == audio or file_hash(helper) != artifact.get("sha256"):
                    raise ValueError("Plik pomocniczy został zmieniony. Zachowano pliki do analizy.")
                artifacts.append((helper, artifact["sha256"]))
        records.append((path, record, artifacts))
    removed = 0
    for path, record, artifacts in records:
        for helper, expected_hash in artifacts:
            if helper.is_symlink() or (helper.exists() and file_hash(helper) != expected_hash):
                raise ValueError("Plik zmienił się podczas porządkowania. Zachowano go.")
            helper.unlink(missing_ok=True)
            removed += 1
        record["cleanupState"] = "completed"
        atomic_json(path, record)
    return {"state": "completed", "removed": removed, "songs": len(records)}
