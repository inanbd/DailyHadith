import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/repositories/speech_synthesizer.dart';

/// [SpeechSynthesizer] backed by the platform engine via `flutter_tts`.
///
/// The engine is created lazily: a reader who never presses play never pays
/// for initialising it.
class FlutterTtsSpeechSynthesizer implements SpeechSynthesizer {
  FlutterTtsSpeechSynthesizer({FlutterTts? tts}) : _injected = tts;

  final FlutterTts? _injected;
  FlutterTts? _tts;

  /// Availability is asked once per language and cached. The set of installed
  /// voices does not change while the app is in the foreground, and the query
  /// is a platform channel round trip.
  final Map<String, bool> _availability = <String, bool>{};

  Future<FlutterTts> _engine() async {
    final FlutterTts? existing = _tts;
    if (existing != null) return existing;

    final FlutterTts tts = _injected ?? FlutterTts();
    // Makes `speak` complete when the utterance ends rather than when it
    // starts, which is what lets the UI show a stop button for the duration.
    await tts.awaitSpeakCompletion(true);
    _tts = tts;
    return tts;
  }

  @override
  Future<bool> isLanguageAvailable(String languageCode) async {
    final bool? cached = _availability[languageCode];
    if (cached != null) return cached;

    bool available;
    try {
      final FlutterTts tts = await _engine();
      available = await tts.isLanguageAvailable(languageCode) == true;
    } on Object {
      // A device without a TTS engine throws rather than answering. Treat that
      // as "no voice" so the button is simply not offered.
      available = false;
    }
    _availability[languageCode] = available;
    return available;
  }

  @override
  Future<void> speak(String text, {required String languageCode}) async {
    if (text.trim().isEmpty) return;
    final FlutterTts tts = await _engine();
    await tts.stop();
    await tts.setLanguage(languageCode);
    await tts.speak(text);
  }

  @override
  Future<void> stop() async {
    final FlutterTts? tts = _tts;
    if (tts == null) return;
    await tts.stop();
  }

  @override
  Future<void> dispose() async {
    final FlutterTts? tts = _tts;
    _tts = null;
    if (tts == null) return;
    await tts.stop();
  }
}
