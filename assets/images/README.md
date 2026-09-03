# Sprite drop zone

Put transparent PNGs here using exactly these file names:

- `player.png`
- `enemy_basic.png`
- `enemy_fast.png`
- `enemy_tank.png`
- `bullet_player.png`
- `bullet_enemy.png`
- `powerup_health.png`
- `powerup_rapidfire.png`

Point ships and bullets along their direction of travel: the player and its bullets face
**up**, enemies and their bullets face **down**.

This folder is already declared in `pubspec.yaml`, so no pubspec change is needed — add the
files and hot restart.

Anything missing is fine: the game draws a code-drawn placeholder shape for it instead, so
you can add the sprites one at a time. See the root `README.md` for suggested sizes.
