import 'package:timeago/timeago.dart' as timeago;

class FormatUtils {
  static String formatTimestamp(dynamic timestamp, {String fallback = "just now", String locale = 'en_short'}) {
    if (timestamp == null) return fallback;
    try {
      final parsedDate = DateTime.parse(timestamp.toString());
      return timeago.format(parsedDate, locale: locale);
    } catch (e) {
      return fallback;
    }
  }
}
