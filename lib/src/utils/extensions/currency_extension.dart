import 'package:intl/intl.dart';

/// أكبر مقدارٍ يُنسّقه `NumberFormat` بأمان: فوق 2^63 يمرّ العدد عنده على
/// `int64` فيُقصّ صامتاً إلى 9,223,372,036,854,775,807 بلا استثناء ولا تحذير.
/// ما فوق هذا الحدّ يُنسَّق يدوياً عبر `BigInt` (وكلّ عددٍ عشريٍّ فوقه صحيحٌ
/// أصلاً، إذ تتجاوز المسافة بين القيم المتجاورة الواحدَ الصحيح).
const double _int64Limit = 9223372036854775808.0;

/// يُدخِل فواصل الآلاف على عددٍ صحيحٍ ضخم مع حفظ إشارته.
String _groupThousands(BigInt value) {
  final String digits = value.abs().toString();
  final StringBuffer buffer = StringBuffer(value.isNegative ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// يمحو إشارة السالب عن ناتجٍ كلّ خاناته أصفار («-0.00» ← «0.00»).
///
/// الفحص على النصّ لا على المُدخَل، لأنّ التقريب هو ما يُفني القيمة: ‎-0.004
/// سالبٌ فعلاً لكنّه يُعرض «0.00»، و«-0.00 ر.س» رصيدٌ لا معنى له ويُقلق
/// المستخدم. و«-∞» و«NaN» تنجوان لأنّ فيهما ما ليس صفراً ولا فاصلاً.
String _withoutNegativeZero(String formatted) {
  if (!formatted.startsWith('-')) {
    return formatted;
  }
  for (int i = 1; i < formatted.length; i++) {
    final String character = formatted[i];
    if (character != '0' && character != ',' && character != '.') {
      return formatted;
    }
  }
  return formatted.substring(1);
}

/// Extensions للعملات
extension CurrencyExtension on double {
  /// تنسيق كعملة مع فواصل الآلاف وخانتين عشريتين
  String get toCurrency {
    if (isFinite && abs() >= _int64Limit) {
      return '${_groupThousands(BigInt.from(this))}.00';
    }
    return _withoutNegativeZero(NumberFormat('#,##0.00', 'en_US').format(this));
  }

  /// تنسيق كعملة بدون خانات عشرية
  String get toCurrencyNoDecimals {
    if (isFinite && abs() >= _int64Limit) {
      return _groupThousands(BigInt.from(this));
    }
    return _withoutNegativeZero(NumberFormat('#,##0', 'en_US').format(this));
  }
}

/// Extensions للأعداد الصحيحة
extension IntCurrencyExtension on int {
  /// تنسيق كعملة مع فواصل الآلاف
  String get toCurrency {
    return NumberFormat('#,##0', 'en_US').format(this);
  }

  /// مرادفٌ لـ`toCurrency` يُتيح نداءً واحداً على العدد صحيحاً كان أو عشرياً،
  /// فلا يضطرّ المستدعي إلى `.toDouble()` — وهي تفقد الدقّة فوق 2^53.
  String get toCurrencyNoDecimals => toCurrency;
}
