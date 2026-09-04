import 'package:flutter/material.dart';

import 'sprite_library.dart';

/// One muzzle on a ship: where it sits and which way it points.
class Barrel {
  const Barrel({required this.offset, this.angle = 0});

  /// Horizontal muzzle position as a fraction of the ship's width, measured
  /// from the centreline. -0.25 is a quarter of the way out to the left.
  final double offset;

  /// Degrees away from straight up; positive leans right.
  final double angle;
}

/// How a skin's cannon lays out one volley. `Player._fire()` walks [barrels]
/// and emits one bullet per entry.
class WeaponSpec {
  const WeaponSpec({
    required this.name,
    required this.description,
    required this.barrels,
    required this.damageMultiplier,
    required this.fireIntervalMultiplier,
    required this.bulletAsset,
    required this.bulletColor,
  });

  /// Shown on the skin card, e.g. "Twin Plasma".
  final String name;

  /// One line of flavour explaining what the weapon does.
  final String description;

  final List<Barrel> barrels;

  final double damageMultiplier;

  /// Below 1 shoots faster than the base cadence, above 1 slower.
  final double fireIntervalMultiplier;

  final String bulletAsset;

  /// Used for the code-drawn bullet and the card's weapon chip.
  final Color bulletColor;

  int get shotCount => barrels.length;
}

/// One entry in the hangar: a ship the player can look at, unlock and fly.
///
/// Locked skins are fully browsable - art, stats and weapon are all visible
/// before you own one. That is the point of the home screen.
class ShipSkin {
  const ShipSkin({
    required this.id,
    required this.name,
    required this.callsign,
    required this.asset,
    required this.price,
    required this.rarity,
    required this.accent,
    required this.width,
    required this.height,
    required this.maxHp,
    required this.speed,
    required this.weapon,
    required this.hitboxWidth,
    required this.hitboxHeight,
    required this.hitboxCenterY,
  });

  /// Stable key used in saved data. Never change one after release.
  final String id;

  final String name;

  /// Short subtitle, e.g. "Mk I - Recon".
  final String callsign;

  final String asset;

  /// Coin cost. Zero means owned from the start.
  final int price;

  /// 1-4 stars, purely cosmetic ranking on the card.
  final int rarity;

  /// Drives the card trim, the ship's glow and its explosion colour.
  final Color accent;

  final double width;
  final double height;

  final double maxHp;
  final double speed;

  final WeaponSpec weapon;

  final double hitboxWidth;
  final double hitboxHeight;
  final double hitboxCenterY;

  bool get isFree => price == 0;

  /// 0-1 bar values for the card's stat rows, scaled against the best ship.
  double get hpBar => (maxHp / 220).clamp(0.0, 1.0);
  double get speedBar => (speed / 420).clamp(0.0, 1.0);
  double get powerBar => (weapon.damageMultiplier * weapon.shotCount / 7)
      .clamp(0.0, 1.0);
  double get rateBar => (0.30 / weapon.fireIntervalMultiplier / 1.6)
      .clamp(0.0, 1.0);
}

/// The hangar catalogue.
///
/// Only the first entry is free; everything else is locked behind coins and
/// exists purely to be admired until then. Adding a ship is one entry here plus
/// its PNG - nothing else in the game needs to change.
class ShipCatalog {
  const ShipCatalog._();

  static const ShipSkin scout = ShipSkin(
    id: 'scout',
    name: 'SCOUT',
    callsign: 'Mk I - Recon',
    asset: SpriteLibrary.player,
    price: 0,
    rarity: 1,
    accent: Color(0xFF56E1FF),
    width: 64,
    height: 68,
    maxHp: 100,
    speed: 340,
    hitboxWidth: 0.42,
    hitboxHeight: 0.60,
    hitboxCenterY: 0.44,
    weapon: WeaponSpec(
      name: 'PULSE CANNON',
      description: 'A single fast bolt straight up the centreline.',
      barrels: <Barrel>[Barrel(offset: 0)],
      damageMultiplier: 1,
      fireIntervalMultiplier: 1,
      bulletAsset: SpriteLibrary.bulletPlayer,
      bulletColor: Color(0xFF7DF9FF),
    ),
  );

  static const ShipSkin interceptor = ShipSkin(
    id: 'interceptor',
    name: 'INTERCEPTOR',
    callsign: 'Mk II - Strike',
    asset: SpriteLibrary.playerMk2,
    price: 400,
    rarity: 2,
    accent: Color(0xFF63B3FF),
    width: 68,
    height: 72,
    maxHp: 120,
    speed: 370,
    hitboxWidth: 0.42,
    hitboxHeight: 0.60,
    hitboxCenterY: 0.44,
    weapon: WeaponSpec(
      name: 'TWIN PLASMA',
      description: 'Two parallel barrels. Double the bolts, same cadence.',
      barrels: <Barrel>[Barrel(offset: -0.22), Barrel(offset: 0.22)],
      damageMultiplier: 0.9,
      fireIntervalMultiplier: 1,
      bulletAsset: SpriteLibrary.bulletPlayer,
      bulletColor: Color(0xFF7DF9FF),
    ),
  );

  static const ShipSkin destroyer = ShipSkin(
    id: 'destroyer',
    name: 'DESTROYER',
    callsign: 'Mk III - Assault',
    asset: SpriteLibrary.playerMk3,
    price: 1200,
    rarity: 3,
    accent: Color(0xFFFFC531),
    width: 76,
    height: 80,
    maxHp: 160,
    speed: 315,
    hitboxWidth: 0.46,
    hitboxHeight: 0.62,
    hitboxCenterY: 0.46,
    weapon: WeaponSpec(
      name: 'TRI-SPREAD',
      description: 'Three heavy bolts in a fan. Slower, and it hurts.',
      barrels: <Barrel>[
        Barrel(offset: -0.26, angle: -11),
        Barrel(offset: 0),
        Barrel(offset: 0.26, angle: 11),
      ],
      damageMultiplier: 1.25,
      fireIntervalMultiplier: 1.18,
      bulletAsset: SpriteLibrary.bulletPlayerHeavy,
      bulletColor: Color(0xFFFFD86B),
    ),
  );

  static const ShipSkin dreadnought = ShipSkin(
    id: 'dreadnought',
    name: 'DREADNOUGHT',
    callsign: 'Mk IV - Siege',
    asset: SpriteLibrary.playerMk4,
    price: 3000,
    rarity: 4,
    accent: Color(0xFFFF5FA2),
    width: 88,
    height: 92,
    maxHp: 220,
    speed: 275,
    hitboxWidth: 0.50,
    hitboxHeight: 0.64,
    hitboxCenterY: 0.48,
    weapon: WeaponSpec(
      name: 'SIEGE BATTERY',
      description: 'Five barrels in a wide arc. Nothing survives the front.',
      barrels: <Barrel>[
        Barrel(offset: -0.34, angle: -20),
        Barrel(offset: -0.17, angle: -10),
        Barrel(offset: 0),
        Barrel(offset: 0.17, angle: 10),
        Barrel(offset: 0.34, angle: 20),
      ],
      damageMultiplier: 1.15,
      fireIntervalMultiplier: 1.35,
      bulletAsset: SpriteLibrary.bulletPlayerHeavy,
      bulletColor: Color(0xFFFF8AC4),
    ),
  );

  /// Display order on the home screen, cheapest first.
  static const List<ShipSkin> all = <ShipSkin>[
    scout,
    interceptor,
    destroyer,
    dreadnought,
  ];

  static ShipSkin byId(String id) =>
      all.firstWhere((skin) => skin.id == id, orElse: () => scout);
}
