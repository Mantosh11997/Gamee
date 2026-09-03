# Nebula Strike

A complete vertical space shooter for Android and iOS, built with **Flutter** and the
**[Flame](https://pub.dev/packages/flame) 1.38.2** game engine.

Everything except the ship/bullet/pickup sprites is drawn in code: the space gradient, the
parallax starfield, the HUD, glows, HP bars, explosions, thruster trails and screen shake.

---

## Running it

```bash
flutter pub get
flutter run          # with a device or emulator attached
```

Requires **Flutter 3.41 or newer** (Dart 3.11+), because that is what `flame: 1.38.2`
pins. Check with `flutter --version`; `flutter upgrade` if you are behind.

The Android and iOS projects are already generated and locked to portrait. There is
nothing else to configure — the game **runs immediately with no art at all** (see below).

Useful extras:

```bash
flutter test         # 13 tests: lifecycle, difficulty ramp, combat rules, both render paths
flutter analyze      # clean
flutter build apk --release
flutter build ios --release
```

---

## Where the PNGs go

Drop transparent PNGs into **`assets/images/`** using exactly these names:

| File | Used by | Suggested size |
| --- | --- | --- |
| `player.png` | the player ship, nose pointing **up** | 128×128 |
| `enemy_basic.png` | slow, low-HP enemy, nose **down** | 128×128 |
| `enemy_fast.png` | quick weaving enemy, nose **down** | 96×96 |
| `enemy_tank.png` | slow, high-HP, larger enemy | 192×192 |
| `bullet_player.png` | player projectile, pointing **up** | 32×96 |
| `bullet_enemy.png` | enemy projectile, pointing **down** | 32×80 |
| `powerup_health.png` | health pickup badge | 96×96 |
| `powerup_rapidfire.png` | rapid-fire pickup badge | 96×96 |

The folder is already declared in `pubspec.yaml`, so no pubspec edit is needed — just add
the files and hot restart.

**Missing files are fine.** `SpriteLibrary` checks the asset manifest at boot and any sprite
it cannot find is left `null`; the component then draws a distinct code-drawn placeholder
instead (each enemy type has its own silhouette). You can add the eight PNGs one at a time
and the game keeps working throughout. Sprites are drawn scaled to the component's `size`,
so exact pixel dimensions do not matter — aspect ratio does.

---

## How it fits together

```
lib/
├─ main.dart                     app entry: portrait lock, full screen, GameWidget + overlays
├─ game/
│  ├─ config.dart                ★ every tuning number in the game lives here
│  ├─ space_shooter_game.dart    the FlameGame: component layout, states, score, screen shake
│  └─ sprite_library.dart        PNG loading with graceful fallback to placeholder shapes
├─ components/
│  ├─ art_component.dart         SpriteComponent base that tolerates a missing sprite
│  ├─ background.dart            gradient + nebulae + 3-layer looping parallax starfield
│  ├─ game_layer.dart            container for gameplay entities; applies the screen shake
│  ├─ player.dart                movement, firing cadence, HP, i-frames, glow, thruster
│  ├─ enemy.dart                 3 archetypes + specs, weaving, shooting, HP bar, death flash
│  ├─ bullet.dart                PlayerBullet / EnemyBullet with code-drawn bloom
│  ├─ powerup.dart               health & rapid-fire drops
│  ├─ effects.dart               particle explosions, sparks, thruster puffs, pickup sparkle
│  ├─ controls.dart              joystick + optional hold-to-fire button
│  └─ hud.dart                   HP bar, score, wave, buff timer, wave banner
├─ managers/
│  ├─ wave_manager.dart          spawn cadence, enemy mix, difficulty ramp
│  └─ score_manager.dart         score / kills / session best
└─ ui/
   ├─ overlay_ids.dart           overlay name constants
   └─ overlays.dart              start menu, pause, game over (Flutter widgets)
```

### Rendering layers

All components are children of the game itself, so everything works in plain screen
coordinates — no camera maths anywhere:

| priority | component | notes |
| --- | --- | --- |
| −100 | `StarfieldBackground` | never shakes |
| −50 | `WaveManager` | invisible, spawn logic only |
| 0 | `GameLayer` | player, enemies, bullets, pickups, particles |
| 100 | `Hud` | code-drawn |
| 200 | `GameJoystick`, `FireButton` | |

Screen shake is a **render-only** translation applied by `GameLayer`, so hitboxes never
move and the HUD, controls and starfield stay rock steady while the action rattles.

### Game states

`PlayState.menu → playing ⇄ paused → gameOver → playing`

Each state swaps Flutter overlays (`lib/ui/overlays.dart`) and toggles the on-screen
controls. `startGame()` wipes the battlefield, resets score and waves and rebuilds the
player, so Restart is a genuine full reset. The app also auto-pauses when it loses focus.

---

## Tuning it

Open `lib/game/config.dart` — it is the single knob board. A few you will probably reach
for first:

| Constant | Effect |
| --- | --- |
| `autoFire` | `true` (default) the ship shoots by itself; `false` adds a hold-to-fire button bottom-right |
| `playerFireInterval` / `rapidFireInterval` | seconds between shots, normally and while buffed |
| `playerSpeed`, `playerMaxHp`, `playerInvulnerability` | ship feel and survivability |
| `baseSpawnInterval`, `spawnIntervalDecayPerWave`, `minSpawnInterval` | how fast waves get busy |
| `baseEnemiesPerWave`, `enemiesAddedPerWave` | wave size growth |
| `enemySpeedRampPerWave`, `maxEnemySpeedMultiplier` | the speed curve and its ceiling |
| `firstShootingWave`, `firstTankWave` | how gentle the opening is |
| `powerupDropChance`, `healthRestore`, `rapidFireDuration` | drop economy |
| `shakeOnPlayerHit`, `shakeOnExplosion` | how much the screen kicks |

Enemy stats (HP, speed, size, score, weave, rate of fire, placeholder colour) live in
`EnemySpec.specs` in `lib/components/enemy.dart`. **Adding a fourth enemy type is two
steps**: add a value to the `EnemyType` enum and an entry to `EnemySpec.specs`. The wave
manager picks it up from there — only `_pickType()` needs a weight for it.

---

## Adding sound

Sound is not wired up (there are no audio assets to ship). To add it, uncomment
`flame_audio: 2.12.2` in `pubspec.yaml`, add an `assets/audio/` entry, and call
`FlameAudio.play('shoot.wav')` from `Player._fire()` and `Enemy._explode()`.
