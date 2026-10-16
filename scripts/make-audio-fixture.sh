#!/usr/bin/env bash
# Synthetic tone only; no provider media or credentials enter the fixtures.
set -euo pipefail
command -v ffmpeg >/dev/null || { echo 'ffmpeg is required to generate the audio integration fixture.' >&2; exit 1; }
mkdir -p build/fixtures
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'sine=frequency=440:sample_rate=48000' -t 16 \
  -c:a aac -b:a 128k -f mpegts build/fixtures/aether-audio.ts
