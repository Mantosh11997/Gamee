import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/audio.dart';
import '../game/config.dart';
import '../game/sprite_library.dart';
import 'art_component.dart';
import 'bullet.dart';
import 'effects.dart';

/// The three enemy archetypes.
enum EnemyType {
  basic,
  fast,
  tank,
  heavy,
  assault,
  basicElite,
  fastElite,
  tankElite,
  bomber,
  drone,
  boss,
}

/// The code-drawn silhouette an enemy falls back to when its PNG is missing.
///
/// Several archetypes share a body plan - an elite raider is a raider with
/// better guns - so shapes are a small closed set rather than one per type.
enum EnemyShape { raider, dart, hulk, gunship, bomber, orb }

/// Immutable per-type stats. Add a new archetype by adding an enum value and
/// an entry in [EnemySpec.specs] - the spawner picks types up automatically.
class EnemySpec {
  const EnemySpec({
    required this.displayName,
    required this.description,
    required this.asset,
    required this.width,
    required this.height,
    required this.maxHp,
    required this.speed,
    required this.score,
    required this.color,
    required this.hitboxWidth,
    required this.hitboxHeight,
    required this.hitboxCenterY,
    required this.firstWave,
    required this.shape,
    this.fireInterval,
    this.bulletAsset = SpriteLibrary.bulletEnemy,
    this.bulletDamage = GameConfig.enemyBulletDamage,
    this.weaveAmplitude = 0,
    this.weaveFrequency = 0,
  });

  /// Shown in the hangar's hostile codex.
  final String displayName;

  /// One line on how this enemy behaves, for the codex.
  final String description;

  /// PNG file name inside `assets/images/`.
  final String asset;
  final double width;
  final double height;

  final double maxHp;

  /// Base downward speed in px/s, before the per-wave multiplier.
  final double speed;

  /// Points awarded on kill.
  final int score;

  /// Used for the code-drawn fallback shape, the HP bar and the explosion.
  final Color color;

  /// Earliest wave this type can spawn. The wave manager gates on it and the
  /// hangar's codex reports it, so there is one source of truth.
  final int firstWave;

  /// Which placeholder body plan to draw with no art. See [EnemyShape].
  final EnemyShape shape;

  /// Seconds between shots, or null for an enemy that never shoots.
  final double? fireInterval;

  /// Projectile art and punch. The big hulls throw something heavier.
  final String bulletAsset;
  final double bulletDamage;

  /// Horizontal sine-wave weave, in pixels (0 = flies straight down).
  final double weaveAmplitude;
  final double weaveFrequency;

  /// Collision box as fractions of the sprite box - the art has wingtips and
  /// exhaust plumes that should not be solid. See `ArtComponent.hitboxFor`.
  final double hitboxWidth;
  final double hitboxHeight;
  final double hitboxCenterY;

