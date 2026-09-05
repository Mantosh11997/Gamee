// Renders store-ready screenshots from the real game.
//
// Lives outside test/ so `flutter test` and CI never run it. Drive it with:
//   flutter test tool/demo/screenshots.dart      # -> build/screenshots/*.png
//
// It captures several candidates per scene; pick the four you want to ship.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_shooter/components/enemy.dart';
import 'package:space_shooter/components/player.dart';
import 'package:space_shooter/game/audio.dart';
import 'package:space_shooter/game/config.dart';
import 'package:space_shooter/game/ship_skin.dart';
import 'package:space_shooter/game/space_shooter_game.dart';
import 'package:space_shooter/game/sprite_library.dart';
import 'package:space_shooter/ui/home_screen.dart';
import 'package:space_shooter/ui/overlay_ids.dart';
import 'package:space_shooter/ui/overlays.dart';

const String kOutDir = 'build/screenshots';
const double kScale = 3; // 380x820 logical -> 1140x2460

void main() {
  final captureKey = GlobalKey();

  testWidgets('capture screenshots', (tester) async {
    final fontDir = Directory(
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
      '/bin/cache/artifacts/material_fonts',
    );
    for (final face in <String>['Roboto-Regular', 'Roboto-Bold', 'Roboto-Black']) {
      final file = File('${fontDir.path}/$face.ttf');
      if (file.existsSync()) {
        await (FontLoader('Roboto')
              ..addFont(
                Future<ByteData>.value(
                  ByteData.sublistView(file.readAsBytesSync()),
                ),
              ))
            .load();
      }
    }
    final icons = File('${fontDir.path}/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')
            ..addFont(
              Future<ByteData>.value(
                ByteData.sublistView(icons.readAsBytesSync()),
              ),
            ))
          .load();
    }
    GameConfig.fontFamily = 'Roboto';

    AudioManager.enabled = false;
    // These harnesses run under flutter_test but live outside test/, so the
    // analyzer does not recognise them as tests. Starting from an empty store
    // keeps every capture reproducible.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(380, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = SpaceShooterGame();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            backgroundColor: const Color(0xFF05060F),
            body: GameWidget<SpaceShooterGame>(
              game: game,
              overlayBuilderMap:
                  <String, Widget Function(BuildContext, SpaceShooterGame)>{
                    Overlays.mainMenu: (c, g) => HomeScreen(game: g),
                    Overlays.gameOver: (c, g) => GameOverOverlay(game: g),
                    Overlays.pauseMenu: (c, g) => PauseOverlay(game: g),
                    Overlays.pauseButton: (c, g) => PauseButtonOverlay(game: g),
                  },
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 500 && !game.isLoaded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 4)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(HomeScreen));
      for (final name in SpriteLibrary.all) {
        await precacheImage(AssetImage('assets/images/$name'), ctx);
      }
    });

    final dir = Directory(kOutDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);

    game.profile.addCoins(999999);
    for (final skin in ShipCatalog.all) {
      game.profile.unlock(skin);
    }

    // ---- meta screens -----------------------------------------------------
    game.profile.equip(ShipCatalog.titan);
    await _settle(tester, 20);
    // The carousel opens on the equipped hull, so page forward to reach the
    // capital ships rather than shooting the starter again.
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(PageView), const Offset(-900, 0));
      await _settle(tester, 45);
      await _grab(tester, captureKey, 'hangar_$i');
    }

    await tester.tap(find.text('HOSTILES'));
    await _settle(tester, 20);
    await _grab(tester, captureKey, 'codex_top');
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await _settle(tester, 30);
    await _grab(tester, captureKey, 'codex_scrolled');

    await tester.tap(find.text('FLEET'));
    await _settle(tester, 20);

    // ---- combat -----------------------------------------------------------
    await _combat(
      tester, game, captureKey, ShipCatalog.titan, 'combat_titan',
      <EnemyType>[
        EnemyType.boss, EnemyType.basicElite, EnemyType.tankElite,
        EnemyType.assault, EnemyType.drone,
      ],
    );
    await _combat(
      tester, game, captureKey, ShipCatalog.battlecruiser, 'combat_cruiser',
      <EnemyType>[
        EnemyType.tank, EnemyType.heavy, EnemyType.fastElite,
        EnemyType.bomber, EnemyType.basic,
      ],
    );
    await _combat(
      tester, game, captureKey, ShipCatalog.destroyer, 'combat_destroyer',
      <EnemyType>[
        EnemyType.heavy, EnemyType.fast, EnemyType.basicElite,
        EnemyType.tank, EnemyType.basic,
      ],
    );

    stdout.writeln('screenshots written to $kOutDir');
  }, timeout: const Timeout(Duration(minutes: 15)));
}

Future<void> _settle(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(microseconds: 16667));
  }
}

/// Sets up a fight, lets it develop, then grabs a burst of candidates.
Future<void> _combat(
  WidgetTester tester,
  SpaceShooterGame game,
  GlobalKey key,
  ShipSkin skin,
  String name,
  List<EnemyType> hostiles,
) async {
  game.profile.equip(skin);
  if (game.state != PlayState.playing) {
    game.startGame();
  } else {
    game.player?.removeFromParent();
    final player = Player(
      position: Vector2(
        game.size.x / 2,
        game.size.y - GameConfig.playerBottomMargin,
      ),
      sprite: game.sprites[skin.asset],
      skin: skin,
    );
    game.player = player;
    game.layer.add(player);
  }
  // A plausible mid-run HUD rather than "WAVE 1 / 0".
  game.scores.reset();
  game.addScore(18400 + game.rng.nextInt(900));
  game.waves.wave = 12;
  // Let the wave banner clear so it is not sitting across the shot.
  await _settle(tester, 130);

  // Staged in frame, not off the top edge, so every hostile is visible.
  for (var i = 0; i < hostiles.length; i++) {
    final spec = EnemySpec.specs[hostiles[i]]!;
    game.layer.add(
      Enemy(
        type: hostiles[i],
        position: Vector2(
          game.size.x * (0.16 + 0.17 * i),
          90.0 + (i.isEven ? 0 : 90) + i * 34,
        ),
        sprite: game.sprites[spec.asset],
        speedMultiplier: 0.35,
        canShoot: true,
      ),
    );
  }

  // Let the fight develop, then take a spread of candidates.
  for (var shot = 0; shot < 5; shot++) {
    for (var i = 0; i < 18; i++) {
      final player = game.player;
      for (final enemy in game.layer.children.whereType<Enemy>()) {
        if (!enemy.isDying) {
          // Photo shoot, not a fight to the death: keep the cast on stage.
          enemy.hp = enemy.spec.maxHp;
        }
      }
      if (player != null) {
        player.hp = player.maxHp;
        final live = game.layer.children
            .whereType<Enemy>()
            .where((e) => !e.isDying)
            .toList();
        if (live.isNotEmpty) {
          live.sort((a, b) => b.position.y.compareTo(a.position.y));
          final delta = (live.first.position.x - player.position.x)
              .clamp(-6.0, 6.0);
          player.position.x = (player.position.x + delta)
              .clamp(player.size.x / 2, game.size.x - player.size.x / 2);
        }
      }
      await tester.pump(const Duration(microseconds: 16667));
    }
    await _grab(tester, key, '${name}_$shot');
  }
}

Future<void> _grab(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: kScale);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$kOutDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
