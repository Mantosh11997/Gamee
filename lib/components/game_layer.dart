import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Container for every gameplay entity (player, enemies, bullets, power-ups,
/// explosions).
///
/// It exists so screen shake can be applied to the whole battlefield in one
/// place. The shake is a pure *render* translation - it never touches the
/// components' real positions, so hitboxes and collision results stay exactly
/// where the simulation put them while the picture rattles around.
class GameLayer extends PositionComponent {
  GameLayer() : super(priority: 0);

  /// Current render-only offset, driven by `SpaceShooterGame.shake()`.
  final Vector2 shakeOffset = Vector2.zero();

  @override
  void renderTree(Canvas canvas) {
    if (shakeOffset.isZero()) {
      super.renderTree(canvas);
      return;
    }
    canvas.save();
    canvas.translate(shakeOffset.x, shakeOffset.y);
    super.renderTree(canvas);
    canvas.restore();
  }
}
