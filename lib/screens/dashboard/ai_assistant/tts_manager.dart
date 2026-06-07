import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../services/overlay_service.dart';
import 'language_detector.dart';

class TTSManager {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  Map<String, dynamic>? _availableVoices;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _availableVoices = await _getAvailableVoices();
      if (Platform.isAndroid) await _tts.awaitSpeakCompletion(true);

      _tts.setCompletionHandler(() => OverlayService().hideAudioPlayer());
      _tts.setCancelHandler(() => OverlayService().hideAudioPlayer());

      _isInitialized = true;
    } catch (error) {
      debugPrint('TTS Initialization Error: $error');
    }
  }

  Future<Map<String, dynamic>> _getAvailableVoices() async {
    try {
      final voices = await _tts.getVoices;
      final voiceMap = <String, dynamic>{'id-ID': [], 'en-US': [], 'en-GB': []};

      if (voices != null && voices is List) {
        for (final voice in voices) {
          if (voice is Map) {
            final locale = voice['locale']?.toString() ?? '';
            final name = voice['name']?.toString() ?? '';
            if (locale.startsWith('id') || name.contains('Indonesia')) {
              voiceMap['id-ID']!.add(voice);
            } else if (locale.startsWith('en-US') ||
                name.contains('United States')) {
              voiceMap['en-US']!.add(voice);
            } else if (locale.startsWith('en')) {
              voiceMap['en-GB']!.add(voice);
            }
          }
        }
      }
      return voiceMap;
    } catch (_) {
      return {};
    }
  }

  Future<void> speak(BuildContext context, String text) async {
    if (!_isInitialized) await initialize();
    if (text.trim().isEmpty) return;

    try {
      await _tts.stop();
      final detectedLang = LanguageDetector.detect(text);
      final success = await _setLanguageWithFallback(detectedLang);

      if (!success) await _tts.setLanguage(detectedLang);

      final cleanText = text
          .replaceAll(RegExp(r'[*#_`~\[\]()]'), '')
          .replaceAll(RegExp(r'\n+'), '. ')
          .trim();

      if (cleanText.isEmpty) return;
      if (!context.mounted) return;

      OverlayService().showAudioPlayer(context, () async {
        await _tts.stop();
      });

      await _tts.speak(cleanText);
    } catch (_) {
      OverlayService().hideAudioPlayer();
    }
  }

  Future<bool> _setLanguageWithFallback(String targetLang) async {
    final fallbackChain = [
      targetLang,
      if (targetLang != 'en-US') 'en-US',
      'en-GB',
    ];
    for (final lang in fallbackChain) {
      try {
        final isAvailable = await _tts.isLanguageAvailable(lang);
        if (isAvailable) {
          await _tts.setLanguage(lang);
          if (Platform.isAndroid && _availableVoices != null) {
            final voices = _availableVoices![lang] as List?;
            if (voices != null && voices.isNotEmpty) {
              try {
                await _tts.setVoice(voices.first);
              } catch (_) {}
            }
          }
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<void> stop() async {
    await _tts.stop();
    OverlayService().hideAudioPlayer();
  }

  void dispose() {
    _tts.stop();
    OverlayService().hideAudioPlayer();
  }
}
