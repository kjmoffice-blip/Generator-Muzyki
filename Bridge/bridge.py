#!/usr/bin/env python3
"""Line-oriented native-app bridge for the user's local ACE-Step installation."""

import argparse
import contextlib
import json
import os
from pathlib import Path
import sys
from urllib.error import URLError

from library import list_songs
from validation import validate_request, validate_server


def main():
    """Read one request and emit prefixed JSON events until completion."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--output-dir")
    parser.add_argument("--storage-layout", choices=["flat", "legacy"], default="flat")
    parser.add_argument("--server", default="http://127.0.0.1:7860")
    args = parser.parse_args()
    protocol_output = sys.stdout

    def emit(**event):
        """Write one unambiguous event even when dependencies print diagnostics."""
        print("ACE_EVENT " + json.dumps(event, ensure_ascii=False, allow_nan=False),
              file=protocol_output, flush=True)

    try:
        raw = sys.stdin.readline(5_000_001)
        if len(raw) > 5_000_000:
            raise ValueError("Żądanie jest zbyt duże.")
        request = json.loads(raw)
        if not isinstance(request, dict):
            raise ValueError("Żądanie musi być obiektem JSON.")
        root = Path(args.root).expanduser().resolve()
        if not root.is_dir():
            raise ValueError("Folder ACE jest niedostępny. Podłącz dysk i spróbuj ponownie.")
        command = request.get("command")
        if command == "import_plan":
            from plan import parse_plan_text, load_plan_file
            result = load_plan_file(request["path"]) if request.get("path") else parse_plan_text(request.get("text", ""))
            emit(type="plan", plan=result)
        elif command == "library":
            songs = {s["audioPath"]: s for s in list_songs(root, args.output_dir)}
            if args.storage_layout == "flat":
                from flat_library import list_flat
                songs.update({s["audioPath"]: s for s in list_flat(root, args.output_dir)})
            emit(type="library", songs=sorted(songs.values(), key=lambda s: s["createdAt"], reverse=True))
        elif command == "cleanup_collection":
            from cleanup import cleanup_collection
            emit(type="cleanup", result=cleanup_collection(root, args.output_dir, request.get("job_ids")))
        elif command == "recover_job":
            from flat_library import find_flat_job
            from library import find_completed_job
            job_id = request.get("job_id")
            song = find_flat_job(root, job_id, args.output_dir) or find_completed_job(root, job_id, args.output_dir)
            if song:
                emit(type="result", song=song)
            else:
                emit(type="recovery", found=False)
        elif command == "generate":
            normalized = validate_request(request)
            server = validate_server(args.server)
            with contextlib.redirect_stdout(sys.stderr):
                from generator import generate
                song = generate(root, server, normalized, emit, output_dir=args.output_dir,
                                flat_output=args.storage_layout == "flat")
            emit(type="result", song=song)
        else:
            raise ValueError("Nieznane polecenie mostka muzycznego.")
        return 0
    except TimeoutError as error:
        emit(type="error", message=str(error))
        # Stop client worker threads; do not kill or restart the external engine.
        os._exit(1)
    except URLError:
        emit(type="error", message="Brak połączenia z ACE-Step. Uruchom silnik i spróbuj ponownie.")
    except Exception as error:
        emit(type="error", message=str(error)[:1200] or type(error).__name__)
    return 1


if __name__ == "__main__":
    sys.exit(main())
