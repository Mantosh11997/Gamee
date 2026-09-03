import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/sprite_library.dart';
import 'art_component.dart';
import 'bullet.dart';
import 'effects.dart';
import 'enemy.dart';
import 'powerup.dart';

/// The player ship.
///
/// Owns movement (joystick driven, clamped to the screen), the firing cadence,
/// HP with a short invulnerability + blink window after being hit, a code-drawn
/// glow and a continuous particle thruster trail.
class Player extends ArtComponent {
  Player({required super.position, required super.sprite})
    : super(
        size: Vector2(GameConfig.playerWidth, GameConfig.playerHeight),
        anchor: Anchor.center,
        priority: 20,
      );

  double hp = GameConfig.playerMaxHp;

  /// Seconds left on the rapid-fire buff (0 = inactive). Read by the HUD.
  double rapidFireRemaining = 0;

  double _fireCooldown = 0;
  double _invulnerability = 0;
  double _blinkTimer = 0;
  bool _spriteVisible = true;
  double _thrusterTimer = 0;
  double _age = 0;

  final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  final Paint _shapePaint = Paint();

  /// Current seconds between shots - the single knob that rapid-fire flips.
  double get fireInterval => rapidFireRemaining > 0
      ? GameConfig.rapidFireInterval
      : GameConfig.playerFireInterval;

  bool get isInvulnerable => _invulnerability > 0;

  double get hpRatio => (hp / GameConfig.playerMaxHp).clamp(0.0, 1.0);

  @override
  Future<void> onLoad() async {
    // Slightly forgiving hitbox: smaller than the sprite so near misses read
    // as misses.
    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.55, size.y * 0.62),
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;

    _move(dt);
    _updateTimers(dt);
    _updateFiring(dt);
    _updateThruster(dt);
  }

  void _move(double dt) {
    final delta = game.joystick.relativeDelta;
    if (!delta.isZero()) {
      position.addScaled(delta, GameConfig.playerSpeed * dt);
    }
    // Keep the ship fully on screen.
    final halfWidth = size.x / 2;
    final halfHeight = size.y / 2;
    position
      ..x = position.x.clamp(halfWidth, max(halfWidth, game.size.x - halfWidth))
      ..y = position.y.clamp(halfHeight, max(halfHeight, game.size.y - halfHeight));
  }

  void _updateTimers(double dt) {
    if (_invulnerability > 0) {
      _invulnerability -= dt;
      _blinkTimer -= dt;
      if (_blinkTimer <= 0) {
        _blinkTimer = GameConfig.playerBlinkPeriod;
        _spriteVisible = !_spriteVisible;
      }
      if (_invulnerability <= 0) {
        _spriteVisible = true;
      }
    }
    if (rapidFireRemaining > 0) {
      rapidFireRemaining = max(0, rapidFireRemaining - dt);
    }
  }

  void _updateFiring(double dt) {
    _fireCooldown -= dt;
    // Either the ship shoots on its own, or the bottom-right button is held.
    final wantsToFire = GameConfig.autoFire || game.fireButton.isPressed;
    if (wantsToFire && _fireCooldown <= 0) {
      _fire();
      _fireCooldown = fireInterval;
    }
  }

  void _fire() {
    final muzzle = Vector2(position.x, position.y - size.y / 2);
    game.layer.add(
      PlayerBullet(
        position: muzzle,
        sprite: game.sprites[SpriteLibrary.bulletPlayer],
      ),
    );
  }

  void _updateThruster(double dt) {
    _thrusterTimer -= dt;
    if (_thrusterTimer > 0) {
      return;
    }
    _thrusterTimer = GameConfig.thrusterInterval;
    game.layer.add(
      Effects.thruster(Vector2(position.x, position.y + size.y * 0.42)),
    );
  }

  /// Applies [amount] damage unless the ship is still in its post-hit grace
  /// period. Triggers game over at 0 HP.
  void takeDamage(double amount) {
    if (isInvulnerable || !isMounted) {
      return;
    }
    hp = max(0, hp - amount);
    _invulnerability = GameConfig.playerInvulnerability;
    _blinkTimer = GameConfig.playerBlinkPeriod;
    _spriteVisible = false;
    game.shake(GameConfig.shakeOnPlayerHit);
    game.layer.add(
      Effects.sparks(absoluteCenter, color: const Color(0xFFFF6B6B), count: 10),
    );
    if (hp <= 0) {
      _die();
    }
  }

  void heal(double amount) {
    hp = min(GameConfig.playerMaxHp, hp + amount);
  }

  void grantRapidFire(double seconds) {
    rapidFireRemaining = max(rapidFireRemaining, 0) + seconds;
  }

  void _die() {
    game.layer.add(
      Effects.explosion(
        absoluteCenter,
        color: GameConfig.playerGlow,
        count: 40,
        speed: 240,
        lifespan: 0.8,
        radius: 4,
      ),
    );
    game.shake(GameConfig.shakeOnPlayerDeath, duration: 0.55);
    removeFromParent();
    game.gameOver();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Powerup) {
      other.collect(this);
      return;
    }
    if (other is Enemy && !other.isDying) {
      // Ramming hurts both sides.
      final damage = GameConfig.playerRamDamage;
      takeDamage(_contactDamageFor(other));
      other.takeDamage(damage);
    }
  }

  double _contactDamageFor(Enemy enemy) {
    switch (enemy.type) {
      case EnemyType.basic:
        return 16;
      case EnemyType.fast:
        return 12;
      case EnemyType.tank:
        return 28;
    }
  }

  @override
  void render(Canvas canvas) {
    // Blinking during the post-hit grace period simply skips whole frames.
    if (!_spriteVisible) {
      return;
    }
    super.render(canvas);
  }

  @override
  void renderUnder(Canvas canvas) => _renderGlow(canvas);

  /// Soft blurred halo behind the ship. It breathes slightly and flares while
  /// rapid-fire is active.
  void _renderGlow(Canvas canvas) {
    final pulse = 0.85 + 0.15 * sin(_age * 4);
    final color = rapidFireRemaining > 0
        ? GameConfig.rapidFireColor
        : GameConfig.playerGlow;
    _glowPaint.color = color.withValues(alpha: 0.38 * pulse);
    canvas.drawCircle(
      Offset(size.x / 2, size.y * 0.55),
      size.x * 0.46 * pulse,
      _glowPaint,
    );
  }

  /// Code-drawn stand-in used when `player.png` is missing.
  @override
  void renderFallback(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    _shapePaint.color = const Color(0xFFDDF6FF);
    final hull = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.86, h * 0.72)
      ..lineTo(w * 0.62, h * 0.66)
      ..lineTo(w * 0.5, h * 0.9)
      ..lineTo(w * 0.38, h * 0.66)
      ..lineTo(w * 0.14, h * 0.72)
      ..close();
    canvas.drawPath(hull, _shapePaint);

    _shapePaint.color = GameConfig.playerGlow;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.42),
        width: w * 0.26,
        height: h * 0.3,
      ),
      _shapePaint,
    );
  }
}
