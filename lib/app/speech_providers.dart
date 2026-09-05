import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/speech_synthesizer.dart';
import 'providers.dart';

/// The language the translation is spoken in. The app ships one translation
/// language, so this is a constant rather than a preference.
const String kSpeechLanguage = 'en-US';

/// Whether this device can speak the translation at all.
///
/// The play button is hidden when it cannot, rather than shown and inert.
final FutureProvider<bool> speechAvailableProvider =
    FutureProvider<bool>((Ref ref) async {
  final SpeechSynthesizer synthesizer = ref.watch(speechSynthesizerProvider);
  return synthesizer.isLanguageAvailable(kSpeechLanguage);
});

/// The id of the hadith currently being spoken, or null when silent.
///
/// Held centrally rather than per-widget so that starting one hadith stops
/// another, and so a hadith scrolled out of view cannot leave a stale button.
class SpeechController extends Notifier<String?> {
  @override
  String? build() {
    // Captured here rather than read inside the callback: Riverpod forbids
    // touching ref from a life-cycle hook.
    final SpeechSynthesizer synthesizer = ref.watch(speechSynthesizerProvider);
    // The reader navigating away should not leave a voice talking.
    ref.onDispose(synthesizer.stop);
    return null;
  }

  /// Speaks [text], or stops if [hadithId] is already speaking.
  Future<void> toggle(String hadithId, String text) async {
    if (state == hadithId) {
      await stop();
      return;
    }

    final SpeechSynthesizer synthesizer = ref.read(speechSynthesizerProvider);
    state = hadithId;
    try {
      await synthesizer.speak(text, languageCode: kSpeechLanguage);
    } on Object {
      // A failed utterance should clear the button, not surface an error over
      // the reading surface.
    } finally {
      // Only clear if this utterance is still the current one: a second tap
      // may have started a different hadith while this was speaking.
      if (state == hadithId) state = null;
    }
  }

  Future<void> stop() async {
    state = null;
    await ref.read(speechSynthesizerProvider).stop();
  }
}

final NotifierProvider<SpeechController, String?> speechControllerProvider =
    NotifierProvider<SpeechController, String?>(SpeechController.new);
