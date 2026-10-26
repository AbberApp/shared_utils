/// إعداد سترايب لدفعةٍ واحدة — يُبنى من ردّ الخادم، لا من ثوابت في التطبيق.
///
/// المفتاح المنشور ودولة التاجر ومعرّف Apple Pay ووضع الاختبار كلّها تأتي مع
/// كتلة `stripe` في ردّ إنشاء الدفع، فينتقل الحساب من الاختبار إلى الحيّ (أو
/// يتبدّل) بلا إصدارٍ جديد. **ولا مفتاح سرّيّ هنا إطلاقاً**: السرّيّ لا يغادر الخادم.
class StripeConfig {
  const StripeConfig({
    required this.publishableKey,
    required this.urlScheme,
    required this.merchantName,
    this.merchantCountry = 'AE',
    this.merchantIdentifier,
    this.testEnv = true,
  });

  /// `pk_test_…` أو `pk_live_…` — غير سرّيّ.
  final String publishableKey;

  /// سكيم العودة بعد تحقّقٍ خارج التطبيق (3DS في متصفّح البنك) — `abber` في عبر،
  /// وسكيم منام في منام. وأندرويد يحتاج له `intent-filter`.
  final String urlScheme;

  /// الاسم الذي تعرضه ورقتا أبل وجوجل للتاجر («عبر»، «منام»).
  final String merchantName;

  /// دولة حساب سترايب — الإمارات لحساب Somow IT.
  final String merchantCountry;

  /// معرّف تاجر Apple Pay المسجَّل بشهادة سترايب (لا `merchant.com.abber`
  /// الخاصّ بهايبرباي). فارغ = لا Apple Pay عبر سترايب.
  final String? merchantIdentifier;

  /// بيئة Google Pay الاختبارية — صحيحة ما لم تكن مفاتيح الخادم حيّة.
  final bool testEnv;

  /// من كتلة `stripe` في ردّ الخادم:
  /// `{publishable_key, merchant_country, merchant_identifier, live_mode, …}`.
  factory StripeConfig.fromServer(
    Map<String, dynamic> json, {
    required String urlScheme,
    required String merchantName,
  }) {
    final String identifier = json['merchant_identifier']?.toString() ?? '';
    return StripeConfig(
      publishableKey: json['publishable_key']?.toString() ?? '',
      urlScheme: urlScheme,
      merchantName: merchantName,
      merchantCountry: json['merchant_country']?.toString() ?? 'AE',
      merchantIdentifier: identifier.isEmpty ? null : identifier,
      testEnv: json['live_mode'] != true,
    );
  }

  /// صالحٌ للاستعمال — بلا مفتاحٍ منشور لا يُهيَّأ SDK سترايب أصلاً.
  bool get isValid => publishableKey.startsWith('pk_');
}
