import 'package:flutter/services.dart';

import '../utils/phone/intl_phone_utils.dart';
import 'number_formatter.dart';

/// منسق لأرقام الهواتف
/// - يزيل الصفر في بداية الرقم
/// - يكتشف رمز الدولة تلقائياً من الرقم
class PhoneNumberFormatter extends TextInputFormatter {
  final ValueChanged<CountryModel> onCountryChanged;

  PhoneNumberFormatter({required this.onCountryChanged});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = convertArabicToEnglishNumbers(newValue.text);
    int cursorPosition = newValue.selection.end;
    bool cursorChanged = false;

    // تحويل 00 إلى +
    if (text.startsWith('00')) {
      text = '+${text.substring(2)}';
      cursorPosition = cursorPosition > 2 ? cursorPosition - 1 : 1;
      cursorChanged = true;
    }

    // إزالة الصفر في البداية
    if (text.startsWith('0')) {
      text = text.substring(1);
      cursorPosition = cursorPosition > 0 ? cursorPosition - 1 : 0;
      cursorChanged = true;
    }

    // اكتشاف رمز الدولة
    if (text.startsWith('+')) {
      final countryCode = IntlPhoneUtils.getCountryCode(text);

      if (countryCode.isNotEmpty) {
        final selectedCountry = IntlPhoneUtils.getCountryByCode(countryCode);
        onCountryChanged(selectedCountry);

        final originalLength = text.length;
        text = IntlPhoneUtils.getPhoneNumberByCountryDialCode(text);

        final lengthDiff = originalLength - text.length;
        cursorPosition = cursorPosition > lengthDiff ? cursorPosition - lengthDiff : 0;
        cursorChanged = true;
      }
    }

    if (cursorChanged) {
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursorPosition),
      );
    }

    return TextEditingValue(text: text, selection: newValue.selection);
  }
}
