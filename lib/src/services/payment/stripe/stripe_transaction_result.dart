/// نتيجة دفعةٍ عبر سترايب — على نمط `HyperPayTransactionResult` في التطبيقات.
enum StripeTransactionStatus {
  /// أكّدها سترايب. **ليس حكماً نهائياً عندنا**: التطبيق يسأل الخادم عن الحالة،
  /// والخادم يقرأ النيّة بنفسه ويسوّيها (والويبهوك شبكة أمان).
  succeeded,

  /// قيد المعالجة عند سترايب (نادر في البطاقات) — يستطلع التطبيق الحالة.
  processing,

  /// رُفضت أو فشلت. `message` بالعربية، و`errorCode` رمز سترايب للتحليل.
  error,

  /// أغلق العميل ورقة الدفع أو تحقّق البنك — ليس فشلاً.
  canceled,
}

class StripeTransactionResult {
  const StripeTransactionResult._({
    required this.status,
    this.message,
    this.errorCode,
    this.paymentIntentId,
  });

  final StripeTransactionStatus status;
  final String? message;
  final String? errorCode;
  final String? paymentIntentId;

  bool get isSucceeded => status == StripeTransactionStatus.succeeded;
  bool get isCanceled => status == StripeTransactionStatus.canceled;

  /// نجح أو ما زال قيد المعالجة — كلاهما يعني «اسأل الخادم الآن».
  bool get needsServerCheck =>
      status == StripeTransactionStatus.succeeded || status == StripeTransactionStatus.processing;

  factory StripeTransactionResult.succeeded({String? paymentIntentId}) =>
      StripeTransactionResult._(status: StripeTransactionStatus.succeeded, paymentIntentId: paymentIntentId);

  factory StripeTransactionResult.processing({String? paymentIntentId}) =>
      StripeTransactionResult._(status: StripeTransactionStatus.processing, paymentIntentId: paymentIntentId);

  factory StripeTransactionResult.error({required String message, String? errorCode}) =>
      StripeTransactionResult._(status: StripeTransactionStatus.error, message: message, errorCode: errorCode);

  factory StripeTransactionResult.canceled() =>
      const StripeTransactionResult._(status: StripeTransactionStatus.canceled);
}