  static const Map<EnemyType, EnemySpec> specs = <EnemyType, EnemySpec>{
    // Sizes follow each PNG's aspect ratio, printed by tool/build_assets.py.
    EnemyType.basic: EnemySpec(
      displayName: 'RAIDER',
      description: 'Flies straight down and takes pot shots from wave 2.',
      asset: SpriteLibrary.enemyBasic,
      width: 53.5,
      height: 54,
      maxHp: 24,
      speed: 78,
      score: 10,
      color: Color(0xFFFF4C3B),
      fireInterval: 2.6,
      hitboxWidth: 0.70,
      hitboxHeight: 0.62,
      hitboxCenterY: 0.62,
      firstWave: 1,
      shape: EnemyShape.raider,
    ),
    EnemyType.fast: EnemySpec(
      displayName: 'STINGER',
      description: 'Weaves across the screen at speed. Fragile, hard to lead.',
      asset: SpriteLibrary.enemyFast,
      width: 40,
      height: 64,
      maxHp: 14,
      speed: 165,
      score: 15,
      color: Color(0xFFFF3D9A),
      weaveAmplitude: 62,
      weaveFrequency: 2.2,
      hitboxWidth: 0.55,
      hitboxHeight: 0.58,
      hitboxCenterY: 0.62,
      firstWave: 2,
      shape: EnemyShape.dart,
    ),
    EnemyType.tank: EnemySpec(
      displayName: 'HULK',
      description: 'Slow armoured brick. Soaks damage and keeps firing.',
      asset: SpriteLibrary.enemyTank,
      width: 88,
      height: 94,
      maxHp: 120,
      speed: 46,
      score: 40,
      color: Color(0xFF7CE23A),
      fireInterval: 1.7,
      hitboxWidth: 0.85,
      hitboxHeight: 0.68,
      hitboxCenterY: 0.56,
      firstWave: GameConfig.firstTankWave,
      shape: EnemyShape.hulk,
    ),
    EnemyType.heavy: EnemySpec(
      displayName: 'HEAVY RAIDER',
      description: 'Up-gunned raider. More armour, and it shoots twice as often.',
      asset: SpriteLibrary.enemyHeavy,
      width: 68,
      height: 67,
      maxHp: 70,
      speed: 92,
      score: 25,
      color: Color(0xFFFF5A2B),
      fireInterval: 1.5,
      hitboxWidth: 0.78,
      hitboxHeight: 0.62,
      hitboxCenterY: 0.58,
      firstWave: GameConfig.firstHeavyWave,
      shape: EnemyShape.raider,
    ),
    EnemyType.assault: EnemySpec(
      displayName: 'ASSAULT CRUISER',
      description: 'Wide gunship that drifts sideways while it hammers you.',
      asset: SpriteLibrary.enemyAssault,
      width: 86,
      height: 88,
      maxHp: 190,
      speed: 62,
      score: 60,
      color: Color(0xFFFF3B2F),
      fireInterval: 1.1,
      weaveAmplitude: 40,
      weaveFrequency: 0.9,
      hitboxWidth: 0.80,
      hitboxHeight: 0.60,
      hitboxCenterY: 0.56,
      firstWave: GameConfig.firstAssaultWave,
      shape: EnemyShape.gunship,
    ),

    // ---- elite variants: the same body plans, up-gunned -------------------
    EnemyType.basicElite: EnemySpec(
      displayName: 'CRIMSON ACE',
      description: 'Gold-trimmed raider. Faster, tougher, and it shoots more.',
      asset: SpriteLibrary.enemyBasicElite,
      width: 60,
      height: 64,
      maxHp: 55,
      speed: 118,
      score: 30,
      color: Color(0xFFFF7A1A),
      fireInterval: 1.6,
      firstWave: 6,
      shape: EnemyShape.raider,
      hitboxWidth: 0.76,
      hitboxHeight: 0.56,
      hitboxCenterY: 0.60,
    ),
    EnemyType.fastElite: EnemySpec(
      displayName: 'VOID LANCER',
      description: 'Razor interceptor. Weaves hard and never stops moving.',
      asset: SpriteLibrary.enemyFastElite,
      width: 58,
      height: 64,
      maxHp: 34,
      speed: 205,
      score: 35,
      color: Color(0xFFFF2EA6),
      firstWave: 7,
      shape: EnemyShape.dart,
      weaveAmplitude: 84,
      weaveFrequency: 2.6,
      hitboxWidth: 0.52,
      hitboxHeight: 0.54,
      hitboxCenterY: 0.60,
    ),
    EnemyType.tankElite: EnemySpec(
      displayName: 'EMERALD BULWARK',
      description: 'Reinforced hulk behind gold plate. Very hard to shift.',
      asset: SpriteLibrary.enemyTankElite,
      width: 82,
      height: 85,
      maxHp: 260,
      speed: 52,
      score: 85,
      color: Color(0xFF57E03A),
      fireInterval: 1.4,
      firstWave: 8,
      shape: EnemyShape.hulk,
      bulletAsset: SpriteLibrary.bulletEnemyHeavy,
      bulletDamage: 15,
      hitboxWidth: 0.82,
      hitboxHeight: 0.64,
      hitboxCenterY: 0.55,
    ),

    // ---- specialists ------------------------------------------------------
    EnemyType.bomber: EnemySpec(
      displayName: 'ORDNANCE BOMBER',
      description: 'Slow bomb truck. Lobs heavy shells that really hurt.',
      asset: SpriteLibrary.enemyBomber,
      width: 76,
      height: 76,
      maxHp: 130,
      speed: 58,
      score: 55,
      color: Color(0xFFFFA51F),
      fireInterval: 2,
      firstWave: 10,
      shape: EnemyShape.bomber,
      bulletAsset: SpriteLibrary.bulletEnemyHeavy,
      bulletDamage: 20,
      hitboxWidth: 0.80,
      hitboxHeight: 0.58,
      hitboxCenterY: 0.55,
    ),
    EnemyType.drone: EnemySpec(
      displayName: 'SENTRY DRONE',
      description: 'Quad-rotor sentry. Drifts in fast and fires on sight.',
      asset: SpriteLibrary.enemyDrone,
      width: 66,
      height: 57,
      maxHp: 46,
      speed: 132,
      score: 30,
      color: Color(0xFFFF3B2F),
      fireInterval: 1.7,
      firstWave: 11,
      shape: EnemyShape.orb,
      weaveAmplitude: 56,
      weaveFrequency: 1.5,
      hitboxWidth: 0.74,
      hitboxHeight: 0.66,
      hitboxCenterY: 0.50,
    ),
    EnemyType.boss: EnemySpec(
      displayName: 'CRIMSON DREADNOUGHT',
      description: 'Capital-class hostile. Rare, enormous, and it shoots back.',
      asset: SpriteLibrary.enemyBoss,
      width: 128,
      height: 127,
      maxHp: 900,
      speed: 34,
      score: 400,
      color: Color(0xFFFF1F0F),
      fireInterval: 0.85,
      firstWave: 14,
      shape: EnemyShape.gunship,
      bulletAsset: SpriteLibrary.bulletEnemyHeavy,
      bulletDamage: 24,
      hitboxWidth: 0.84,
      hitboxHeight: 0.62,
      hitboxCenterY: 0.54,
    ),
  };
}

