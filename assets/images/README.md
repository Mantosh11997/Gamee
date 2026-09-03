# Sprites

Built from `tool/source_art/` by `python3 tool/build_assets.py` — see the root `README.md`
for what that script does and for each sprite's shipped dimensions.

To swap in your own art, either drop replacement PNGs straight in here using the same file
names, or replace the files in `tool/source_art/` and re-run the script. Ships and bullets
must point along their direction of travel: the player and its bullets face **up**, enemies
and their bullets face **down**.

Files: `player.png`, `enemy_basic.png`, `enemy_fast.png`, `enemy_tank.png`,
`bullet_player.png`, `bullet_enemy.png`, `powerup_health.png`, `powerup_rapidfire.png`.

Anything missing is fine — the game draws a code-drawn placeholder shape for it instead, so
you can replace the sprites one at a time. If you change a sprite's aspect ratio, copy the
numbers the build script prints into `GameConfig` / `EnemySpec` so the art is not squashed.
