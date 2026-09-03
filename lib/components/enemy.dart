import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/sprite_library.dart';
import 'art_component.dart';
import 'bullet.dart';
import 'effects.dart';

/// The three enemy archetypes.
enum EnemyType { basic, fast, tank }

/// Immutable per-type stats. Add a new archetype by adding an enum value and
/// an entry in [EnemySpec.specs] - the spawner picks types up automatically.
class EnemySpec {
  const EnemySpec({
    required this.asset,
    required this.width,
    required this.height,
    required this.maxHp,
    required this.speed,
    required this.score,
    required this.color,
    this.fireInterval,
    this.weaveAmplitude = 0,
    this.weaveFrequency = 0,
  });

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

  /// Seconds between shots, or null for an enemy that never shoots.
  final double? fireInterval;

  /// Horizontal sine-wave weave, in pixels (0 = flies straight down).
  final double weaveAmplitude;
  final double weaveFrequency;

  static const Map<EnemyType, EnemySpec> specs = <EnemyType, EnemySpec>{
    EnemyType.basic: EnemySpec(
      asset: SpriteLibrary.enemyBasic,
      width: 46,
      height: 46,
      maxHp: 24,
      speed: 78,
      score: 10,
      color: Color(0xFFB65BFF),
      fireInterval: 2.6,
    ),
    EnemyType.fast: EnemySpec(
      asset: SpriteLibrary.enemyFast,
      width: 38,
      height: 38,
      maxHp: 14,
      speed: 165,
      score: 15,
      color: Color(0xFF2BE0C8),
      weaveAmplitude: 62,
      weaveFrequency: 2.2,
    ),
    EnemyType.tank: EnemySpec(
      asset: SpriteLibrary.enemyTank,
      width: 76,
      height: 76,
      maxHp: 120,
      speed: 46,
      score: 40,
      color: Color(0xFFFF6B4A),
      fireInterval: 1.7,
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

  final Paint _shapePaint = Paint();
  final Paint _barPaint = Paint();

  @override
  Future<void> onLoad() async {
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.8, size.y * 0.8),
        position: size / 2,
        anchor: Anchor.center,
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
    game.layer.add(
      EnemyBullet(
        position: Vector2(position.x, position.y + size.y / 2),
        sprite: game.sprites[SpriteLibrary.bulletEnemy],
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
        count: type == EnemyType.tank ? 34 : 20,
        speed: type == EnemyType.tank ? 220 : 165,
        radius: type == EnemyType.tank ? 4 : 3,
      ),
    );
    game.shake(
      type == EnemyType.tank
          ? GameConfig.shakeOnExplosion * 1.8
          : GameConfig.shakeOnExplosion,
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
    switch (type) {
      case EnemyType.basic:
        // Blunt, downward-pointing hull.
        path
          ..moveTo(w * 0.5, h)
          ..lineTo(w * 0.05, h * 0.35)
          ..lineTo(w * 0.28, h * 0.05)
          ..lineTo(w * 0.72, h * 0.05)
          ..lineTo(w * 0.95, h * 0.35)
          ..close();
      case EnemyType.fast:
        // Narrow dart.
        path
          ..moveTo(w * 0.5, h)
          ..lineTo(w * 0.1, h * 0.45)
          ..lineTo(w * 0.5, 0)
          ..lineTo(w * 0.9, h * 0.45)
          ..close();
      case EnemyType.tank:
        // Broad, armoured hexagon.
        path
          ..moveTo(w * 0.5, h)
          ..lineTo(w * 0.02, h * 0.68)
          ..lineTo(w * 0.12, h * 0.18)
          ..lineTo(w * 0.88, h * 0.18)
          ..lineTo(w * 0.98, h * 0.68)
          ..close();
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
    if (!damaged && type != EnemyType.tank) {
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
