import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../components/background.dart';
import '../components/controls.dart';
import '../components/enemy.dart';
import '../components/game_layer.dart';
import '../components/hud.dart';
import '../components/player.dart';
import '../components/powerup.dart';
import '../managers/score_manager.dart';
import '../managers/wave_manager.dart';
import '../ui/overlay_ids.dart';
import 'audio.dart';
import 'config.dart';
import 'player_profile.dart';
import 'sprite_library.dart';

/// High level game states. The Flutter overlays are driven off this.
enum PlayState { menu, playing, paused, gameOver }

/// The game root.
///
/// Component layout (all children of the game itself, so everything works in
/// plain screen coordinates - no camera maths needed):
///
///   priority -100  [StarfieldBackground]  gradient + parallax stars
///   priority  -50  [WaveManager]          spawning / difficulty (invisible)
///   priority    0  [GameLayer]            player, enemies, bullets, particles
///   priority  100  [Hud]                  code-drawn HP / score / wave
///   priority  200  [GameJoystick], [FireButton]
///
/// Screen shake is applied by [GameLayer] as a render-only translation, so the
/// HUD, the controls and the starfield all stay perfectly still.
class SpaceShooterGame extends FlameGame with HasCollisionDetection {
  final Random rng = Random();

  /// PNG sprites, with null entries for anything missing from assets/images/.
  final SpriteLibrary sprites = SpriteLibrary();

  final ScoreManager scores = ScoreManager();

  /// Sound effects and music. Fails safe: if the audio plugin or the files are
  /// unavailable the game simply runs silent.
  final AudioManager audio = AudioManager();

  /// Coins, owned ships and the equipped one - persisted between sessions.
  final PlayerProfile profile = PlayerProfile();

  /// Coins awarded by the run that just ended, shown on the game-over screen.
  int lastRunCoins = 0;

  late final StarfieldBackground background;
  late final GameLayer layer;
  late final Hud hud;
  late final WaveManager waves;
  late final GameJoystick joystick;
  late final FireButton fireButton;

  /// The live player ship, or null between runs.
  Player? player;

  PlayState state = PlayState.menu;

  /// Top inset (status bar / notch) pushed in from the Flutter side so the HUD
  /// can dodge it. Flame has no MediaQuery of its own.
  double safeTop = 24;

  /// Short centred toast (power-up pickups). Rendered by the HUD.
  String announcementText = '';
  double announcementTimer = 0;

  double _shakeTime = 0;
  double _shakeDuration = GameConfig.shakeDuration;
  double _shakeStrength = 0;

  int get score => scores.score;

  /// True while at least one enemy is still on the field.
  bool get hasLiveEnemies => layer.children.whereType<Enemy>().isNotEmpty;

  @override
  Color backgroundColor() => GameConfig.spaceTop;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Missing PNGs are tolerated - components fall back to drawn shapes.
    await sprites.loadAll(images);
    // Likewise for audio: this never throws, it just goes quiet.
    await audio.init();
    // And for the saved profile: unavailable storage just means no persistence.
    await profile.load();

    background = StarfieldBackground();
    layer = GameLayer();
    hud = Hud();
    waves = WaveManager();
    joystick = GameJoystick(
      knob: CircleComponent(
        radius: 24,
        paint: Paint()..color = const Color(0x99FFFFFF),
      ),
      background: CircleComponent(
        radius: 58,
        paint: Paint()..color = const Color(0x26FFFFFF),
      ),
      margin: const EdgeInsets.only(left: 34, bottom: 46),
    );
    fireButton = FireButton();

    await addAll(<Component>[background, layer, hud, waves, joystick]);
    if (!GameConfig.autoFire) {
      await add(fireButton);
    }

