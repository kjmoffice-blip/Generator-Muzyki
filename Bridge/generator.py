"""Run one job through the existing ACE-Step Gradio queue."""

import json
import os
from pathlib import Path
import tempfile
import threading
import time
from urllib.request import urlopen

from api_mapping import generation_arguments, output_by_label, unpack
from library import read_json, save_song, library_root, find_completed_job


def fetch_schema(server):
    """Read the live contract with a short connection timeout."""
    with urlopen(server + "/gradio_api/info", timeout=10) as response:
        document = json.load(response)
    endpoint = document.get("named_endpoints", {}).get("/generation_wrapper")
    if not isinstance(endpoint, dict):
        raise ValueError("Ten silnik ACE-Step nie udostępnia generatora muzyki.")
    return endpoint


def status_message(status):
    """Translate observed queue states without inventing completion percentages."""
    code = getattr(status.code, "value", str(status.code))
    if code in {"IN_QUEUE", "STARTING", "JOINING_QUEUE"}:
        rank = getattr(status, "rank", None)
        return f"Oczekiwanie w kolejce (pozycja {rank + 1})…" if rank is not None else "Oczekiwanie na silnik…"
    if code == "CANCELLED":
        return "Zadanie zostało anulowane."
    return "Powstaje muzyka…"


def wait_for_result(job, emit, timeout=900):
    """Wait at most timeout seconds and forward only actual job state changes."""
    deadline = time.monotonic() + timeout
    previous = None
    while not job.done():
        if time.monotonic() >= deadline:
            threading.Thread(target=job.cancel, daemon=True).start()
            raise TimeoutError("Przekroczono 15 minut oczekiwania. Silnik może kończyć bieżący etap.")
        message = status_message(job.status())
        if message != previous:
            emit(type="status", message=message)
            previous = message
        time.sleep(0.4)
    return job.result(timeout=1)


def file_path(value, cache):
    """Accept downloaded local files only from this request's cache directory."""
    value = unpack(value)
    if isinstance(value, dict):
        value = value.get("path")
    if not isinstance(value, str):
        return None
    path = Path(value).resolve()
    if path.is_relative_to(cache.resolve()) and path.is_file():
        return path
    return None


def persist_result(root, request, schema, result, cache, output_dir=None, flat_output=False):
    """Extract completed audio and metadata, then commit a stable song folder."""
    audio = output_by_label(schema, result, "🎵 Generated Music (Sample 1)")
    files = output_by_label(schema, result, "📁 All Generated Files (Download)") or []
    paths = [file_path(value, cache) for value in files] if isinstance(files, list) else []
    audio = file_path(audio, cache)
    if audio is None:
        audio = next((p for p in paths if p and p.suffix.lower() in {".mp3", ".wav", ".flac"}), None)
    if audio is None or audio.stat().st_size == 0:
        status = output_by_label(schema, result, "Generation Status") or "Brak pliku audio."
        raise ValueError("Silnik nie utworzył utworu: " + str(status)[:500])
    metadata_path = next((p for p in paths if p and p.suffix.lower() == ".json"), None)
    parameters = read_json(metadata_path) if metadata_path else {}
    if not parameters:
        seed = output_by_label(schema, result, "Seed")
        try:
            parameters["seed"] = int(str(seed).split(",")[0])
        except (TypeError, ValueError):
            pass
    if flat_output:
        from flat_library import save_flat
        return save_flat(root, request, audio, parameters, output_dir=output_dir)
    return save_song(root, request, audio, parameters, output_dir=output_dir)


def generate(root, server, request, emit, output_dir=None, flat_output=False):
    """Connect to the live engine and generate exactly one durable recording."""
    emit(type="status", message="Łączenie z ACE-Step…")
    library_root(root, output_dir)
    if flat_output:
        from flat_library import find_flat_job
        existing = find_flat_job(root, request.get("job_id"), output_dir)
    else:
        existing = find_completed_job(root, request.get("job_id"), output_dir)
    if existing is not None:
        emit(type="status", message="Odnaleziono zapisany utwór — przywracam wynik bez ponownej generacji.")
        return existing
    schema = fetch_schema(server)
    os.environ["GRADIO_ANALYTICS_ENABLED"] = "False"
    os.environ["HF_HUB_DISABLE_IMPLICIT_TOKEN"] = "1"
    from gradio_client import Client, handle_file
    mapped = dict(request)
    if request.get("reference_audio"):
        mapped["reference_audio"] = handle_file(request["reference_audio"])
    arguments = generation_arguments(schema, mapped)

    cache_root = Path(root).resolve() / ".cache" / "kreator"
    if not cache_root.resolve().is_relative_to(Path(root).resolve()):
        raise ValueError("Folder pamięci podręcznej prowadzi poza folder ACE.")
    cache_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="job-", dir=cache_root) as temporary:
        cache = Path(temporary)
        client = Client(server, token=False, verbose=False, download_files=cache,
                        analytics_enabled=False, max_workers=8,
                        httpx_kwargs={"timeout": 900, "trust_env": False})
        try:
            job = client.submit(api_name="/generation_wrapper", **arguments)
            result = wait_for_result(job, emit)
            emit(type="status", message="Zapisywanie utworu w bibliotece…")
            return persist_result(root, request, schema, result, cache, output_dir=output_dir,
                                  flat_output=flat_output)
        finally:
            client.close()
