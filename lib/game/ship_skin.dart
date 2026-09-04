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

/// A heavy secondary weapon: missiles, bombs, atomics.
///
/// Ordnance fires on its own slow cooldown alongside the cannon, flies slower
/// than a bullet, and detonates on impact for splash damage in [blastRadius].
class OrdnanceSpec {
  const OrdnanceSpec({
    required this.name,
    required this.description,
    required this.asset,
    required this.burstAsset,
    required this.damage,
    required this.blastRadius,
    required this.cooldown,
    required this.speed,
    required this.width,
    required this.color,
  });

  final String name;
  final String description;

  /// The projectile sprite.
  final String asset;

  /// The impact effect sprite, scaled to roughly twice [blastRadius].
  final String burstAsset;

  /// Direct damage to whatever it hits.
  final double damage;

  /// Everything within this radius of the impact takes half [damage].
  final double blastRadius;

  /// Seconds between launches.
  final double cooldown;

  final double speed;

  /// On-screen width; height follows the sprite's aspect ratio.
  final double width;

  final Color color;
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
    this.ordnance,
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

  /// Heavy secondary weapon, or null for the light hulls.
  final OrdnanceSpec? ordnance;

  bool get isFree => price == 0;
  bool get hasOrdnance => ordnance != null;

  /// 0-1 bar values for the card's stat rows, scaled against the best ship.
  double get hpBar => (maxHp / 520).clamp(0.0, 1.0);
  double get speedBar => (speed / 400).clamp(0.0, 1.0);
  double get powerBar {
    final cannon = weapon.damageMultiplier * weapon.shotCount;
    final heavy = (ordnance?.damage ?? 0) / 55;
    return ((cannon + heavy) / 22).clamp(0.0, 1.0);
  }

