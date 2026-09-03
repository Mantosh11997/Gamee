import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'config.dart';

/// All sound in the game, behind one fail-safe façade.
///
/// Every call is fire-and-forget and every failure is swallowed: if the audio
/// plugin is unavailable (widget tests, a stripped `assets/audio/` folder, a
/// device that refuses the audio session) [available] flips to false and the
/// game simply runs silent. Nothing here can crash or stall gameplay.
class AudioManager {
  // --- file names, all under assets/audio/ ---------------------------------
  static const String shootPlayer = 'shoot_player.wav';
  static const String shootEnemy = 'shoot_enemy.wav';
  static const String enemyHit = 'enemy_hit.wav';
  static const String explosionSmall = 'explosion_small.wav';
  static const String explosionLarge = 'explosion_large.wav';
  static const String playerHit = 'player_hit.wav';
  static const String powerupHealth = 'powerup_health.wav';
  static const String powerupRapidFire = 'powerup_rapidfire.wav';
  static const String waveStart = 'wave_start.wav';
  static const String gameOver = 'game_over.wav';
  static const String music = 'music.mp3';

  static const List<String> sfxFiles = <String>[
    shootPlayer,
    shootEnemy,
    enemyHit,
    explosionSmall,
    explosionLarge,
    playerHit,
    powerupHealth,
    powerupRapidFire,
    waveStart,
    gameOver,
  ];

  /// Global kill switch. Set to false before creating the game to keep the
  /// audio plugin completely untouched - widget tests do this, because
  /// constructing an `AudioPlayer` without a platform behind it produces
  /// unhandled channel errors.
  static bool enabled = true;

  /// False once the audio backend has proven unusable. Never flips back.
  bool _available = true;

  /// True while sound can actually be produced.
  bool get available => enabled && _available;

  bool _muted = false;
  bool get muted => _muted;

  /// Whether music *should* be sounding, ignoring mute. Keeps unmuting honest.
  bool _musicWanted = false;

  /// The player's cannon is by far the most frequent sound - up to ~11 shots a
  /// second under rapid fire. A pool reuses a handful of players instead of
  /// spinning up (and tearing down) one per shot.
  AudioPool? _shotPool;

  /// Preloads every effect and prepares the music player. Safe to await; it
  /// never throws.
  Future<void> init() async {
    if (!enabled) {
      return;
    }
    try {
      await FlameAudio.audioCache.loadAll(sfxFiles);
      _shotPool = await FlameAudio.createPool(
        shootPlayer,
        minPlayers: 2,
        maxPlayers: 6,
      );
      await FlameAudio.bgm.initialize();
    } catch (_) {
      _available = false;
    }
  }

  // ------------------------------------------------------------------ sfx --

  /// Plays a one-shot effect. [volume] is relative to the master SFX volume.
  void play(String file, {double volume = 1}) {
    if (!available || _muted) {
      return;
    }
    unawaited(_playSafely(file, volume));
  }

  /// The pooled variant used for the player's cannon.
  void playShot({double volume = 1}) {
    if (!available || _muted) {
      return;
    }
    final pool = _shotPool;
    if (pool == null) {
      play(shootPlayer, volume: volume);
      return;
    }
    unawaited(_startPoolSafely(pool, volume));
  }

  Future<void> _playSafely(String file, double volume) async {
    try {
      await FlameAudio.play(file, volume: _sfxVolume(volume));
    } catch (_) {
      _available = false;
    }
  }

  Future<void> _startPoolSafely(AudioPool pool, double volume) async {
    try {
      await pool.start(volume: _sfxVolume(volume));
    } catch (_) {
      _available = false;
    }
  }

  double _sfxVolume(double volume) =>
      (volume * GameConfig.sfxVolume).clamp(0.0, 1.0);

  // ---------------------------------------------------------------- music --

  /// Starts the looping music bed. Idempotent.
  void startMusic() {
    _musicWanted = true;
    if (!available || _muted) {
      return;
    }
    unawaited(_guard(() => FlameAudio.bgm.play(
          music,
          volume: GameConfig.musicVolume,
        )));
  }

  void pauseMusic() {
    if (!available || !FlameAudio.bgm.isPlaying) {
      return;
    }
    unawaited(_guard(FlameAudio.bgm.pause));
  }

  void resumeMusic() {
    if (!available || _muted || !_musicWanted || FlameAudio.bgm.isPlaying) {
      return;
    }
    unawaited(_guard(FlameAudio.bgm.resume));
  }

  // ----------------------------------------------------------------- mute --

  /// Silences (or restores) everything. Effects check [muted] before playing;
  /// the music track is paused rather than stopped so it resumes in place.
  void setMuted(bool value) {
    if (_muted == value) {
      return;
    }
    _muted = value;
    if (!available) {
      return;
    }
    if (value) {
      pauseMusic();
    } else if (_musicWanted) {
      // `pause` cleared Bgm.isPlaying, so resume needs the flag re-checked.
      unawaited(_guard(FlameAudio.bgm.resume));
    }
  }

  void toggleMuted() => setMuted(!_muted);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      _available = false;
    }
  }
}
