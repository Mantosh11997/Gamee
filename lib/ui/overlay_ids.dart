/// Identifiers for the Flutter overlays registered on the `GameWidget`.
///
/// They live in their own file so both the game and the widgets can reference
/// them without importing each other.
class Overlays {
  const Overlays._();

  static const String mainMenu = 'mainMenu';
  static const String gameOver = 'gameOver';
  static const String pauseMenu = 'pauseMenu';
  static const String pauseButton = 'pauseButton';
}
