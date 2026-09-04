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

# (source, output, rotate 180?, longest output side, background key)
#   key: None | "light" | "dark" | "luma"
SPRITES = [
    # --- original set -------------------------------------------------------
    ("player_blue.png", "player.png", False, 256, None),
    ("enemy_basic_red.png", "enemy_basic.png", True, 224, None),
    ("enemy_fast_pink.png", "enemy_fast.png", True, 224, None),
    ("enemy_tank_green.png", "enemy_tank.png", True, 288, "light"),
    ("bullet_player_blue.png", "bullet_player.png", False, 192, None),
    ("bullet_enemy_red.png", "bullet_enemy.png", True, 192, None),
    ("powerup_health_green.png", "powerup_health.png", False, 192, None),
    ("powerup_rapidfire_yellow.png", "powerup_rapidfire.png", False, 192, None),

    # --- heavy player hulls (drawn nose-up already) --------------------------
    ("player_mk5_battlecruiser.png", "player_mk5.png", False, 320, None),
    ("player_mk6_carrier.png", "player_mk6.png", False, 336, None),
    ("player_mk7_superdreadnought.png", "player_mk7.png", False, 352, None),
    ("player_titan.png", "player_titan.png", False, 384, None),

    # --- player ordnance ----------------------------------------------------
    ("bullet_player_ultra.png", "bullet_player_ultra.png", False, 224, None),
    ("bullet_player_laser.png", "bullet_player_laser.png", False, 256, None),
    ("missile_player_heavy.png", "missile_player_heavy.png", False, 224, None),
    ("missile_player_cluster.png", "missile_player_cluster.png", False, 224, None),
    # Both bombs are drawn falling nose-down; the player launches them upward.
    ("bomb_player.png", "bomb_player.png", True, 208, None),
    ("bomb_player_nuclear.png", "bomb_player_nuclear.png", True, 208, "dark"),

    # --- effects: additive light, so alpha comes from brightness ------------
    ("attack_atomic.png", "attack_atomic.png", False, 320, "luma"),
    ("explosion_atomic.png", "explosion_atomic.png", False, 320, "luma"),
    ("attack_nova.png", "attack_nova.png", False, 384, "luma"),
    ("attack_beam.png", "attack_beam.png", False, 320, "luma"),

    # --- heavy enemy hulls (drawn nose-up, rotated to fly down) -------------
    ("enemy_heavy_red.png", "enemy_heavy.png", True, 256, None),
    ("enemy_assault_red.png", "enemy_assault.png", True, 288, None),
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


def key_out_dark_background(im):
    """Flood-fill a baked near-black backdrop in from the edges.

    Mirror image of the light-background key: some art arrives matted onto
    black rather than on real alpha.
    """
    rgb = np.array(im.convert("RGB")).astype(int)
    h, w, _ = rgb.shape
    dark = rgb.max(2) < 42

    outside = np.zeros((h, w), bool)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if dark[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if dark[y, x] and not outside[y, x]:
                outside[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not outside[ny, nx] and dark[ny, nx]:
                outside[ny, nx] = True
                queue.append((ny, nx))

    alpha = np.full((h, w), 255, np.uint8)
    alpha[outside] = 0
    band = dilate(outside, 2) & ~outside
    darkness = np.clip((62 - rgb.max(2)) / 40.0, 0, 1)
    alpha[band] = (255 * (1 - darkness[band])).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA")


def key_by_luminance(im, threshold=78):
    """Turn a glow rendered on black into real alpha.

    Explosions and beams are additive light: the correct alpha for them is
    their own brightness, so black fringes vanish while the fire survives at
    full strength. Existing alpha is respected - this only ever removes.
    """
    a = np.array(im.convert("RGBA")).astype(float)
    luma = a[..., :3].max(2)
    ramp = np.clip(luma / threshold, 0, 1)
    a[..., 3] = a[..., 3] * ramp
    return Image.fromarray(a.astype(np.uint8), "RGBA")


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
    for src_name, out_name, rotate, longest, key in SPRITES:
        im = Image.open(os.path.join(SRC, src_name)).convert("RGBA")
        if key == "light":
            im = key_out_light_background(im)
        elif key == "dark":
            im = key_out_dark_background(im)
        elif key == "luma":
            im = key_by_luminance(im)
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
