import 'package:flutter/material.dart';

/// Every gameplay number lives here so the whole feel of the game can be
/// re-tuned from a single file. Nothing in this class is computed at runtime -
/// values that change while playing (wave scaling, buff timers) derive from
/// these constants inside the managers.
class GameConfig {
  const GameConfig._();

  // ---------------------------------------------------------------- player --

  // Sizes match the aspect ratio of the shipped PNG (241x256) so the art is
  // never squashed. `tool/build_assets.py` prints the ratio for each sprite.
  static const double playerWidth = 64;
  static const double playerHeight = 68;

  /// Hitbox as a fraction of the sprite box: the fuselage from nose to engine,
  /// not the wingtips or the exhaust plume. Deliberately forgiving.
  static const double playerHitboxWidth = 0.42;
  static const double playerHitboxHeight = 0.60;
  static const double playerHitboxCenterY = 0.44;

  /// Pixels per second when the joystick is pushed all the way out.
  static const double playerSpeed = 340;

  static const double playerMaxHp = 100;

  /// Distance from the bottom of the screen the player spawns at.
  static const double playerBottomMargin = 150;

  /// When true the ship shoots by itself and the fire button is not shown.
  /// Flip to false to get a bottom-right fire button you have to hold.
  static const bool autoFire = true;

  /// Seconds between shots. Lower = faster.
  static const double playerFireInterval = 0.26;

  /// Seconds between shots while the rapid-fire buff is active.
  static const double rapidFireInterval = 0.09;

  /// How long the rapid-fire buff lasts, in seconds.
  static const double rapidFireDuration = 7;

  /// Grace period after taking a hit: no damage, sprite blinks.
  static const double playerInvulnerability = 1.1;
  static const double playerBlinkPeriod = 0.09;

  /// Damage dealt to an enemy the player crashes into.
  static const double playerRamDamage = 40;

  /// Seconds between thruster particle emissions.
  static const double thrusterInterval = 0.045;

  // --------------------------------------------------------------- bullets --

  // Bullet sprites are long because they include a motion trail; the hitbox
  // covers only the solid head, which is at the leading end of each one.
  static const double playerBulletSpeed = 640;
  static const double playerBulletDamage = 12;
  static const double playerBulletWidth = 10;
  static const double playerBulletHeight = 56;
  static const double playerBulletHitboxCenterY = 0.24;

  static const double enemyBulletSpeed = 250;
  static const double enemyBulletDamage = 9;
  static const double enemyBulletWidth = 8;
  static const double enemyBulletHeight = 53;
  static const double enemyBulletHitboxCenterY = 0.76;

  static const double bulletHitboxWidth = 0.75;
  static const double bulletHitboxHeight = 0.42;

  // ----------------------------------------------------------------- waves --

  /// Seconds between spawns during wave 1.
  static const double baseSpawnInterval = 1.45;

  /// Each wave shortens the spawn interval by this much...
  static const double spawnIntervalDecayPerWave = 0.085;

  /// ...but never below this.
  static const double minSpawnInterval = 0.4;

  /// Enemies spawned in wave 1, plus [enemiesAddedPerWave] for every wave after.
  static const int baseEnemiesPerWave = 6;
  static const int enemiesAddedPerWave = 2;

  /// Enemy speed grows by this fraction per wave, capped by
  /// [maxEnemySpeedMultiplier], which keeps the early game gentle.
  static const double enemySpeedRampPerWave = 0.035;
  static const double maxEnemySpeedMultiplier = 1.9;

  /// Quiet beat between clearing a wave and the next one starting.
  static const double interWavePause = 1.6;

  /// How long the "WAVE n" banner stays on screen.
  static const double waveBannerDuration = 1.8;

  /// Enemies only start shooting back from this wave onwards.
  static const int firstShootingWave = 2;

  /// Tanks only join the mix from this wave onwards.
  static const int firstTankWave = 3;

  /// The up-gunned hulls arrive later still.
  static const int firstHeavyWave = 5;
  static const int firstAssaultWave = 9;

  // -------------------------------------------------------------- power-ups --

  /// Chance that a killed enemy drops something.
  static const double powerupDropChance = 0.16;
  static const double powerupFallSpeed = 95;
  static const double powerupWidth = 34;
  static const double powerupHeight = 68;
  static const double healthRestore = 30;

  // ------------------------------------------------------------------ juice --

  static const double shakeOnPlayerHit = 10;
  static const double shakeOnExplosion = 5;
  static const double shakeOnPlayerDeath = 18;
  static const double shakeDuration = 0.3;

  // ----------------------------------------------------------------- audio --

  /// Master level for one-shot effects; individual calls scale this further.
  static const double sfxVolume = 0.85;
  static const double musicVolume = 0.42;

  // ---------------------------------------------------------------- palette --

  static const Color spaceTop = Color(0xFF05060F);
  static const Color spaceBottom = Color(0xFF12082B);
  static const Color nebulaA = Color(0xFF3A1D6E);
  static const Color nebulaB = Color(0xFF0E3B5C);

  static const Color playerGlow = Color(0xFF56E1FF);
  static const Color playerBulletColor = Color(0xFF7DF9FF);
  static const Color enemyBulletColor = Color(0xFFFF7A59);

  static const Color hpGood = Color(0xFFFF3B5C);
  static const Color hpTrack = Color(0x55000000);
  static const Color hudText = Color(0xFFE9F1FF);
  static const Color rapidFireColor = Color(0xFFFFC531);
  static const Color healthColor = Color(0xFF4BE38B);
}
