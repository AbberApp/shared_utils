import 'package:flutter/services.dart';

import 'number_formatter.dart';

/// أطوال IBAN لكل دولة وفق معيار ISO 13616
const Map<String, int> _ibanLengths = {
  'AD': 24, // Andorra
  'AE': 23, // United Arab Emirates
  'AL': 28, // Albania
  'AT': 20, // Austria
  'AZ': 28, // Azerbaijan
  'BA': 20, // Bosnia and Herzegovina
  'BE': 16, // Belgium
  'BG': 22, // Bulgaria
  'BH': 22, // Bahrain
  'BI': 27, // Burundi
  'BR': 29, // Brazil
  'BY': 28, // Belarus
  'CH': 21, // Switzerland
  'CR': 22, // Costa Rica
  'CY': 28, // Cyprus
  'CZ': 24, // Czech Republic
  'DE': 22, // Germany
  'DJ': 27, // Djibouti
  'DK': 18, // Denmark
  'DO': 28, // Dominican Republic
  'EE': 20, // Estonia
  'EG': 29, // Egypt
  'ES': 24, // Spain
  'FI': 18, // Finland
  'FK': 18, // Falkland Islands
  'FO': 18, // Faroe Islands
  'FR': 27, // France
  'GB': 22, // United Kingdom
  'GE': 22, // Georgia
  'GI': 23, // Gibraltar
  'GL': 18, // Greenland
  'GR': 27, // Greece
  'GT': 28, // Guatemala
  'HN': 28, // Honduras
  'HR': 21, // Croatia
  'HU': 28, // Hungary
  'IE': 22, // Ireland
  'IL': 23, // Israel
  'IQ': 23, // Iraq
  'IS': 26, // Iceland
  'IT': 27, // Italy
  'JO': 30, // Jordan
  'KW': 30, // Kuwait
  'KZ': 20, // Kazakhstan
  'LB': 28, // Lebanon
  'LC': 32, // Saint Lucia
  'LI': 21, // Liechtenstein
  'LT': 20, // Lithuania
  'LU': 20, // Luxembourg
  'LV': 21, // Latvia
  'LY': 25, // Libya
  'MC': 27, // Monaco
  'MD': 24, // Moldova
  'ME': 22, // Montenegro
  'MN': 20, // Mongolia
  'MK': 19, // North Macedonia
  'MR': 27, // Mauritania
  'MT': 31, // Malta
  'MU': 30, // Mauritius
  'NI': 28, // Nicaragua
  'NL': 18, // Netherlands
  'NO': 15, // Norway
  'OM': 23, // Oman
  'PK': 24, // Pakistan
  'PL': 28, // Poland
  'PS': 29, // Palestine
  'PT': 25, // Portugal
  'QA': 29, // Qatar
  'RO': 24, // Romania
  'RS': 22, // Serbia
  'RU': 33, // Russia
  'SA': 24, // Saudi Arabia
  'SC': 31, // Seychelles
  'SD': 18, // Sudan
  'SE': 24, // Sweden
  'SI': 19, // Slovenia
  'SK': 24, // Slovakia
  'SM': 27, // San Marino
  'SO': 23, // Somalia
  'ST': 25, // Sao Tome and Principe
  'SV': 28, // El Salvador
  'TL': 23, // Timor-Leste
  'TN': 24, // Tunisia
  'TR': 26, // Turkey
  'UA': 29, // Ukraine
  'VA': 22, // Vatican City
  'VG': 24, // British Virgin Islands
  'XK': 20, // Kosovo
  'YE': 30, // Yemen
};

/// الحد الأقصى لطول IBAN بدون مسافات (روسيا 33)
const int _maxIbanLength = 33;

/// المحارف التي تُتجاهَل داخل الـIBAN: كل الفراغات (ومنها المسافة غير
/// الفاصلة U+00A0 والضيّقة U+202F والجدولة والسطر الجديد) إضافةً إلى
/// المحارف الخفيّة وعلامات الاتجاه.
///
/// السبب: الآيبان المنسوخ من صفحة بنكٍ أو من PDF يحمل هذه المحارف عادةً،
/// وحذف المسافة ASCII وحدها كان يجعل آيباناً صحيحاً يُرفض صامتاً.
final RegExp _ignorableIbanChars = RegExp(
  r'[\s\u200B-\u200F\u202A-\u202E\u2066-\u2069]',
);

