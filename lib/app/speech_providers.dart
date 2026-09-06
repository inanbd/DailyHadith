import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/speech_synthesizer.dart';
import 'providers.dart';

/// The language the translation is spoken in. The app ships one translation
/// language, so this is a constant rather than a preference.
const String kEnglishSpeechLanguage = 'en-US';

/// The language the hadith itself is spoken in.
const String kArabicSpeechLanguage = 'ar-SA';

/// One thing being spoken: which hadith, and in which language.
///
/// The language is part of the identity because a hadith can be read aloud two
/// ways, and only the control that started an utterance should offer to stop
/// it.
@immutable
class SpokenUtterance {
  const SpokenUtterance({required this.hadithId, required this.languageCode});

  final String hadithId;
  final String languageCode;

  @override
  bool operator ==(Object other) =>
      other is SpokenUtterance &&
      other.hadithId == hadithId &&
      other.languageCode == languageCode;

  @override
  int get hashCode => Object.hash(hadithId, languageCode);

  @override
  String toString() => 'SpokenUtterance($hadithId, $languageCode)';
}

/// Whether this device can speak [languageCode] at all.
///
/// The matching play button is hidden when it cannot, rather than shown and
/// inert — an Arabic voice in particular is not installed by default on many
/// devices.
final speechAvailableProvider =
    FutureProvider.family<bool, String>((Ref ref, String languageCode) async {
  final SpeechSynthesizer synthesizer = ref.watch(speechSynthesizerProvider);
  return synthesizer.isLanguageAvailable(languageCode);
});

/// What is currently being spoken, or null when silent.
///
/// Held centrally rather than per-widget so that starting one utterance stops
/// another, and so a hadith scrolled out of view cannot leave a stale button.
class SpeechController extends Notifier<SpokenUtterance?> {
  @override
  SpokenUtterance? build() {
    // Captured here rather than read inside the callback: Riverpod forbids
    // touching ref from a life-cycle hook.
    final SpeechSynthesizer synthesizer = ref.watch(speechSynthesizerProvider);
    // The reader navigating away should not leave a voice talking.
    ref.onDispose(synthesizer.stop);
    return null;
  }

  /// Speaks [text] in [languageCode], or stops if that exact utterance is
  /// already speaking.
  ///
  /// Asking for the Arabic of a hadith whose translation is speaking switches
  /// to the Arabic rather than stopping: the engine replaces what it is
  /// saying, and the reader asked for something different.
  Future<void> toggle(
    String hadithId,
    String text, {
    required String languageCode,
  }) async {
    final SpokenUtterance utterance = SpokenUtterance(
      hadithId: hadithId,
      languageCode: languageCode,
    );
    if (state == utterance) {
      await stop();
      return;
    }

    final SpeechSynthesizer synthesizer = ref.read(speechSynthesizerProvider);
    state = utterance;
    try {
      await synthesizer.speak(text, languageCode: languageCode);
    } on Object {
      // A failed utterance should clear the button, not surface an error over
      // the reading surface.
    } finally {
      // Only clear if this utterance is still the current one: a second tap
      // may have started something else while this was speaking. And only if
      // the controller is still alive — the reader can leave the screen,
      // disposing it, while the engine is mid-sentence.
      if (ref.mounted && state == utterance) state = null;
    }
  }

  Future<void> stop() async {
    state = null;
    await ref.read(speechSynthesizerProvider).stop();
  }
}

final NotifierProvider<SpeechController, SpokenUtterance?>
    speechControllerProvider =
    NotifierProvider<SpeechController, SpokenUtterance?>(SpeechController.new);