/// A single enemy ship.
///
/// Renders its PNG when available and a code-drawn silhouette when not, plus a
/// floating HP bar. Dying is a two-step process: a short white flash, then the
/// particle explosion, score award and (sometimes) a power-up drop.
class Enemy extends ArtComponent {
  Enemy({
    required this.type,
    required super.position,
    required super.sprite,
    required this.speedMultiplier,
    required this.canShoot,
  }) : spec = EnemySpec.specs[type]!,
       hp = EnemySpec.specs[type]!.maxHp,
       super(
         size: Vector2(
           EnemySpec.specs[type]!.width,
           EnemySpec.specs[type]!.height,
         ),
         anchor: Anchor.center,
         priority: 10,
       ) {
    _baseX = position.x;
    _fireTimer = (spec.fireInterval ?? 0) * (0.5 + _rng.nextDouble() * 0.8);
    _weavePhase = _rng.nextDouble() * pi * 2;
  }

  static final Random _rng = Random();

  final EnemyType type;
  final EnemySpec spec;

  /// Wave-based speed scaling handed down by the [WaveManager].
  final double speedMultiplier;

  /// Whether this enemy is allowed to fire back (off during the first waves).
  final bool canShoot;

  double hp;

  late final double _baseX;
  late double _fireTimer;
  late final double _weavePhase;
  double _age = 0;

  /// Damage flash timer (white tint right after being hit).
  double _hitFlash = 0;

  /// Death flash timer. While > 0 the enemy is fully white and untouchable.
  double _deathFlash = 0;
  bool _dying = false;

  /// True once the enemy is committed to dying - bullets must ignore it.
  bool get isDying => _dying;

  /// The big hulls get a louder death.
  bool get _isHeavy => const <EnemyType>{
    EnemyType.tank,
    EnemyType.assault,
    EnemyType.tankElite,
    EnemyType.bomber,
    EnemyType.boss,
  }.contains(type);

