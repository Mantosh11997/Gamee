import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_shooter/components/art_component.dart';
import 'package:space_shooter/components/bullet.dart';
import 'package:space_shooter/components/enemy.dart';
import 'package:space_shooter/components/player.dart';
import 'package:space_shooter/components/ordnance.dart';
import 'package:space_shooter/components/powerup.dart';
import 'package:space_shooter/components/sprite_burst.dart';
import 'package:space_shooter/game/audio.dart';
import 'package:space_shooter/game/player_profile.dart';
import 'package:space_shooter/game/ship_skin.dart';
import 'package:space_shooter/ui/home_screen.dart';
import 'package:space_shooter/game/config.dart';
import 'package:space_shooter/game/sprite_library.dart';
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

/// Lets real async work (asset manifest reads, PNG decoding) actually finish.
///
/// `pump` alone does not drive the image pipeline, so `onLoad` would never
/// complete and the game's `late final` fields would still be unset.
Future<void> _settleLoad(WidgetTester tester, SpaceShooterGame game) async {
  // `runAsync` lets the real event loop (and the image codec) make progress;
  // `pump` then drives the fake-async zone the load future lives in. Both are
  // needed, alternating, or `onLoad` never finishes.
  for (var i = 0; i < 300 && !game.isLoaded; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 4)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(game.isLoaded, isTrue, reason: 'the game never finished onLoad');
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
                Overlays.mainMenu: (context, game) => HomeScreen(game: game),
                Overlays.gameOver: (context, game) => GameOverOverlay(game: game),
                Overlays.pauseMenu: (context, game) => PauseOverlay(game: game),
                Overlays.pauseButton: (context, game) =>
                    PauseButtonOverlay(game: game),
              },
        ),
      ),
    ),
  );
  await _settleLoad(tester, game);
  // Frames for the widget swap out of the loader and the first game tick.
  await _tick(tester, 6);
  return game;
}

/// Swipes the hangar carousel one ship to the right and lets it snap.
///
/// `pumpAndSettle` is unusable here: the Flame game rendering behind the
/// overlay schedules frames forever, so it would always time out.
Future<void> _swipeToNextShip(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-300, 0));
  await _tick(tester, 45);
}

/// Boots the game and taps through the title screen into a live run.
Future<SpaceShooterGame> _startRun(WidgetTester tester) async {
  final game = await _bootGame(tester);
  await tester.tap(find.text('PLAY'));
  await _tick(tester, 3);
  return game;
}

