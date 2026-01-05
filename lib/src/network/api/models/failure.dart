/// نموذج يمثل فشل في العملية
class Failure {
  final int code;
  final String? message;
  final List<FieldError> fields;

  const Failure({required this.code, this.message, this.fields = const []});

  String get displayMessage => message ?? 'حدث خطأ';

  factory Failure.fromJson(int code, Map<String, dynamic> json) {
    String? error;
    if (json['message'] != null && json['message'].isNotEmpty) {
      error = json['message'] as String;
    }
    if (json['error'] != null) {
      error = json['error'] as String;
    }
    if (json['details'] != null) {
      error = json['details'] as String;
    }
    if (json['detail'] != null) {
      error = json['detail'] as String;
    }
    if (json['errors'] != null) {
      error = json['errors'] as String;
    }

    return Failure(
      code: code,
      message: error,
      fields: json['fields'] != null
          ? (json['fields'] as List).map((e) => FieldError.fromJson(e)).toList()
          : [],
    );
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
