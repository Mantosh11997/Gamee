# Audio

Everything here is generated — no samples, no downloads. Rebuild with:

```bash
pip install numpy soundfile
python3 tool/build_audio.py
```

Ten one-shot effects as 16-bit mono WAV (small and low-latency) plus `music.mp3`, a
29-second looping bed. MP3 rather than Ogg Vorbis because iOS cannot play Ogg.

Missing files just mean silence: `AudioManager` degrades to a no-op rather than throwing.
