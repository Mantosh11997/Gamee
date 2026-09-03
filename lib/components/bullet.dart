import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import 'art_component.dart';
import 'effects.dart';
import 'enemy.dart';
import 'player.dart';

/// Shared behaviour for every projectile: travel straight along Y, glow, and
/// despawn as soon as it leaves the screen.
///
/// Bullets are [SpriteComponent]s. When the PNG is missing the `render`
/// override falls back to a code-drawn capsule, so combat still reads clearly
/// with no art in the project.
abstract class Bullet extends ArtComponent {
  Bullet({
    required super.position,
    required super.sprite,
    required super.size,
    required this.velocityY,
    required this.damage,
    required this.glowColor,
  }) : super(anchor: Anchor.center, priority: 15);

  /// Signed vertical speed in px/s. Negative travels up the screen.
  final double velocityY;
  final double damage;
  final Color glowColor;

  final Paint _glowPaint = Paint();
  final Paint _corePaint = Paint();

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(size: size * 0.85, position: size / 2, anchor: Anchor.center));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += velocityY * dt;

    // Cull once fully off either edge.
    final margin = size.y;
    if (position.y < -margin || position.y > game.size.y + margin) {
      removeFromParent();
    }
  }

  @override
  void renderUnder(Canvas canvas) => _renderGlow(canvas);

  /// Cheap fake bloom: a few stacked translucent capsules. Much less expensive
  /// on mobile than a real `MaskFilter.blur` on every bullet.
  void _renderGlow(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    for (var i = 3; i >= 1; i--) {
      _glowPaint.color = glowColor.withValues(alpha: 0.10 * i);
      final grow = i * 2.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: size.x + grow * 2,
            height: size.y + grow,
          ),
          Radius.circular(size.x),
        ),
        _glowPaint,
      );
    }
  }

  @override
  void renderFallback(Canvas canvas) {
    _corePaint.color = glowColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size(size.x, size.y),
        Radius.circular(size.x / 2),
      ),
      _corePaint,
    );
    _corePaint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y / 2),
          width: size.x * 0.4,
          height: size.y * 0.7,
        ),
        Radius.circular(size.x / 2),
      ),
      _corePaint,
    );
  }
}

/// Fired by the player, travels up, damages enemies.
class PlayerBullet extends Bullet {
  PlayerBullet({required super.position, required super.sprite})
    : super(
        size: Vector2(GameConfig.playerBulletWidth, GameConfig.playerBulletHeight),
        velocityY: -GameConfig.playerBulletSpeed,
        damage: GameConfig.playerBulletDamage,
        glowColor: GameConfig.playerBulletColor,
      );

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    // `isRemoving` guards against one bullet damaging two enemies in the same
    // tick when hitboxes overlap.
    if (isRemoving || other is! Enemy || other.isDying) {
      return;
    }
    other.takeDamage(damage);
    game.layer.add(
      Effects.sparks(absoluteCenter, color: GameConfig.playerBulletColor, count: 6),
    );
    removeFromParent();
  }
}

/// Fired by enemies, travels down, damages the player.
class EnemyBullet extends Bullet {
  EnemyBullet({required super.position, required super.sprite})
    : super(
        size: Vector2(GameConfig.enemyBulletWidth, GameConfig.enemyBulletHeight),
        velocityY: GameConfig.enemyBulletSpeed,
        damage: GameConfig.enemyBulletDamage,
        glowColor: GameConfig.enemyBulletColor,
      );

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (isRemoving || other is! Player) {
      return;
    }
    other.takeDamage(damage);
    removeFromParent();
  }
}
