"""Package the signed full Apple Silicon app, including its local AI runtime."""
from pathlib import Path
import hashlib
import json
import os
import plistlib
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "build/packaging"))
from dmgbuild import build_dmg

APP = ROOT / "build/Generator Muzyki.app"
DMG = ROOT / "build/Generator-Muzyki-3.0.0-AppleSilicon.dmg"
IDENTITY = os.environ["CODESIGN_IDENTITY"]

def run(*args):
    """Run one checked packaging command."""
    subprocess.run([str(arg) for arg in args], check=True)

info = plistlib.loads((APP / 'Contents/Info.plist').read_bytes())
assert info['CFBundleShortVersionString'] == '3.0.0' and not info.get('SOSMusicPreviewMode')
assert (APP / 'Contents/Resources/Runtime/Silnik/checkpoints').is_dir()
run("codesign", "--verify", "--deep", "--strict", "--verbose=2", APP)
if DMG.exists():
    raise SystemExit("DMG already exists; preserve it before rebuilding")
build_dmg(str(DMG), "Generator Muzyki", settings={
    "files": [str(APP)], "symlinks": {"Applications": "/Applications"},
    "background": str(ROOT / "Resources/dmg-background.png"),
    "window_rect": ((180, 140), (720, 600)),
    "icon_locations": {"Generator Muzyki.app": (190, 225), "Applications": (530, 225)},
    "icon_size": 112, "text_size": 14,
    "show_status_bar": False, "show_tab_view": False, "show_pathbar": False,
    "show_toolbar": False, "show_sidebar": False,
    "default_view": "icon-view", "format": "UDZO", "compression_level": 1, "filesystem": "HFS+",
})
run("codesign", "--sign", IDENTITY, "--timestamp", DMG)
run("codesign", "--verify", "--strict", "--verbose=2", DMG)
with DMG.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
manifest = {"version": "3.0.0", "architecture": "arm64", "app": str(APP),
    "dmg": str(DMG), "sha256": digest, "bytes": DMG.stat().st_size,
    "selfContainedRuntime": True, "modelManifest": "Resources/Licenses/Model-files.json",
    "signing": IDENTITY, "notarization": "not-submitted-awaiting-local-login"}
(ROOT / "build/release.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
print(DMG)
