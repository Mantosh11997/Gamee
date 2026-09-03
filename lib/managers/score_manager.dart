/// Keeps the running score for the current run plus a session best.
///
/// Kept deliberately tiny and free of Flame types so it is trivial to swap in
/// persistence (shared_preferences, a backend, ...) later.
class ScoreManager {
  int score = 0;
  int best = 0;
  int enemiesDestroyed = 0;

  /// Registers a kill worth [points].
  void addKill(int points) {
    score += points;
    enemiesDestroyed++;
    if (score > best) {
      best = score;
    }
  }

  /// Clears the run, keeping [best].
  void reset() {
    score = 0;
    enemiesDestroyed = 0;
  }
}
