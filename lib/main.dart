import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/space_shooter_game.dart';
import 'ui/overlay_ids.dart';
import 'ui/overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only, edge to edge - this is a one-thumb vertical shooter.
  await Flame.device.fullScreen();
  await Flame.device.setPortrait();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  runApp(const SpaceShooterApp());
}

class SpaceShooterApp extends StatelessWidget {
  const SpaceShooterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Nebula Strike',
      debugShowCheckedModeBanner: false,
      home: GameScreen(),
    );
  }
}

/// Hosts the [GameWidget] and registers every Flutter overlay.
///
/// It also auto-pauses the run when the app loses focus, which is what players
/// expect on mobile.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final SpaceShooterGame _game = SpaceShooterGame();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _game.pauseGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Flame has no MediaQuery, so hand the notch inset to the HUD from here.
    _game.safeTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFF05060F),
      body: GameWidget<SpaceShooterGame>(
        game: _game,
        overlayBuilderMap: <String, Widget Function(BuildContext, SpaceShooterGame)>{
          Overlays.mainMenu: (context, game) => MainMenuOverlay(game: game),
          Overlays.gameOver: (context, game) => GameOverOverlay(game: game),
          Overlays.pauseMenu: (context, game) => PauseOverlay(game: game),
          Overlays.pauseButton: (context, game) => PauseButtonOverlay(game: game),
        },
      ),
    );
  }
}
