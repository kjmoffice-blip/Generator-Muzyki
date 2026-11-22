"""Build reproducible LGPL audio tools from official source distributions."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = Path("/private/tmp/sosdigital-audio-build-3")
PREFIX = BUILD / "prefix"
SOURCES = ROOT / "Resources/Licenses/Sources"
SOURCES.mkdir(parents=True, exist_ok=True)
BUILD.mkdir(parents=True, exist_ok=True)


def download(name, url, expected=None):
    """Retrieve an official archive and preserve its hash with the release."""
    target = SOURCES / name
    if not target.exists():
        temporary = target.with_suffix(target.suffix + ".download")
        subprocess.run(["/usr/bin/curl", "--fail", "--location", "--retry", "2",
                        "--proto", "=https", "--connect-timeout", "20", "--max-time", "180",
                        "--output", str(temporary), url], check=True)
        temporary.replace(target)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    if expected:
        assert digest == expected, f"Source checksum mismatch: {name}"
    with tarfile.open(target) as archive:
        archive.extractall(BUILD, filter="data")
    return {"file": name, "url": url, "sha256": digest}


def run(args, cwd, env=None):
    """Run a build step with a persistent diagnostic log."""
    print("Build step:", args[0], cwd.name, flush=True)
    with (BUILD / "build.log").open("a") as log:
        subprocess.run(args, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)


sources = [
    download("ffmpeg-9.0.2.tar.xz", "https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz"),
    download("lame-4.0.tar.gz",
             "https://sourceforge.net/projects/lame/files/lame/4.0/lame-4.0.tar.gz/download",
             "3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb"),
]
env = dict(os.environ, MACOSX_DEPLOYMENT_TARGET="14.0")
tool_bin = BUILD / "bin"
tool_bin.mkdir(exist_ok=True)
shutil.copy2(ROOT / "build/build-tools/pkgconf/.bin/pkgconf", tool_bin / "pkgconf")
if not (tool_bin / "pkg-config").exists():
    (tool_bin / "pkg-config").symlink_to("pkgconf")
env["PATH"] = str(tool_bin) + ":" + env.get("PATH", "")
env["PKG_CONFIG"] = str(tool_bin / "pkg-config")
env["PKG_CONFIG_PATH"] = str(PREFIX / "lib/pkgconfig")
lame = BUILD / "lame-4.0"
run(["./configure", f"--prefix={PREFIX}", "--disable-shared", "--enable-static",
     "--disable-frontend", "--disable-decoder", "--disable-analyzer-hooks",
     "--disable-dependency-tracking"], lame, env)
run(["make", "-j4"], lame, env)
run(["make", "install"], lame, env)
ffmpeg = BUILD / "ffmpeg-9.0.2"
options = [
    "./configure", f"--prefix={PREFIX}", "--arch=arm64", "--target-os=darwin",
    "--cc=clang", "--disable-autodetect", "--disable-everything", "--disable-network",
    "--disable-shared", "--enable-static", "--disable-doc", "--disable-debug",
    "--enable-ffmpeg", "--enable-ffprobe", "--enable-avcodec", "--enable-avformat",
    "--enable-avfilter", "--enable-swresample", "--enable-libmp3lame",
    f"--extra-cflags=-I{PREFIX}/include -mmacosx-version-min=14.0",
    f"--extra-ldflags=-L{PREFIX}/lib -mmacosx-version-min=14.0",
    "--enable-protocol=file,pipe",
    "--enable-demuxer=mp3,aac,wav,flac,ogg,mov,aiff,matroska",
    "--enable-decoder=mp3,mp3float,aac,aac_fixed,flac,vorbis,opus,alac,pcm_s16le,pcm_s16be,pcm_s24le,pcm_s24be,pcm_s32le,pcm_s32be,pcm_f32le,pcm_f64le,pcm_u8",
    "--enable-parser=mpegaudio,aac,flac,opus,vorbis",
    "--enable-muxer=mp3,wav,flac,ogg,ipod,adts,null,framemd5,md5",
    "--enable-encoder=libmp3lame,pcm_s16le,pcm_s24le,pcm_f32le,flac,aac",
    "--enable-filter=aresample,aformat,anull,volume,volumedetect,astats,atrim,asetpts,acopy,abuffer,abuffersink",
]
run(options, ffmpeg, env)
run(["make", "-j4"], ffmpeg, env)
run(["make", "install"], ffmpeg, env)
tools = ROOT / "build/Generator Muzyki.app/Contents/Resources/Runtime/Tools"
tools.mkdir(parents=True, exist_ok=True)
for name in ["ffmpeg", "ffprobe"]:
    shutil.copy2(PREFIX / "bin" / name, tools / name)
license_text = subprocess.check_output([str(tools / "ffmpeg"), "-L"], text=True)
assert "GNU Lesser General Public License" in " ".join(license_text.split())
assert "--enable-gpl" not in subprocess.check_output([str(tools / "ffmpeg"), "-buildconf"], text=True, stderr=subprocess.STDOUT)
lic = ROOT / "Resources/Licenses"
(lic / "FFmpeg-build.json").write_text(json.dumps({"sources": sources, "configure": options}, indent=2))
(lic / "FFmpeg-license.txt").write_text(license_text)
shutil.copy2(ffmpeg / "COPYING.LGPLv2.1", lic / "LGPL-2.1.txt")
shutil.copy2(lame / "COPYING", lic / "LAME-license.txt")
print("LGPL audio tools built and copied.", flush=True)
