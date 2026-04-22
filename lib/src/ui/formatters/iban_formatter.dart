import 'package:flutter/services.dart';

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
  'BR': 29, // Brazil
  'BY': 28, // Belarus
  'CH': 21, // Switzerland
  'CR': 22, // Costa Rica
  'CY': 28, // Cyprus
  'CZ': 24, // Czech Republic
  'DE': 22, // Germany
  'DK': 18, // Denmark
  'DO': 28, // Dominican Republic
  'EE': 20, // Estonia
  'EG': 29, // Egypt
  'ES': 24, // Spain
  'FI': 18, // Finland
  'FO': 18, // Faroe Islands
  'FR': 27, // France
  'GB': 22, // United Kingdom
  'GE': 22, // Georgia
  'GI': 23, // Gibraltar
  'GL': 18, // Greenland
  'GR': 27, // Greece
  'GT': 28, // Guatemala
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
  'MK': 19, // North Macedonia
  'MR': 27, // Mauritania
  'MT': 31, // Malta
  'MU': 30, // Mauritius
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
    // استخراج المحارف النقية (بدون مسافات) وتحويلها لأحرف كبيرة
    final raw = newValue.text.replaceAll(' ', '').toUpperCase();

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
      selection: TextSelection.collapsed(offset: formatted.length),
    );
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

  /// إزالة المسافات والحصول على IBAN النقي للإرسال للـ API
  static String strip(String iban) => iban.replaceAll(' ', '').toUpperCase();

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
      remainder = (remainder * 10 + int.parse(digits[i])) % 97;
    }

    return remainder == 1;
  }
}
