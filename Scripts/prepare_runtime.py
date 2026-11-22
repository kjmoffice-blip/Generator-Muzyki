"""Bundle the verified local engine, models and portable interpreter without user data."""
from pathlib import Path
import hashlib
import json
import os
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ["SOS_MUSIC_SOURCE"]).expanduser() if "SOS_MUSIC_SOURCE" in os.environ else ROOT / "dependencies/ACE"
DEST = ROOT / "build/Generator Muzyki.app/Contents/Resources/Runtime"
IGNORE = shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store", ".cache", ".git")


def copy_tree(source, destination):
    """Copy immutable runtime files, preserving only internal interpreter symlinks."""
    shutil.copytree(source, destination, dirs_exist_ok=True, ignore=IGNORE, symlinks=True)


def patch_engine(engine):
    """Redirect engine output to the app's writable data directory, preserving defaults."""
    files = {
        "acestep/acestep_v15_pipeline.py": (
            'output_dir = os.path.join(project_root, "gradio_outputs")',
            'output_dir = os.environ.get("SOS_MUSIC_ENGINE_OUTPUT", '
            'os.path.join(project_root, "gradio_outputs"))'),
        "acestep/ui/gradio/api/api_routes.py": (
            'DEFAULT_RESULTS_DIR = os.path.join(PROJECT_ROOT, "gradio_outputs").replace("\\\\", "/")',
            'DEFAULT_RESULTS_DIR = os.environ.get("SOS_MUSIC_ENGINE_OUTPUT", '
            'os.path.join(PROJECT_ROOT, "gradio_outputs")).replace("\\\\", "/")'),
        "acestep/ui/gradio/events/results/generation_info.py": (
            'DEFAULT_RESULTS_DIR = os.path.join(PROJECT_ROOT, "gradio_outputs").replace("\\\\", "/")',
            'DEFAULT_RESULTS_DIR = os.environ.get("SOS_MUSIC_ENGINE_OUTPUT", '
            'os.path.join(PROJECT_ROOT, "gradio_outputs")).replace("\\\\", "/")'),
        "acestep/inference.py": (
            'results_root = os.path.join(os.getcwd(), "gradio_outputs")',
            'results_root = os.environ.get("SOS_MUSIC_ENGINE_OUTPUT", '
            'os.path.join(os.getcwd(), "gradio_outputs"))'),
        "acestep/ui/gradio/events/results/session_artifacts.py": (
            'results_root = Path.cwd() / "gradio_outputs"',
            'results_root = Path(os.environ.get("SOS_MUSIC_ENGINE_OUTPUT", '
            'str(Path.cwd() / "gradio_outputs")))'),
    }
    for relative, (old, new) in files.items():
        path = engine / relative
        text = path.read_text()
        if new not in text:
            assert text.count(old) == 1, f"Unexpected upstream source: {relative}"
            path.write_text(text.replace(old, new))


def prepare():
    """Assemble a relocatable payload and record original model hashes."""
    DEST.mkdir(parents=True, exist_ok=True)
    engine = DEST / "Silnik"
    engine.mkdir(exist_ok=True)
    source_engine = SOURCE / "Silnik"
    for name in ["acestep", "assets", "examples", "docs", "checkpoints"]:
        copy_tree(source_engine / name, engine / name)
    for name in ["LICENSE", "README.md", "pyproject.toml", "AGENTS.md"]:
        shutil.copy2(source_engine / name, engine / name)
    copy_tree(SOURCE / "Runtime/python", DEST / "Runtime/python")
    site = engine / ".venv/lib/python3.12/site-packages"
    copy_tree(source_engine / ".venv/lib/python3.12/site-packages", site)
    # PYTHONPATH selects the bundled engine directly; discard old editable SSD paths.
    for path in site.glob("*ace_step*.pth"):
        path.unlink()
    for path in site.glob("_editable_impl_ace_step*.py"):
        path.unlink()
    tools = DEST / "Tools"
    tools.mkdir(exist_ok=True)
    # Replaced by our minimal LGPL build before signing/release.
    shutil.copy2(source_engine / ".venv/bin/ffmpeg", tools / "ffmpeg")
    patch_engine(engine)
    external = [str(p) for p in DEST.rglob("*")
                if p.is_symlink() and not p.resolve().is_relative_to(DEST.resolve())]
    assert not external, f"External runtime links: {external[:5]}"
    models = []
    for path in sorted((engine / "checkpoints").rglob("*")):
        if path.is_file():
            models.append({"file": str(path.relative_to(engine)), "bytes": path.stat().st_size,
                           "sha256": hashlib.file_digest(path.open("rb"), "sha256").hexdigest()})
    (ROOT / "build/model-manifest.json").write_text(json.dumps(models, indent=2))
    print(f"Bundled {len(models)} model files; model data {sum(v['bytes'] for v in models)/1e9:.2f} GB", flush=True)


if __name__ == "__main__":
    prepare()
