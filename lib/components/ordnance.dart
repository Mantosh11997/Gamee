import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/audio.dart';
import '../game/ship_skin.dart';
import 'art_component.dart';
import 'effects.dart';
import 'enemy.dart';
import 'sprite_burst.dart';

/// A heavy player weapon: missile, bomb or atomic warhead.
///
/// Unlike a bullet it is slow, hits once, and detonates for splash damage
/// across [OrdnanceSpec.blastRadius] - so it is worth aiming at a cluster
/// rather than a single ship.
class Ordnance extends ArtComponent {
  Ordnance({
    required super.position,
    required super.sprite,
    required this.spec,
    required Sprite? burstSprite,
  }) : _burstSprite = burstSprite,
       super(
         size: Vector2(spec.width, spec.width / _aspect),
         anchor: Anchor.center,
         priority: 16,
       );

  /// Every ordnance PNG is roughly this tall relative to its width; the exact
  /// value only affects how the art is framed, not the hitbox.
  static const double _aspect = 0.47;

  final OrdnanceSpec spec;
  final Sprite? _burstSprite;

  bool _detonated = false;
  final Paint _shapePaint = Paint();

  @override
  Future<void> onLoad() async {
    add(
      hitboxFor(widthFactor: 0.6, heightFactor: 0.5, centerY: 0.34),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= spec.speed * dt;
    if (position.y < -size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_detonated || other is! Enemy || other.isDying) {
      return;
    }
    _detonate(other);
  }

  /// Direct damage to the ship hit, half damage to everything else inside the
  /// blast, then the painted burst and a heavy shake.
  void _detonate(Enemy direct) {
    _detonated = true;
    final centre = absoluteCenter;

    direct.takeDamage(spec.damage);
    for (final enemy in game.layer.children.whereType<Enemy>()) {
      if (identical(enemy, direct) || enemy.isDying) {
        continue;
      }
      if (enemy.absoluteCenter.distanceTo(centre) <= spec.blastRadius) {
        enemy.takeDamage(spec.damage * 0.5);
      }
    }

    game.layer.addAll(<Component>[
      SpriteBurst(
        position: centre,
        radius: spec.blastRadius,
        sprite: _burstSprite,
        color: spec.color,
      ),
      Effects.explosion(
        centre,
        color: spec.color,
        count: 26,
        speed: spec.blastRadius * 2.4,
        radius: 4,
      ),
    ]);
    game.shake(spec.blastRadius * 0.14, duration: 0.4);
    game.audio.play(AudioManager.explosionLarge);
    removeFromParent();
  }

  @override
  void renderFallback(Canvas canvas) {
    // A blunt warhead: body, nose cone and fins, in the ordnance's colour.
    final w = size.x;
    final h = size.y;
    _shapePaint.color = spec.color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.18, w * 0.44, h * 0.62),
        Radius.circular(w * 0.2),
      ),
      _shapePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, 0)
        ..lineTo(w * 0.72, h * 0.26)
        ..lineTo(w * 0.28, h * 0.26)
        ..close(),
      _shapePaint,
    );
    _shapePaint.color = const Color(0xFF0B0D1A);
    canvas.drawCircle(Offset(w * 0.5, h * 0.46), w * 0.12, _shapePaint);
  }
}