/// حذف المحارف المتجاهَلة ورفع الحروف — أساس كل تنظيفٍ في هذا الملف
String _stripIgnorable(String value) =>
    value.replaceAll(_ignorableIbanChars, '').toUpperCase();

/// منسق حقل إدخال IBAN
///
/// يقوم بـ:
/// - تحويل الأحرف إلى أحرف كبيرة تلقائياً
/// - إدراج مسافة كل 4 محارف للعرض (SA44 2000 0001 ...)
/// - تحديد الحد الأقصى للطول بناءً على رمز الدولة تلقائياً
/// - رفض أي محارف غير مسموح بها (يقبل أحرفاً وأرقاماً فقط)
class IbanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // استخراج المحارف النقية (بدون فراغات) وتحويلها لأحرف كبيرة.
    // التوحيد يبدأ بالأرقام العربية-الهندية كبقيّة منسّقات المكتبة
    // (card/phone/number)، وإلّا سقط إدخال لوحة المفاتيح العربية صامتاً:
    // المحرف يُرفض ويُعاد oldValue بلا رسالة، فيبدو الحقل معطّلاً.
    final raw = _cleanInput(newValue.text);

    // رفض أي محرف غير حرف أو رقم
    if (!RegExp(r'^[A-Z0-9]*$').hasMatch(raw)) {
      return oldValue;
    }

    // تحديد الحد الأقصى بناءً على رمز الدولة
    final maxRaw = _resolveMaxLength(raw);

    // تطبيق الحد الأقصى
    final trimmed = raw.length > maxRaw ? raw.substring(0, maxRaw) : raw;

    // تنسيق: مسافة كل 4 محارف
    final formatted = _insertSpaces(trimmed);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _mapCursor(newValue, trimmed.length, formatted.length),
      ),
    );
  }

  /// تنظيف نص الإدخال: توحيد الأرقام ثم حذف الفراغات ورفع الحروف
  String _cleanInput(String text) =>
      _stripIgnorable(convertArabicToEnglishNumbers(text));

  /// موضع المؤشّر في النص المنسَّق مقابل موضعه في النص الوارد
  ///
  /// تثبيت المؤشّر على آخر النص كان يجعل تصحيح رقمٍ في وسط الآيبان
  /// مستحيلاً: المحرف يُدرج في مكانه الصحيح ثم يقفز المؤشّر إلى النهاية،
  /// فيُكتب ما بعده في آخر النص. لذا نَعُدّ المحارف النقية قبل المؤشّر
  /// ونحوّل العدد إلى إزاحة بإضافة المسافات المُدرَجة قبله (مسافة لكل 4).
  int _mapCursor(
    TextEditingValue newValue,
    int rawLength,
    int formattedLength,
  ) {
    final end = newValue.selection.end;
    if (end < 0) return formattedLength; // تحديد غير صالح ⇒ النهاية

    final cut = end > newValue.text.length ? newValue.text.length : end;
    var rawBefore = _cleanInput(newValue.text.substring(0, cut)).length;
    if (rawBefore > rawLength) rawBefore = rawLength; // بعد القصّ بالطول

    final offset = rawBefore + rawBefore ~/ 4;
    return offset > formattedLength ? formattedLength : offset;
  }

  /// تحديد الطول الأقصى للـIBAN بناءً على رمز الدولة (أول حرفين)
  int _resolveMaxLength(String raw) {
    if (raw.length < 2) return _maxIbanLength;
    final countryCode = raw.substring(0, 2);

    // تأكد أن أول حرفين حروف (رمز الدولة)
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) return _maxIbanLength;

    return _ibanLengths[countryCode] ?? _maxIbanLength;
  }

  String _insertSpaces(String raw) {
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }
}

/// أدوات مساعدة لـ IBAN
class IbanUtils {
  IbanUtils._();

