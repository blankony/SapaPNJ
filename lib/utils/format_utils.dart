import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

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

  static String formatJoinedDate(dynamic rawDate, {required String unknownText, required String joinedPrefix}) {
    if (rawDate == null) return unknownText;

    DateTime? dateTime;
    if (rawDate is String) {
      dateTime = DateTime.tryParse(rawDate);
    }

    if (dateTime == null) return unknownText;
    return '$joinedPrefix ${DateFormat('MMMM yyyy').format(dateTime)}';
  }
}
