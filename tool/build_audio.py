#!/usr/bin/env python3
"""Synthesise every sound in the game into assets/audio/.

Run from the repo root:  python3 tool/build_audio.py

Nothing here is sampled or downloaded - the sound effects are built from
oscillators, noise and envelopes, and the music loop is sequenced from the same
primitives. Re-run after editing to regenerate.

Formats are chosen for cross-platform playback through audioplayers:
  * short SFX  -> 16-bit mono WAV  (tiny, zero decode latency, universal)
  * music loop -> mono MP3         (Ogg Vorbis is not supported on iOS)

Requires: pip install numpy soundfile
"""

import os

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")

SFX_RATE = 22050
MUSIC_RATE = 44100

rng = np.random.default_rng(0xC0FFEE)


# --------------------------------------------------------------- primitives --

def t_axis(seconds, rate):
    return np.arange(int(seconds * rate)) / rate


def sine(freq, t, phase=0.0):
    return np.sin(2 * np.pi * freq * t + phase)


def _phase(freq, t):
    """Continuous phase for a (possibly swept) frequency."""
    freq = np.asarray(freq, dtype=float)
    if freq.ndim == 0:
        freq = np.full_like(t, float(freq))
    dt = np.gradient(t) if len(t) > 1 else np.array([1.0])
    return 2 * np.pi * np.cumsum(freq * dt)


def saw(freq, t):
    p = _phase(freq, t)
    return 2 * ((p / (2 * np.pi)) % 1.0) - 1


def square(freq, t, duty=0.5):
    p = (_phase(freq, t) / (2 * np.pi)) % 1.0
    return np.where(p < duty, 1.0, -1.0)


def triangle(freq, t):
    p = (_phase(freq, t) / (2 * np.pi)) % 1.0
    return 4 * np.abs(p - 0.5) - 1


def noise(n):
    return rng.uniform(-1, 1, n)


def sweep(start, end, t, curve=2.5):
    """Exponential-ish glide from start Hz to end Hz across t."""
    if len(t) < 2:
        return np.full(len(t), start, dtype=float)
    x = t / t[-1]
    return start * (end / start) ** (x ** (1 / curve))


def env(t, attack=0.005, decay=None, sustain=0.0, release=None, curve=3.0):
    """Simple percussive/ADSR-ish envelope over the whole of t."""
    n = len(t)
    total = t[-1] if n else 0.0
    a = int(attack * n / total) if total else 0
    out = np.ones(n)
    if a > 1:
        out[:a] = np.linspace(0, 1, a)
    if decay is None:
        # pure exponential decay for the remainder
        out[a:] *= np.exp(-curve * np.linspace(0, 1, max(1, n - a)))
        return out
    d = int(decay * n / total)
    r = int((release or 0.0) * n / total)
    s = max(0, n - a - d - r)
    seg = [np.linspace(1, sustain, d), np.full(s, sustain), np.linspace(sustain, 0, r)]
    tail = np.concatenate([x for x in seg if len(x)])
    out[a : a + len(tail)] *= tail
    if a + len(tail) < n:
        out[a + len(tail) :] = 0
    return out


def lowpass(x, cutoff, rate):
    """One-pole low-pass. `cutoff` may be a scalar or a per-sample array."""
    c = np.asarray(cutoff, dtype=float)
    if c.ndim == 0:
        c = np.full(len(x), float(c))
    alpha = 1 - np.exp(-2 * np.pi * np.clip(c, 20, rate / 2 - 1) / rate)
    out = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        out[i] = acc
    return out


def highpass(x, cutoff, rate):
    return x - lowpass(x, cutoff, rate)


