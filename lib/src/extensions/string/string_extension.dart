/// Extensions على String
extension StringExtension on String {
  /// التحقق من أن النص يحتوي على أرقام فقط
  bool get isAllDigits {
    if (isEmpty) return false;
    return RegExp(r'^[0-9]+$').hasMatch(this);
  }

  /// التحقق من أن النص يحتوي على أرقام ونقطة عشرية فقط
  bool get isValidDecimal {
    if (isEmpty) return false;
    // نقطة عشرية واحدة فقط
    if (split('.').length > 2) return false;
    return RegExp(r'^[0-9.]+$').hasMatch(this);
  }

  /// إزالة الأقواس من النص (مفيد للقوائم)
  String get withoutBrackets {
    if (length < 2) return this;
    return substring(1, length - 1);
  }

  /// التحقق من صحة البريد الإلكتروني
  bool get isValidEmail {
    return RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    ).hasMatch(this);
  }

  /// تحويل الحرف الأول إلى حرف كبير
  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
