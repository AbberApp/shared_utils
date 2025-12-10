import 'package:intl/intl.dart';

/// Extensions للعملات
extension CurrencyExtension on double {
  /// تنسيق كعملة مع فواصل الآلاف وخانتين عشريتين
  String get toCurrency {
    return NumberFormat('#,##0.00', 'en_US').format(this);
  }

  /// تنسيق كعملة بدون خانات عشرية
  String get toCurrencyNoDecimals {
    return NumberFormat('#,##0', 'en_US').format(this);
  }
}

/// Extensions للأعداد الصحيحة
extension IntCurrencyExtension on int {
  /// تنسيق كعملة مع فواصل الآلاف
  String get toCurrency {
    return NumberFormat('#,##0', 'en_US').format(this);
  }
}
