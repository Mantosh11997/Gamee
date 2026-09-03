import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// Code-drawn particle effects. Everything here is built from Flame's
/// [Particle] primitives - no images, no external effect library.
class Effects {
  const Effects._();

  static final Random _rng = Random();

  /// Debris burst + expanding shockwave ring used when an enemy dies.
  static ParticleSystemComponent explosion(
    Vector2 position, {
    Color color = const Color(0xFFFF9A3C),
    int count = 22,
    double speed = 170,
    double lifespan = 0.55,
    double radius = 3,
  }) {
    return ParticleSystemComponent(
      position: position.clone(),
      priority: 30,
      particle: Particle.generate(
        count: count + 1,
        lifespan: lifespan,
        generator: (int i) {
          // The very first particle is the shockwave ring, the rest is debris.
          if (i == 0) {
            return _ring(color, radius * 10);
          }
          final angle = _rng.nextDouble() * pi * 2;
          final magnitude = speed * (0.35 + _rng.nextDouble() * 0.65);
          return AcceleratedParticle(
            speed: Vector2(cos(angle), sin(angle)) * magnitude,
            acceleration: Vector2(0, 90),
            child: _fadingDot(
              // Mix a little white in so the core of the blast reads hot.
              Color.lerp(color, const Color(0xFFFFFFFF), _rng.nextDouble() * 0.6)!,
              radius * (0.5 + _rng.nextDouble()),
              lifespan,
            ),
          );
        },
      ),
    );
  }

  /// Small spark spray - used for bullet impacts and player hits.
  static ParticleSystemComponent sparks(
    Vector2 position, {
    Color color = const Color(0xFFFFFFFF),
    int count = 8,
    double speed = 110,
    double lifespan = 0.3,
  }) {
    return ParticleSystemComponent(
      position: position.clone(),
      priority: 30,
      particle: Particle.generate(
        count: count,
        lifespan: lifespan,
        generator: (int i) {
          final angle = _rng.nextDouble() * pi * 2;
          return AcceleratedParticle(
            speed: Vector2(cos(angle), sin(angle)) * (speed * _rng.nextDouble()),
            child: _fadingDot(color, 1.6 + _rng.nextDouble(), lifespan),
          );
        },
      ),
    );
  }

  /// A single puff of engine exhaust, emitted continuously behind the ship.
  static ParticleSystemComponent thruster(Vector2 position) {
    const lifespan = 0.34;
    return ParticleSystemComponent(
      position: position.clone(),
      priority: 5,
      particle: Particle.generate(
        count: 2,
        lifespan: lifespan,
        generator: (int i) => AcceleratedParticle(
          speed: Vector2((_rng.nextDouble() - 0.5) * 26, 60 + _rng.nextDouble() * 50),
          acceleration: Vector2(0, 120),
          child: _fadingDot(
            Color.lerp(
              const Color(0xFF7DF9FF),
              const Color(0xFF2A6BFF),
              _rng.nextDouble(),
            )!,
            2 + _rng.nextDouble() * 2,
            lifespan,
          ),
        ),
      ),
    );
  }

  /// Sparkle trail left behind by a collected power-up.
  static ParticleSystemComponent pickup(Vector2 position, Color color) {
    const lifespan = 0.5;
    return ParticleSystemComponent(
      position: position.clone(),
      priority: 30,
      particle: Particle.generate(
        count: 14,
        lifespan: lifespan,
        generator: (int i) {
          final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * pi;
          return AcceleratedParticle(
            speed: Vector2(cos(angle), sin(angle)) * (70 + _rng.nextDouble() * 90),
            acceleration: Vector2(0, 60),
            child: _fadingDot(color, 2 + _rng.nextDouble() * 2, lifespan),
          );
        },
      ),
    );
  }

  /// A dot that shrinks and fades out over its lifetime.
  static Particle _fadingDot(Color color, double radius, double lifespan) {
    final paint = Paint();
    return ComputedParticle(
      lifespan: lifespan,
      renderer: (canvas, particle) {
        final t = particle.progress;
        paint.color = color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
        canvas.drawCircle(Offset.zero, radius * (1 - t * 0.55), paint);
      },
    );
  }

  /// An expanding, fading stroked circle: the explosion's shockwave.
  static Particle _ring(Color color, double maxRadius) {
    final paint = Paint()..style = PaintingStyle.stroke;
    return ComputedParticle(
      renderer: (canvas, particle) {
        final t = particle.progress;
        paint
          ..color = color.withValues(alpha: (1 - t) * 0.8)
          ..strokeWidth = 3 * (1 - t) + 0.5;
        canvas.drawCircle(Offset.zero, maxRadius * t, paint);
      },
    );
  }
}
