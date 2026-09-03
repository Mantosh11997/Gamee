import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/sprite_library.dart';
import 'art_component.dart';
import 'effects.dart';
import 'player.dart';

/// The kinds of pickup a destroyed enemy can leave behind.
enum PowerupType {
  /// Restores [GameConfig.healthRestore] HP immediately.
  health,

  /// Temporarily shortens the player's fire interval.
  rapidFire,
}

extension PowerupTypeInfo on PowerupType {
  String get asset => switch (this) {
    PowerupType.health => SpriteLibrary.powerupHealth,
    PowerupType.rapidFire => SpriteLibrary.powerupRapidFire,
  };

  Color get color => switch (this) {
    PowerupType.health => GameConfig.healthColor,
    PowerupType.rapidFire => GameConfig.rapidFireColor,
  };

  String get label => switch (this) {
    PowerupType.health => 'REPAIR',
    PowerupType.rapidFire => 'RAPID FIRE',
  };
}

/// A pickup that drifts down the screen until it is collected or leaves play.
///
/// Its hitbox is passive: the [Player]'s active hitbox is what detects the
/// overlap, and [collect] is driven from there.
class Powerup extends ArtComponent {
  Powerup({
    required this.type,
    required super.position,
    required super.sprite,
  }) : super(
         size: Vector2.all(GameConfig.powerupSize),
         anchor: Anchor.center,
         priority: 12,
       ) {
    _baseX = position.x;
  }

  final PowerupType type;

  late final double _baseX;
  double _age = 0;
  bool _collected = false;

  final Paint _glowPaint = Paint();
  final Paint _shapePaint = Paint();

  @override
  Future<void> onLoad() async {
    add(
      RectangleHitbox(
        size: size * 0.9,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y += GameConfig.powerupFallSpeed * dt;
    // Gentle horizontal wobble so drops are easy to spot.
    position.x = _baseX + sin(_age * 2.4) * 14;

    if (position.y - size.y > game.size.y) {
      removeFromParent();
    }
  }

  /// Applies the effect to [player] and removes the pickup.
  void collect(Player player) {
    if (_collected) {
      return;
    }
    _collected = true;

    switch (type) {
      case PowerupType.health:
        player.heal(GameConfig.healthRestore);
      case PowerupType.rapidFire:
        player.grantRapidFire(GameConfig.rapidFireDuration);
    }

    game.layer.add(Effects.pickup(absoluteCenter, type.color));
    game.announce(type.label);
    removeFromParent();
  }

  @override
  void renderUnder(Canvas canvas) {
    final pulse = 0.85 + 0.15 * sin(_age * 6);
    _glowPaint.color = type.color.withValues(alpha: 0.28 * pulse);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x * 0.75 * pulse,
      _glowPaint,
    );
  }

  /// Code-drawn stand-in: a rounded capsule badge with a cross (health) or a
  /// chevron stack (rapid fire).
  @override
  void renderFallback(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    _shapePaint.color = type.color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size(w, h),
        Radius.circular(w * 0.28),
      ),
      _shapePaint,
    );

    _shapePaint.color = const Color(0xFF0B0D1A);
    switch (type) {
      case PowerupType.health:
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: w * 0.5,
            height: h * 0.16,
          ),
          _shapePaint,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: w * 0.16,
            height: h * 0.5,
          ),
          _shapePaint,
        );
      case PowerupType.rapidFire:
        for (var i = 0; i < 2; i++) {
          final top = h * (0.24 + i * 0.3);
          final chevron = Path()
            ..moveTo(w * 0.28, top + h * 0.16)
            ..lineTo(w * 0.5, top)
            ..lineTo(w * 0.72, top + h * 0.16)
            ..lineTo(w * 0.62, top + h * 0.16)
            ..lineTo(w * 0.5, top + h * 0.08)
            ..lineTo(w * 0.38, top + h * 0.16)
            ..close();
          canvas.drawPath(chevron, _shapePaint);
        }
    }
  }
}
