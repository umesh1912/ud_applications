import 'package:flutter_tts/flutter_tts.dart';

/// Reads questions aloud with the phone's text-to-speech engine.
class Speaker {
  Speaker._();

  static final FlutterTts _tts = FlutterTts();

  static Future<void> say(String text, String lang) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(lang == 'hi' ? 'hi-IN' : 'en-IN');
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (_) {
      // No TTS engine on this phone — fail quietly; text stays on screen.
    }
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
