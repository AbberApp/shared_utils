/// رسائل رفض سترايب بالعربية — مطابقة لـ`DECLINE_MESSAGES` في مُهايئ الخادم
/// (`payment/adapters/stripe.py`)، فيقرأ العميل الجملة نفسها أيّاً كان مصدرها.
abstract final class StripeErrorMessages {
  static const String fallback = 'فشلت عملية الدفع';

  static const Map<String, String> _byCode = {
    'card_declined': 'رفض البنك المُصدِر البطاقة',
    'generic_decline': 'رفض البنك المُصدِر البطاقة',
    'do_not_honor': 'رفض البنك المُصدِر البطاقة',
    'lost_card': 'رفض البنك المُصدِر البطاقة',
    'stolen_card': 'رفض البنك المُصدِر البطاقة',
    'insufficient_funds': 'رصيد البطاقة غير كافٍ',
    'expired_card': 'البطاقة منتهية الصلاحية',
    'incorrect_cvc': 'رمز التحقق (CVV) غير صحيح',
    'invalid_cvc': 'رمز التحقق (CVV) غير صحيح',
    'incorrect_number': 'رقم البطاقة غير صحيح',
    'invalid_number': 'رقم البطاقة غير صحيح',
    'invalid_expiry_month': 'شهر انتهاء البطاقة غير صحيح',
    'invalid_expiry_year': 'سنة انتهاء البطاقة غير صحيحة',
    'processing_error': 'حدث خطأ مؤقت، حاول مرة أخرى',
    'authentication_required': 'يطلب البنك التحقق من الدفع',
    'payment_intent_authentication_failure': 'لم يكتمل تحقق البنك',
    'card_not_supported': 'هذه البطاقة لا تدعم هذه العملية، استعمل بطاقة أخرى',
    'currency_not_supported': 'هذه البطاقة لا تدعم هذه العملة',
  };

  /// أولوية الرمز: سبب الرفض من البنك، ثم رمز خطأ سترايب، ثم رسالة سترايب المترجمة.
  static String of({String? declineCode, String? stripeErrorCode, String? localizedMessage}) {
    return _byCode[declineCode] ?? _byCode[stripeErrorCode] ?? _nonEmpty(localizedMessage) ?? fallback;
  }

  static String? _nonEmpty(String? value) => (value == null || value.trim().isEmpty) ? null : value;
}
