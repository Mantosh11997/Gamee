#!/usr/bin/env python3
"""Turn the raw art in tool/source_art/ into the game sprites in assets/images/.

Run from the repo root:  python3 tool/build_assets.py

What it does per sprite:
  1. keys out an opaque background where one is baked in (the tank art ships
     with a white/checkerboard backdrop),
  2. trims fully transparent margins,
  3. rotates the sprite so it points the way the game expects (player and its
     bullets fly up, enemies and their bullets fly down),
  4. downscales to a sensible power-of-two-ish size with Lanczos,
  5. prints the aspect ratio and a measured "hull box" for each sprite - those
     are the numbers baked into lib/game/config.dart and EnemySpec, so re-run
     this if you swap the art and copy the reported values across.

Requires: pip install Pillow numpy
"""

from collections import deque
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tool", "source_art")
OUT = os.path.join(ROOT, "assets", "images")

# name in source_art -> (output name, rotate 180?, longest output side, de-key light bg?)
SPRITES = [
    ("player_blue.png", "player.png", False, 256, False),
    ("enemy_basic_red.png", "enemy_basic.png", True, 224, False),
    ("enemy_fast_pink.png", "enemy_fast.png", True, 224, False),
    ("enemy_tank_green.png", "enemy_tank.png", True, 288, True),
    ("bullet_player_blue.png", "bullet_player.png", False, 192, False),
    ("bullet_enemy_red.png", "bullet_enemy.png", True, 192, False),
    ("powerup_health_green.png", "powerup_health.png", False, 192, False),
    ("powerup_rapidfire_yellow.png", "powerup_rapidfire.png", False, 192, False),
]


def dilate(mask, radius=1):
    out = mask.copy()
    for _ in range(radius):
        d = out.copy()
        d[1:, :] |= out[:-1, :]
        d[:-1, :] |= out[1:, :]
        d[:, 1:] |= out[:, :-1]
        d[:, :-1] |= out[:, 1:]
        out = d
    return out


def key_out_light_background(im):
    """Flood-fill the near-white background in from the edges and feather it.

    Only the region connected to the image border is removed, so white
    highlights inside the ship survive.
    """
    rgb = np.array(im.convert("RGB")).astype(int)
    h, w, _ = rgb.shape
    light = rgb.min(2) > 222

    outside = np.zeros((h, w), bool)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if light[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if light[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not outside[ny, nx] and light[ny, nx]:
                outside[ny, nx] = True
                queue.append((ny, nx))

    alpha = np.full((h, w), 255, np.uint8)
    alpha[outside] = 0

    # Feather the two pixels just inside the cut so the silhouette is not a
    # hard staircase against the dark space background.
    band = dilate(outside, 2) & ~outside
    whiteness = np.clip((rgb.min(2) - 198) / 57.0, 0, 1)
    alpha[band] = (255 * (1 - whiteness[band])).astype(np.uint8)

    out = np.dstack([rgb.astype(np.uint8), alpha])
    return Image.fromarray(out, "RGBA")


def trim(im, threshold=8):
    alpha = np.array(im)[..., 3]
    ys, xs = np.where(alpha > threshold)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def hull_box(im, density=0.45):
    """Measure the dense core of the sprite, ignoring thin exhaust plumes.

    Returns (left, top, right, bottom) as fractions of the image, which is what
    the components use to place their hitboxes.
    """
    alpha = np.array(im)[..., 3] > 96
    h, w = alpha.shape
    rows = alpha.sum(1)
    keep_rows = np.where(rows >= rows.max() * density)[0]
    top, bottom = keep_rows.min(), keep_rows.max() + 1
    cols = alpha[top:bottom].sum(0)
    keep_cols = np.where(cols >= cols.max() * density)[0]
    left, right = keep_cols.min(), keep_cols.max() + 1
    return left / w, top / h, right / w, bottom / h


def main():
    os.makedirs(OUT, exist_ok=True)
    print(f"{'sprite':22s} {'output px':>11s} {'w/h':>6s}   hull box (l,t,r,b as fractions)")
    for src_name, out_name, rotate, longest, dekey in SPRITES:
        im = Image.open(os.path.join(SRC, src_name)).convert("RGBA")
        if dekey:
            im = key_out_light_background(im)
        im = trim(im)
        if rotate:
            im = im.rotate(180)

        scale = longest / max(im.size)
        size = (max(1, round(im.size[0] * scale)), max(1, round(im.size[1] * scale)))
        im = im.resize(size, Image.LANCZOS)

        box = hull_box(im)
        im.save(os.path.join(OUT, out_name), optimize=True)
        print(
            f"{out_name:22s} {size[0]:5d}x{size[1]:<5d} {size[0] / size[1]:6.3f}   "
            + ", ".join(f"{v:.3f}" for v in box)
        )


if __name__ == "__main__":
    main()
