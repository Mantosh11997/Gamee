import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';

/// One parallax layer of the starfield.
class _StarLayer {
  _StarLayer({
    required this.count,
    required this.minRadius,
    required this.maxRadius,
    required this.speed,
    required this.opacity,
    required this.twinkle,
  });

  final int count;
  final double minRadius;
  final double maxRadius;

  /// Downward scroll speed in px/s. Bigger = closer to the camera.
  final double speed;
  final double opacity;

  /// How strongly the star pulses (0 = steady).
  final double twinkle;

  final List<double> xs = <double>[];
  final List<double> ys = <double>[];
  final List<double> radii = <double>[];
  final List<double> phases = <double>[];

  void populate(Random rng, Vector2 view) {
    xs.clear();
    ys.clear();
    radii.clear();
    phases.clear();
    for (var i = 0; i < count; i++) {
      xs.add(rng.nextDouble() * view.x);
      ys.add(rng.nextDouble() * view.y);
      radii.add(minRadius + rng.nextDouble() * (maxRadius - minRadius));
      phases.add(rng.nextDouble() * pi * 2);
    }
  }

  /// Scrolls the layer and wraps stars around the top edge, which makes the
  /// field loop seamlessly: a star leaving the bottom re-enters at the top at
  /// a fresh horizontal position.
  void update(double dt, Random rng, Vector2 view) {
    for (var i = 0; i < ys.length; i++) {
      ys[i] += speed * dt;
      if (ys[i] - radii[i] > view.y) {
        ys[i] -= view.y + radii[i] * 2;
        xs[i] = rng.nextDouble() * view.x;
      }
    }
  }
}

/// Fully code-drawn background: a vertical space gradient, two soft nebula
/// blobs and a three-layer parallax starfield. No image assets involved.
///
/// It is added straight to the game root (not to the shakeable [GameLayer]) so
/// screen shake rattles the action while the sky stays rock steady.
class StarfieldBackground extends PositionComponent {
  StarfieldBackground({int? seed})
    : _rng = Random(seed ?? 7),
      super(priority: -100);

  final Random _rng;
  double _elapsed = 0;

  final List<_StarLayer> _layers = <_StarLayer>[
    // far / dim / slow ... near / bright / fast
    _StarLayer(
      count: 70,
      minRadius: 0.5,
      maxRadius: 1.1,
      speed: 14,
      opacity: 0.45,
      twinkle: 0.35,
    ),
    _StarLayer(
      count: 42,
      minRadius: 0.9,
      maxRadius: 1.7,
      speed: 38,
      opacity: 0.7,
      twinkle: 0.25,
    ),
    _StarLayer(
      count: 18,
      minRadius: 1.5,
      maxRadius: 2.6,
      speed: 78,
      opacity: 1,
      twinkle: 0.15,
    ),
  ];

  Rect _viewRect = Rect.zero;
  Paint _skyPaint = Paint()..color = GameConfig.spaceTop;
  final Paint _starPaint = Paint();
  final Paint _nebulaPaint = Paint();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    _viewRect = Offset.zero & Size(size.x, size.y);
    _skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          GameConfig.spaceTop,
          Color(0xFF0A0A1E),
          GameConfig.spaceBottom,
        ],
        stops: <double>[0, 0.55, 1],
      ).createShader(_viewRect);
    for (final layer in _layers) {
      layer.populate(_rng, size);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (size.x <= 0) {
      return;
    }
    _elapsed += dt;
    for (final layer in _layers) {
      layer.update(dt, _rng, size);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_viewRect.isEmpty) {
      return;
    }
    canvas.drawRect(_viewRect, _skyPaint);
    _renderNebulae(canvas);
    _renderStars(canvas);
  }

  /// Two slowly drifting radial blobs that give the void a bit of depth.
  void _renderNebulae(Canvas canvas) {
    _drawBlob(
      canvas,
      Offset(
        size.x * 0.25 + sin(_elapsed * 0.05) * 18,
        size.y * 0.28 + cos(_elapsed * 0.04) * 14,
      ),
      size.x * 0.75,
      GameConfig.nebulaA,
    );
    _drawBlob(
      canvas,
      Offset(
        size.x * 0.8 + cos(_elapsed * 0.045) * 20,
        size.y * 0.72 + sin(_elapsed * 0.035) * 16,
      ),
      size.x * 0.65,
      GameConfig.nebulaB,
    );
  }

  void _drawBlob(Canvas canvas, Offset center, double radius, Color color) {
    _nebulaPaint.shader = RadialGradient(
      colors: <Color>[
        color.withValues(alpha: 0.30),
        color.withValues(alpha: 0.10),
        color.withValues(alpha: 0),
      ],
      stops: const <double>[0, 0.45, 1],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, _nebulaPaint);
  }

  void _renderStars(Canvas canvas) {
    for (final layer in _layers) {
      for (var i = 0; i < layer.xs.length; i++) {
        final pulse = layer.twinkle == 0
            ? 1.0
            : 1 - layer.twinkle + layer.twinkle * (0.5 + 0.5 * sin(_elapsed * 2.4 + layer.phases[i]));
        _starPaint.color = const Color(0xFFFFFFFF).withValues(
          alpha: (layer.opacity * pulse).clamp(0.0, 1.0),
        );
        canvas.drawCircle(
          Offset(layer.xs[i], layer.ys[i]),
          layer.radii[i],
          _starPaint,
        );
      }
    }
  }
}