  double get rateBar =>
      (0.30 / weapon.fireIntervalMultiplier / 1.9).clamp(0.0, 1.0);
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
      bulletAsset: SpriteLibrary.bulletPlayerUltra,
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
    ordnance: heavyMissile,
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
      bulletAsset: SpriteLibrary.bulletPlayerUltra,
      bulletColor: Color(0xFFFF8AC4),
    ),
  );

  // --- heavy secondary weapons ---------------------------------------------

  static const OrdnanceSpec heavyMissile = OrdnanceSpec(
    name: 'HEAVY MISSILE',
    description: 'A slow armoured missile that detonates on impact.',
    asset: SpriteLibrary.missilePlayerHeavy,
    burstAsset: SpriteLibrary.explosionAtomic,
    damage: 55,
    blastRadius: 52,
    cooldown: 2.2,
    speed: 320,
    width: 26,
    color: Color(0xFF7DF9FF),
  );

  static const OrdnanceSpec clusterMissile = OrdnanceSpec(
    name: 'CLUSTER SALVO',
    description: 'Five warheads on one rack. Wide blast, short fuse.',
    asset: SpriteLibrary.missilePlayerCluster,
    burstAsset: SpriteLibrary.explosionAtomic,
    damage: 80,
    blastRadius: 76,
    cooldown: 2.4,
    speed: 300,
    width: 38,
    color: Color(0xFF7DF9FF),
  );

  static const OrdnanceSpec gravityBomb = OrdnanceSpec(
    name: 'GRAVITY BOMB',
    description: 'A reactor-cored bomb. Slow, and it clears a room.',
    asset: SpriteLibrary.bombPlayer,
    burstAsset: SpriteLibrary.attackAtomic,
    damage: 120,
    blastRadius: 104,
    cooldown: 3.0,
    speed: 250,
    width: 40,
    color: Color(0xFF63B3FF),
  );

  static const OrdnanceSpec nuclearBomb = OrdnanceSpec(
    name: 'ATOMIC WARHEAD',
    description: 'Tactical nuke. Everything in the blast simply stops.',
    asset: SpriteLibrary.bombPlayerNuclear,
    burstAsset: SpriteLibrary.attackNova,
    damage: 220,
    blastRadius: 150,
    cooldown: 3.6,
    speed: 235,
    width: 46,
    color: Color(0xFFFFC531),
  );

  // --- heavy hulls ----------------------------------------------------------

  static const ShipSkin battlecruiser = ShipSkin(
    id: 'battlecruiser',
    name: 'BATTLECRUISER',
    callsign: 'Mk V - Line',
    asset: SpriteLibrary.playerMk5,
    price: 6500,
    rarity: 4,
    accent: Color(0xFF4DA6FF),
    width: 74,
    height: 109,
    maxHp: 300,
    speed: 255,
    hitboxWidth: 0.52,
    hitboxHeight: 0.56,
    hitboxCenterY: 0.52,
    ordnance: heavyMissile,
    weapon: WeaponSpec(
      name: 'PLASMA BATTERY',
      description: 'Seven barrels in a broad wall of fire.',
      barrels: <Barrel>[
        Barrel(offset: -0.36, angle: -19),
        Barrel(offset: -0.24, angle: -12),
        Barrel(offset: -0.12, angle: -5),
        Barrel(offset: 0),
        Barrel(offset: 0.12, angle: 5),
        Barrel(offset: 0.24, angle: 12),
        Barrel(offset: 0.36, angle: 19),
      ],
      damageMultiplier: 1.2,
      fireIntervalMultiplier: 1.45,
      bulletAsset: SpriteLibrary.bulletPlayerUltra,
      bulletColor: Color(0xFF8FE4FF),
    ),
  );

  static const ShipSkin carrier = ShipSkin(
    id: 'carrier',
    name: 'CARRIER',
    callsign: 'Mk VI - Fleet',
    asset: SpriteLibrary.playerMk6,
    price: 12000,
    rarity: 4,
    accent: Color(0xFF38D6FF),
    width: 78,
    height: 115,
    maxHp: 360,
    speed: 240,
    hitboxWidth: 0.54,
    hitboxHeight: 0.56,
    hitboxCenterY: 0.52,
    ordnance: clusterMissile,
    weapon: WeaponSpec(
      name: 'LANCE ARRAY',
      description: 'Eight focused lances. Thin, fast, and they bite.',
      barrels: <Barrel>[
        Barrel(offset: -0.38, angle: -17),
        Barrel(offset: -0.27, angle: -11),
        Barrel(offset: -0.16, angle: -5),
        Barrel(offset: -0.05),
        Barrel(offset: 0.05),
        Barrel(offset: 0.16, angle: 5),
        Barrel(offset: 0.27, angle: 11),
        Barrel(offset: 0.38, angle: 17),
      ],
      damageMultiplier: 1.1,
      fireIntervalMultiplier: 1.35,
      bulletAsset: SpriteLibrary.bulletPlayerLaser,
      bulletColor: Color(0xFF9BF1FF),
    ),
  );

  static const ShipSkin superDreadnought = ShipSkin(
    id: 'super_dreadnought',
    name: 'SUPER DREADNOUGHT',
    callsign: 'Mk VII - Siege',
    asset: SpriteLibrary.playerMk7,
    price: 22000,
    rarity: 4,
    accent: Color(0xFFFFC531),
    width: 84,
    height: 128,
    maxHp: 430,
    speed: 225,
    hitboxWidth: 0.56,
    hitboxHeight: 0.58,
    hitboxCenterY: 0.53,
    ordnance: gravityBomb,
    weapon: WeaponSpec(
      name: 'SIEGE LANCES',
      description: 'Nine lances and a bomb bay. A fortress that flies.',
      barrels: <Barrel>[
        Barrel(offset: -0.40, angle: -24),
        Barrel(offset: -0.30, angle: -18),
        Barrel(offset: -0.20, angle: -12),
        Barrel(offset: -0.10, angle: -6),
        Barrel(offset: 0),
        Barrel(offset: 0.10, angle: 6),
        Barrel(offset: 0.20, angle: 12),
        Barrel(offset: 0.30, angle: 18),
        Barrel(offset: 0.40, angle: 24),
      ],
      damageMultiplier: 1.25,
      fireIntervalMultiplier: 1.5,
      bulletAsset: SpriteLibrary.bulletPlayerLaser,
      bulletColor: Color(0xFFFFE08A),
    ),
  );

  static const ShipSkin titan = ShipSkin(
    id: 'titan',
    name: 'TITAN',
    callsign: 'Capital - Apex',
    asset: SpriteLibrary.playerTitan,
    price: 40000,
    rarity: 4,
    accent: Color(0xFFB98BFF),
    width: 92,
    height: 139,
    maxHp: 520,
    speed: 210,
    hitboxWidth: 0.58,
    hitboxHeight: 0.60,
    hitboxCenterY: 0.53,
    ordnance: nuclearBomb,
    weapon: WeaponSpec(
      name: 'APEX BATTERY',
      description: 'Eleven lances and a nuke rack. The last ship you buy.',
      barrels: <Barrel>[
        Barrel(offset: -0.44, angle: -30),
        Barrel(offset: -0.35, angle: -24),
        Barrel(offset: -0.26, angle: -18),
        Barrel(offset: -0.17, angle: -12),
        Barrel(offset: -0.08, angle: -6),
        Barrel(offset: 0),
        Barrel(offset: 0.08, angle: 6),
        Barrel(offset: 0.17, angle: 12),
        Barrel(offset: 0.26, angle: 18),
        Barrel(offset: 0.35, angle: 24),
        Barrel(offset: 0.44, angle: 30),
      ],
      damageMultiplier: 1.3,
      fireIntervalMultiplier: 1.6,
      bulletAsset: SpriteLibrary.bulletPlayerLaser,
      bulletColor: Color(0xFFD9B6FF),
    ),
  );

  /// Display order on the home screen, cheapest first.
  static const List<ShipSkin> all = <ShipSkin>[
    scout,
    interceptor,
    destroyer,
    dreadnought,
    battlecruiser,
    carrier,
    superDreadnought,
    titan,
  ];

  static ShipSkin byId(String id) =>
      all.firstWhere((skin) => skin.id == id, orElse: () => scout);
}
