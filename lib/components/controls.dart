import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';

/// The on-screen joystick, with a [visible] switch so it can be hidden while a
/// menu overlay is up without unmounting (and re-mounting) the component.
///
/// While hidden it also reports a zero delta, so nothing can nudge the ship.
class GameJoystick extends JoystickComponent {
  GameJoystick({
    required PositionComponent knob,
    required PositionComponent background,
    super.margin,
    int priority = 200,
  }) : super(knob: knob, background: background, priority: priority);

  bool visible = true;

  @override
  Vector2 get relativeDelta => visible ? super.relativeDelta : Vector2.zero();

  @override
  void renderTree(Canvas canvas) {
    if (visible) {
      super.renderTree(canvas);
    }
  }
}

/// Bottom-right hold-to-shoot button.
///
/// Only added to the game when [GameConfig.autoFire] is false; the player reads
/// [isPressed] every tick and uses the same cooldown as auto-fire, so the two
/// input modes share one firing-rate variable.
class FireButton extends PositionComponent with TapCallbacks {
  FireButton()
    : super(size: Vector2.all(104), anchor: Anchor.center, priority: 200);

  /// True for as long as a finger is held on the button.
  bool isPressed = false;
  bool visible = true;

  final Paint _fill = Paint();
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  final TextPaint _label = TextPaint(
    style: TextStyle(
      fontFamily: GameConfig.fontFamily,
      color: const Color(0xCCFFFFFF),
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    ),
  );

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Anchored to the bottom-right corner, mirroring the joystick.
    position = Vector2(size.x - 82, size.y - 104);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    // Circular hit area rather than the square bounding box.
    final radius = size.x / 2;
    return (point - size / 2).length <= radius;
  }

  @override
  void onTapDown(TapDownEvent event) => isPressed = visible;

  @override
  void onTapUp(TapUpEvent event) => isPressed = false;

  @override
  void onTapCancel(TapCancelEvent event) => isPressed = false;

  @override
  void renderTree(Canvas canvas) {
    if (visible) {
      super.renderTree(canvas);
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;

    _fill.color = isPressed
        ? GameConfig.playerGlow.withValues(alpha: 0.42)
        : const Color(0x33FFFFFF);
    canvas.drawCircle(center, radius, _fill);

    _ring.color = const Color(0x88FFFFFF);
    canvas.drawCircle(center, radius - 1, _ring);

    _label.render(canvas, 'FIRE', Vector2(center.dx, center.dy), anchor: Anchor.center);
  }
}
