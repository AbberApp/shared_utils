import 'dart:convert';
import 'dart:developer';

/// تحويل قيمة خام إلى Map قابل للاستخدام.
/// تقبل String أو Map أو null وتعالجها بشكل تكراري.
/// تعالج booleans و single quotes تلقائياً،
/// وتعالج القيم المتداخلة بشكل تكراري (Strings, Maps, Lists).
Map<String, dynamic> parseToMap(dynamic rawData) {
  if (rawData == null) return {};
  if (rawData is Map) return _processMap(rawData);
  if (rawData is String) {
    if (rawData.isEmpty) return {};

    // محاولة أولى: تنظيف عادي
    try {
      final cleaned = _cleanRaw(rawData);
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map) return {};
      return _processMap(decoded);
    } catch (_) {}

    // محاولة ثانية: إصلاح المفاتيح والقيم غير المقتبسة (صيغة Dart/Python toString)
    try {
      final fixed = _fixUnquotedJson(_cleanRaw(rawData));
      final decoded = jsonDecode(fixed);
      if (decoded is! Map) return {};
      return _processMap(decoded);
    } catch (e) {
      log('Failed to parse data: $e', name: 'parseToMap');
      return {};
    }
  }
  return {};
}

/// تنظيف النص الخام
String _cleanRaw(String raw) => raw
    .replaceAll('True', 'true')
    .replaceAll('False', 'false')
    .replaceAll("'", '"');

/// إصلاح صيغة {key: value} غير المقتبسة (ناتج Dart/Python toString)
String _fixUnquotedJson(String s) {
  // اقتباس المفاتيح غير المقتبسة: word chars قبل ':'
  s = s.replaceAllMapped(
    RegExp(r'(?<=[{,]\s*)([A-Za-z_]\w*)(?=\s*:)'),
    (m) => '"${m[1]}"',
  );

  // اقتباس قيم النصوص غير المقتبسة بعد ':'
  // يتجاهل: الأرقام، booleans، null، objects، arrays، القيم المقتبسة مسبقاً
  s = s.replaceAllMapped(
    RegExp(r'(:\s*)([^"{}\[\],\s][^,}\]"]*)(\s*(?=[,}]))'),
    (m) {
      final v = (m[2] ?? '').trim();
      if (v == 'true' || v == 'false' || v == 'null') return '${m[1]}$v${m[3]}';
      if (double.tryParse(v) != null) return '${m[1]}$v${m[3]}';
      return '${m[1]}"$v"${m[3]}';
    },
  );

  return s;
}

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
  if (value is String) {
    // تحويل boolean strings (Python/Dart) إلى bool حقيقي
    if (value == 'True' || value == 'true') return true;
    if (value == 'False' || value == 'false') return false;
    return _tryParseString(value);
  }
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
