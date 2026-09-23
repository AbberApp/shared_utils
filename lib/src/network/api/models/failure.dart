/// نموذج يمثل فشل في العملية
class Failure {
  final int code;
  final String? message;
  final List<FieldError> fields;

  /// عدد الثواني المطلوب الانتظار قبل إعادة المحاولة (من ترويسة Retry-After عند 429)
  final int? retryAfter;

  const Failure({
    required this.code,
    this.message,
    this.fields = const [],
    this.retryAfter,
  });

  /// النصّ الاحتياطي بالهمزة المركّبة (أ = U+0623) كسائر المكتبة: الصّيغة
  /// المتحلّلة (ا + U+0654) تُعرَض مثلها تماماً ولا تساويها نصّياً،
  /// فتفشل مقارنةُ المستهلك ولا يجدها البحث في الشّيفرة.
  String get displayMessage => message ?? 'حدث خطأ غير متوقع';

  /// هل الفشل بسبب تجاوز حد المعدّل (throttling 429)؟
  bool get isTooManyRequests => code == 429;

  /// هل يحوي الفشل أخطاء حقول (validation) على مستوى الحقول؟
  bool get hasFields => fields.isNotEmpty;

  /// رسالة خطأ الحقل المطابق لاسمه، أو `null` إن لم يكن له خطأ.
  /// مثال: `failure.fieldError('phone')`.
  String? fieldError(String field) {
    for (final FieldError e in fields) {
      if (e.field == field) return e.message;
    }
    return null;
  }

  factory Failure.fromJson(int code, Map<String, dynamic> json) {
    // فحص النوع يسبق `isNotEmpty`: استدعاؤها على قيمةٍ غير نصّية — كـ
    // `{"message": 400}` — يرمي `NoSuchMethodError` فتُهدَر بقيّة المفاتيح
    // ولا تُقرأ رسالةٌ أصلاً، ولو كانت حاضرةً في `detail` أو `errors`.
    String? error;
    for (final String key in _messageKeys) {
      final Object? value = json[key];
      // `isNotEmpty` تصدُق على المسافات وحدها: رسالةٌ بيضاء تُعرَض فراغاً
      // وتحجب مفتاحاً صالحاً بعدها، فتُعامَل معاملة النصّ الفارغ.
      // وتُحفظ القيمة كما وردت لا مقصوصةً: القصّ يغيّر رسالة الخادم.
      if (value is String && value.trim().isNotEmpty) {
        error = value;
        break;
      }
    }

    // مرورٌ ثانٍ للقوائم: الخادم (DRF) يُرسل الرسالة قائمةَ نصوصٍ كثيراً،
    // و[FieldError.fromJson] يعالج الشكل نفسه هنا — فإهمالها كان يُضيّع رسالة
    // الخادم كلّها ويعرض النصّ الاحتياطي بدلاً منها.
    // وهو مرورٌ تالٍ لا مدموجٌ في الأوّل: مفتاحٌ نصّيٌّ صالح يبقى أولى من
    // قائمةٍ سبقته في الترتيب، فلا تحجب القائمةُ رسالةً منصوصة بعدها.
    if (error == null) {
      for (final String key in _messageKeys) {
        final Object? value = json[key];
        if (value is! List) continue;
        final String joined = value
            .whereType<Object>()
            .map((Object e) => e.toString())
            .where((String e) => e.trim().isNotEmpty)
            .join('، ');
        if (joined.isNotEmpty) {
          error = joined;
          break;
        }
      }
    }

    // عنصرٌ فاسد يُتخطّى وحده: `map().toList()` داخل try واحدة كانت تُسقِط
    // أخطاء الحقول الصحيحة كلّها بسبب مدخلةٍ واحدة ناقصة.
    final List<FieldError> fields = <FieldError>[];
    final Object? rawFields = json['fields'];
    if (rawFields is List) {
      for (final Object? item in rawFields) {
        if (item is! Map<String, dynamic>) continue;
        final FieldError fieldError = FieldError.fromJson(item);
        // حقلٌ بلا اسم لا يطابقه [fieldError] أبداً، فوجوده ضجيجٌ لا فائدة فيه.
        // والرسالة الفارغة مثله وأضرّ: `FieldErrors.apply` يعدّ كلّ قيمةٍ غير
        // null توجيهاً ناجحاً فيكتم الرسالة العامّة، والمُتحقِّق يرسم سطر خطأٍ
        // فارغاً — فيضيع الخطأ صامتاً. أمّا النموذج المبنيّ يدوياً فيبقى كما
        // بُني: الإسقاط قراءةُ جسمٍ خام لا تعديلُ حالة.
        if (fieldError.field.isEmpty) continue;
        if (fieldError.message.trim().isEmpty) continue;
        fields.add(fieldError);
      }
    }

    return Failure(code: code, message: error, fields: fields);
  }

  @override
  String toString() =>
      'Failure(code: $code, message: $message, fields: $fields)';

  /// مفاتيح الرسالة مرتّبةً بالأولوية — يقرأها [fromJson] مرّتين: نصّاً ثمّ قائمة.
  static const List<String> _messageKeys = <String>[
    'message',
    'error',
    'details',
    'detail',
    'errors',
  ];
}

/// خطأ متعلق بحقل معين
class FieldError {
  final String field;
  final String message;

  const FieldError({required this.field, required this.message});

  /// قراءةٌ متسامحة: الخادم قد يُسقِط مفتاحاً أو يُرسل الرسالة قائمةً
  /// (`{"message": ["مطلوب"]}`)، و`as String` كانت ترمي عندها فتضيع بقيّة
  /// أخطاء الحقول معها.
  factory FieldError.fromJson(Map<String, dynamic> json) {
    final Object? message = json['message'];
    return FieldError(
      field: json['field']?.toString() ?? '',
      message: message is List
          ? message
                .whereType<Object>()
                .map((Object e) => e.toString())
                .join('، ')
          : message?.toString() ?? '',
    );
  }

  @override
  String toString() => 'FieldError(field: $field, message: $message)';
}