void main() {
  // The audio plugin has no platform behind it under `flutter test`; leave it
  // switched off so nothing reaches audioplayers.
  setUpAll(() => AudioManager.enabled = false);

  // The profile persists through shared_preferences; give every test a clean,
  // in-memory store so unlocks and coins never leak between them.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('AudioManager', () {
    test('is inert and mutable while the plugin is unavailable', () async {
      final audio = AudioManager();
      await audio.init();

      expect(audio.available, isFalse, reason: 'disabled by the kill switch');
      expect(audio.muted, isFalse);

      // Every one of these must be a silent no-op rather than a throw.
      audio
        ..play(AudioManager.explosionSmall)
        ..playShot()
        ..startMusic()
        ..pauseMusic()
        ..resumeMusic();

      audio.toggleMuted();
      expect(audio.muted, isTrue);
      audio.setMuted(false);
      expect(audio.muted, isFalse);
    });
  });

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
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('loads the shipped sprites and tolerates the missing ones',
        (tester) async {
      final game = await _bootGame(tester);

      // Art that is in the repo today.
      for (final name in const <String>[
        SpriteLibrary.player,
        SpriteLibrary.enemyBasic,
        SpriteLibrary.enemyFast,
        SpriteLibrary.enemyTank,
        SpriteLibrary.bulletPlayer,
        SpriteLibrary.bulletEnemy,
        SpriteLibrary.powerupHealth,
        SpriteLibrary.powerupRapidFire,
      ]) {
        expect(game.sprites[name], isNotNull, reason: '$name should have loaded');
      }

      // The heavy hulls, ordnance and effect art that arrived later.
      for (final name in const <String>[
        SpriteLibrary.playerMk5,
        SpriteLibrary.playerMk6,
        SpriteLibrary.playerMk7,
        SpriteLibrary.playerTitan,
        SpriteLibrary.bulletPlayerUltra,
        SpriteLibrary.bulletPlayerLaser,
        SpriteLibrary.missilePlayerHeavy,
        SpriteLibrary.missilePlayerCluster,
        SpriteLibrary.bombPlayer,
        SpriteLibrary.bombPlayerNuclear,
        SpriteLibrary.attackAtomic,
        SpriteLibrary.explosionAtomic,
        SpriteLibrary.attackNova,
        SpriteLibrary.attackBeam,
        SpriteLibrary.enemyHeavy,
        SpriteLibrary.enemyAssault,
      ]) {
        expect(game.sprites[name], isNotNull, reason: '$name should have loaded');
      }

      // Mid-tier skin art that still has not been drawn. Absent is a supported
      // state: the hangar and the game both fall back to code-drawn shapes.
      for (final name in const <String>[
        SpriteLibrary.playerMk2,
        SpriteLibrary.playerMk3,
        SpriteLibrary.playerMk4,
        SpriteLibrary.bulletPlayerHeavy,
      ]) {
        expect(game.sprites[name], isNull, reason: '$name is not drawn yet');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the title screen starts a run', (tester) async {
      final game = await _startRun(tester);

      expect(game.state, PlayState.playing);
      expect(game.player, isNotNull);
      expect(game.player!.hp, game.player!.maxHp);
      expect(game.waves.wave, 1);
      expect(game.joystick.visible, isTrue);
      expect(find.text('PLAY'), findsNothing);
    });

    testWidgets('the mute toggle flips the audio manager and its icon',
        (tester) async {
      final game = await _startRun(tester);
      expect(game.audio.muted, isFalse);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();

      expect(game.audio.muted, isTrue);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    testWidgets('the wave manager spawns enemies once a run is going',
        (tester) async {
      final game = await _startRun(tester);
      await _tick(tester, 200); // ~3.2 seconds of game time

      // Counting spawns rather than survivors: the ship auto-fires, so whether
      // any given enemy is still alive at this instant is not deterministic.
      expect(game.waves.totalSpawned, greaterThanOrEqualTo(2));
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

      game.player!.takeDamage(game.player!.maxHp);
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
      expect(game.player!.hp, game.player!.maxHp);
      expect(game.hasLiveEnemies, isFalse, reason: 'the field is wiped clean');
    });

    testWidgets('the player is briefly invulnerable after a hit',
        (tester) async {
      final game = await _startRun(tester);
      final player = game.player!;

      final full = player.maxHp;
      player.takeDamage(10);
      expect(player.hp, full - 10);
      expect(player.isInvulnerable, isTrue);

      // A second hit inside the grace window is ignored.
      player.takeDamage(10);
      expect(player.hp, full - 10);
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
      expect(player.hp, player.maxHp - 90);

      player.heal(GameConfig.healthRestore);
      expect(player.hp, player.maxHp - 90 + GameConfig.healthRestore);

      player.heal(1000);
      expect(player.hp, player.maxHp);
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
        Player(position: Vector2.all(50), sprite: sprite, skin: ShipCatalog.scout),
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

    testWidgets('and through the code-drawn fallback when a PNG is missing',
        (tester) async {
      final entities = <ArtComponent>[
        Player(position: Vector2.all(50), sprite: null, skin: ShipCatalog.dreadnought),
        for (final type in EnemyType.values)
          Enemy(
            type: type,
            position: Vector2.all(50),
            sprite: null,
            speedMultiplier: 1,
            canShoot: true,
          ),
        for (final type in PowerupType.values)
          Powerup(type: type, position: Vector2.all(50), sprite: null),
        PlayerBullet(position: Vector2.all(50), sprite: null),
        EnemyBullet(position: Vector2.all(50), sprite: null),
      ];

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final entity in entities) {
        expect(entity.usesFallbackArt, isTrue);
        entity.render(canvas);
      }
      recorder.endRecording().dispose();
      expect(tester.takeException(), isNull);
    });
  });

  group('Hangar and coins', () {
    test('profile starts with the free ship only, and unlocking costs coins',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final profile = PlayerProfile();
      await profile.load();

      expect(profile.coins, 0);
      expect(profile.isOwned(ShipCatalog.scout), isTrue);
      expect(profile.isEquipped(ShipCatalog.scout), isTrue);
      for (final skin in ShipCatalog.all.where((s) => !s.isFree)) {
        expect(profile.isOwned(skin), isFalse, reason: '${skin.id} is locked');
      }

      // Too poor: the unlock is refused and nothing is spent.
      expect(profile.unlock(ShipCatalog.interceptor), isFalse);
      expect(profile.isOwned(ShipCatalog.interceptor), isFalse);
      expect(profile.coins, 0);

      profile.addCoins(ShipCatalog.interceptor.price);
      expect(profile.unlock(ShipCatalog.interceptor), isTrue);
      expect(profile.isOwned(ShipCatalog.interceptor), isTrue);
      expect(profile.isEquipped(ShipCatalog.interceptor), isTrue,
          reason: 'unlocking equips');
      expect(profile.coins, 0, reason: 'the price was deducted');

      // Buying twice must not double-charge.
      profile.addCoins(1000);
      expect(profile.unlock(ShipCatalog.interceptor), isFalse);
      expect(profile.coins, 1000);
    });

    test('a locked ship can never be equipped', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final profile = PlayerProfile();
      await profile.load();

      expect(profile.equip(ShipCatalog.dreadnought), isFalse);
      expect(profile.isEquipped(ShipCatalog.scout), isTrue);
    });

    test('a run pays out coins and records the best score', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final profile = PlayerProfile();
      await profile.load();

      final earned = profile.recordRun(score: 1200, wave: 6, kills: 40);
      expect(earned, greaterThan(0));
      expect(profile.coins, earned);
      expect(profile.bestScore, 1200);
      expect(profile.bestWave, 6);

      // A worse run still pays, but does not lower the record.
      profile.recordRun(score: 300, wave: 2, kills: 10);
      expect(profile.bestScore, 1200);
      expect(profile.bestWave, 6);
      expect(profile.coins, greaterThan(earned));
    });

    test('coins and unlocks survive a reload', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = PlayerProfile();
      await first.load();
      first.addCoins(5000);
      first.unlock(ShipCatalog.destroyer);
      await first.saved;

      final second = PlayerProfile();
      await second.load();
      expect(second.isOwned(ShipCatalog.destroyer), isTrue);
      expect(second.isEquipped(ShipCatalog.destroyer), isTrue);
      expect(second.coins, 5000 - ShipCatalog.destroyer.price);
    });

    test('every catalogue entry is well formed', () {
      final ids = <String>{};
      for (final skin in ShipCatalog.all) {
        expect(ids.add(skin.id), isTrue, reason: 'duplicate id ${skin.id}');
        expect(skin.weapon.barrels, isNotEmpty);
        expect(skin.rarity, inInclusiveRange(1, 4));
        expect(ShipCatalog.byId(skin.id).id, skin.id);
      }
      expect(ShipCatalog.all.first.isFree, isTrue,
          reason: 'the starter ship must be free');
      expect(ShipCatalog.byId('nope').id, ShipCatalog.scout.id,
          reason: 'an unknown id falls back to the starter');
    });
  });

  group('Home screen', () {
    testWidgets('shows every ship, locks the paid ones, and unlocks on tap',
        (tester) async {
      final game = await _bootGame(tester);
      game.profile.addCoins(ShipCatalog.interceptor.price);
      await tester.pump();

      // The whole catalogue is browsable from the hangar.
      expect(find.text(ShipCatalog.scout.name), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets,
          reason: 'locked ships are badged');

      // Swipe to the second ship and buy it.
      await _swipeToNextShip(tester);
      expect(find.text(ShipCatalog.interceptor.name), findsWidgets);

      await tester.tap(find.textContaining('UNLOCK'));
      await tester.pump();

      expect(game.profile.isOwned(ShipCatalog.interceptor), isTrue);
      expect(game.profile.coins, 0);
    });

    testWidgets('an unaffordable ship shows the shortfall and cannot be bought',
        (tester) async {
      final game = await _bootGame(tester);

      await _swipeToNextShip(tester);

      final button = find.textContaining('NEED');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();

      expect(game.profile.isOwned(ShipCatalog.interceptor), isFalse);
    });

    testWidgets('the equipped ship is the one that flies', (tester) async {
      final game = await _bootGame(tester);
      game.profile
        ..addCoins(9999)
        ..unlock(ShipCatalog.dreadnought);
      await tester.pump();

      await tester.tap(find.text('PLAY'));
      await _tick(tester, 3);

      expect(game.player!.skin.id, ShipCatalog.dreadnought.id);
      expect(game.player!.maxHp, ShipCatalog.dreadnought.maxHp);
    });

    testWidgets('each ship fires its own barrel count', (tester) async {
      final game = await _bootGame(tester);
      game.profile
        ..addCoins(9999)
        ..unlock(ShipCatalog.destroyer);
      await tester.pump();
      await tester.tap(find.text('PLAY'));
      await _tick(tester, 3);

      final before = game.layer.children.whereType<PlayerBullet>().length;
      game.player!.forceFire();
      await _tick(tester, 2);
      final after = game.layer.children.whereType<PlayerBullet>().length;

      expect(after - before, ShipCatalog.destroyer.weapon.shotCount);
    });

    testWidgets('game over pays out and returns to the hangar', (tester) async {
      final game = await _bootGame(tester);
      await tester.tap(find.text('PLAY'));
      await _tick(tester, 3);

      game.addScore(600);
      game.player!.takeDamage(game.player!.maxHp);
      await _tick(tester, 2);

      expect(game.lastRunCoins, greaterThan(0));
      expect(game.profile.coins, game.lastRunCoins);
      expect(find.textContaining('COINS'), findsOneWidget);

      await tester.tap(find.text('HANGAR'));
      await _tick(tester, 2);
      expect(game.state, PlayState.menu);
      expect(find.text('PLAY'), findsOneWidget);
    });
  });

  group('Ordnance', () {
    testWidgets('a heavy hull launches ordnance that splashes on impact',
        (tester) async {
      final game = await _bootGame(tester);
      game.profile
        ..addCoins(99999)
        ..unlock(ShipCatalog.titan);
      await tester.pump();
      await tester.tap(find.text('PLAY'));
      await _tick(tester, 3);

      final player = game.player!;
      expect(player.skin.hasOrdnance, isTrue);

      // Two enemies close together: one takes the direct hit, the other is
      // inside the blast.
      final direct = Enemy(
        type: EnemyType.basic,
        position: Vector2(player.position.x, player.position.y - 120),
        sprite: null,
        speedMultiplier: 0.0001,
        canShoot: false,
      );
      final splashed = Enemy(
        type: EnemyType.basic,
        position: Vector2(player.position.x + 30, player.position.y - 120),
        sprite: null,
        speedMultiplier: 0.0001,
        canShoot: false,
      );
      game.layer.addAll(<Component>[direct, splashed]);
      await _tick(tester, 2);

      player.forceOrdnance();
      await _tick(tester, 40);

      // The warhead out-damages a raider several times over, so both die.
      expect(direct.isMounted && !direct.isDying, isFalse);
      expect(splashed.isMounted && !splashed.isDying, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('light hulls carry no ordnance and launch nothing',
        (tester) async {
      final game = await _startRun(tester);
      final player = game.player!;

      expect(player.skin.hasOrdnance, isFalse);
      player.forceOrdnance();
      await _tick(tester, 2);
      expect(game.layer.children.whereType<Ordnance>(), isEmpty);
    });

    test('every ordnance spec is sane', () {
      for (final skin in ShipCatalog.all) {
        final ordnance = skin.ordnance;
        if (ordnance == null) {
          continue;
        }
        expect(ordnance.damage, greaterThan(0));
        expect(ordnance.blastRadius, greaterThan(0));
        expect(ordnance.cooldown, greaterThan(0));
        expect(ordnance.speed, greaterThan(0));
      }
      // The ladder must actually escalate: the last hull is the strongest.
      expect(ShipCatalog.all.last.maxHp, ShipCatalog.all
          .map((s) => s.maxHp)
          .reduce((a, b) => a > b ? a : b));
      expect(ShipCatalog.all.last.hasOrdnance, isTrue);
    });

    testWidgets('a sprite burst cleans itself up', (tester) async {
      final game = await _startRun(tester);
      final burst = SpriteBurst(
        position: Vector2.all(100),
        radius: 40,
        sprite: null,
        color: const Color(0xFF7DF9FF),
        duration: 0.2,
      );
      game.layer.add(burst);
      await _tick(tester, 2);
      expect(burst.isMounted, isTrue);

      await _tick(tester, 20);
      expect(burst.isMounted, isFalse, reason: 'it removes itself when done');
    });
  });

  group('Hostile codex', () {
    test('every enemy type has codex copy and a spawn wave', () {
      final names = <String>{};
      for (final type in EnemyType.values) {
        final spec = EnemySpec.specs[type]!;
        expect(spec.displayName, isNotEmpty);
        expect(spec.description, isNotEmpty);
        expect(spec.firstWave, greaterThanOrEqualTo(1));
        expect(names.add(spec.displayName), isTrue,
            reason: 'duplicate codex name ${spec.displayName}');
      }
    });

    test('the spawner never picks a type before its first wave', () {
      final waves = WaveManager()..reset();
      for (var wave = 1; wave <= 30; wave++) {
        waves.wave = wave;
        for (var roll = 0; roll < 80; roll++) {
          final spec = EnemySpec.specs[waves.debugPickType()]!;
          expect(spec.firstWave, lessThanOrEqualTo(wave),
              reason: 'picked ${spec.displayName} on wave $wave');
        }
      }
    });

    testWidgets('the hostiles tab lists every enemy', (tester) async {
      await _bootGame(tester);

      await tester.tap(find.text('HOSTILES'));
      await _tick(tester, 4);

      // The list scrolls, so check the early entries are rendered and that the
      // ship actions are replaced by PLAY alone.
      expect(find.text(EnemySpec.specs[EnemyType.basic]!.displayName),
          findsOneWidget);
      expect(find.text(EnemySpec.specs[EnemyType.fast]!.displayName),
          findsOneWidget);
      expect(find.textContaining('UNLOCK'), findsNothing);
      expect(find.text('PLAY'), findsOneWidget);

      await tester.tap(find.text('FLEET'));
      await _tick(tester, 4);
      expect(find.text(ShipCatalog.scout.name), findsOneWidget);
    });
  });
}

/// 2x2 half-transparent red PNG, used to exercise sprite rendering in tests.
const String _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DQAMIM'
    'MAYAOOgF/REzMMkAAAAASUVORK5CYII=';
