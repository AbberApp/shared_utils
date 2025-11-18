import 'package:flutter/services.dart';

import '../utils/functions.dart';
import '../utils/intl_phone_field_utils.dart';

class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String newText = convertArabicNumbers(newValue.text);

    if (newText.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    // إزالة أي محارف غير رقمية
    final String digitsOnly = newText.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    // معالجة الشهر
    String processedText = digitsOnly;

    if (digitsOnly.length == 1) {
      // إذا كان الرقم الأول بين 2-9، أضف 0 قبله
      int firstDigit = int.parse(digitsOnly);
      if (firstDigit >= 2 && firstDigit <= 9) {
        processedText = '0$digitsOnly';
      }
    } else if (digitsOnly.length >= 2) {
      // التحقق من أن الشهر لا يتجاوز 12
      int month = int.parse(digitsOnly.substring(0, 2));

      if (month > 12) {
        // إذا كان الشهر أكبر من 12، ارجع للقيمة القديمة
        return oldValue;
      }

      // إذا كان الشهر 00، ارجع للقيمة القديمة
      if (month == 0) {
        return oldValue;
      }
    }

    // حد أقصى 4 أرقام (MM/YY)
    if (processedText.length > 4) {
      processedText = processedText.substring(0, 4);
    }

    final String formattedText = _formatExpiry(processedText);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String _formatExpiry(String digits) {
    if (digits.length <= 2) {
      return digits;
    }

    // تنسيق MM/YY
    final String month = digits.substring(0, 2);
    final String year = digits.substring(2);

    return '$month/$year';
  }
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String text = convertArabicNumbers(newValue.text);

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    final String formattedText = _formatCardNumber(text);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String _formatCardNumber(String input) {
    input = input.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      buffer.write(input[i]);
      final int nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != input.length) {
        // Add double spaces
        buffer.write('  ');
      }
    }
    return buffer.toString();
  }
}

class AllowNumbersFormatter extends TextInputFormatter {
  AllowNumbersFormatter({this.enubleDecimal = false});
  final bool enubleDecimal;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String persianInput = convertArabicNumbers(newValue.text);
    final int selectionIndex = newValue.selection.end;

    // إذا كان العدد العشري مفعل
    if (enubleDecimal) {
      // السماح بالأرقام والنقطة العشرية، ولكن فقط نقطة واحدة
      if (persianInput.contains(RegExp(r'[^\d.]')) ||
          (persianInput.split('.').length > 2)) {
        return oldValue;
      }

      // التأكد من عدم وجود أكثر من نقطة عشرية واحدة
      if (persianInput.contains('.')) {
        // إذا كان المستخدم يحاول إضافة نقطة عشرية ثانية
        if (persianInput.indexOf('.') != persianInput.lastIndexOf('.')) {
          return oldValue;
        }
      }
    } else {
      // السماح بالأرقام فقط
      if (persianInput.contains(RegExp(r'\D'))) {
        return oldValue;
      }
    }

    return newValue.copyWith(
      text: persianInput,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

/// معالج مخصص لتنسيق أرقام الهاتف
/// يقوم بإزالة الـ "0" في بداية الرقم وإزالة رموز الدولة (+966 أو 00967) إذا وجدت
class PhoneNumberFormatter extends TextInputFormatter {
  PhoneNumberFormatter({required this.onCountryChanged});

  // return the selected country
  final ValueChanged<CountryModel> onCountryChanged;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = convertArabicNumbers(newValue.text);
    int cursorPosition = newValue.selection.end;
    bool cursorChanged = false;

    // تحويل الأرقام التي تبدأ بـ 00 إلى تنسيق +
    if (text.startsWith('00')) {
      final String newText = '+${text.substring(2)}';
      text = newText;
      // تعديل موضع المؤشر - نقص حرف واحد (+ بدلاً من 00)
      cursorPosition = cursorPosition > 2 ? cursorPosition - 1 : 1;
      cursorChanged = true;
    }

    // التعامل مع الأرقام التي تبدأ بصفر (إزالة الصفر)
    if (text.startsWith('0')) {
      text = text.substring(1);
      cursorPosition = cursorPosition > 0 ? cursorPosition - 1 : 0;
      cursorChanged = true;
    }

    // التعامل مع الأرقام التي تبدأ بـ + (اكتشاف رمز الدولة)
    if (text.startsWith('+')) {
      final String countryCode = IntlPhoneUtils.getCountryCode(text);

      // التحقق من وجود رمز دولة صالح
      if (countryCode.isNotEmpty) {
        final CountryModel selectedCountry = IntlPhoneUtils.getCountryByCode(
          countryCode,
        );

        // استدعاء دالة تغيير الدولة
        onCountryChanged(selectedCountry);

        // حفظ طول النص الأصلي
        final int originalLength = text.length;

        // استخدام الدالة للحصول على رقم الهاتف بدون رمز الدولة
        text = IntlPhoneUtils.getPhoneNumberByCountryDialCode(text);

        // حساب الفرق في الطول وتعديل موضع المؤشر
        final int lengthDifference = originalLength - text.length;
        cursorPosition = cursorPosition > lengthDifference
            ? cursorPosition - lengthDifference
            : 0;
        cursorChanged = true;
      }
    }

    // إذا تمت معالجة النص، قم بتحديث موضع المؤشر
    if (cursorChanged) {
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursorPosition),
      );
    }

    return TextEditingValue(text: text, selection: newValue.selection);
  }
}

class NoEnglishLettersInputFormatter {
  NoEnglishLettersInputFormatter._();

  static final formatter = FilteringTextInputFormatter.deny(
    RegExp(r'[A-Za-z]'), // يمنع الأحرف الإنجليزية فقط
  );
}

/// Formatter يقبل الأحرف والأرقام الإنجليزية فقط ويحول الأحرف الصغيرة إلى كبيرة
class UpperCaseEnglishInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // نحافظ فقط على الأحرف والأرقام الإنجليزية
    final filtered = newValue.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

    // نحول الكل إلى UpperCase
    final upperCased = filtered.toUpperCase();

    return newValue.copyWith(
      text: upperCased,
      selection: TextSelection.collapsed(offset: upperCased.length),
    );
  }
}
