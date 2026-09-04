import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../components/enemy.dart';
import '../game/audio.dart';
import '../game/config.dart';
import '../game/player_profile.dart';
import '../game/ship_skin.dart';
import '../game/space_shooter_game.dart';

/// The hangar: the game's home screen.
///
/// Everything in the catalogue is browsable whether or not it is owned - art,
/// stats and weapon are all on show for locked ships, with the price on the
/// card. Coins come from playing; unlocking equips the ship immediately.
///
/// It renders over the live game, so the parallax starfield keeps drifting
/// behind the scrim.
class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.game, super.key});

  final SpaceShooterGame game;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _viewportFraction = 0.62;

  late final PageController _pages;
  late int _selected;

  /// Which half of the hangar is showing: your fleet, or the threat codex.
  bool _showingHostiles = false;

  @override
  void initState() {
    super.initState();
    // Open on the ship the player is already flying.
    _selected = ShipCatalog.all.indexWhere(
      (skin) => skin.id == widget.game.profile.equipped.id,
    );
    if (_selected < 0) {
      _selected = 0;
    }
    _pages = PageController(
      viewportFraction: _viewportFraction,
      initialPage: _selected,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _unlock(ShipSkin skin) {
    if (widget.game.profile.unlock(skin)) {
      widget.game.audio.play(AudioManager.powerupRapidFire);
    }
  }

  void _equip(ShipSkin skin) {
    if (widget.game.profile.equip(skin)) {
      widget.game.audio.play(AudioManager.powerupHealth, volume: 0.7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.game.profile;

    return DecoratedBox(
      // Let the starfield glimmer through the top of the scrim.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xD905060F), Color(0xF20A0A1E), Color(0xFA12082B)],
          stops: <double>[0, 0.45, 1],
        ),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: profile,
          builder: (context, _) {
            final skin = ShipCatalog.all[_selected];
            return Column(
              children: <Widget>[
                _TopBar(game: widget.game),
                const _Title(),
                _RecordRow(
                  bestScore: profile.bestScore,
                  bestWave: profile.bestWave,
                ),
                const SizedBox(height: 10),
                _TabBar(
                  showingHostiles: _showingHostiles,
                  onChanged: (value) =>
                      setState(() => _showingHostiles = value),
                ),
                Expanded(
                  child: _showingHostiles
                      ? const _HostileCodex()
                      : _buildFleet(skin),
                ),
                _ActionBar(
                  skin: skin,
                  profile: profile,
                  hideShipActions: _showingHostiles,
                  onUnlock: () => _unlock(skin),
                  onEquip: () => _equip(skin),
                  onPlay: widget.game.startGame,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFleet(ShipSkin skin) {
    // Centre the block when it is shorter than the viewport, and let it scroll
    // on a short screen instead of overflowing.
    // The detail block takes the height it needs and the carousel claims
    // everything else, so the ship is drawn as large as the screen allows
    // instead of floating in a fixed-height box with dead space around it.
    return Column(
      children: <Widget>[
        const SizedBox(height: 6),
        Expanded(child: _buildCarousel()),
        const SizedBox(height: 8),
        _ShipDetail(skin: skin),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCarousel() {
    return PageView.builder(
      controller: _pages,
      itemCount: ShipCatalog.all.length,
      onPageChanged: (index) => setState(() => _selected = index),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _pages,
          builder: (context, child) {
            // Neighbours sit slightly smaller and dimmer so the focused ship
            // reads as the subject.
            final page = _pages.hasClients && _pages.position.haveDimensions
                ? _pages.page ?? _selected.toDouble()
                : _selected.toDouble();
            final distance = (page - index).abs().clamp(0.0, 1.0);
            final scale = 1 - distance * 0.18;
            return Transform.scale(
              scale: scale,
              child: Opacity(opacity: 1 - distance * 0.45, child: child),
            );
          },
          child: _ShipCard(
            skin: ShipCatalog.all[index],
            owned: widget.game.profile.isOwned(ShipCatalog.all[index]),
            equipped: widget.game.profile.isEquipped(ShipCatalog.all[index]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- chrome ----

class _TopBar extends StatefulWidget {
  const _TopBar({required this.game});

  final SpaceShooterGame game;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  @override
  Widget build(BuildContext context) {
    final muted = widget.game.audio.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: <Widget>[
          _GlassCircle(
            icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            onTap: () => setState(widget.game.audio.toggleMuted),
            semanticLabel: muted ? 'Unmute' : 'Mute',
          ),
          const Spacer(),
          _CoinPill(coins: widget.game.profile.coins),
        ],
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Coin balance, top right.
class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: GameConfig.rapidFireColor.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _CoinIcon(size: 20),
          const SizedBox(width: 8),
          Text(
            _formatCoins(coins),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCoins(int value) {
  if (value < 1000) {
    return '$value';
  }
  final thousands = value / 1000;
  return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}k';
}

/// Code-drawn coin so the shop needs no extra art.
class _CoinIcon extends StatelessWidget {
  const _CoinIcon({this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinPainter()),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0xFFFFE9A3), Color(0xFFFFB020)],
      ).createShader(Rect.fromCircle(center: centre, radius: radius));
    canvas.drawCircle(centre, radius, paint);
    canvas.drawCircle(
      centre,
      radius * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.16
        ..color = const Color(0x667A4A00),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        'NEBULA STRIKE',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          shadows: <Shadow>[
            const Shadow(color: GameConfig.playerGlow, blurRadius: 22),
            Shadow(
              color: GameConfig.playerGlow.withValues(alpha: 0.5),
              blurRadius: 44,
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented switch between the player's fleet and the enemy codex.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.showingHostiles, required this.onChanged});

  final bool showingHostiles;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: <Widget>[
            _tab('FLEET', Icons.rocket_launch_rounded,
                !showingHostiles, GameConfig.playerGlow, () => onChanged(false)),
            _tab('HOSTILES', Icons.warning_amber_rounded,
                showingHostiles, GameConfig.hpGood, () => onChanged(true)),
          ],
        ),
      ),
    );
  }

  Widget _tab(
    String label,
    IconData icon,
    bool active,
    Color accent,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? accent.withValues(alpha: 0.7) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 15,
                color: active ? accent : Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.bestScore, required this.bestWave});

  final int bestScore;
  final int bestWave;

  @override
  Widget build(BuildContext context) {
    if (bestScore <= 0) {
      return Text(
        'NO RUNS YET',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          letterSpacing: 3,
        ),
      );
    }
    return Text(
      'BEST $bestScore  ·  WAVE $bestWave',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
        letterSpacing: 3,
      ),
    );
  }
}

// ------------------------------------------------------------- ship card ----

class _ShipCard extends StatelessWidget {
  const _ShipCard({
    required this.skin,
    required this.owned,
    required this.equipped,
  });

  final ShipSkin skin;
  final bool owned;
  final bool equipped;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              skin.accent.withValues(alpha: owned ? 0.20 : 0.09),
              Colors.black.withValues(alpha: 0.45),
            ],
          ),
          border: Border.all(
            color: equipped
                ? skin.accent
                : skin.accent.withValues(alpha: owned ? 0.5 : 0.22),
            width: equipped ? 2 : 1,
          ),
          boxShadow: equipped
              ? <BoxShadow>[
                  BoxShadow(
                    color: skin.accent.withValues(alpha: 0.35),
                    blurRadius: 26,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Padding(
                      // Room at the top for the corner badges, none wasted at
                      // the sides - the hull is the point of the card.
                      padding: const EdgeInsets.fromLTRB(6, 30, 6, 2),
                      child: ShipArt(skin: skin, dimmed: !owned),
                    ),
                  ),
                  // Badges sit in the corners rather than over the ship, so a
                  // locked hull is still fully visible - that is what makes it
                  // worth saving up for.
                  if (!owned)
                    Positioned(top: 8, left: 8, child: _PriceTag(skin: skin)),
                  if (equipped)
                    Positioned(top: 8, right: 8, child: _EquippedTag(skin: skin)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      skin.name,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    skin.callsign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _RarityStars(rarity: skin.rarity, accent: skin.accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Padlock and price, tucked into the card's top-left corner.
class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.skin});

  final ShipSkin skin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: GameConfig.rapidFireColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.lock_rounded,
            size: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 5),
          const _CoinIcon(size: 13),
          const SizedBox(width: 5),
          Text(
            '${skin.price}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EquippedTag extends StatelessWidget {
  const _EquippedTag({required this.skin});

  final ShipSkin skin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: skin.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'EQUIPPED',
        style: TextStyle(
          color: Color(0xFF05060F),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _RarityStars extends StatelessWidget {
  const _RarityStars({required this.rarity, required this.accent});

  final int rarity;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              i < rarity ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 12,
              color: i < rarity ? accent : Colors.white.withValues(alpha: 0.22),
            ),
          ),
      ],
    );
  }
}

/// The ship's PNG, or a code-drawn silhouette when the art is not in the build.
///
/// This mirrors the in-game fallback contract: the hangar must stay usable
/// before the new sprites exist.
class ShipArt extends StatelessWidget {
  const ShipArt({required this.skin, this.dimmed = false, super.key});

  final ShipSkin skin;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    // SizedBox.expand matters: it hands tight constraints down, so both the
    // PNG and the CustomPaint fallback fill the card instead of collapsing.
    return SizedBox.expand(
      child: Opacity(
        opacity: dimmed ? 0.86 : 1,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // A soft radial bloom behind the hull. A BoxShadow would give the
            // *box* a rectangular shadow, which reads as a smudge.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: <Color>[
                      skin.accent.withValues(alpha: dimmed ? 0.16 : 0.30),
                      skin.accent.withValues(alpha: 0),
                    ],
                    stops: const <double>[0, 0.72],
                  ),
                ),
              ),
            ),
            Image.asset(
              'assets/images/${skin.asset}',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              // The skin PNGs are optional, exactly as in the game itself.
              errorBuilder: (context, error, stack) => CustomPaint(
                painter: _ShipSilhouettePainter(skin.accent),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShipSilhouettePainter extends CustomPainter {
  _ShipSilhouettePainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hull = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.86, h * 0.74)
      ..lineTo(w * 0.62, h * 0.68)
      ..lineTo(w * 0.5, h * 0.92)
      ..lineTo(w * 0.38, h * 0.68)
      ..lineTo(w * 0.14, h * 0.74)
      ..close();
    canvas.drawPath(hull, Paint()..color = const Color(0xFFDDF6FF));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.44),
        width: w * 0.24,
        height: h * 0.26,
      ),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _ShipSilhouettePainter old) =>
      old.accent != accent;
}

// ----------------------------------------------------------- detail pane ----

class _ShipDetail extends StatelessWidget {
  const _ShipDetail({required this.skin});

  final ShipSkin skin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _StatBar(
                  label: 'HULL',
                  value: skin.hpBar,
                  accent: skin.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBar(
                  label: 'SPEED',
                  value: skin.speedBar,
                  accent: skin.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBar(
                  label: 'POWER',
                  value: skin.powerBar,
                  accent: skin.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBar(
                  label: 'RATE',
                  value: skin.rateBar,
                  accent: skin.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LoadoutPanel(skin: skin),
        ],
      ),
    );
  }
}

/// Small pill used for numeric call-outs.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Every hostile in the game, with the stats that matter and when it starts
/// showing up. Browsable before you ever meet one.
class _HostileCodex extends StatelessWidget {
  const _HostileCodex();

  @override
  Widget build(BuildContext context) {
    final entries = EnemyType.values
        .map((type) => MapEntry(type, EnemySpec.specs[type]!))
        .toList()
      ..sort((a, b) => a.value.firstWave.compareTo(b.value.firstWave));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      itemCount: entries.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _HostileCard(spec: entries[index].value),
    );
  }
}

class _HostileCard extends StatelessWidget {
  const _HostileCard({required this.spec});

  final EnemySpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            spec.color.withValues(alpha: 0.16),
            Colors.black.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: spec.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 62,
            height: 62,
            child: Image.asset(
              'assets/images/${spec.asset}',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Icon(
                Icons.flight_rounded,
                color: spec.color,
                size: 34,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        spec.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    _Chip(
                      label: 'WAVE ${spec.firstWave}+',
                      color: spec.color,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  spec.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: <Widget>[
                    _Chip(label: '${spec.maxHp.toInt()} HP', color: spec.color),
                    _Chip(
                      label: '${spec.speed.toInt()} SPD',
                      color: spec.color,
                    ),
                    _Chip(label: '${spec.score} PTS', color: spec.color),
                    if (spec.fireInterval != null)
                      _Chip(
                        label: 'FIRES ${spec.fireInterval!.toStringAsFixed(1)}s',
                        color: spec.color,
                      )
                    else
                      _Chip(label: 'NO GUNS', color: spec.color),
                    if (spec.weaveAmplitude > 0)
                      _Chip(label: 'WEAVES', color: spec.color),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => LinearProgressIndicator(
              value: t,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),
      ],
    );
  }
}

/// The ship's loadout: its cannon, and its heavy weapon when it has one.
///
/// One bordered block rather than two stacked panels - it reads as a single
/// spec sheet and gives the carousel above it another ~30px of height.
class _LoadoutPanel extends StatelessWidget {
  const _LoadoutPanel({required this.skin});

  final ShipSkin skin;

  @override
  Widget build(BuildContext context) {
    final ordnance = skin.ordnance;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: <Widget>[
          _LoadoutRow(
            art: SizedBox(
              width: 26,
              height: 34,
              child: CustomPaint(
                painter: _VolleyPainter(
                  barrels: skin.weapon.barrels,
                  color: skin.weapon.bulletColor,
                ),
              ),
            ),
            title: skin.weapon.name,
            description: skin.weapon.description,
            color: skin.weapon.bulletColor,
            chips: <String>['×${skin.weapon.shotCount}'],
          ),
          if (ordnance != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            _LoadoutRow(
              art: SizedBox(
                width: 26,
                height: 34,
                child: Image.asset(
                  'assets/images/${ordnance.asset}',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) =>
                      Icon(Icons.rocket_rounded, color: ordnance.color, size: 22),
                ),
              ),
              title: ordnance.name,
              description: ordnance.description,
              color: ordnance.color,
              chips: <String>[
                '${ordnance.damage.toInt()} DMG',
                '${ordnance.cooldown.toStringAsFixed(1)}s',
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadoutRow extends StatelessWidget {
  const _LoadoutRow({
    required this.art,
    required this.title,
    required this.description,
    required this.color,
    required this.chips,
  });

  final Widget art;
  final String title;
  final String description;
  final Color color;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        art,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  for (final chip in chips) ...<Widget>[
                    const SizedBox(width: 5),
                    _Chip(label: chip, color: color),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 10.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Draws the ship's actual volley: one glowing bolt per barrel, at its angle.
class _VolleyPainter extends CustomPainter {
  _VolleyPainter({required this.barrels, required this.color});

  final List<Barrel> barrels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final originX = size.width / 2;
    final originY = size.height;
    final length = size.height * 0.8;

    for (final barrel in barrels) {
      final radians = barrel.angle * math.pi / 180;
      final start = Offset(originX + barrel.offset * size.width * 1.3, originY);
      final end = Offset(
        start.dx + math.sin(radians) * length,
        start.dy - math.cos(radians) * length,
      );
      canvas
        ..drawLine(
          start,
          end,
          Paint()
            ..color = color.withValues(alpha: 0.25)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        )
        ..drawLine(
          start,
          end,
          Paint()
            ..color = color
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _VolleyPainter old) =>
      old.color != color || old.barrels != barrels;
}

// ------------------------------------------------------------ action bar ----

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.skin,
    required this.profile,
    required this.hideShipActions,
    required this.onUnlock,
    required this.onEquip,
    required this.onPlay,
  });

  final ShipSkin skin;
  final PlayerProfile profile;

  /// The codex tab has no ship selected, so the unlock/equip row is dropped.
  final bool hideShipActions;
  final VoidCallback onUnlock;
  final VoidCallback onEquip;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final owned = profile.isOwned(skin);
    final equipped = profile.isEquipped(skin);
    final canAfford = profile.canAfford(skin);
    final shortfall = math.max(0, skin.price - profile.coins);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
      child: Column(
        children: <Widget>[
          if (!hideShipActions) ...<Widget>[
            SizedBox(
              height: 44,
              width: double.infinity,
              child: _secondaryButton(owned, equipped, canAfford, shortfall),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 56,
            width: double.infinity,
            child: FilledButton(
              onPressed: onPlay,
              style: FilledButton.styleFrom(
                backgroundColor: GameConfig.playerGlow,
                foregroundColor: const Color(0xFF05060F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.play_arrow_rounded, size: 26),
                  SizedBox(width: 6),
                  Text(
                    'PLAY',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondaryButton(
    bool owned,
    bool equipped,
    bool canAfford,
    int shortfall,
  ) {
    if (equipped) {
      return Center(
        child: Text(
          'FLYING THE ${skin.name}',
          style: TextStyle(
            color: skin.accent.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
      );
    }

    if (owned) {
      return OutlinedButton(
        onPressed: onEquip,
        style: OutlinedButton.styleFrom(
          foregroundColor: skin.accent,
          side: BorderSide(color: skin.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: const Text(
          'EQUIP',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      );
    }

    // Locked. The button states the price, and says exactly how far short the
    // player is rather than just refusing.
    return FilledButton(
      onPressed: canAfford ? onUnlock : null,
      style: FilledButton.styleFrom(
        backgroundColor: GameConfig.rapidFireColor,
        foregroundColor: const Color(0xFF05060F),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.07),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(canAfford ? Icons.lock_open_rounded : Icons.lock_rounded, size: 17),
          const SizedBox(width: 8),
          Text(
            canAfford ? 'UNLOCK · ${skin.price}' : 'NEED $shortfall MORE',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
