import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ship_skin.dart';

/// Everything that survives between runs: coins, which ships are owned, which
/// one is equipped, and the best score.
///
/// Backed by shared_preferences, but every call degrades gracefully - if the
/// store is unavailable the profile still works for the session and simply
/// forgets on exit, exactly like the audio manager does for sound.
class PlayerProfile extends ChangeNotifier {
  static const String _coinsKey = 'coins';
  static const String _ownedKey = 'ownedSkins';
  static const String _equippedKey = 'equippedSkin';
  static const String _bestScoreKey = 'bestScore';
  static const String _bestWaveKey = 'bestWave';

  SharedPreferences? _prefs;

  /// Tail of the serialised write chain. Await [saved] to be sure everything
  /// has hit disk - useful on shutdown, and required by tests that reload.
  Future<void> _writes = Future<void>.value();
  Future<void> get saved => _writes;

  int _coins = 0;
  int get coins => _coins;

  int _bestScore = 0;
  int get bestScore => _bestScore;

  int _bestWave = 0;
  int get bestWave => _bestWave;

  /// Ids of every owned ship. The free starter is always in here.
  final Set<String> _owned = <String>{ShipCatalog.scout.id};
  Set<String> get owned => Set<String>.unmodifiable(_owned);

  String _equippedId = ShipCatalog.scout.id;
  ShipSkin get equipped => ShipCatalog.byId(_equippedId);

  bool isOwned(ShipSkin skin) => _owned.contains(skin.id);
  bool isEquipped(ShipSkin skin) => skin.id == _equippedId;
  bool canAfford(ShipSkin skin) => _coins >= skin.price;

  /// Loads the saved profile. Never throws.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      _coins = prefs.getInt(_coinsKey) ?? 0;
      _bestScore = prefs.getInt(_bestScoreKey) ?? 0;
      _bestWave = prefs.getInt(_bestWaveKey) ?? 0;
      _owned
        ..clear()
        ..add(ShipCatalog.scout.id)
        ..addAll(prefs.getStringList(_ownedKey) ?? const <String>[]);
      final saved = prefs.getString(_equippedKey);
      // Guard against a ship that was removed from the catalogue, or one the
      // save claims is equipped but not owned.
      if (saved != null && _owned.contains(saved)) {
        _equippedId = ShipCatalog.byId(saved).id;
      }
    } catch (_) {
      // No persistence available - carry on with defaults.
    }
    notifyListeners();
  }

  void addCoins(int amount) {
    if (amount <= 0) {
      return;
    }
    _coins += amount;
    _write((p) => p.setInt(_coinsKey, _coins));
    notifyListeners();
  }

  /// Buys [skin] and equips it. Returns false when it is already owned or the
  /// player cannot afford it.
  bool unlock(ShipSkin skin) {
    if (isOwned(skin) || !canAfford(skin)) {
      return false;
    }
    _coins -= skin.price;
    _owned.add(skin.id);
    _equippedId = skin.id;
    _write((p) async {
      await p.setInt(_coinsKey, _coins);
      await p.setStringList(_ownedKey, _owned.toList());
      await p.setString(_equippedKey, _equippedId);
    });
    notifyListeners();
    return true;
  }

  /// Equips an owned ship. Returns false for a locked one.
  bool equip(ShipSkin skin) {
    if (!isOwned(skin) || isEquipped(skin)) {
      return false;
    }
    _equippedId = skin.id;
    _write((p) => p.setString(_equippedKey, _equippedId));
    notifyListeners();
    return true;
  }

  /// Records the outcome of a run and returns the coins it earned.
  int recordRun({required int score, required int wave, required int kills}) {
    final earned = score ~/ 12 + wave * 15 + kills * 2;
    var dirty = false;
    if (score > _bestScore) {
      _bestScore = score;
      dirty = true;
    }
    if (wave > _bestWave) {
      _bestWave = wave;
      dirty = true;
    }
    if (dirty) {
      _write((p) async {
        await p.setInt(_bestScoreKey, _bestScore);
        await p.setInt(_bestWaveKey, _bestWave);
      });
    }
    addCoins(earned);
    return earned;
  }

  /// Test/debug helper: wipes coins, unlocks and records.
  Future<void> reset() async {
    _coins = 0;
    _bestScore = 0;
    _bestWave = 0;
    _owned
      ..clear()
      ..add(ShipCatalog.scout.id);
    _equippedId = ShipCatalog.scout.id;
    try {
      await _prefs?.clear();
    } catch (_) {
      // Ignored - the in-memory reset above is what matters.
    }
    notifyListeners();
  }

  /// Queues a write. Calls are chained rather than fired in parallel so two
  /// rapid changes cannot land out of order, and a failure never surfaces as
  /// an unhandled error - a lost write costs a saved coin, never a frame.
  void _write(Future<void> Function(SharedPreferences prefs) action) {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    _writes = _writes.then((_) => action(prefs)).catchError((Object _) {});
  }
}
