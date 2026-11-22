"""Build the native Apple Silicon studio using the installed Xcode toolchain."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
APP = ROOT / "build/Generator Muzyki.app"
contents = APP / "Contents"
for folder in (contents / "MacOS", contents / "Resources"):
    folder.mkdir(parents=True, exist_ok=True)
subprocess.run(["xcrun", "clang", "-O2", "-target", "arm64-apple-macosx14.0", "-c",
                str(ROOT / "Sources/SystemMetrics.c"), "-o", str(ROOT / "build/SystemMetrics.o")], check=True)
subprocess.run([
    "xcrun", "swiftc", "-swift-version", "5", "-O", "-whole-module-optimization",
    "-target", "arm64-apple-macosx14.0", "-module-cache-path", str(ROOT / "build/module-cache"),
    *[str(p) for p in sorted((ROOT / "Sources").glob("*.swift"))],
    str(ROOT / "build/SystemMetrics.o"),
    "-framework", "SwiftUI", "-framework", "AppKit", "-framework", "AVFoundation",
    "-o", str(contents / "MacOS/GeneratorMuzyki")
], check=True)
for name in ("Bridge", "Resources"):
    target = contents / "Resources/Bridge" if name == "Bridge" else contents / "Resources"
    shutil.copytree(ROOT / name, target, dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__"))
info = {
    "CFBundleExecutable": "GeneratorMuzyki", "CFBundleIdentifier": "pro.sosdigital.generatormuzyki" + (".preview" if "--preview" in sys.argv else ""),
    "CFBundleName": "Generator Muzyki", "CFBundleDisplayName": "Generator Muzyki",
    "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "3.0.0",
    "CFBundleVersion": "1", "LSMinimumSystemVersion": "14.0",
    "NSHighResolutionCapable": True, "CFBundleIconFile": "AppIcon",
    "NSHumanReadableCopyright": "© 2026 SOS DIGITAL . PRO. Silnik ACE-Step 1.5.",
    "NSAppTransportSecurity": {"NSAllowsLocalNetworking": True},
    "SOSMusicPreviewMode": "--preview" in sys.argv,
}
(contents / "Info.plist").write_bytes(plistlib.dumps(info))
print(APP)
