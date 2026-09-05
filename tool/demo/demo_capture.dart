// Renders a scripted demo of the real game and writes one PNG per frame.
//
// This is not a unit test - it is a capture harness, and it lives outside
// test/ on purpose so `flutter test` (and CI) never picks it up: a run takes
// four minutes and writes ~600MB of frames. Drive it explicitly:
//
//   flutter test tool/demo/demo_capture.dart   # -> build/demo_frames/*.png
//   ./tool/build_demo_video.sh                 # -> build/nebula_strike_demo.mp4
//
// The gameplay is genuine: real components, real collisions, real physics and
// the real wave manager running underneath. Only the *inputs* are scripted -
// a director swaps hulls, seeds each hostile type, and steers the ship.
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
import 'package:space_shooter/components/powerup.dart';
import 'package:space_shooter/game/audio.dart';
import 'package:space_shooter/game/config.dart';
import 'package:space_shooter/game/ship_skin.dart';
import 'package:space_shooter/game/space_shooter_game.dart';
import 'package:space_shooter/game/sprite_library.dart';
import 'package:space_shooter/ui/home_screen.dart';
import 'package:space_shooter/ui/overlay_ids.dart';
import 'package:space_shooter/ui/overlays.dart';

const int kFps = 30;
const int kSeconds = 30;
const double kCaptureScale = 2; // 380x820 logical -> 760x1640 video
const String kOutDir = 'build/demo_frames';

/// One beat of the demo: a hull, the hostiles to throw at it, and a caption.
class Beat {
  const Beat(this.skin, this.caption, this.hostiles);
  final ShipSkin skin;
  final String caption;
  final List<EnemyType> hostiles;
}

const List<Beat> kBeats = <Beat>[
  Beat(ShipCatalog.scout, 'MK I - SCOUT', <EnemyType>[
    EnemyType.basic, EnemyType.basic, EnemyType.fast, EnemyType.basic,
  ]),
  Beat(ShipCatalog.interceptor, 'MK II - INTERCEPTOR', <EnemyType>[
    EnemyType.fast, EnemyType.heavy, EnemyType.basic, EnemyType.fast,
  ]),
  Beat(ShipCatalog.destroyer, 'MK III - DESTROYER', <EnemyType>[
    EnemyType.heavy, EnemyType.tank, EnemyType.fast, EnemyType.heavy,
  ]),
  Beat(ShipCatalog.dreadnought, 'MK IV - DREADNOUGHT', <EnemyType>[
    EnemyType.basicElite, EnemyType.fastElite, EnemyType.basic,
    EnemyType.basicElite,
  ]),
  Beat(ShipCatalog.battlecruiser, 'MK V - BATTLECRUISER', <EnemyType>[
    EnemyType.tankElite, EnemyType.tank, EnemyType.heavy, EnemyType.fastElite,
  ]),
  Beat(ShipCatalog.carrier, 'MK VI - CARRIER', <EnemyType>[
    EnemyType.bomber, EnemyType.drone, EnemyType.fastElite, EnemyType.drone,
  ]),
  Beat(ShipCatalog.superDreadnought, 'MK VII - SUPER DREADNOUGHT', <EnemyType>[
    EnemyType.assault, EnemyType.drone, EnemyType.bomber, EnemyType.tankElite,
  ]),
  Beat(ShipCatalog.titan, 'CAPITAL - TITAN', <EnemyType>[
    EnemyType.boss, EnemyType.basicElite, EnemyType.assault, EnemyType.drone,
  ]),
];

