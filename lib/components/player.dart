import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/audio.dart';
import '../game/config.dart';
import '../game/ship_skin.dart';
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
  Player({
    required super.position,
    required super.sprite,
    required this.skin,
  }) : hp = skin.maxHp,
       super(
         size: Vector2(skin.width, skin.height),
         anchor: Anchor.center,
         priority: 20,
       );

  /// The equipped ship. Drives size, stats, weapon layout and glow colour.
  final ShipSkin skin;

  double hp;

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

  /// Current seconds between shots. Rapid fire overrides the ship's own
  /// cadence entirely, so the buff feels the same on every hull.
  double get fireInterval => rapidFireRemaining > 0
      ? GameConfig.rapidFireInterval
      : GameConfig.playerFireInterval * skin.weapon.fireIntervalMultiplier;

  bool get isInvulnerable => _invulnerability > 0;

  double get hpRatio => (hp / skin.maxHp).clamp(0.0, 1.0);

  /// Full health for the equipped ship, read by the HUD.
  double get maxHp => skin.maxHp;

  @override
  Future<void> onLoad() async {
    // Only the fuselage collides - not the wingtips, and not the exhaust
    // plume at the bottom of the sprite.
    add(
      hitboxFor(
        widthFactor: skin.hitboxWidth,
        heightFactor: skin.hitboxHeight,
        centerY: skin.hitboxCenterY,
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
      position.addScaled(delta, skin.speed * dt);
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

  /// Fires one volley immediately, ignoring the cooldown. Test hook.
  @visibleForTesting
  void forceFire() => _fire();

  /// Emits one volley of the equipped ship's weapon: one bullet per barrel,
  /// each at its own muzzle offset and angle.
  void _fire() {
    game.audio.playShot(volume: 0.45);
    final weapon = skin.weapon;
    final bulletSprite = game.sprites[weapon.bulletAsset] ??
        game.sprites[SpriteLibrary.bulletPlayer];
    final muzzleY = position.y - size.y * 0.42;

    for (final barrel in weapon.barrels) {
      game.layer.add(
        PlayerBullet(
          position: Vector2(position.x + barrel.offset * size.x, muzzleY),
          sprite: bulletSprite,
          damage: GameConfig.playerBulletDamage * weapon.damageMultiplier,
          color: weapon.bulletColor,
          angleDegrees: barrel.angle,
        ),
      );
    }
  }

  void _updateThruster(double dt) {
    _thrusterTimer -= dt;
    if (_thrusterTimer > 0) {
      return;
    }
    _thrusterTimer = GameConfig.thrusterInterval;
    game.layer.add(
      Effects.thruster(Vector2(position.x, position.y + size.y * 0.34)),
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
    game.audio.play(AudioManager.playerHit, volume: 0.9);
    game.layer.add(
      Effects.sparks(absoluteCenter, color: const Color(0xFFFF6B6B), count: 10),
    );
    if (hp <= 0) {
      _die();
    }
  }

  void heal(double amount) {
    hp = min(skin.maxHp, hp + amount);
  }

  void grantRapidFire(double seconds) {
    rapidFireRemaining = max(rapidFireRemaining, 0) + seconds;
  }

  void _die() {
    game.layer.add(
      Effects.explosion(
        absoluteCenter,
        color: skin.accent,
        count: 40,
        speed: 240,
        lifespan: 0.8,
        radius: 4,
      ),
    );
    game.shake(GameConfig.shakeOnPlayerDeath, duration: 0.55);
    game.audio.play(AudioManager.explosionLarge);
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
        : skin.accent;
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

    _shapePaint.color = skin.accent;
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
