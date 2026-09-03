import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/space_shooter_game.dart';

/// Shared chrome for the full-screen menu overlays: a dark scrim over the live
/// game, a glowing title and a stack of content.
class _MenuScrim extends StatelessWidget {
  const _MenuScrim({required this.children, this.onTap});

  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xE605060F), Color(0xF212082B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Title text with a soft neon glow, drawn entirely in Flutter.
class _NeonTitle extends StatelessWidget {
  const _NeonTitle(this.text, {this.size = 44, this.color = GameConfig.playerGlow});

  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: size * 0.12,
        shadows: <Shadow>[
          Shadow(color: color, blurRadius: 24),
          Shadow(color: color.withValues(alpha: 0.6), blurRadius: 48),
        ],
      ),
    );
  }
}

/// Primary action button used on the menus.
class _NeonButton extends StatelessWidget {
  const _NeonButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const Color color = GameConfig.playerGlow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF05060F),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Title screen. Tapping anywhere starts a run.
class MainMenuOverlay extends StatelessWidget {
  const MainMenuOverlay({required this.game, super.key});

  final SpaceShooterGame game;

  @override
  Widget build(BuildContext context) {
    return _MenuScrim(
      onTap: game.startGame,
      children: <Widget>[
        const _NeonTitle('NEBULA\nSTRIKE'),
        const SizedBox(height: 16),
        Text(
          'Survive the waves',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 48),
        const _PulsingHint(),
        const SizedBox(height: 40),
        const _InstructionRow(
          icon: Icons.gamepad_outlined,
          text: 'Drag the joystick to fly',
        ),
        const SizedBox(height: 10),
        const _InstructionRow(
          icon: GameConfig.autoFire
              ? Icons.auto_mode
              : Icons.radio_button_checked,
          text: GameConfig.autoFire
              ? 'Your cannons fire automatically'
              : 'Hold FIRE to shoot',
        ),
        const SizedBox(height: 10),
        const _InstructionRow(
          icon: Icons.bolt,
          text: 'Grab drops for health & rapid fire',
        ),
        const SizedBox(height: 18),
        MuteButton(game: game, label: true),
      ],
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: GameConfig.playerGlow),
        const SizedBox(width: 10),
        // Flexible so long strings wrap on narrow screens instead of
        // overflowing the row.
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Tap to play" prompt that breathes so it reads as interactive.
class _PulsingHint extends StatefulWidget {
  const _PulsingHint();

  @override
  State<_PulsingHint> createState() => _PulsingHintState();
}

class _PulsingHintState extends State<_PulsingHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: const Text(
        'TAP TO PLAY',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
        ),
      ),
    );
  }
}

/// Small translucent circular icon button, used for the in-game controls.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Speaker toggle. Stateful so the icon flips the moment it is tapped -
/// overlays are not rebuilt by the game loop.
class MuteButton extends StatefulWidget {
  const MuteButton({required this.game, this.label = false, super.key});

  final SpaceShooterGame game;

  /// When true, renders as a labelled text row instead of a bare icon.
  final bool label;

  @override
  State<MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<MuteButton> {
  void _toggle() {
    setState(widget.game.audio.toggleMuted);
  }

  @override
  Widget build(BuildContext context) {
    final muted = widget.game.audio.muted;
    final icon = muted ? Icons.volume_off_rounded : Icons.volume_up_rounded;
    if (!widget.label) {
      return _RoundIconButton(
        icon: icon,
        onPressed: _toggle,
        tooltip: muted ? 'Unmute' : 'Mute',
      );
    }
    return TextButton.icon(
      onPressed: _toggle,
      icon: Icon(icon, size: 18, color: GameConfig.playerGlow),
      label: Text(
        muted ? 'SOUND OFF' : 'SOUND ON',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

/// Shown when the player ship is destroyed.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.game, super.key});

  final SpaceShooterGame game;

  @override
  Widget build(BuildContext context) {
    return _MenuScrim(
      children: <Widget>[
        const _NeonTitle('GAME OVER', size: 38, color: GameConfig.hpGood),
        const SizedBox(height: 28),
        _StatRow(label: 'SCORE', value: '${game.scores.score}'),
        _StatRow(label: 'BEST', value: '${game.scores.best}'),
        _StatRow(label: 'WAVE REACHED', value: '${game.waves.wave}'),
        _StatRow(label: 'ENEMIES DOWN', value: '${game.scores.enemiesDestroyed}'),
        const SizedBox(height: 36),
        _NeonButton(label: 'RESTART', onPressed: game.startGame),
        const SizedBox(height: 12),
        TextButton(
          onPressed: game.returnToMenu,
          child: Text(
            'MAIN MENU',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              letterSpacing: 2,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pause menu. The Flame engine is stopped while this is up.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({required this.game, super.key});

  final SpaceShooterGame game;

  @override
  Widget build(BuildContext context) {
    return _MenuScrim(
      children: <Widget>[
        const _NeonTitle('PAUSED', size: 34),
        const SizedBox(height: 32),
        _NeonButton(label: 'RESUME', onPressed: game.resumeGame),
        const SizedBox(height: 4),
        MuteButton(game: game, label: true),
        const SizedBox(height: 4),
        TextButton(
          onPressed: game.returnToMenu,
          child: Text(
            'QUIT TO MENU',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Mute and pause, shown top-centre while a run is in progress.
class PauseButtonOverlay extends StatelessWidget {
  const PauseButtonOverlay({required this.game, super.key});

  final SpaceShooterGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MuteButton(game: game),
              const SizedBox(width: 10),
              _RoundIconButton(
                icon: Icons.pause,
                onPressed: game.pauseGame,
                tooltip: 'Pause',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