    _applyStateToControls();
    audio.startMusic();
    overlays.add(Overlays.mainMenu);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (announcementTimer > 0) {
      announcementTimer = max(0, announcementTimer - dt);
    }
    _updateShake(dt);
  }

  // ---------------------------------------------------------------- states --

  /// Starts a brand new run from a completely clean slate.
  void startGame() {
    _resetRun();
    state = PlayState.playing;
    overlays.remove(Overlays.mainMenu);
    overlays.remove(Overlays.gameOver);
    overlays.add(Overlays.pauseButton);
    _applyStateToControls();
    audio.startMusic();
    resumeEngine();
  }

  void pauseGame() {
    if (state != PlayState.playing) {
      return;
    }
    state = PlayState.paused;
    fireButton.isPressed = false;
    overlays.remove(Overlays.pauseButton);
    overlays.add(Overlays.pauseMenu);
    audio.pauseMusic();
    pauseEngine();
  }

  void resumeGame() {
    if (state != PlayState.paused) {
      return;
    }
    state = PlayState.playing;
    overlays.remove(Overlays.pauseMenu);
    overlays.add(Overlays.pauseButton);
    audio.resumeMusic();
    resumeEngine();
  }

  /// Called by [Player] when the ship is destroyed.
  void gameOver() {
    if (state != PlayState.playing) {
      return;
    }
    state = PlayState.gameOver;
    lastRunCoins = profile.recordRun(
      score: scores.score,
      wave: waves.wave,
      kills: scores.enemiesDestroyed,
    );
    player = null;
    overlays.remove(Overlays.pauseButton);
    overlays.add(Overlays.gameOver);
    audio.play(AudioManager.gameOver);
    _applyStateToControls();
  }

  /// Abandons the current run and goes back to the title screen.
  void returnToMenu() {
    state = PlayState.menu;
    player = null;
    layer.removeWhere((_) => true);
    layer.shakeOffset.setZero();
    _shakeTime = 0;
    overlays.removeAll(<String>[
      Overlays.pauseMenu,
      Overlays.gameOver,
      Overlays.pauseButton,
    ]);
    overlays.add(Overlays.mainMenu);
    _applyStateToControls();
    audio.resumeMusic();
    resumeEngine();
  }

  /// Wipes the battlefield and rebuilds the player + wave state.
  void _resetRun() {
    layer.removeWhere((_) => true);
    layer.shakeOffset.setZero();
    _shakeTime = 0;
    _shakeStrength = 0;
    announcementTimer = 0;
    scores.reset();
    waves.reset();

    final skin = profile.equipped;
    player = Player(
      position: Vector2(size.x / 2, size.y - GameConfig.playerBottomMargin),
      // Falls back to the starter hull's art when a skin's PNG is missing, and
      // to a code-drawn shape when even that is absent.
      sprite: sprites[skin.asset] ?? sprites[SpriteLibrary.player],
      skin: skin,
    );
    layer.add(player!);
  }

  /// Controls are only live (and only drawn) while a run is in progress.
  void _applyStateToControls() {
    final inRun = state == PlayState.playing || state == PlayState.paused;
    joystick.visible = inRun;
    fireButton.visible = inRun && !GameConfig.autoFire;
    if (!inRun) {
      fireButton.isPressed = false;
    }
  }

  // ------------------------------------------------------------- gameplay --

  void addScore(int points) => scores.addKill(points);

  /// Rolls for a power-up drop at [at]. Biased towards health when the player
  /// is low, so comebacks are possible.
  void maybeDropPowerup(Vector2 at) {
    if (rng.nextDouble() > GameConfig.powerupDropChance) {
      return;
    }
    final double hpRatio = player?.hpRatio ?? 1;
    final hurt = hpRatio < 0.5;
    // Health is weighted up when the player is low so comebacks are possible;
    // overdrive is the rare one.
    final roll = rng.nextDouble();
    final PowerupType type;
    if (roll < (hurt ? 0.60 : 0.36)) {
      type = PowerupType.health;
    } else if (roll < (hurt ? 0.85 : 0.74)) {
      type = PowerupType.rapidFire;
    } else {
      type = PowerupType.overdrive;
    }

    layer.add(
      Powerup(
        type: type,
        position: at.clone(),
        sprite: sprites[type.asset],
      ),
    );
  }

  /// Shows a short centred message (e.g. "RAPID FIRE").
  void announce(String text, {double duration = 1.1}) {
    announcementText = text;
    announcementTimer = duration;
  }

  // ---------------------------------------------------------- screen shake --

  /// Kicks off a screen shake. A stronger shake always wins over a weaker one
  /// that is still running, so a tank explosion is never damped by a stray
  /// bullet impact.
  void shake(double strength, {double duration = GameConfig.shakeDuration}) {
    if (_shakeTime > 0 && strength < _shakeStrength) {
      _shakeTime = max(_shakeTime, duration * 0.5);
      return;
    }
    _shakeStrength = strength;
    _shakeDuration = duration;
    _shakeTime = duration;
  }

  void _updateShake(double dt) {
    if (_shakeTime <= 0) {
      return;
    }
    _shakeTime -= dt;
    if (_shakeTime <= 0) {
      layer.shakeOffset.setZero();
      return;
    }
    // Quadratic falloff: a hard initial jolt that settles quickly.
    final t = _shakeTime / _shakeDuration;
    final amplitude = _shakeStrength * t * t;
    layer.shakeOffset.setValues(
      (rng.nextDouble() * 2 - 1) * amplitude,
      (rng.nextDouble() * 2 - 1) * amplitude,
    );
  }
}
