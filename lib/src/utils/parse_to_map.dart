import 'dart:convert';
import 'dart:developer';

/// تحويل نص خام إلى Map قابل للاستخدام.
/// تعالج booleans و single quotes تلقائياً،
/// وتعالج القيم المتداخلة بشكل تكراري (Strings, Maps, Lists).
Map<String, dynamic> parseToMap(String rawData) {
  if (rawData.isEmpty) return {};
  try {
    final cleaned = _cleanRaw(rawData);
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map) return {};
    return _processMap(decoded);
  } catch (e) {
    log('Failed to parse data: $e', name: 'parseToMap');
    return {};
  }
}

/// تنظيف النص الخام
String _cleanRaw(String raw) => raw
    .replaceAll('True', 'true')
    .replaceAll('False', 'false')
    .replaceAll("'", '"');

/// معالجة Map بشكل تكراري
Map<String, dynamic> _processMap(Map map) {
  return map.map((key, value) => MapEntry(
        key.toString(),
        _processValue(value),
      ));
}

/// معالجة أي قيمة بشكل تكراري
dynamic _processValue(dynamic value) {
  if (value is Map) return _processMap(value);
  if (value is List) return value.map(_processValue).toList();
  if (value is String) return _tryParseString(value);
  return value;
}

/// محاولة تحويل String إلى Map أو List إذا كانت تحتوي على JSON
dynamic _tryParseString(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return value;
  try {
    final cleaned = _cleanRaw(trimmed);
    final decoded = jsonDecode(cleaned);
    if (decoded is Map) return _processMap(decoded);
    if (decoded is List) return decoded.map(_processValue).toList();
    return value;
  } catch (_) {
    return value;
  }
}