void main() {
  final captureKey = GlobalKey();

  testWidgets('capture demo', (tester) async {
    // Real type, not the test framework's placeholder glyphs.
    final robotoDir = Directory(
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
      '/bin/cache/artifacts/material_fonts',
    );
    for (final face in <String>['Roboto-Regular', 'Roboto-Bold', 'Roboto-Black']) {
      final file = File('${robotoDir.path}/$face.ttf');
      if (file.existsSync()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future<ByteData>.value(
              ByteData.sublistView(file.readAsBytesSync()),
            ),
          );
        await loader.load();
      }
    }
    // ...and the icon font, or the pause and mute controls render as boxes.
    final iconFile = File('${robotoDir.path}/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(
          Future<ByteData>.value(
            ByteData.sublistView(iconFile.readAsBytesSync()),
          ),
        );
      await loader.load();
    }
    GameConfig.fontFamily = 'Roboto';

    AudioManager.enabled = false;
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

    // Let onLoad finish and decode every sprite.
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

    game.profile.addCoins(999999);
    for (final skin in ShipCatalog.all) {
      game.profile.unlock(skin);
    }
    game.profile.equip(ShipCatalog.scout);
    game.startGame();
    await tester.pump(const Duration(milliseconds: 16));

    final outDir = Directory(kOutDir);
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }
    outDir.createSync(recursive: true);

    final director = _Director(game, tester);
    final totalFrames = kFps * kSeconds;
    for (var frame = 0; frame < totalFrames; frame++) {
      director.tick(frame, totalFrames);
      // Two 60fps simulation steps per captured frame: the video is 30fps but
      // the physics still runs at the rate the game was tuned for.
      await tester.pump(const Duration(microseconds: 16667));
      await tester.pump(const Duration(microseconds: 16667));
      await _grab(tester, captureKey, '$kOutDir/f${frame.toString().padLeft(5, '0')}.png');
    }

    stdout.writeln('captured $totalFrames frames into $kOutDir');
  }, timeout: const Timeout(Duration(minutes: 25)));
}

Future<void> _grab(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: kCaptureScale);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

/// Drives the demo: swaps hulls on the beat, seeds hostiles, keeps the ship
/// alive and aims it at whatever is closest to the bottom of the screen.
class _Director {
  _Director(this.game, this.tester);

  final SpaceShooterGame game;
  final WidgetTester tester;

  int _beatIndex = -1;
  int _seeded = 0;

  void tick(int frame, int totalFrames) {
    final framesPerBeat = totalFrames ~/ kBeats.length;
    final beat = frame ~/ framesPerBeat;
    final within = frame % framesPerBeat;

    if (beat != _beatIndex && beat < kBeats.length) {
      _beatIndex = beat;
      _seeded = 0;
      _swapHull(kBeats[beat]);
    }

    final current = kBeats[_beatIndex.clamp(0, kBeats.length - 1)];

    // Stagger the hostiles across the beat so the screen keeps filling.
    final spawnEvery = (framesPerBeat / (current.hostiles.length + 0.5)).floor();
    if (_seeded < current.hostiles.length && within >= spawnEvery * _seeded) {
      _spawn(current.hostiles[_seeded]);
      _seeded++;
    }

    // One power-up mid-run so the buff shows up on camera.
    if (frame == totalFrames ~/ 2) {
      game.layer.add(
        Powerup(
          type: PowerupType.overdrive,
          position: Vector2(game.size.x * 0.5, 60),
          sprite: game.sprites[PowerupType.overdrive.asset],
        ),
      );
    }

    _steer();
  }

  void _swapHull(Beat beat) {
    game.player?.removeFromParent();
    final player = Player(
      position: Vector2(
        game.size.x / 2,
        game.size.y - GameConfig.playerBottomMargin,
      ),
      sprite: game.sprites[beat.skin.asset],
      skin: beat.skin,
    );
    game.player = player;
    game.layer.add(player);
    game.announce(beat.caption, duration: 2.4);
  }

  void _spawn(EnemyType type) {
    final spec = EnemySpec.specs[type]!;
    final half = spec.width / 2;
    final x = half + 10 + game.rng.nextDouble() * (game.size.x - (half + 10) * 2);
    game.layer.add(
      Enemy(
        type: type,
        position: Vector2(x, -spec.height),
        sprite: game.sprites[spec.asset],
        // Slowed a touch so each hostile stays on screen long enough to read.
        speedMultiplier: 0.72,
        canShoot: true,
      ),
    );
  }

  void _steer() {
    final player = game.player;
    if (player == null) {
      return;
    }
    // Keep the demo running: top up before the ship can actually die.
    if (player.hp < player.maxHp * 0.45) {
      player.heal(player.maxHp);
    }

    final live = game.layer.children
        .whereType<Enemy>()
        .where((e) => !e.isDying)
        .toList();
    if (live.isEmpty) {
      return;
    }
    // Chase whichever hostile is furthest down the screen so shots connect.
    live.sort((a, b) => b.position.y.compareTo(a.position.y));
    final target = live.first.position.x;
    final delta = (target - player.position.x).clamp(-5.0, 5.0);
    player.position.x = (player.position.x + delta)
        .clamp(player.size.x / 2, game.size.x - player.size.x / 2);
  }
}
