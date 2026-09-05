/// Speaks text aloud through the platform's text-to-speech engine.
///
/// A seam, like [NotificationScheduler]: the app depends on this interface so
/// tests can run without a real engine, and so a different backend can be
/// dropped in without touching the reading screens.
abstract interface class SpeechSynthesizer {
  /// Whether the device has a usable voice for [languageCode].
  ///
  /// Speaking is offered only when this is true, so the button never appears
  /// on a device that would silently do nothing.
  Future<bool> isLanguageAvailable(String languageCode);

  /// Speaks [text], replacing anything already being spoken.
  ///
  /// Completes when the utterance finishes, or immediately if it is stopped.
  Future<void> speak(String text, {required String languageCode});

  /// Stops the current utterance. Safe to call when nothing is speaking.
  Future<void> stop();

  /// Releases engine resources.
  Future<void> dispose();
}