def normalise(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def write_wav(name, data, rate=SFX_RATE):
    path = os.path.join(OUT, name)
    sf.write(path, normalise(data.astype(np.float32), 0.92), rate, subtype="PCM_16")
    print(f"  {name:24s} {len(data) / rate:5.2f}s  {os.path.getsize(path) // 1024:4d} KB")


# ------------------------------------------------------------ sound effects --

def shoot_player():
    t = t_axis(0.14, SFX_RATE)
    f = sweep(1500, 420, t)
    body = 0.6 * square(f, t, duty=0.35) + 0.4 * saw(f * 1.005, t)
    body = lowpass(body, sweep(6000, 1200, t), SFX_RATE)
    click = noise(len(t)) * np.exp(-260 * t) * 0.5
    return (body * env(t, attack=0.002, curve=5.5)) + click * 0.35


def shoot_enemy():
    t = t_axis(0.18, SFX_RATE)
    f = sweep(700, 170, t)
    body = 0.7 * square(f, t, duty=0.5) + 0.3 * saw(f * 0.5, t)
    body = lowpass(body, sweep(2400, 500, t), SFX_RATE)
    return body * env(t, attack=0.004, curve=4.0) * 0.9


def enemy_hit():
    """Very short tick for a bullet that damages but does not kill."""
    t = t_axis(0.07, SFX_RATE)
    tick = noise(len(t)) * np.exp(-90 * t)
    tick = highpass(tick, 1800, SFX_RATE)
    ping = sine(sweep(2600, 1500, t), t) * np.exp(-70 * t) * 0.5
    return (tick + ping) * 0.8


def _boom(seconds, thump_from, thump_to, cut_from, cut_to, rumble=0.0):
    t = t_axis(seconds, SFX_RATE)
    body = noise(len(t))
    body = lowpass(body, sweep(cut_from, cut_to, t), SFX_RATE)
    body *= env(t, attack=0.004, curve=3.4)
    thump = sine(sweep(thump_from, thump_to, t), t) * np.exp(-9 / seconds * t / 3)
    # Bright crack on the transient, otherwise the low-passed noise reads as a
    # soft thud rather than a blast.
    crack = highpass(noise(len(t)), 2200, SFX_RATE) * np.exp(-38 * t)
    out = body * 0.8 + thump * 0.72 + crack * 0.55
    if rumble:
        low = lowpass(noise(len(t)), 140, SFX_RATE) * np.exp(-2.4 * t / seconds)
        out += low * rumble
    return out


def explosion_small():
    return _boom(0.45, 150, 55, 5200, 380)


def explosion_large():
    return _boom(0.95, 110, 34, 4200, 190, rumble=0.6)


def player_hit():
    t = t_axis(0.32, SFX_RATE)
    grind = square(sweep(320, 105, t), t, duty=0.3) * 0.6
    crunch = lowpass(noise(len(t)), sweep(3200, 400, t), SFX_RATE) * 0.8
    return (grind + crunch) * env(t, attack=0.002, curve=4.2)


def _arp(freqs, step, seconds, wave=triangle, shimmer=0.0):
    total = t_axis(seconds, SFX_RATE)
    out = np.zeros(len(total))
    n_step = int(step * SFX_RATE)
    for i, f in enumerate(freqs):
        start = i * n_step
        seg_len = len(total) - start
        if seg_len <= 0:
            break
        ts = t_axis(seg_len / SFX_RATE, SFX_RATE)
        voice = wave(f, ts)
        if shimmer:
            voice = voice + shimmer * sine(f * 2.01, ts)
        out[start : start + len(ts)] += voice * env(ts, attack=0.004, curve=5.0)
    return out


def powerup_health():
    # Bright major arpeggio: C5 E5 G5 C6
    return _arp([523.25, 659.26, 783.99, 1046.50], 0.075, 0.5, shimmer=0.25)


def powerup_rapidfire():
    # Faster, edgier climb: G5 B5 D6 G6 B6
    return _arp([783.99, 987.77, 1174.66, 1567.98, 1975.53], 0.055, 0.45,
                wave=lambda f, t: 0.7 * square(f, t, 0.35) + 0.3 * triangle(f, t))


def wave_start():
    # Two-note call, wide and confident: D5 -> A5
    out = _arp([587.33, 880.00], 0.16, 0.62,
               wave=lambda f, t: 0.55 * saw(f, t) + 0.45 * square(f * 0.5, t))
    t = t_axis(len(out) / SFX_RATE, SFX_RATE)
    return lowpass(out, sweep(1200, 4200, t), SFX_RATE)


def game_over():
    # Descending minor fall: A4 G4 F4 D4, then a low drop.
    out = _arp([440.00, 392.00, 349.23, 293.66], 0.22, 1.5,
               wave=lambda f, t: 0.6 * triangle(f, t) + 0.4 * square(f, t, 0.45))
    t = t_axis(len(out) / SFX_RATE, SFX_RATE)
    drop = sine(sweep(220, 55, t), t) * np.exp(-2.2 * t) * 0.5
    return out * 0.8 + drop


SFX = {
    "shoot_player.wav": shoot_player,
    "shoot_enemy.wav": shoot_enemy,
    "enemy_hit.wav": enemy_hit,
    "explosion_small.wav": explosion_small,
    "explosion_large.wav": explosion_large,
    "player_hit.wav": player_hit,
    "powerup_health.wav": powerup_health,
    "powerup_rapidfire.wav": powerup_rapidfire,
    "wave_start.wav": wave_start,
    "game_over.wav": game_over,
}


# ------------------------------------------------------------------- music --

BPM = 132
BEAT = 60 / BPM
BAR = BEAT * 4
EIGHTH = BEAT / 2
BARS = 16

# Four-bar loop, repeated four times.
PROGRESSION = [
    ("Am", 110.00, [220.00, 261.63, 329.63]),  # A2 root, A3 C4 E4
    ("F", 87.31, [174.61, 220.00, 261.63]),    # F2 root, F3 A3 C4
    ("C", 130.81, [261.63, 329.63, 392.00]),   # C3 root, C4 E4 G4
    ("G", 98.00, [196.00, 246.94, 293.66]),    # G2 root, G3 B3 D4
]

# Eight eighth-notes per bar; multiples of the chord root.
BASS_PATTERN = [1, 1, 1, 1, 1.5, 1, 2, 1]

A5, C6, D6, E6, G6 = 880.00, 1046.50, 1174.66, 1318.51, 1567.98
C5, D5, E5, G5 = 523.25, 587.33, 659.26, 783.99

# Lead phrase for bars 9-16, one entry per eighth note (None = rest).
LEAD = [
    [A5, None, C6, None, E6, None, D6, None],
    [C6, None, A5, None, G5, None, A5, None],
    [E6, None, G6, None, E6, None, C6, None],
    [D6, None, C6, None, A5, None, None, None],
    [A5, None, E5, None, A5, None, C6, None],
    [C6, None, D6, None, C6, None, A5, None],
    [G5, None, E5, None, G5, None, C6, None],
    [D6, None, None, None, None, None, None, None],
]


def _add(buf, start_sec, block, rate=MUSIC_RATE):
    i = int(start_sec * rate)
    n = min(len(block), len(buf) - i)
    if n > 0:
        buf[i : i + n] += block[:n]


def _kick(rate=MUSIC_RATE):
    t = t_axis(0.26, rate)
    body = sine(sweep(115, 42, t, curve=1.4), t) * np.exp(-13 * t)
    click = noise(len(t)) * np.exp(-320 * t) * 0.25
    return body + click


def _snare(rate=MUSIC_RATE):
    t = t_axis(0.19, rate)
    body = highpass(noise(len(t)), 900, rate) * np.exp(-22 * t)
    tone = sine(190, t) * np.exp(-30 * t) * 0.35
    return body + tone


def _hat(rate=MUSIC_RATE, decay=90):
    t = t_axis(0.07, rate)
    return highpass(noise(len(t)), 6500, rate) * np.exp(-decay * t)


def build_music():
    rate = MUSIC_RATE
    total = BARS * BAR
    n = int(total * rate)
    bass = np.zeros(n)
    arp = np.zeros(n)
    pad = np.zeros(n)
    lead = np.zeros(n)
    drums = np.zeros(n)

    kick, snare = _kick(rate), _snare(rate)
    hat_soft, hat_hard = _hat(rate, 130), _hat(rate, 70)

    for bar in range(BARS):
        name, root, triad = PROGRESSION[bar % 4]
        bar_start = bar * BAR

        # --- pad: the triad held across the bar, dark and quiet -------------
        pt = t_axis(BAR * 0.98, rate)
        chord = np.zeros(len(pt))
        for f in triad:
            chord += saw(f, pt) + saw(f * 1.004, pt)
        chord = lowpass(chord / (2 * len(triad)), 700, rate)
        chord *= env(pt, attack=0.12, decay=BAR * 0.5, sustain=0.75, release=BAR * 0.3)
        _add(pad, bar_start, chord)

        # --- bass: driving eighths -----------------------------------------
        for step, mult in enumerate(BASS_PATTERN):
            bt = t_axis(EIGHTH * 0.92, rate)
            f = root * mult
            voice = 0.7 * saw(f, bt) + 0.3 * square(f, bt, 0.5)
            voice = lowpass(voice, 380 + 900 * np.exp(-14 * bt), rate)
            voice *= env(bt, attack=0.004, curve=3.2)
            _add(bass, bar_start + step * EIGHTH, voice)

        # --- arp: sixteenths walking the chord ------------------------------
        shape = triad + [triad[1] * 2, triad[2], triad[1], triad[0] * 2, triad[1]]
        for step in range(16):
            at = t_axis(EIGHTH * 0.5 * 0.9, rate)
            f = shape[step % len(shape)] * 2
            voice = square(f, at, 0.25) * env(at, attack=0.002, curve=7.0)
            _add(arp, bar_start + step * EIGHTH * 0.5, lowpass(voice, 3200, rate))

        # --- drums -----------------------------------------------------------
        for step in range(8):
            pos = bar_start + step * EIGHTH
            if step in (0, 4) or (step == 6 and bar % 2 == 1):
                _add(drums, pos, kick * 0.95)
            if step in (2, 6):
                _add(drums, pos, snare * 0.5)
            _add(drums, pos, (hat_hard if step % 2 == 0 else hat_soft) * 0.22)

        # --- lead: second half of the loop only ------------------------------
        if bar >= 8:
            for step, f in enumerate(LEAD[bar - 8]):
                if f is None:
                    continue
                lt = t_axis(EIGHTH * 1.85, rate)
                vib = f * (1 + 0.006 * np.sin(2 * np.pi * 5.2 * lt))
                voice = 0.55 * square(vib, lt, 0.42) + 0.45 * triangle(vib, lt)
                voice = lowpass(voice, 2600, rate)
                voice *= env(lt, attack=0.012, decay=EIGHTH * 0.9,
                             sustain=0.5, release=EIGHTH * 0.8)
                _add(lead, bar_start + step * EIGHTH, voice)

    mix = (0.50 * bass + 0.13 * arp + 0.11 * pad + 0.26 * lead + 0.42 * drums)
    mix = np.tanh(mix * 1.25) * 0.8  # gentle glue / soft clip

    # A few milliseconds of fade at each end so the loop seam cannot click.
    edge = int(0.004 * rate)
    mix[:edge] *= np.linspace(0, 1, edge)
    mix[-edge:] *= np.linspace(1, 0, edge)
    return mix, rate


def write_music():
    mix, rate = build_music()
    path = os.path.join(OUT, "music.mp3")
    sf.write(path, normalise(mix.astype(np.float32), 0.88), rate,
             format="MP3", subtype="MPEG_LAYER_III")
    print(f"  {'music.mp3':24s} {len(mix) / rate:5.2f}s  "
          f"{os.path.getsize(path) // 1024:4d} KB")


def main():
    os.makedirs(OUT, exist_ok=True)
    print("sound effects:")
    for name, fn in SFX.items():
        write_wav(name, fn())
    print("music:")
    write_music()


if __name__ == "__main__":
    main()
