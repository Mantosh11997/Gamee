import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_shooter/components/art_component.dart';
import 'package:space_shooter/components/bullet.dart';
import 'package:space_shooter/components/enemy.dart';
import 'package:space_shooter/components/player.dart';
import 'package:space_shooter/components/powerup.dart';
import 'package:space_shooter/game/config.dart';
import 'package:space_shooter/game/space_shooter_game.dart';
import 'package:space_shooter/managers/score_manager.dart';
import 'package:space_shooter/managers/wave_manager.dart';
import 'package:space_shooter/ui/overlay_ids.dart';
import 'package:space_shooter/ui/overlays.dart';

/// Advances the game clock by [frames] frames of ~60fps.
///
/// `pumpAndSettle` must never be used here: a Flame game schedules frames
/// forever, so it would simply time out.
Future<void> _tick(WidgetTester tester, [int frames = 1]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Boots the game inside a `GameWidget` with all overlays registered.
Future<SpaceShooterGame> _bootGame(WidgetTester tester) async {
  final game = SpaceShooterGame();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<SpaceShooterGame>(
          game: game,
          overlayBuilderMap:
              <String, Widget Function(BuildContext, SpaceShooterGame)>{
                Overlays.mainMenu: (context, game) => MainMenuOverlay(game: game),
                Overlays.gameOver: (context, game) => GameOverOverlay(game: game),
                Overlays.pauseMenu: (context, game) => PauseOverlay(game: game),
                Overlays.pauseButton: (context, game) =>
                    PauseButtonOverlay(game: game),
              },
        ),
      ),
    ),
  );
  // Frames for onLoad (which probes for the optional PNGs) and the first tick.
  await _tick(tester, 8);
  return game;
}

/// Boots the game and taps through the title screen into a live run.
Future<SpaceShooterGame> _startRun(WidgetTester tester) async {
  final game = await _bootGame(tester);
  await tester.tap(find.text('TAP TO PLAY'));
  await _tick(tester, 3);
  return game;
}

