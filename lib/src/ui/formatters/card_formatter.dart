import 'package:flutter/services.dart';

import 'number_formatter.dart';

/// منسق لأرقام البطاقات الائتمانية (تجميع كل 4 أرقام)
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = convertArabicToEnglishNumbers(newValue.text);

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    final formatted = _formatCardNumber(text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatCardNumber(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      final position = i + 1;
      if (position % 4 == 0 && position != digitsOnly.length) {
        buffer.write('  '); // مسافتين للفصل
      }
    }

    return buffer.toString();
  }
}

/// منسق لتاريخ انتهاء البطاقة (MM/YY)
class CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final converted = convertArabicToEnglishNumbers(newValue.text);

    if (converted.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    // إزالة أي محارف غير رقمية
    final digitsOnly = converted.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    String processed = digitsOnly;

    // معالجة الشهر
    if (digitsOnly.length == 1) {
      final firstDigit = int.parse(digitsOnly);
      if (firstDigit >= 2 && firstDigit <= 9) {
        processed = '0$digitsOnly';
      }
    } else if (digitsOnly.length >= 2) {
      final month = int.parse(digitsOnly.substring(0, 2));
      if (month > 12 || month == 0) {
        return oldValue;
      }
    }

    // حد أقصى 4 أرقام (MM/YY)
    if (processed.length > 4) {
      processed = processed.substring(0, 4);
    }

    final formatted = _formatExpiry(processed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatExpiry(String digits) {
    if (digits.length < 2) return digits;

    final month = digits.substring(0, 2);
    final year = digits.substring(2);

    return '$month/$year';
  }
}
