#!/usr/bin/env bash
# Encodes the frames captured by test/demo_capture_test.dart into an MP4,
# scored with the game's own generated music loop.
#
#   flutter test tool/demo/demo_capture.dart   # writes build/demo_frames/*.png
#   ./tool/build_demo_video.sh                 # writes build/nebula_strike_demo.mp4
#
# ffmpeg comes from the imageio-ffmpeg wheel if it is not on PATH:
#   pip install imageio-ffmpeg
set -euo pipefail
cd "$(dirname "$0")/.."

FFMPEG="${FFMPEG:-$(command -v ffmpeg || python3 -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')}"
FRAMES=build/demo_frames
OUT=build/nebula_strike_demo.mp4
FPS=30

[ -d "$FRAMES" ] || { echo "no frames in $FRAMES - run the capture test first" >&2; exit 1; }

"$FFMPEG" -y -loglevel error \
  -framerate "$FPS" -i "$FRAMES/f%05d.png" \
  -stream_loop -1 -i assets/audio/music.mp3 \
  -map 0:v -map 1:a -shortest \
  -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 20 -preset slow \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  "$OUT"

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
