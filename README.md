# Nebula Strike

A complete vertical space shooter for Android and iOS, built with **Flutter** and the
**[Flame](https://pub.dev/packages/flame) 1.38.2** game engine.

Ships, bullets and pickups are PNG sprites. Everything else — the space gradient, the
parallax starfield, the HUD, glows, HP bars, explosions, thruster trails, screen shake —
is drawn in code. Every sound in the game is **synthesised from oscillators and noise** by
a script in `tool/`; nothing is sampled or downloaded.

---

## Running it

```bash
flutter pub get
flutter run          # with a device or emulator attached
```

Requires **Flutter 3.41 or newer** (Dart 3.11+), because that is what `flame: 1.38.2`
pins. Check with `flutter --version`; `flutter upgrade` if you are behind.

The Android and iOS projects are generated and locked to portrait, and the art and audio
are already in the repo — there is nothing to configure before the first run.

```bash
flutter test         # 33 tests: lifecycle, difficulty, combat, audio, hangar economy, ordnance, codex, both render paths
flutter analyze      # clean
flutter build apk --release
flutter build ios --release
```

Platform floors are already satisfied: `audioplayers` needs Android minSdk 19 (Flutter's
default is 24) and iOS 13 (the project targets 15).

---

## The hangar

The home screen is a ship shop. Every hull in `ShipCatalog` is **browsable whether or not
you own it** - art, stats and weapon are all on show behind the padlock, with the price on
the card. Swipe the carousel, read the stats, unlock with coins, and the ship you equip is
the one that flies.

| Ship | Price | Cannon | Ordnance |
| --- | --- | --- | --- |
| Scout | free | Pulse Cannon ×1 | — |
| Interceptor | 400 | Twin Plasma ×2 | — |
| Destroyer | 1200 | Tri-Spread ×3 | — |
| Dreadnought | 3000 | Siege Battery ×5 | Heavy Missile |
| Battlecruiser | 6500 | Plasma Battery ×7 | Cluster Salvo |
| Carrier | 12000 | Lance Array ×8 | Cluster Salvo |
| Super Dreadnought | 22000 | Siege Lances ×9 | Gravity Bomb |
| Titan | 40000 | Apex Battery ×11 | Atomic Warhead |

**Ordnance** is the heavy secondary weapon the big hulls carry. It fires on its own slow
cooldown alongside the cannon, flies slower than a bullet, and detonates on impact for full
damage to what it hit plus half damage to everything inside its blast radius — so it is
worth lining up on a cluster. The impact paints a `SpriteBurst`: a scaling, fading sprite
(atomic burst, nova) rather than a particle spray.

**Coins** come from playing: `score / 12 + wave × 15 + kills × 2`, shown on the game-over
screen and added to the balance in the top-right of the hangar. Coins, unlocked ships, the
equipped ship and the best score persist through `shared_preferences` - and, like the audio
and the sprites, degrade gracefully: if the store is unavailable the profile still works
for the session and simply forgets on exit.

Each ship's `WeaponSpec` is a list of `Barrel`s - a muzzle offset across the hull and an
angle in degrees. `Player._fire()` walks that list, so a new weapon is data, not code, and
the hangar's weapon panel draws the same volley the ship will actually fire. Adding a ship
is one entry in `ShipCatalog.all` plus its PNG.

Skin art is optional exactly like everything else. `player_mk2/3/4.png` and
`bullet_player_heavy.png` are still not in the repo, so those three cards show a code-drawn
silhouette and those hulls fall back to the starter sprite in-game; everything else —
stats, weapons, ordnance, prices, unlocking — works regardless. Drop the PNGs in and they
appear with no code change.

---

## Getting an APK

`.github/workflows/build-apk.yml` analyzes, tests and builds the app on every branch push,
on version tags, and on demand from the **Actions** tab (**Build APK → Run workflow**).

Each successful run attaches a `nebula-strike-apk-<run>-<sha>` artifact containing:

| APK | Use |
| --- | --- |
| `app-release.apk` | universal — installs on any device, largest download |
| `app-arm64-v8a-release.apk` | modern phones (almost certainly the one you want) |
| `app-armeabi-v7a-release.apk` | older 32-bit ARM devices |
| `app-x86_64-release.apk` | emulators |

Download it from the run's summary page, unzip, and `adb install app-arm64-v8a-release.apk`
(or copy it to the device and open it). The run summary also lists each APK's size and says
which key it was signed with.

Push a tag to cut a release — the workflow publishes the APKs to a GitHub Release with
generated notes:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Locally the same builds are:

```bash
flutter build apk --release                  # build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi  # smaller, one per architecture
```

### Signing

Out of the box the release build is signed with the **debug key**. That is enough to
install and play, but not to publish — Google Play rejects debug-signed uploads.

To sign with a real upload key, generate one:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

then add four repository secrets (**Settings → Secrets and variables → Actions**):

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | `base64 -w 0 upload-keystore.jks` |
| `KEYSTORE_PASSWORD` | the keystore password |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | the key password |

The workflow writes `android/key.properties` from those and deletes it afterwards; with no
secrets set it skips the step entirely and nothing changes. For local release builds, create
`android/key.properties` yourself (it is already gitignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

`android/app/build.gradle.kts` picks that file up automatically and falls back to the debug
key when it is absent.

---

## How it fits together

```
lib/
├─ main.dart                     app entry: portrait lock, full screen, GameWidget + overlays
├─ game/
│  ├─ config.dart                ★ every tuning number in the game lives here
│  ├─ space_shooter_game.dart    the FlameGame: component layout, states, score, screen shake
│  ├─ sprite_library.dart        PNG loading with graceful fallback to placeholder shapes
│  ├─ audio.dart                 fail-safe SFX + music façade over flame_audio
│  ├─ ship_skin.dart             the ship catalogue: stats, prices, weapons, ordnance
│  └─ player_profile.dart        coins, owned ships, equipped ship, best score (persisted)
├─ components/
│  ├─ art_component.dart         SpriteComponent base that tolerates a missing sprite
│  ├─ background.dart            gradient + nebulae + 3-layer looping parallax starfield
│  ├─ game_layer.dart            container for gameplay entities; applies the screen shake
│  ├─ player.dart                movement, firing cadence, HP, i-frames, glow, thruster
│  ├─ enemy.dart                 5 archetypes + specs, weaving, shooting, HP bar, death flash
│  ├─ bullet.dart                PlayerBullet / EnemyBullet
│  ├─ ordnance.dart              missiles, bombs and atomics with splash damage
│  ├─ sprite_burst.dart          scaling/fading sprite explosions
│  ├─ powerup.dart               health & rapid-fire drops
│  ├─ effects.dart               particle explosions, sparks, thruster puffs, pickup sparkle
│  ├─ controls.dart              joystick + optional hold-to-fire button
│  └─ hud.dart                   HP bar, score, wave, buff timer, wave banner
├─ managers/
│  ├─ wave_manager.dart          spawn cadence, enemy mix, difficulty ramp
│  └─ score_manager.dart         score / kills / session best
└─ ui/
   ├─ overlay_ids.dart           overlay name constants
   └─ overlays.dart              start menu, pause, game over, mute toggle
tool/
├─ build_assets.py               raw art  -> assets/images/  (keying, trimming, rotating)
├─ build_audio.py                oscillators -> assets/audio/ (all SFX + the music loop)
└─ source_art/                   the untouched source images
.github/workflows/
└─ build-apk.yml                 analyze + test + APK build, and releases on a tag
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

Each state swaps Flutter overlays and toggles the on-screen controls. `startGame()` wipes
the battlefield, resets score and waves and rebuilds the player, so Restart is a genuine
full reset. The app auto-pauses when it loses focus.

---

## Art

The eight sprites in `assets/images/` are built from `tool/source_art/` by:

```bash
pip install Pillow numpy
python3 tool/build_assets.py
```

The script keys out baked-in backgrounds (the tank art arrives on a white checkerboard),
trims transparent margins, rotates enemies and their bullets to face down, downscales with
Lanczos, and prints each sprite's aspect ratio and measured hull box. Those printed numbers
are what `GameConfig` and `EnemySpec` use for component sizes and hitboxes — **re-run the
script and copy the values across if you swap the art.**

| File | Used by | Shipped size |
| --- | --- | --- |
| `player.png` | player ship, nose **up** | 241×256 |
| `enemy_basic.png` | slow, low-HP enemy, nose **down** | 222×224 |
| `enemy_fast.png` | quick weaving enemy | 140×224 |
| `enemy_tank.png` | slow, high-HP, larger enemy | 269×288 |
| `bullet_player.png` | player projectile, **up** | 34×192 |
| `bullet_enemy.png` | enemy projectile, **down** | 29×192 |
| `powerup_health.png` | health pickup | 92×192 |
| `powerup_rapidfire.png` | rapid-fire pickup | 98×192 |

Hitboxes are a **slice** of each sprite box, not the whole thing — wingtips, exhaust
plumes and bullet trails do not collide. See `ArtComponent.hitboxFor` and the
`hitbox*` fields on `GameConfig` / `EnemySpec`.

**Deleting any sprite is still safe.** `SpriteLibrary` checks the asset manifest at boot;
anything it cannot find is left `null` and the component draws a distinct code-drawn
placeholder instead (each enemy type has its own silhouette). Both render paths are
covered by tests.

---

## Sound

`assets/audio/` holds ten one-shot effects as 16-bit mono WAV plus a 29-second music loop
as MP3 (Ogg Vorbis is not playable on iOS). Regenerate everything with:

```bash
pip install numpy soundfile
python3 tool/build_audio.py
```

| Sound | Fires when |
| --- | --- |
| `shoot_player.wav` | the ship fires (pooled — up to 11×/s under rapid fire) |
| `shoot_enemy.wav` | an enemy fires |
| `enemy_hit.wav` | a bullet damages an enemy that survives |
| `explosion_small.wav` | a basic or fast enemy dies |
| `explosion_large.wav` | a tank dies, or the player does |
| `player_hit.wav` | the ship takes damage |
| `powerup_health.wav` / `powerup_rapidfire.wav` | a pickup is collected |
| `wave_start.wav` | a wave begins |
| `game_over.wav` | the run ends |
| `music.mp3` | looping bed, 16 bars in A minor at 132 BPM |

`AudioManager` is deliberately unkillable: if the plugin, the platform or the files are
unavailable it flips `available` to false and the game runs silent — no throw, no stall.
`AudioManager.enabled = false` switches it off entirely before the plugin is ever touched,
which is what the widget tests do. A speaker button sits next to the pause control and on
both menus; mute pauses the music in place rather than stopping it.

---

## Tuning it

Open `lib/game/config.dart` — it is the single knob board.

| Constant | Effect |
| --- | --- |
| `autoFire` | `true` (default) the ship shoots by itself; `false` adds a hold-to-fire button bottom-right |
| `playerFireInterval` / `rapidFireInterval` | seconds between shots, normally and while buffed |
| `playerSpeed`, `playerMaxHp`, `playerInvulnerability` | ship feel and survivability |
| `playerHitbox*`, `bulletHitbox*` | which slice of the sprite actually collides |
| `baseSpawnInterval`, `spawnIntervalDecayPerWave`, `minSpawnInterval` | how fast waves get busy |
| `baseEnemiesPerWave`, `enemiesAddedPerWave` | wave size growth |
| `enemySpeedRampPerWave`, `maxEnemySpeedMultiplier` | the speed curve and its ceiling |
| `firstShootingWave`, `firstTankWave` | how gentle the opening is |
| `powerupDropChance`, `healthRestore`, `rapidFireDuration` | drop economy |
| `shakeOnPlayerHit`, `shakeOnExplosion` | how much the screen kicks |
| `sfxVolume`, `musicVolume` | master audio levels |

Enemy stats (HP, speed, size, score, weave, rate of fire, hitbox, placeholder colour) live
in `EnemySpec.specs` in `lib/components/enemy.dart`. **Adding a fourth enemy type is two
steps**: add a value to the `EnemyType` enum and an entry to `EnemySpec.specs`. The wave
manager picks it up from there — only `_pickType()` needs a weight for it.

### The hostile codex

The home screen's second tab lists every enemy in the game — art, HP, speed, points, rate
of fire, whether it weaves, and the earliest wave it can appear on — so you can read the
threat before you meet it.

| Enemy | From | HP | Behaviour |
| --- | --- | --- | --- |
| Raider | wave 1 | 24 | straight down, shoots from wave 2 |
| Stinger | wave 2 | 14 | fast, weaves, no guns |
| Hulk | wave 3 | 120 | slow armoured brick |
| Heavy Raider | wave 5 | 70 | up-gunned raider, fires twice as often |
| Assault Cruiser | wave 9 | 190 | wide gunship that drifts while it hammers you |

Each type's `firstWave` lives on its `EnemySpec`, and both the spawner and the codex read
it — so the list can't drift out of sync with what actually spawns. A test asserts the
spawner never picks a type before its first wave, across 30 waves.

### Waves, not levels

There is no fixed level count and no win state: `WaveManager` increments `wave` forever and
the run ends when HP hits 0. Wave size grows by 2 enemies each time (uncapped); the spawn
interval bottoms out at wave 14 and the speed multiplier at wave 27, so the difficulty
curve is fully ramped from there on.
