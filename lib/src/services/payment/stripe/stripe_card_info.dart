/// بيانات بطاقةٍ كتبها العميل في **نموذج التطبيق نفسه** (تصميمنا لا تصميم سترايب).
///
/// الحقول نفسها التي يرسلها التطبيق إلى هايبرباي، فيُحوَّل نموذج البطاقة إليها
/// بسطرٍ واحد — وبهذا يعمل الرجوع التلقائي إلى سترايب بالبطاقة نفسها بلا أن
/// يكتبها العميل مرّتين. تبقى في الذاكرة فقط: لا تُخزَّن ولا تُسجَّل، وتُسلَّم إلى
/// SDK سترايب مباشرةً لا إلى خادمنا.
class StripeCardInfo {
  const StripeCardInfo({
    required this.cardNumber,
    required this.cvv,
    required this.expiryMonth,
    required this.expiryYear,
  });

  final String cardNumber;
  final String cvv;

  /// `"07"` أو `"7"`.
  final String expiryMonth;

  /// `"2029"` أو `"29"`.
  final String expiryYear;

  /// الرقم بلا مسافات ولا شرطات.
  String get digits => cardNumber.replaceAll(RegExp(r'\D'), '');

  int? get month => int.tryParse(expiryMonth.trim());

  /// سنة بأربع خانات — `29` تصير `2029`.
  int? get year {
    final int? value = int.tryParse(expiryYear.trim());
    if (value == null) return null;
    return value < 100 ? 2000 + value : value;
  }

  bool get isComplete => digits.length >= 12 && cvv.trim().length >= 3 && month != null && year != null;
}
