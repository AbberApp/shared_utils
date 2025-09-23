class Failure {
  final int code;
  final String message;
  final List<Map<String, dynamic>>? data;
  final Map<String, dynamic>? extraData;

  Failure(this.code, this.message, {this.data, this.extraData});

  String get toMessage => '$message   \n رمز الخطأ : $code';

  String get toMessageWithExtraData {
    try {
      if (extraData == null) {
        return message;
      }
      if (extraData!.isEmpty) {
        return message;
      }
      if (extraData!['error'] != null) {
        return extraData!['error'];
      }
      if (extraData!['message'] != null) {
        return extraData!['message'];
      }
      if (extraData!['errors'] != null) {
        return extraData!['errors'];
      }
      if (extraData!['details'] != null) {
        return extraData!['details'];
      }
      return message;
    } catch (e) {
      return e.toString();
    }
  }
}
