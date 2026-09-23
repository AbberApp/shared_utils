import 'dart:convert';
import 'dart:developer';

/// أقصى طول نصّ يُسمح له بدخول المسار الترميميّ [_fixUnquotedJson].
/// تكلفة الـ regex هناك تربيعيّة على نصّ مشوّه طويل، والتنفيذ يجري على الـ UI
/// isolate — فبلا سقفٍ تكفي حمولةٌ واحدة مشوّهة لتجميد الواجهة (ANR).
const int _maxRepairLength = 16 * 1024;

/// حرفيّات Python في موضع القيمة وحدها: بعد ':' أو '[' أو ','، وبشرط أن تكون
/// الكلمة هي القيمة **كاملةً** (يتلوها ',' أو '}' أو ']' أو نهاية النصّ).
/// الاستبدال الأعمى كان يفسد نصوصاً مثل "TrueVision" ومفاتيح مثل isTrueOwner؛
/// وحدّ الكلمة \b وحده لم يكن كافياً لأنّ المسافة حدُّ كلمة، فكانت الجملة
/// «True story» تُخفَّض إلى «true story» رغم أنّها نصّ لا قيمة منطقيّة.
final RegExp _pythonLiteral =
    RegExp(r'(?<=[:\[,]\s*)(True|False|None)(?=\s*(?:[,}\]]|$))');

/// ما تقابله حرفيّات Python في JSON. None كانت مُغفَلة فتصل إلى مسار الإصلاح
/// وتُقتبس نصّاً «None» — قيمةٌ غير-null تنجو من كلّ فحوص الـ null عند المستهلك.
const Map<String, String> _pythonLiterals = {
  'True': 'true',
  'False': 'false',
  'None': 'null',
};

/// مفتاح غير مقتبس (ناتج Dart/Python toString) قبل ':'.
/// الصنف كان [A-Za-z_]\w* لاتينيّاً صرفاً، فالمفتاح العربيّ يبقى بلا اقتباس
/// ويفشل فكّ الترميز وتضيع الحمولة كاملةً — في مكتبةٍ حمولاتها عربية أصلاً.
/// \p{L}/\p{N} مع unicode تشمل كلّ الكتابات لا اللاتينيّة وحدها.
final RegExp _unquotedKey = RegExp(
  r'(?<=[{,]\s*)([\p{L}_][\p{L}\p{N}_]*)(?=\s*:)',
  unicode: true,
);

/// عنصر قائمة غير مقتبس: بعد '[' أو ',' ويتلوه ',' أو ']'.
/// كان الإصلاح يقتبس ما بعد ':' وحده، فعناصر القائمة العارية تبقى بلا اقتباس
/// فيسقط فكّ الخريطة كلّها لا الحقل وحده.
/// ':' مستبعَدٌ من المحتوى عمداً: بدونه يبتلع النمط زوج «مفتاح: قيمة» في كائن
/// بين فاصلتين فيقتبسه كلّه عنصراً واحداً.
/// والمحتوى لا يبتلع مسافاته الذيليّة تجنّباً للتراجع التربيعيّ (كما في
/// [_unquotedValue]).
final RegExp _unquotedListItem = RegExp(
  r'(?<=[\[,]\s*)([^"{}\[\],:\s](?:[^"{}\[\],:]*[^"{}\[\],:\s])?)(?=\s*[,\]])',
);

/// القيمة لا تبتلع مسافاتها الذيليّة، وإلّا تداخلت مع الـ \s* التالية فولّدت
/// تراجعاً تربيعيّاً (قِيس: 40 ألف حرف = 6.9 ثانية قبل الفصل، 1ms بعده).
final RegExp _unquotedValue =
    RegExp(r'(:\s*)([^"{}\[\],\s](?:[^,}\]"]*[^,}\]"\s])?)(\s*(?=[,}]))');

/// نحو رقم JSON الصارم. double.tryParse كان يقبل ما يرفضه jsonDecode
/// (صفر بادئ مثل 0501234567، وInfinity) فيسقط فكّ ترميز الخريطة كلّها.
final RegExp _jsonNumber =
    RegExp(r'^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$');