  /// إزالة الفراغات والحصول على IBAN النقي للإرسال للـ API
  ///
  /// تُحذف كل الفراغات لا المسافة ASCII وحدها (راجع [_ignorableIbanChars]).
  /// ولا تُوحَّد هنا الأرقام العربية-الهندية عمداً: الآيبان الحامل لها ليس
  /// صالحاً بمعيار ISO 13616، فتوحيدها يجعل [isValid] يقبل ما يرفضه المعيار.
  static String strip(String iban) => _stripIgnorable(iban);

  /// تنسيق IBAN للعرض بمسافة كل 4 محارف
  static String format(String iban) {
    final raw = strip(iban);
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }

  /// التحقق من صحة IBAN (الطول + خوارزمية MOD 97)
  static bool isValid(String iban) {
    final raw = strip(iban);

    if (raw.length < 5) return false;

    final countryCode = raw.substring(0, 2);
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) return false;

    final expectedLength = _ibanLengths[countryCode];
    if (expectedLength == null || raw.length != expectedLength) return false;

    // حارس طقم المحارف قبل MOD 97: الطول وحده لا يضمن أن الباقي
    // أبجديّ-رقميّ، وبدونه تصل محارف كالواصلة أو الرموز التعبيرية أو
    // الأرقام العربية-الهندية إلى int.parse داخل الخوارزمية فترمي
    // FormatException بدل أن تعيد الدالّة false.
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(raw)) return false;

    // خانتا التحقّق (الموضعان ٣-٤) رقمان حصراً بمعيار ISO 13616، ومداهما
    // ٠٢..٩٨ لأنّ ISO 7064 يولّدهما بـ (٩٨ − الباقي) والباقي ٠..٩٦.
    // لا الطولُ ولا MOD-97 يكشف خرق هذه القاعدة: الباقي دوريّ بـ ٩٧، فالخانة
    // المكافئة (dd ± ٩٧) تعطي باقياً ١ أيضاً — IQ98 ↔ IQ01 وRU02 ↔ RU99
    // وSA97 ↔ SA00؛ وبعضُ أزواج الحروف في الموضعين يعطيه صدفةً كـ SANZ.
    final checkDigits = int.tryParse(raw.substring(2, 4));
    if (checkDigits == null || checkDigits < 2 || checkDigits > 98) {
      return false;
    }

    return _validateMod97(raw);
  }

  /// التحقق من رقم الدولة المدعومة
  static bool isSupportedCountry(String countryCode) {
    return _ibanLengths.containsKey(countryCode.toUpperCase());
  }

  /// الطول المتوقع لـ IBAN حسب رمز الدولة (null إذا غير مدعومة)
  static int? expectedLength(String countryCode) {
    return _ibanLengths[countryCode.toUpperCase()];
  }

  /// خوارزمية MOD 97 وفق ISO 7064
  static bool _validateMod97(String iban) {
    // نقل أول 4 محارف (رمز الدولة + أرقام التحقق) إلى النهاية
    final rearranged = iban.substring(4) + iban.substring(0, 4);

    // تحويل الحروف إلى أرقام: A=10, B=11, ..., Z=35
    final buffer = StringBuffer();
    for (final char in rearranged.runes) {
      final c = String.fromCharCode(char);
      if (RegExp(r'[A-Z]').hasMatch(c)) {
        buffer.write(char - 55); // A(65)-55=10
      } else {
        buffer.write(c);
      }
    }

    // حساب باقي القسمة على 97 على دفعات لتفادي تجاوز حجم الأعداد
    final digits = buffer.toString();
    int remainder = 0;
    for (int i = 0; i < digits.length; i++) {
      // tryParse لا parse: حزام أمانٍ ثانٍ كي تبقى الدالّة تعيد false
      // بدل أن ترمي لو نودِيت يوماً بمُدخلٍ لم يمرّ بحارس المحارف أعلاه.
      final digit = int.tryParse(digits[i]);
      if (digit == null) return false;
      remainder = (remainder * 10 + digit) % 97;
    }

    return remainder == 1;
  }
}
