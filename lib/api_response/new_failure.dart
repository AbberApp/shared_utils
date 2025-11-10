
class Failure {
  final int code;
  final String? message;
  final List<FieldFailure>? fields;

  Failure({required this.code, this.message, this.fields});

  String get toMessage => message ??  'حدث خطاء';

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