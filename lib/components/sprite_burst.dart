import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/space_shooter_game.dart';

/// A one-shot sprite explosion: scales up and fades out, then removes itself.
///
/// The particle system in `Effects` covers debris and sparks; this covers the
/// big painted blasts (atomic bursts, novas) where the art *is* the effect.
/// Like everything else it survives a missing PNG - with no sprite it draws an
/// expanding ring instead.
class SpriteBurst extends PositionComponent
    with HasGameReference<SpaceShooterGame> {
  SpriteBurst({
    required Vector2 position,
    required this.radius,
    required this.sprite,
    required this.color,
    this.duration = 0.55,
    this.startScale = 0.35,
    this.endScale = 1.15,
  }) : super(position: position, anchor: Anchor.center, priority: 32);

  /// Half the blast's final on-screen width.
  final double radius;
  final Sprite? sprite;
  final Color color;
  final double duration;
  final double startScale;
  final double endScale;

  double _elapsed = 0;
  final Paint _paint = Paint();

  /// 0 at the flash, 1 when it has faded out.
  double get _progress => (_elapsed / duration).clamp(0.0, 1.0);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = _progress;
    // Ease out so the blast punches open and then lingers as it fades.
    final scale = startScale + (endScale - startScale) * (1 - (1 - t) * (1 - t));
    final extent = radius * 2 * scale;
    final opacity = (1 - t * t).clamp(0.0, 1.0);

    final currentSprite = sprite;
    if (currentSprite == null) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.18 * (1 - t) + 1
        ..color = color.withValues(alpha: opacity * 0.9);
      canvas.drawCircle(Offset.zero, extent / 2, _paint);
      return;
    }

    _paint
      ..style = PaintingStyle.fill
      ..colorFilter = null
      ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity);
    currentSprite.render(
      canvas,
      position: Vector2(-extent / 2, -extent / 2),
      size: Vector2.all(extent),
      overridePaint: _paint,
    );
  }
}
