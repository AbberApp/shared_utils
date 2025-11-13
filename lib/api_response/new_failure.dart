
class Failure {
  final int code;
  final String? message;
  final List<FieldFailure> fields;

  Failure({required this.code, this.message, this.fields = const []});

  String get toMessage => message ??  'حدث خطاء';

  factory Failure.fromJson(int code, Map<String, dynamic> json) {
    return Failure(
      code: code,
      message: json['message'],
      fields: json['fields'] != null
          ? (json['fields'] as List)
              .map((e) => FieldFailure.fromJson(e))
              .toList()
          : [],
    );
  }

}

class FieldFailure {
  final String field;
  final String message;
  FieldFailure({required this.field, required this.message});

  factory FieldFailure.fromJson(Map<String, dynamic> json) {
    return FieldFailure(
      field: json['field'],
      message: json['message'],
    );
  }
}