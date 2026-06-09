import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../main.dart';

enum AppHapticType { selection, light, medium, heavy }

class HapticService {
  static const MethodChannel _channel = MethodChannel('sapa_pnj/haptics');

  static Future<void> selectionClick() => _perform(AppHapticType.selection);

  static Future<void> lightImpact() => _perform(AppHapticType.light);

  static Future<void> mediumImpact() => _perform(AppHapticType.medium);

  static Future<void> heavyImpact() => _perform(AppHapticType.heavy);

  static Future<void> _perform(AppHapticType type) async {
    if (!hapticNotifier.value) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod<void>('impact', {'type': type.name});
        return;
      }

      await _flutterHaptic(type);
    } catch (_) {
      await _flutterHaptic(type);
    }
  }

  static Future<void> _flutterHaptic(AppHapticType type) {
    switch (type) {
      case AppHapticType.selection:
        return HapticFeedback.selectionClick();
      case AppHapticType.light:
        return HapticFeedback.lightImpact();
      case AppHapticType.medium:
        return HapticFeedback.mediumImpact();
      case AppHapticType.heavy:
        return HapticFeedback.heavyImpact();
    }
  }
}
