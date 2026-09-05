# Store listing copy

Everything below is drafted for Google Play's field limits. Swap the game name if you
rename it (see the naming notes in the chat log) and re-check the character counts.

---

## App name (30 chars max)

```
Nebula Strike
```
13 chars. Fits under an app icon without truncating.

## Short description (80 chars max)

```
Fly it, fight it, fund the next one. 8 hulls, 11 hostiles, endless waves.
```

Alternates:
```
One-thumb space shooter. Earn coins, unlock capital ships, hold the line.
Endless waves. Eight ships to unlock, from a scout to a nuke-armed Titan.
Survive the waves, bank the coins, buy a bigger ship. Repeat until you don't.
```

## Full description (4000 chars max)

```
Hold the line against endless waves of hostiles, then spend what you earn on a bigger ship.

Nebula Strike is a one-thumb vertical space shooter. Drag to fly, your cannons fire
themselves, and the only question is how long you last — and what you buy with the coins
when you don't.

FLY EIGHT SHIPS
Start in a Scout with a single pulse cannon. Finish in a Titan: eleven barrels in a wide
arc and a tactical nuke on a cooldown. Every hull in between changes how the game plays —
the Destroyer trades speed for an angled three-way fan, the Carrier fires eight focused
lances, the Super Dreadnought carries a gravity bomb. You can look at all of them from the
first minute. Paying for them is the game.

EARN, UNLOCK, EQUIP
Coins come from playing: score, waves survived, and every kill. Nothing is timed, nothing
expires, and the ship you equip is the ship that flies. Your coins, your fleet and your
best run are saved between sessions.

ELEVEN HOSTILES, ONE CODEX
Raiders come straight down. Stingers weave. Hulks soak everything you have. Later waves
bring gold-trimmed elites, an ordnance bomber lobbing heavy shells, quad-rotor sentry
drones, and — rarely — a capital-class Crimson Dreadnought with 900 hit points. The in-game
codex lists every one of them with its stats, its behaviour and the wave it starts
appearing on, so you can read the threat before you meet it.

HEAVY ORDNANCE
The bigger hulls carry a second weapon on its own cooldown: heavy missiles, cluster salvos,
gravity bombs, atomic warheads. They fly slower than a bullet and detonate for splash
damage, so they reward lining up on a cluster instead of a single ship.

ENDLESS, NOT LEVELS
There is no level select and no win screen. Waves keep coming, get bigger and get faster,
and the run ends when your hull does. Difficulty is fully ramped by wave 27; after that the
only thing still rising is how many of them there are.

BUILT TO FEEL GOOD
Parallax starfield, particle explosions with shockwave rings, screen shake that never moves
a hitbox, engine trails, glowing bolts, and a soundtrack synthesised from scratch.

No ads. No in-app purchases. No account. No internet connection needed.
```

~1,980 chars.

---

## Screenshots

`docs/screenshots/` — 1140×2460 PNG, portrait, rendered from the real game.

| File | Shows |
| --- | --- |
| `01-combat.png` | Battlecruiser mid-fight: seven-barrel fan, six hostile types on screen, return fire |
| `02-endgame.png` | Titan at wave 12: eleven-barrel arc, an explosion and a death flash |
| `03-hangar.png` | The hangar — Titan card, stat bars, Apex Battery ×11 and Atomic Warhead loadout |
| `04-codex.png` | The hostile codex — art, behaviour and stats for each enemy |

Regenerate with `flutter test tool/demo/screenshots.dart` and pick from the candidates it
writes to `build/screenshots/`.

## Promo video

`tool/demo/demo_capture.dart` + `tool/build_demo_video.sh` render a 30-second clip covering
every ship and every enemy, scored with the game's own music loop. 760×1640, 30fps.

---

## Content and tech facts

| | |
| --- | --- |
| Genre | Vertical scrolling shoot-'em-up (shmup), endless |
| Controls | One thumb: on-screen joystick, auto-fire (hold-to-fire is a config flag) |
| Orientation | Portrait, locked |
| Player ships | 8, priced 0 / 400 / 1,200 / 3,000 / 6,500 / 12,000 / 22,000 / 40,000 coins |
| Enemy types | 11, arriving between wave 1 and wave 14 |
| Weapons | 8 cannon layouts (1–11 barrels) + 4 ordnance types |
| Power-ups | Repair, Rapid Fire, Overdrive |
| Progression | Coins → permanent ship unlocks; persisted locally |
| Engine | Flutter + Flame 1.38.2 |
| Audio | flame_audio; 10 SFX + a 29-second music loop, all synthesised, no samples |
| Platforms | Android (minSdk 24) and iOS (13+) |
| Monetisation | None — no ads, no IAP, no analytics, no network calls |
| Permissions | None requested |
| Data collected | None. Coins, unlocks and best score never leave the device |
| Content rating | Fantasy sci-fi combat, no gore, no text chat — expect Everyone / PEGI 3–7 |
