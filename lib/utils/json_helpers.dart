import 'dart:convert';

class JsonHelpers {
  static String? parseString(Map<String, dynamic>? json, String key) {
    return json?[key] as String?;
  }

  static int? parseInt(Map<String, dynamic>? json, String key) {
    final value = json?[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static double? parseDouble(Map<String, dynamic>? json, String key) {
    final value = json?[key];
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool? parseBool(Map<String, dynamic>? json, String key) {
    return json?[key] as bool?;
  }

  static DateTime? parseDateTime(Map<String, dynamic>? json, String key) {
    final value = json?[key];
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<String> parseStringList(Map<String, dynamic>? json, String key) {
    final value = json?[key];
    if (value == null) return [];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  static Map<String, dynamic> parseJsonMap(
    Map<String, dynamic>? json,
    String key,
  ) {
    final value = json?[key];
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      try {
        return Map<String, dynamic>.from(jsonDecode(value));
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  static List<Map<String, dynamic>> parseJsonList(
    Map<String, dynamic>? json,
    String key,
  ) {
    final value = json?[key];
    if (value == null) return [];
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
