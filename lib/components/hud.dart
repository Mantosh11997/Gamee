import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/space_shooter_game.dart';

/// Code-drawn heads-up display: HP bar (top-left), score + wave (top-right),
/// the active-buff indicator and the centred wave / pickup banners.
///
/// It reads straight off the game object every frame, so nothing here needs to
/// be kept in sync manually.
class Hud extends PositionComponent with HasGameReference<SpaceShooterGame> {
  Hud() : super(priority: 100);

  static const double _margin = 16;
  static const double _hpBarHeight = 14;

  final Paint _paint = Paint();

  final TextPaint _hpText = TextPaint(
    style: const TextStyle(
      color: GameConfig.hudText,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    ),
  );

  final TextPaint _scoreText = TextPaint(
    style: const TextStyle(
      color: GameConfig.hudText,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    ),
  );

  final TextPaint _waveText = TextPaint(
    style: const TextStyle(
      color: Color(0xFF9FB4D6),
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
    ),
  );

  final TextPaint _buffText = TextPaint(
    style: const TextStyle(
      color: Color(0xFF0B0D1A),
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    ),
  );

  @override
  void render(Canvas canvas) {
    // Nothing to show behind the title screen.
    if (game.state == PlayState.menu) {
      return;
    }
    final top = game.safeTop + _margin;
    _renderHp(canvas, top);
    _renderScoreAndWave(canvas, top);
    _renderBuff(canvas, top + _hpBarHeight + 12);
    _renderWaveBanner(canvas);
    _renderAnnouncement(canvas);
  }

  // ------------------------------------------------------------------- HP --

  void _renderHp(Canvas canvas, double top) {
    final player = game.player;
    final double ratio = player?.hpRatio ?? 0;
    final double hp = player?.hp ?? 0;

    final barWidth = min(190.0, game.size.x * 0.46);
    final rect = Rect.fromLTWH(_margin, top, barWidth, _hpBarHeight);

    _paint.color = GameConfig.hpTrack;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      _paint,
    );

    if (ratio > 0) {
      _paint.color = Color.lerp(
        GameConfig.hpGood,
        const Color(0xFFFF8A3D),
        ratio * 0.35,
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left, rect.top, rect.width * ratio, rect.height),
          const Radius.circular(7),
        ),
        _paint,
      );
    }

    _paint
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      _paint,
    );
    _paint.style = PaintingStyle.fill;

    _hpText.render(
      canvas,
      '${hp.ceil()} / ${(player?.maxHp ?? GameConfig.playerMaxHp).toInt()}',
      Vector2(rect.left + 10, rect.top + _hpBarHeight / 2),
      anchor: Anchor.centerLeft,
    );
  }

  // -------------------------------------------------------- score and wave --

  void _renderScoreAndWave(Canvas canvas, double top) {
    final right = game.size.x - _margin;
    _scoreText.render(
      canvas,
      '${game.score}',
      Vector2(right, top - 4),
      anchor: Anchor.topRight,
    );
    _waveText.render(
      canvas,
      'WAVE ${game.waves.wave}',
      Vector2(right, top + 28),
      anchor: Anchor.topRight,
    );
  }

  // ---------------------------------------------------------------- buffs --

  /// Pill showing the remaining time on the rapid-fire buff.
  void _renderBuff(Canvas canvas, double top) {
    final player = game.player;
    final double remaining = player?.rapidFireRemaining ?? 0;
    if (remaining <= 0) {
      return;
    }
    final ratio = (remaining / GameConfig.rapidFireDuration).clamp(0.0, 1.0);

    const width = 132.0;
    const height = 20.0;
    final rect = Rect.fromLTWH(_margin, top, width, height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    _paint.color = const Color(0x66000000);
    canvas.drawRRect(rrect, _paint);

    // The fill drains left-to-right as the buff expires.
    canvas.save();
    canvas.clipRRect(rrect);
    _paint.color = GameConfig.rapidFireColor;
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width * ratio, rect.height),
      _paint,
    );
    canvas.restore();

    _buffText.render(
      canvas,
      'RAPID FIRE ${remaining.ceil()}s',
      Vector2(rect.center.dx, rect.center.dy),
      anchor: Anchor.center,
    );
  }

  // -------------------------------------------------------------- banners --

  /// Big "WAVE n" title that fades in and out at the start of every wave.
  ///
  /// The style is rebuilt each frame because the alpha animates; that is a
  /// single text layout per frame and only while a banner is on screen.
  void _renderWaveBanner(Canvas canvas) {
    final waves = game.waves;
    if (waves.bannerTimer <= 0) {
      return;
    }
    final t = waves.bannerTimer / GameConfig.waveBannerDuration;
    // Fade in over the first ~third of the banner's life, hold, fade out.
    final alpha = (t > 0.85 ? (1 - t) / 0.15 : min(1.0, t / 0.35)).clamp(0.0, 1.0);

    _fadedBanner(alpha).render(
      canvas,
      'WAVE ${waves.wave}',
      Vector2(game.size.x / 2, game.size.y * 0.33),
      anchor: Anchor.center,
    );
  }

  TextPaint _fadedBanner(double alpha) => TextPaint(
    style: TextStyle(
      color: Colors.white.withValues(alpha: alpha),
      fontSize: 40,
      fontWeight: FontWeight.w900,
      letterSpacing: 6,
      shadows: <Shadow>[
        Shadow(
          color: GameConfig.playerGlow.withValues(alpha: alpha * 0.8),
          blurRadius: 18,
        ),
      ],
    ),
  );

  /// Short toast used for power-up pickups.
  void _renderAnnouncement(Canvas canvas) {
    final timer = game.announcementTimer;
    if (timer <= 0) {
      return;
    }
    final alpha = min(1.0, timer / 0.4).clamp(0.0, 1.0);
    TextPaint(
      style: TextStyle(
        color: Colors.white.withValues(alpha: alpha),
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
      ),
    ).render(
      canvas,
      game.announcementText,
      Vector2(game.size.x / 2, game.size.y * 0.62),
      anchor: Anchor.center,
    );
  }
}