void main() {
  group('ScoreManager', () {
    test('tracks score, kills and a session best', () {
      final scores = ScoreManager()
        ..addKill(10)
        ..addKill(40);
      expect(scores.score, 50);
      expect(scores.enemiesDestroyed, 2);
      expect(scores.best, 50);

      scores.reset();
      expect(scores.score, 0);
      expect(scores.enemiesDestroyed, 0);
      expect(scores.best, 50, reason: 'best survives a reset');
    });
  });

  group('Difficulty ramp', () {
    test('spawns speed up wave after wave, and both curves are capped', () {
      final waves = WaveManager()..reset();

      expect(waves.wave, 1);
      expect(waves.speedMultiplier, 1);
      final firstInterval = waves.spawnInterval;

      waves.wave = 6;
      expect(waves.spawnInterval, lessThan(firstInterval));
      expect(waves.speedMultiplier, greaterThan(1));

      waves.wave = 500;
      expect(waves.spawnInterval, GameConfig.minSpawnInterval);
      expect(waves.speedMultiplier, GameConfig.maxEnemySpeedMultiplier);
    });
  });

  group('Enemy specs', () {
    test('every type has a spec; tanks are tough, fast ones weave', () {
      for (final type in EnemyType.values) {
        expect(EnemySpec.specs[type], isNotNull, reason: '$type needs a spec');
      }
      final basic = EnemySpec.specs[EnemyType.basic]!;
      final fast = EnemySpec.specs[EnemyType.fast]!;
      final tank = EnemySpec.specs[EnemyType.tank]!;

      expect(tank.maxHp, greaterThan(basic.maxHp));
      expect(tank.score, greaterThan(basic.score));
      expect(tank.width, greaterThan(basic.width));
      expect(fast.speed, greaterThan(basic.speed));
      expect(fast.weaveAmplitude, greaterThan(0));
    });
  });

  group('Game lifecycle', () {
    testWidgets('boots into the main menu with no player', (tester) async {
      final game = await _bootGame(tester);

      expect(game.state, PlayState.menu);
      expect(game.player, isNull);
      expect(game.joystick.visible, isFalse);
      expect(find.text('TAP TO PLAY'), findsOneWidget);
    });

    testWidgets('runs with no PNG assets present', (tester) async {
      final game = await _bootGame(tester);
      // Nothing was found in assets/images/, and that is a supported setup.
      expect(game.sprites.missing.length, 8);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the title screen starts a run', (tester) async {
      final game = await _startRun(tester);

      expect(game.state, PlayState.playing);
      expect(game.player, isNotNull);
      expect(game.player!.hp, GameConfig.playerMaxHp);
      expect(game.waves.wave, 1);
      expect(game.joystick.visible, isTrue);
      expect(find.text('TAP TO PLAY'), findsNothing);
    });

    testWidgets('the wave manager spawns enemies once a run is going',
        (tester) async {
      final game = await _startRun(tester);
      await _tick(tester, 200); // ~3.2 seconds of game time

      expect(game.hasLiveEnemies, isTrue);
      expect(game.state, PlayState.playing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pause stops the engine, resume restarts it', (tester) async {
      final game = await _startRun(tester);

      game.pauseGame();
      await tester.pump();
      expect(game.state, PlayState.paused);
      expect(game.paused, isTrue);
      expect(find.text('RESUME'), findsOneWidget);

      await tester.tap(find.text('RESUME'));
      await _tick(tester, 2);
      expect(game.state, PlayState.playing);
      expect(game.paused, isFalse);
    });

    testWidgets('running out of HP ends the run; restart resets everything',
        (tester) async {
      final game = await _startRun(tester);
      game.addScore(123);

      game.player!.takeDamage(GameConfig.playerMaxHp);
      await _tick(tester, 2);

      expect(game.state, PlayState.gameOver);
      expect(game.player, isNull);
      expect(find.text('RESTART'), findsOneWidget);
      expect(find.text('123'), findsAtLeastNWidgets(1));

      await tester.tap(find.text('RESTART'));
      await _tick(tester, 3);

      expect(game.state, PlayState.playing);
      expect(game.score, 0);
      expect(game.waves.wave, 1);
      expect(game.player!.hp, GameConfig.playerMaxHp);
      expect(game.hasLiveEnemies, isFalse, reason: 'the field is wiped clean');
    });

    testWidgets('the player is briefly invulnerable after a hit',
        (tester) async {
      final game = await _startRun(tester);
      final player = game.player!;

      player.takeDamage(10);
      expect(player.hp, GameConfig.playerMaxHp - 10);
      expect(player.isInvulnerable, isTrue);

      // A second hit inside the grace window is ignored.
      player.takeDamage(10);
      expect(player.hp, GameConfig.playerMaxHp - 10);
    });

    testWidgets('rapid fire shortens the firing interval', (tester) async {
      final game = await _startRun(tester);
      final player = game.player!;

      expect(player.fireInterval, GameConfig.playerFireInterval);
      player.grantRapidFire(GameConfig.rapidFireDuration);
      expect(player.fireInterval, GameConfig.rapidFireInterval);
      expect(player.fireInterval, lessThan(GameConfig.playerFireInterval));
    });

    testWidgets('health pickups heal but never overheal', (tester) async {
      final game = await _startRun(tester);
      final player = game.player!;

      player.takeDamage(90);
      expect(player.hp, GameConfig.playerMaxHp - 90);

      player.heal(GameConfig.healthRestore);
      expect(player.hp, GameConfig.playerMaxHp - 90 + GameConfig.healthRestore);

      player.heal(1000);
      expect(player.hp, GameConfig.playerMaxHp);
    });

    testWidgets('every entity also renders through the real sprite path',
        (tester) async {
      // A 2x2 semi-transparent PNG stands in for the real art, so both render
      // branches (sprite present / sprite missing) are covered by the suite.
      late final ui.Image image;
      await tester.runAsync(() async {
        image = await decodeImageFromList(base64Decode(_tinyPngBase64));
      });
      final sprite = Sprite(image);

      final entities = <ArtComponent>[
        Player(position: Vector2.all(50), sprite: sprite),
        Enemy(
          type: EnemyType.tank,
          position: Vector2.all(50),
          sprite: sprite,
          speedMultiplier: 1,
          canShoot: true,
        ),
        Powerup(
          type: PowerupType.rapidFire,
          position: Vector2.all(50),
          sprite: sprite,
        ),
        PlayerBullet(position: Vector2.all(50), sprite: sprite),
      ];

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final entity in entities) {
        expect(entity.usesFallbackArt, isFalse);
        entity.render(canvas);
      }
      recorder.endRecording().dispose();
      expect(tester.takeException(), isNull);
    });
  });
}

/// 2x2 half-transparent red PNG, used to exercise sprite rendering in tests.
const String _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DQAMIM'
    'MAYAOOgF/REzMMkAAAAASUVORK5CYII=';
