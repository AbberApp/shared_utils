import 'package:flutter/services.dart';

/// تحويل الأرقام العربية إلى إنجليزية
String convertArabicToEnglishNumbers(String text) {
  return text
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll('٣', '3')
      .replaceAll('٤', '4')
      .replaceAll('٥', '5')
      .replaceAll('٦', '6')
      .replaceAll('٧', '7')
      .replaceAll('٨', '8')
      .replaceAll('٩', '9')
      .replaceAll('٠', '0')
      .replaceAll('٫', '.')
      .replaceAll(',', '.');
}

/// منسق يحول الأرقام العربية إلى إنجليزية تلقائياً عند الإدخال
class ConvertArabicToEnglishNumbersFormatter extends TextInputFormatter {
  const ConvertArabicToEnglishNumbersFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final converted = convertArabicToEnglishNumbers(newValue.text);
    if (converted == newValue.text) return newValue;
    return newValue.copyWith(
      text: converted,
      selection: TextSelection.collapsed(offset: newValue.selection.end),
    );
  }
}

/// منسق يسمح بالأرقام فقط (مع دعم اختياري للأرقام العشرية)
class NumbersOnlyFormatter extends TextInputFormatter {
  final bool allowDecimal;

  const NumbersOnlyFormatter({this.allowDecimal = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final converted = convertArabicToEnglishNumbers(newValue.text);
    final cursorPosition = newValue.selection.end;

    if (allowDecimal) {
      // السماح بالأرقام والنقطة العشرية الواحدة فقط
      if (converted.contains(RegExp(r'[^\d.]')) || converted.split('.').length > 2) {
        return oldValue;
      }
    } else {
      // السماح بالأرقام فقط
      if (converted.contains(RegExp(r'\D'))) {
        return oldValue;
      }
    }

    return newValue.copyWith(
      text: converted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}
