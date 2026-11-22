"""Download the exact platform-neutral model files, or verify an existing payload."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPO = 'ACE-Step/Ace-Step1.5'
REVISION = '19671f406d603126926c1b7e2adc169acbcade22'


def matches(path, entry):
    """Check the complete local file against the frozen release manifest."""
    if not path.is_file() or path.stat().st_size != entry['bytes']:
        return False
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest() == entry['sha256']


def fetch(path, entry):
    """Resume HTTPS downloads; never replace a different pre-existing model."""
    if path.exists():
        raise ValueError(f'Existing file differs from the release: {path}')
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(path.name + '.download')
    relative = entry['file'].removeprefix('checkpoints/')
    url = f'https://huggingface.co/{REPO}/resolve/{REVISION}/' + urllib.parse.quote(relative, safe='/')
    for attempt in range(3):
        offset = partial.stat().st_size if partial.exists() else 0
        request = urllib.request.Request(url, headers={'Range': f'bytes={offset}-'} if offset else {})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                append = offset > 0 and response.status == 206
                if append and not response.headers.get('Content-Range', '').startswith(f'bytes {offset}-'):
                    raise ValueError('Incorrect resume range from the model host')
                with partial.open('ab' if append else 'wb') as output:
                    while chunk := response.read(1024 * 1024):
                        output.write(chunk)
                    output.flush()
                    os.fsync(output.fileno())
            if not matches(partial, entry):
                raise ValueError(f'Model checksum mismatch: {relative}')
            partial.replace(path)
            return
        except (OSError, ValueError):
            if attempt == 2:
                raise


def main():
    """Use one pinned HF revision and the same hashes on Mac and Windows."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine-root', type=Path, required=True)
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    root = args.engine_root.resolve()
    entries = json.loads((ROOT / 'Resources/Licenses/Model-files.json').read_text())
    for entry in entries:
        relative = Path(entry['file'])
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Invalid model manifest path')
        target = root / relative
        if target.is_symlink() or not target.resolve().is_relative_to(root):
            raise ValueError('Model path escapes the selected engine')
        if not matches(target, entry):
            if args.verify_only:
                raise ValueError(f'Missing or different model: {relative}')
            fetch(target, entry)
        print('VERIFIED', entry['file'], flush=True)
    print(f'{len(entries)} model files match the release manifest.')


if __name__ == '__main__':
    main()
