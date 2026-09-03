import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/space_shooter_game.dart';

/// Base class for every gameplay entity that is drawn from a PNG.
///
/// It is a real [SpriteComponent] - the sprite is used whenever the PNG was
/// found in `assets/images/` - but it tolerates a **missing** sprite and asks
/// the subclass to draw a code-drawn stand-in instead. That is what lets the
/// whole game run before a single asset has been added.
///
/// Subclasses hook into three slots instead of overriding `render` directly:
///   [renderUnder]     glow / halo behind the art
///   [renderFallback]  the placeholder shape (only when there is no sprite)
///   [renderOver]      trim drawn on top, e.g. an enemy HP bar
abstract class ArtComponent extends SpriteComponent
    with HasGameReference<SpaceShooterGame>, CollisionCallbacks {
  ArtComponent({
    super.position,
    super.sprite,
    super.size,
    super.anchor,
    super.priority,
  });

  /// True when the PNG for this entity was not found and the placeholder shape
  /// is being drawn instead.
  bool get usesFallbackArt => sprite == null;

  /// Builds a hitbox from fractions of the sprite box.
  ///
  /// The art includes wingtips and exhaust plumes that should not be solid, so
  /// every entity states which slice of its box actually collides:
  /// [widthFactor] and [heightFactor] size the box, [centerY] slides it along
  /// the sprite (0 = top edge, 1 = bottom edge).
  RectangleHitbox hitboxFor({
    required double widthFactor,
    required double heightFactor,
    required double centerY,
    CollisionType collisionType = CollisionType.active,
  }) {
    return RectangleHitbox(
      size: Vector2(size.x * widthFactor, size.y * heightFactor),
      position: Vector2(size.x / 2, size.y * centerY),
      anchor: Anchor.center,
      collisionType: collisionType,
    );
  }

  /// Drawn before the sprite. Default: nothing.
  void renderUnder(Canvas canvas) {}

  /// The code-drawn stand-in, in local coordinates (0,0)-(size.x,size.y).
  void renderFallback(Canvas canvas);

  /// Drawn after the sprite. Default: nothing.
  void renderOver(Canvas canvas) {}

  /// [SpriteComponent.onMount] does nothing but assert that a sprite exists,
  /// which is exactly the situation this class is built to survive. Neither
  /// `Component.onMount` nor `PositionComponent` do any work of their own, so
  /// skipping the super call costs nothing.
  @override
  // ignore: must_call_super
  void onMount() {}

  @override
  void render(Canvas canvas) {
    renderUnder(canvas);
    if (sprite == null) {
      renderFallback(canvas);
    } else {
      // SpriteComponent draws the sprite scaled to `size` using `paint`, so
      // tints applied through `paint.colorFilter` come along for free.
      super.render(canvas);
    }
    renderOver(canvas);
  }
}
