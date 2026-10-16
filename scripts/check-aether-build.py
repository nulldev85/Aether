#!/usr/bin/env python3
"""Check the actual device payload before exporting it for re-signing."""
import argparse
import plistlib
import re
import subprocess
from pathlib import Path

FRAMEWORKS = ["avcodec", "avformat", "avutil", "swresample", "swscale", "avfilter", "dav1d", "zimg", "zvbi"]
NOTICES = ["AetherEngine", "GPL-3.0", "FFmpegBuild", "FFmpeg-Notices", "FFmpeg-LGPL-2.1", "dav1d", "libzvbi-ure", "zimg", "LibDovi"]


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def verify(app):
    with (app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    assert "iPhoneOS" in info["CFBundleSupportedPlatforms"], "Simulator bundle supplied as device payload"
    assert int(info["MinimumOSVersion"].split(".")[0]) >= 18, "AetherEngine requires iOS 18"
    executable = app / info["CFBundleExecutable"]
    assert "arm64" in command("lipo", "-archs", str(executable)).split(), "Missing device arm64"
    for name in FRAMEWORKS:
        path = app / "Frameworks" / f"AetherLib{name}.framework" / f"AetherLib{name}"
        assert path.is_file(), f"Decoder framework not embedded: {path.name}"
    for path in app.rglob("*.framework"):
        assert "vlc" not in path.name.lower(), "VLC must not remain in the audio-only build"
        assert path.name not in {"DTSX.framework", "TrueHD.framework"}, "Optional object-audio decoder was linked"
    assert list(app.rglob("AetherEngine_AetherEngine.bundle/silent-atmos.mp4")), "Upstream runtime resource missing"
    for name in NOTICES:
        assert list(app.glob(f"PlaybackLicense-{name}.txt")), f"License not reachable by the acknowledgement screen: {name}"
    binaries = [executable] + [p / p.stem for p in (app / "Frameworks").glob("*.framework")]
    for binary in binaries:
        if not binary.is_file():
            continue
        links = command("otool", "-L", str(binary))
        assert "VLCKit" not in links, f"VLC linkage remains in {binary.name}"
        for library in re.findall(r"@rpath/([^\s]+)", links):
            if library.startswith("libswift"):
                continue  # Supplied by the OS Swift runtime or SwiftSupport.
            assert (app / "Frameworks" / library).exists(), f"Unresolved dynamic dependency: {library}"
    size = sum(p.stat().st_size for p in app.rglob("*") if p.is_file())
    print(f"Verified iPhoneOS audio build, embedded decoders, notices, and dynamic links ({size / 1024**2:.1f} MiB uncompressed).")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("app", type=Path)
    verify(parser.parse_args().app)
