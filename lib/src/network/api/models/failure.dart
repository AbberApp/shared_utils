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

  String get displayMessage => message ?? 'حدث خطأ غير متوقع';

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
    String? error;
    try {
      if (json['message'] != null &&
          json['message'].isNotEmpty &&
          json['message'] is String) {
        error = json['message'] as String;
      }
      if (json['error'] != null &&
          json['error'].isNotEmpty &&
          json['error'] is String &&
          error == null) {
        error = json['error'] as String;
      }
      if (json['details'] != null &&
          json['details'].isNotEmpty &&
          json['details'] is String &&
          error == null) {
        error = json['details'] as String;
      }
      if (json['detail'] != null &&
          json['detail'].isNotEmpty &&
          json['detail'] is String &&
          error == null) {
        error = json['detail'] as String;
      }
      if (json['errors'] != null &&
          json['errors'].isNotEmpty &&
          json['errors'] is String &&
          error == null) {
        error = json['errors'] as String;
      }
    } on Object catch (_) {}

    List<FieldError> fields = [];
    try {
      if (json['fields'] != null) {
        fields = (json['fields'] as List)
            .map((e) => FieldError.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on Object catch (_) {}

    return Failure(code: code, message: error, fields: fields);
  }

  @override
  String toString() =>
      'Failure(code: $code, message: $message, fields: $fields)';
}

/// خطأ متعلق بحقل معين
class FieldError {
  final String field;
  final String message;

  const FieldError({required this.field, required this.message});

  factory FieldError.fromJson(Map<String, dynamic> json) {
    return FieldError(
      field: json['field'] as String,
      message: json['message'] as String,
    );
  }

  @override
  String toString() => 'FieldError(field: $field, message: $message)';
}