  final Paint _shapePaint = Paint();
  final Paint _barPaint = Paint();

  @override
  Future<void> onLoad() async {
    add(
      hitboxFor(
        widthFactor: spec.hitboxWidth,
        heightFactor: spec.hitboxHeight,
        centerY: spec.hitboxCenterY,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_dying) {
      _deathFlash -= dt;
      if (_deathFlash <= 0) {
        _explode();
      }
      return;
    }

    _age += dt;
    if (_hitFlash > 0) {
      _hitFlash -= dt;
    }

    // --- movement ---------------------------------------------------------
    position.y += spec.speed * speedMultiplier * dt;
    if (spec.weaveAmplitude > 0) {
      final half = size.x / 2;
      position.x = (_baseX +
              sin(_age * spec.weaveFrequency + _weavePhase) * spec.weaveAmplitude)
          .clamp(half, max(half, game.size.x - half));
    }

    // --- shooting ---------------------------------------------------------
    final interval = spec.fireInterval;
    if (canShoot && interval != null) {
      _fireTimer -= dt;
      if (_fireTimer <= 0) {
        _fireTimer = interval;
        _shoot();
      }
    }

    // --- despawn once past the bottom edge --------------------------------
    if (position.y - size.y > game.size.y) {
      removeFromParent();
    }
  }

  void _shoot() {
    if (position.y < 0) {
      return;
    }
    game.audio.play(AudioManager.shootEnemy, volume: 0.35);
    game.layer.add(
      EnemyBullet(
        position: Vector2(position.x, position.y + size.y * 0.4),
        sprite: game.sprites[spec.bulletAsset],
        damage: spec.bulletDamage,
        heavy: spec.bulletAsset != SpriteLibrary.bulletEnemy,
      ),
    );
  }

  /// Applies [amount] damage. Triggers the death sequence when HP runs out.
  void takeDamage(double amount) {
    if (_dying) {
      return;
    }
    hp -= amount;
    _hitFlash = 0.07;
    if (hp <= 0) {
      hp = 0;
      _startDying();
    }
  }

  /// Step one of dying: freeze, go white, stop colliding. The explosion itself
  /// happens a frame or three later in [_explode].
  void _startDying() {
    _dying = true;
    _deathFlash = 0.09;
    for (final hitbox in children.whereType<ShapeHitbox>()) {
      hitbox.collisionType = CollisionType.inactive;
    }
    game.addScore(spec.score);
  }

  void _explode() {
    final center = absoluteCenter;
    game.layer.add(
      Effects.explosion(
        center,
        color: spec.color,
        count: _isHeavy ? 34 : 20,
        speed: _isHeavy ? 220 : 165,
        radius: _isHeavy ? 4 : 3,
      ),
    );
    game.shake(
      _isHeavy
          ? GameConfig.shakeOnExplosion * 1.8
          : GameConfig.shakeOnExplosion,
    );
    game.audio.play(
      _isHeavy ? AudioManager.explosionLarge : AudioManager.explosionSmall,
      volume: _isHeavy ? 0.95 : 0.6,
    );
    game.maybeDropPowerup(center);
    removeFromParent();
  }

  /// White while flashing from a hit and during the pre-explosion death frame.
  bool get _isWhite => _dying || _hitFlash > 0;

  @override
  void render(Canvas canvas) {
    // Applied to the sprite by SpriteComponent via `paint`.
    paint.colorFilter = _isWhite
        ? const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcATop)
        : null;
    super.render(canvas);
  }

  @override
  void renderOver(Canvas canvas) {
    if (!_dying) {
      _renderHpBar(canvas);
    }
  }

