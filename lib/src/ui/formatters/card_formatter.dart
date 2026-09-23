import 'package:flutter/services.dart';

import 'number_formatter.dart';

/// منسق لأرقام البطاقات الائتمانية (تجميع كل 4 أرقام)
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // التحويل يحافظ على الطول (استبدال محرفٍ بمحرف)، فإزاحات المؤشّر
    // في `newValue.text` تصلح كما هي على `text`.
    final text = convertArabicToEnglishNumbers(newValue.text);

    // الحارس الوحيد هو النصّ الفارغ. الحارس القديم (`baseOffset == 0`)
    // كان يُعيد `newValue` خاماً فيُهمل التحويل والتجميع معاً: يبقى
    // رقمٌ هنديّ-عربيّ بلا تحويل ثم يسقط لاحقاً في تصفية `\D`، وتبقى
    // المسافات في غير مواضعها بعد الحذف من أوّل الحقل.
    if (text.isEmpty) {
      // قيمة جديدة لا `newValue`: تُولد بـ composing فارغ، فلا يبقى مدى
      // تأليفٍ يشير إلى نصٍّ لم يعد موجوداً.
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _formatCardNumber(text);

    // موضع المؤشّر يُحسب بعدد الأرقام التي تسبقه لا بطول النصّ المنسّق:
    // تثبيته عند النهاية كان يقذفه إلى آخر البطاقة بعد كلّ ضغطة، فيتعذّر
    // تصحيح خانةٍ في المنتصف (كلّ backspace يأكل آخر رقمٍ لا المقصود).
    final baseOffset = newValue.selection.baseOffset;
    final offset = baseOffset < 0
        ? formatted.length
        : _offsetAfterDigits(formatted, _countDigits(text, baseOffset));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
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

  /// عدد الأرقام الواقعة قبل الإزاحة [end] في [text].
  int _countDigits(String text, int end) {
    final limit = end > text.length ? text.length : end;
    int count = 0;
    for (int i = 0; i < limit; i++) {
      if (_isDigit(text.codeUnitAt(i))) count++;
    }
    return count;
  }

  /// الإزاحة في النصّ المنسّق مباشرةً بعد الرقم رقم [digitCount].
  /// نقف قبل فاصل المسافتين لا بعده، كي يحذف backspace رقماً لا مسافة.
  int _offsetAfterDigits(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;
    int seen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (_isDigit(formatted.codeUnitAt(i))) {
        seen++;
        if (seen == digitCount) return i + 1;
      }
    }
    return formatted.length;
  }

  bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
}

/// منسق لتاريخ انتهاء البطاقة (MM/YY)
class CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final converted = convertArabicToEnglishNumbers(newValue.text);

    // اتجاه التعديل: التنسيق وحده لا يميّز الإدراج من الحذف، فيُعيد بناء
    // '/' بعد رقمَي الشهر حتى حين يحذفها المستخدم.
    final isDeleting = newValue.text.length < oldValue.text.length;

    // إزالة أي محارف غير رقمية
    final digitsOnly = converted.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      // قيمة جديدة لا `copyWith`: الأخير يحتفظ بـ composing القديم، فيبقى
      // مدى التأليف مشيراً إلى نصٍّ صار فارغاً ويفشل تأكيد فلاتر
      // ('has an invalid non-empty composing range') مع لوحات IME.
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
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

    final formatted = _formatExpiry(processed, isDeleting: isDeleting);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatExpiry(String digits, {bool isDeleting = false}) {
    if (digits.length < 2) return digits;

    // عند الحذف لا نُعيد إلحاق '/' برقمَي الشهر وحدهما، وإلّا عاد النصّ
    // كما كان ('12/' ← backspace ← '12' ← '12/') فعلِق المستخدم بلا
    // طريقةٍ لتصحيح شهرٍ أدخله خطأً.
    if (digits.length == 2 && isDeleting) return digits;

    final month = digits.substring(0, 2);
    final year = digits.substring(2);

    return '$month/$year';
  }
}
