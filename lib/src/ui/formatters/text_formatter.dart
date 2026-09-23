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

    // قيمة جديدة لا `newValue.copyWith`: التصفية تُقصّر النصّ كلّما رُشِّح
    // محرف، و`copyWith` كان يُبقي `composing` المحسوب على النصّ الأطول.
    // مع لوحةٍ عربية يصير النصّ المصفّى فارغاً بينما مدى التأليف يشير إلى
    // محارف لم تعد موجودة، فيسقط تأكيد `isComposingRangeValid` في
    // controller وفي `toJSON`. البناء المباشر يُولّد `composing` فارغاً.
    return TextEditingValue(
      text: upperCased,
      selection: TextSelection.collapsed(offset: upperCased.length),
    );
  }
}
