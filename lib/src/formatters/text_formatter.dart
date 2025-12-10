import 'package:flutter/services.dart';

/// منسق يمنع الأحرف الإنجليزية
class NoEnglishLettersFormatter {
  const NoEnglishLettersFormatter._();

  static final formatter = FilteringTextInputFormatter.deny(
    RegExp(r'[A-Za-z]'),
  );
}

/// منسق يقبل الأحرف والأرقام الإنجليزية فقط ويحولها إلى أحرف كبيرة
class UpperCaseEnglishFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // الاحتفاظ بالأحرف والأرقام الإنجليزية فقط
    final filtered = newValue.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final upperCased = filtered.toUpperCase();

    return newValue.copyWith(
      text: upperCased,
      selection: TextSelection.collapsed(offset: upperCased.length),
    );
  }
}
