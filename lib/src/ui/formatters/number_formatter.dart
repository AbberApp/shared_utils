import 'package:flutter/services.dart';

/// تحويل الأرقام العربية إلى إنجليزية، وتوحيد فواصل الأعداد.
///
/// ‏يشمل التحويل:
/// * الأرقام العربية-الهندية `٠..٩` (U+0660..U+0669).
/// * نظيرتها الفارسية/الأردية `۰..۹` (U+06F0..U+06F9) — وهي ما تُخرجه لوحة
///   المفاتيح الفارسية، ومحارفها مختلفة عن العربية-الهندية لا مجرّد شكلٍ آخر.
/// * `٫` (U+066B) فاصلةٌ **عشرية** عربية ⇒ نقطة.
/// * `٬` (U+066C) فاصلةُ **آلافٍ** عربية ⇒ تُحذف.
/// * `,` (U+002C) فاصلةُ آلافٍ لاتينية ⇒ تُحذف. وهي في هذه المكتبة فاصلةُ
///   آلافٍ لا غير: `toCurrency` تُخرج `NumberFormat('#,##0.00', 'en_US')`.
///   فردّها نقطةً عشرية كان يجعل «1,234» المعروضة تعود 1.234 — خطأ ×١٠٠٠.
///
/// ‏وما عدا ذلك يمرّ كما هو: الفاصلة العربية `،` (U+060C) ليست فاصلة عدد،
/// وإشارتا السالب `-` و`−` تبقيان، والحروف والمسافات تسلم.
String convertArabicToEnglishNumbers(String text) {
  if (text.isEmpty) return text;

  final buffer = StringBuffer();
  for (final int rune in text.runes) {
    if (rune >= _arabicIndicZero && rune <= _arabicIndicNine) {
      buffer.writeCharCode(_latinZero + rune - _arabicIndicZero);
    } else if (rune >= _extendedArabicIndicZero &&
        rune <= _extendedArabicIndicNine) {
      buffer.writeCharCode(_latinZero + rune - _extendedArabicIndicZero);
    } else if (rune == _arabicDecimalSeparator) {
      buffer.write('.');
    } else if (rune == _arabicThousandsSeparator || rune == _latinComma) {
      // ‏فواصل الآلاف تُحذف لا تُستبدل: إبقاؤها يُسقط اللصقة عند منسّقات
      // الأرقام، واستبدالها بنقطةٍ يُفسد قيمة المبلغ.
      continue;
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

const int _latinZero = 0x30; // '0'
const int _arabicIndicZero = 0x0660; // '٠'
const int _arabicIndicNine = 0x0669; // '٩'
const int _extendedArabicIndicZero = 0x06F0; // '۰'
const int _extendedArabicIndicNine = 0x06F9; // '۹'
const int _arabicDecimalSeparator = 0x066B; // '٫'
const int _arabicThousandsSeparator = 0x066C; // '٬'
const int _latinComma = 0x2C; // ','

/// ‏موضع المؤشّر بعد تحويلٍ قد يُقصّر النصّ (حذف فواصل الآلاف).
///
/// قبل حذف الفواصل كان التحويل محرفاً بمحرف فيستحيل أن يتجاوز المؤشّرُ النصّ؛
/// أمّا الآن فلصق «1,234» يُخرج أربعة محارف ومؤشّراً عند 5، وتحديدٌ خارج النصّ
/// يرمي في طبقة العرض. نقصّه إلى نهاية النصّ، ونترك «لا تحديد» (‎-1) كما هو
/// لأنّه ليس موضعاً بل غيابُ موضع.
int _clampCursor(int offset, int length) => offset > length ? length : offset;

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
      selection: TextSelection.collapsed(
        offset: _clampCursor(newValue.selection.end, converted.length),
      ),
    );
  }
}

/// منسق يسمح بالأرقام فقط (مع دعم اختياري للأرقام العشرية)
///
/// ‏ضمانه: كلّ نصٍّ **غير فارغ** يخرج من هذا المنسّق يقبله `double.parse`،
/// بما في ذلك الحالات العابرة أثناء الكتابة مثل «5.» و«.5» و«0.».
/// أمّا النصّ الفارغ فحالةٌ مشروعة (محو الحقل) لا يقبلها `double.parse`،
/// فاستعمل عند الإرسال `double.tryParse(controller.text)` لا `double.parse`.
class NumbersOnlyFormatter extends TextInputFormatter {
  final bool allowDecimal;

  const NumbersOnlyFormatter({this.allowDecimal = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final converted = convertArabicToEnglishNumbers(newValue.text);
    final cursorPosition = _clampCursor(
      newValue.selection.end,
      converted.length,
    );

    if (allowDecimal) {
      // السماح بالأرقام والنقطة العشرية الواحدة فقط
      if (converted.contains(RegExp(r'[^\d.]')) || converted.split('.').length > 2) {
        return oldValue;
      }
      // ‏النقطة وحدها ليست عدداً: `double.parse('.')` يرمي FormatException،
      // بخلاف «.5» و«5.» فكلاهما يُحلَّل بلا مشكلة. فنُكملها إلى «0.» بدل
      // رفضها كي يبقى كلّ نصٍّ غير فارغٍ قابلاً للتحليل، ويواصل المستخدمُ
      // كتابة كسره كما لو بدأ بالنقطة.
      if (converted == '.') {
        return const TextEditingValue(
          text: '0.',
          selection: TextSelection.collapsed(offset: 2),
        );
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
