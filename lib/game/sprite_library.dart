import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads the PNG sprites once at boot and hands them out by name.
///
/// Every lookup is nullable on purpose: if a PNG is missing from
/// `assets/images/` the entry stays `null` and the component that asked for it
/// draws a code-drawn placeholder shape instead, so the game always runs - with
/// no art at all, or with only some of the eight sprites in place.
class SpriteLibrary {
  static const String player = 'player.png';
  static const String playerMk2 = 'player_mk2.png';
  static const String playerMk3 = 'player_mk3.png';
  static const String playerMk4 = 'player_mk4.png';
  static const String playerMk5 = 'player_mk5.png';
  static const String playerMk6 = 'player_mk6.png';
  static const String playerMk7 = 'player_mk7.png';
  static const String playerTitan = 'player_titan.png';
  static const String enemyBasic = 'enemy_basic.png';
  static const String enemyFast = 'enemy_fast.png';
  static const String enemyTank = 'enemy_tank.png';
  static const String enemyHeavy = 'enemy_heavy.png';
  static const String enemyAssault = 'enemy_assault.png';
  static const String enemyBasicElite = 'enemy_basic_elite.png';
  static const String enemyFastElite = 'enemy_fast_elite.png';
  static const String enemyTankElite = 'enemy_tank_elite.png';
  static const String enemyBomber = 'enemy_bomber.png';
  static const String enemyDrone = 'enemy_drone.png';
  static const String enemyBoss = 'enemy_boss.png';
  static const String bulletPlayer = 'bullet_player.png';
  static const String bulletPlayerHeavy = 'bullet_player_heavy.png';
  static const String bulletPlayerUltra = 'bullet_player_ultra.png';
  static const String bulletPlayerLaser = 'bullet_player_laser.png';

  // Ordnance: the slow, heavy, splash-damage weapons.
  static const String missilePlayer = 'missile_player.png';
  static const String missilePlayerHeavy = 'missile_player_heavy.png';
  static const String missilePlayerCluster = 'missile_player_cluster.png';
  static const String bombPlayer = 'bomb_player.png';
  static const String bombPlayerNuclear = 'bomb_player_nuclear.png';

  // Impact effects, drawn as scaling sprites rather than particles.
  static const String attackAtomic = 'attack_atomic.png';
  static const String explosionAtomic = 'explosion_atomic.png';
  static const String attackNova = 'attack_nova.png';
  static const String attackBeam = 'attack_beam.png';
  static const String bulletEnemy = 'bullet_enemy.png';
  static const String bulletEnemyHeavy = 'bullet_enemy_heavy.png';
  static const String powerupHealth = 'powerup_health.png';
  static const String powerupRapidFire = 'powerup_rapidfire.png';
  static const String powerupEvolution = 'powerup_evolution.png';

  static const List<String> all = <String>[
    player,
    playerMk2,
    playerMk3,
    playerMk4,
    playerMk5,
    playerMk6,
    playerMk7,
    playerTitan,
    enemyBasic,
    enemyFast,
    enemyTank,
    enemyHeavy,
    enemyAssault,
    enemyBasicElite,
    enemyFastElite,
    enemyTankElite,
    enemyBomber,
    enemyDrone,
    enemyBoss,
    bulletPlayer,
    bulletPlayerHeavy,
    bulletPlayerUltra,
    bulletPlayerLaser,
    missilePlayer,
    missilePlayerHeavy,
    missilePlayerCluster,
    bombPlayer,
    bombPlayerNuclear,
    attackAtomic,
    explosionAtomic,
    attackNova,
    attackBeam,
    bulletEnemy,
    bulletEnemyHeavy,
    powerupHealth,
    powerupRapidFire,
    powerupEvolution,
  ];

  final Map<String, Sprite?> _sprites = <String, Sprite?>{};

  /// Names of the assets that were not found, in load order.
  final List<String> missing = <String>[];

  /// Loads whatever art is actually bundled.
  ///
  /// The asset manifest is consulted first rather than simply catching a failed
  /// `Images.load`: that call caches its future internally, so a miss would
  /// leave an unhandled async error behind even when we swallow it here.
  Future<void> loadAll(Images images) async {
    final bundled = await _bundledAssetPaths(images.bundle);

    for (final name in all) {
      final path = '${images.prefix}$name';
      if (!bundled.contains(path)) {
        _markMissing(name);
        continue;
      }
      try {
        _sprites[name] = Sprite(await images.load(name));
      } catch (_) {
        // Present in the manifest but unreadable (corrupt / not an image).
        _markMissing(name);
      }
    }

    if (missing.isNotEmpty && kDebugMode) {
      debugPrint(
        '[SpriteLibrary] No PNG for: ${missing.join(', ')} - drawing '
        'placeholder shapes for those. Drop the files in assets/images/ to '
        'use real art.',
      );
    }
  }

  void _markMissing(String name) {
    _sprites[name] = null;
    missing.add(name);
  }

  Future<Set<String>> _bundledAssetPaths(AssetBundle bundle) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      return manifest.listAssets().toSet();
    } catch (_) {
      // No manifest at all - treat every sprite as missing.
      return const <String>{};
    }
  }

  /// The sprite for [name], or null when the PNG was not bundled.
  Sprite? operator [](String name) => _sprites[name];
}
