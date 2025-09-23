import 'package:intl/intl.dart';

extension CurrencyFormatting on double {
  String get toCurrencyFormatRial {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    // final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(this);
  }
}