  /// Code-drawn stand-in so the game is playable before any PNG is dropped in.
  /// Each type gets a distinct silhouette so they stay readable.
  @override
  void renderFallback(Canvas canvas) {
    final white = _isWhite;
    _shapePaint.color = white ? const Color(0xFFFFFFFF) : spec.color;
    final w = size.x;
    final h = size.y;
    final path = Path();
    switch (spec.shape) {
      case EnemyShape.raider:
        // Blunt, downward-pointing hull.
        path
          ..moveTo(w * 0.5, h)
          ..lineTo(w * 0.05, h * 0.35)
          ..lineTo(w * 0.28, h * 0.05)
          ..lineTo(w * 0.72, h * 0.05)
          ..lineTo(w * 0.95, h * 0.35)
          ..close();
      case EnemyShape.dart:
        // Narrow spike.
        path
          ..moveTo(w * 0.5, h)
          ..lineTo(w * 0.1, h * 0.45)
          ..lineTo(w * 0.5, 0)
          ..lineTo(w * 0.9, h * 0.45)
          ..close();
      case EnemyShape.hulk:
        // Broad, armoured hexagon.
        path
          ..moveTo(w * 0.5, h)
          ..lineTo(w * 0.02, h * 0.68)
          ..lineTo(w * 0.12, h * 0.18)
          ..lineTo(w * 0.88, h * 0.18)
          ..lineTo(w * 0.98, h * 0.68)
          ..close();
      case EnemyShape.gunship:
        // Wide hull with long swept wings either side.
        path
          ..moveTo(w * 0.5, h)
          ..lineTo(w * 0.16, h * 0.72)
          ..lineTo(w * 0.0, h * 0.22)
          ..lineTo(w * 0.26, h * 0.28)
          ..lineTo(w * 0.30, h * 0.0)
          ..lineTo(w * 0.70, h * 0.0)
          ..lineTo(w * 0.74, h * 0.28)
          ..lineTo(w * 1.0, h * 0.22)
          ..lineTo(w * 0.84, h * 0.72)
          ..close();
      case EnemyShape.bomber:
        // Fat belly, stubby wings.
        path
          ..moveTo(w * 0.5, h * 0.98)
          ..lineTo(w * 0.14, h * 0.66)
          ..lineTo(w * 0.02, h * 0.30)
          ..lineTo(w * 0.32, h * 0.36)
          ..lineTo(w * 0.36, h * 0.04)
          ..lineTo(w * 0.64, h * 0.04)
          ..lineTo(w * 0.68, h * 0.36)
          ..lineTo(w * 0.98, h * 0.30)
          ..lineTo(w * 0.86, h * 0.66)
          ..close();
      case EnemyShape.orb:
        // Core disc with four rotor pods.
        path.addOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.5),
            width: w * 0.46,
            height: h * 0.62,
          ),
        );
        for (final dx in <double>[0.16, 0.84]) {
          for (final dy in <double>[0.22, 0.78]) {
            path.addOval(
              Rect.fromCenter(
                center: Offset(w * dx, h * dy),
                width: w * 0.30,
                height: h * 0.26,
              ),
            );
          }
        }
    }
    canvas.drawPath(path, _shapePaint);

    // Cockpit highlight.
    _shapePaint.color = white
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0B0D1A).withValues(alpha: 0.7);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.42),
        width: w * 0.32,
        height: h * 0.24,
      ),
      _shapePaint,
    );
  }

  /// Small floating HP bar above the ship. Hidden while at full health for the
  /// weaker types so the screen stays clean.
  void _renderHpBar(Canvas canvas) {
    final damaged = hp < spec.maxHp;
    if (!damaged && !_isHeavy) {
      return;
    }
    const barHeight = 4.0;
    final barWidth = size.x * 0.86;
    final left = (size.x - barWidth) / 2;
    const top = -9.0;
    final ratio = (hp / spec.maxHp).clamp(0.0, 1.0);

    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, barWidth, barHeight),
      const Radius.circular(2),
    );
    _barPaint.color = const Color(0xAA000000);
    canvas.drawRRect(track, _barPaint);

    _barPaint.color = Color.lerp(
      const Color(0xFFFF3B5C),
      const Color(0xFF4BE38B),
      ratio,
    )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth * ratio, barHeight),
        const Radius.circular(2),
      ),
      _barPaint,
    );
  }
}