/// تحويل قيمة خام إلى Map قابل للاستخدام.
/// تقبل String أو Map أو null وتعالجها بشكل تكراري.
/// تعالج booleans و single quotes تلقائياً،
/// وتعالج القيم المتداخلة بشكل تكراري (Strings, Maps, Lists).
///
/// [coerceBooleanStrings] يحوّل النصوص "true"/"false"/"True"/"False" إلى bool
/// حقيقي. افتراضُه true حفاظاً على السلوك القائم؛ مرّر false إن كانت حقولك
/// النصّية قد تحمل هذه الكلمات فعلاً، وإلّا تغيّر نوع الحقل وسقط الـ cast.
Map<String, dynamic> parseToMap(
  dynamic rawData, {
  bool coerceBooleanStrings = true,
}) {
  if (rawData == null) return {};
  if (rawData is Map) return _processMap(rawData, coerceBooleanStrings);
  if (rawData is String) {
    if (rawData.isEmpty) return {};

    // محاولة أولى: النصّ الخام كما هو بلا أيّ تنظيف. التنظيف أدناه هدّام
    // (يحوّل كل ' إلى ")، فلا يجوز أن يمرّ عليه JSON صحيحٌ يحمل اقتباساً
    // مفرداً داخل قيمة — كان يُرجع {} ويضيّع الحمولة كاملةً بلا خطأ.
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map) return _processMap(decoded, coerceBooleanStrings);
    } on Object catch (_) {}

    // محاولة ثانية: تنظيف الاقتباسات وحرفيّات Python
    try {
      final decoded = jsonDecode(_cleanRaw(rawData));
      if (decoded is Map) return _processMap(decoded, coerceBooleanStrings);
    } on Object catch (_) {}

    // محاولة ثالثة: إصلاح المفاتيح والقيم غير المقتبسة (صيغة Dart/Python toString)
    if (rawData.length > _maxRepairLength) {
      log('Payload too large to repair: ${rawData.length}', name: 'parseToMap');
      return {};
    }
    try {
      final decoded = jsonDecode(_fixUnquotedJson(_cleanRaw(rawData)));
      if (decoded is! Map) return {};
      return _processMap(decoded, coerceBooleanStrings);
    } on Object catch (e) {
      log('Failed to parse data: $e', name: 'parseToMap');
      return {};
    }
  }
  return {};
}

/// تنظيف النص الخام — مسارٌ ترميميّ فقط، لا يُطبَّق على JSON صحيح
String _cleanRaw(String raw) => raw
    .replaceAll("'", '"')
    .replaceAllMapped(_pythonLiteral, (m) => _pythonLiterals[m[1]!]!);

/// إصلاح صيغة {key: value} غير المقتبسة (ناتج Dart/Python toString)
String _fixUnquotedJson(String s) {
  // اقتباس المفاتيح غير المقتبسة قبل ':'
  s = s.replaceAllMapped(_unquotedKey, (m) => '"${m[1]}"');

  // اقتباس عناصر القوائم غير المقتبسة — بعد اقتباس المفاتيح لا قبله: عندها
  // يبدأ كلّ مفتاحٍ بـ '"' المستبعَد من النمط، فلا يلتبس بعنصر قائمة.
  s = s.replaceAllMapped(_unquotedListItem, (m) {
    final v = m[1]!;
    if (v == 'true' || v == 'false' || v == 'null') return v;
    if (_jsonNumber.hasMatch(v)) return v;
    return '"$v"';
  });

  // اقتباس قيم النصوص غير المقتبسة بعد ':'
  // يتجاهل: الأرقام، booleans، null، objects، arrays، القيم المقتبسة مسبقاً
  s = s.replaceAllMapped(
    _unquotedValue,
    (m) {
      final v = m[2]!;
      if (v == 'true' || v == 'false' || v == 'null') return '${m[1]}$v${m[3]}';
      if (_jsonNumber.hasMatch(v)) return '${m[1]}$v${m[3]}';
      return '${m[1]}"$v"${m[3]}';
    },
  );

  return s;
}

/// معالجة Map بشكل تكراري
Map<String, dynamic> _processMap(Map map, bool coerceBooleanStrings) {
  return map.map((key, value) => MapEntry(
        key.toString(),
        _processValue(value, coerceBooleanStrings),
      ));
}

/// معالجة أي قيمة بشكل تكراري
dynamic _processValue(dynamic value, bool coerceBooleanStrings) {
  if (value is Map) return _processMap(value, coerceBooleanStrings);
  if (value is List) {
    return value.map((e) => _processValue(e, coerceBooleanStrings)).toList();
  }
  if (value is String) {
    // تحويل boolean strings (Python/Dart) إلى bool حقيقي
    if (coerceBooleanStrings) {
      if (value == 'True' || value == 'true') return true;
      if (value == 'False' || value == 'false') return false;
    }
    return _tryParseString(value, coerceBooleanStrings);
  }
  return value;
}

/// محاولة تحويل String إلى Map أو List إذا كانت تحتوي على JSON
dynamic _tryParseString(String value, bool coerceBooleanStrings) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return value;
  // النصّ الخام أوّلاً للسبب نفسه أعلاه: التنظيف يفسد الاقتباسات المفردة
  try {
    final decoded = jsonDecode(trimmed);
    final result = _decodedOrNull(decoded, coerceBooleanStrings);
    if (result != null) return result;
  } on Object catch (_) {}
  try {
    final decoded = jsonDecode(_cleanRaw(trimmed));
    final result = _decodedOrNull(decoded, coerceBooleanStrings);
    if (result != null) return result;
    return value;
  } on Exception catch (_) {
    return value;
  }
}

/// معالجة ناتج فكّ الترميز إن كان Map أو List، وإلّا null
dynamic _decodedOrNull(dynamic decoded, bool coerceBooleanStrings) {
  if (decoded is Map) return _processMap(decoded, coerceBooleanStrings);
  if (decoded is List) {
    return decoded.map((e) => _processValue(e, coerceBooleanStrings)).toList();
  }
  return null;
}
