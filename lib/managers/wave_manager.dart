import 'dart:math';

import 'package:flame/components.dart';

import '../components/enemy.dart';
import '../game/config.dart';
import '../game/space_shooter_game.dart';

/// Drives spawning and difficulty.
///
/// A wave is a fixed number of enemies. Once they have all been spawned *and*
/// cleared, a short breather runs and the next wave starts - bigger, faster and
/// with a nastier mix. Everything scales off [GameConfig], so the whole ramp is
/// re-tunable from one file.
class WaveManager extends Component with HasGameReference<SpaceShooterGame> {
  WaveManager() : super(priority: -50);

  final Random _rng = Random();

  /// 1-based wave number; 0 before the first wave starts.
  int wave = 0;

  /// Seconds of "WAVE n" banner left. Read by the HUD.
  double bannerTimer = 0;

  int _remainingToSpawn = 0;
  double _spawnTimer = 0;
  double _interWaveTimer = 0;

  /// Small delay after the last spawn before we start checking whether the
  /// wave is cleared, so a just-added enemy is definitely in the tree.
  double _clearCheckDelay = 0;

  /// Seconds between spawns for the current wave.
  double get spawnInterval => max(
    GameConfig.minSpawnInterval,
    GameConfig.baseSpawnInterval -
        (wave - 1) * GameConfig.spawnIntervalDecayPerWave,
  );

  /// Speed scaling handed to every enemy spawned this wave.
  double get speedMultiplier => min(
    GameConfig.maxEnemySpeedMultiplier,
    1 + (wave - 1) * GameConfig.enemySpeedRampPerWave,
  );

  /// Back to wave 1. Called on every fresh run.
  void reset() {
    wave = 0;
    bannerTimer = 0;
    _interWaveTimer = 0;
    _remainingToSpawn = 0;
    _clearCheckDelay = 0;
    _startNextWave();
  }

  void _startNextWave() {
    wave++;
    _remainingToSpawn =
        GameConfig.baseEnemiesPerWave +
        (wave - 1) * GameConfig.enemiesAddedPerWave;
    // Give the player a beat to read the banner before the first ship arrives.
    _spawnTimer = 0.9;
    _clearCheckDelay = 0;
    bannerTimer = GameConfig.waveBannerDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.state != PlayState.playing) {
      return;
    }

    if (bannerTimer > 0) {
      bannerTimer = max(0, bannerTimer - dt);
    }

    // Breather between waves.
    if (_interWaveTimer > 0) {
      _interWaveTimer -= dt;
      if (_interWaveTimer <= 0) {
        _startNextWave();
      }
      return;
    }

    // Still pumping out this wave's ships.
    if (_remainingToSpawn > 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnEnemy();
        _remainingToSpawn--;
        _spawnTimer = spawnInterval;
        if (_remainingToSpawn == 0) {
          _clearCheckDelay = 0.5;
        }
      }
      return;
    }

    // Wave fully spawned - wait until the screen is clear.
    if (_clearCheckDelay > 0) {
      _clearCheckDelay -= dt;
      return;
    }
    if (!game.hasLiveEnemies) {
      _interWaveTimer = GameConfig.interWavePause;
    }
  }

  void _spawnEnemy() {
    final type = _pickType();
    final spec = EnemySpec.specs[type]!;
    final half = spec.width / 2;
    final usable = max(1.0, game.size.x - (half + 8) * 2);
    final x = half + 8 + _rng.nextDouble() * usable;

    game.layer.add(
      Enemy(
        type: type,
        position: Vector2(x, -spec.height),
        sprite: game.sprites[spec.asset],
        speedMultiplier: speedMultiplier,
        canShoot: wave >= GameConfig.firstShootingWave,
      ),
    );
  }

  /// Weighted pick. Wave 1 is all `basic` ships; `fast` joins at wave 2 and
  /// `tank` at [GameConfig.firstTankWave], both growing more common after that
  /// while plain enemies thin out.
  EnemyType _pickType() {
    final weights = <EnemyType, double>{
      EnemyType.basic: max(3.0, 10 - (wave - 1) * 0.45),
      EnemyType.fast: wave >= 2 ? min(9.0, 3.5 + (wave - 2) * 1.1) : 0,
      EnemyType.tank: wave >= GameConfig.firstTankWave
          ? min(5.0, 1.2 + (wave - GameConfig.firstTankWave) * 0.55)
          : 0,
    };

    final total = weights.values.fold<double>(0, (sum, w) => sum + w);
    var roll = _rng.nextDouble() * total;
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll <= 0) {
        return entry.key;
      }
    }
    return EnemyType.basic;
  }
}
