"""Compile and run the existing native regression programs in isolated test state."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build/native-tests'
BUILD.mkdir(parents=True, exist_ok=True)

def run(args):
    subprocess.run([str(a) for a in args], cwd=ROOT, check=True)

run(['xcrun', 'clang', '-O2', '-target', 'arm64-apple-macosx14.0', '-c',
     ROOT/'Sources/SystemMetrics.c', '-o', BUILD/'SystemMetrics.o'])
for test in sorted((ROOT/'Tests').glob('*Tests.swift')):
    binary = BUILD/test.stem
    run(['xcrun', 'swiftc', '-swift-version', '5', '-O', '-target', 'arm64-apple-macosx14.0',
         '-module-cache-path', BUILD/'module-cache',
         *sorted(p for p in (ROOT/'Sources').glob('*.swift') if p.name != 'App.swift'),
         BUILD/'SystemMetrics.o', test, '-framework', 'SwiftUI', '-framework', 'AppKit',
         '-framework', 'AVFoundation', '-o', binary])
    run([binary])
run(['xcrun', 'clang', '-O2', ROOT/'Sources/SystemMetrics.c', ROOT/'Tests/SystemMetricsTests.c',
     '-o', BUILD/'SystemMetricsTests'])
run([BUILD/'SystemMetricsTests'])
