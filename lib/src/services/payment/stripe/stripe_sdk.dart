import 'dart:developer';

import 'package:flutter_stripe/flutter_stripe.dart'
    show
        ApplePayCartSummaryItem,
        ApplePayParams,
        CardDetails,
        FailureCode,
        GooglePayParams,
        IsGooglePaySupportedParams,
        PaymentIntent,
        PaymentIntentsStatus,
        PaymentMethodData,
        PaymentMethodDataCardFromMethod,
        PaymentMethodParams,
        PlatformPayConfirmParams,
        Stripe,
        StripeException;

import 'stripe_card_info.dart';
import 'stripe_config.dart';
import 'stripe_error_messages.dart';
import 'stripe_transaction_result.dart';

/// سترايب بواجهتنا لا بواجهته — على نمط `HyperPaySDK` في التطبيقات.
///
/// العميل يكتب بطاقته في **نموذج التطبيق نفسه**، فتُسلَّم إلى SDK سترايب الأصليّ
/// (`dangerouslyUpdateCardDetails` يُنشئ حقل بطاقةٍ بلا واجهة على iOS وأندرويد)
/// ثمّ تُؤكَّد النيّة (`confirmPayment`) ويعرض SDK سترايب تحقّق البنك (3DS) إن
/// طلبه البنك. ومحافظ المنصّة (Google Pay / Apple Pay) بزرّنا وورقتها الأصلية.
///
/// المكوّن لا يعرف خادم أيّ تطبيق: يأخذ `clientSecret` الذي أنشأه الخادم والإعداد
/// الذي ردّه، ويُرجع النتيجة؛ ثمّ يسأل التطبيقُ خادمَه عن الحالة — فالحكم الماليّ
/// للخادم وحده.
///
/// ```dart
/// StripeSDK().initialize(StripeConfig.fromServer(data['stripe'], urlScheme: 'abber', merchantName: 'عبر'));
/// final result = await StripeSDK().submitCardPayment(clientSecret: secret, card: card);
/// // بطاقة محفوظة: الخادم ردّ `stripe.payment_method`، والعميل أعاد كتابة الـCVV.
/// final again = await StripeSDK().submitSavedCardPayment(clientSecret: secret, paymentMethodId: pm, cvv: cvv);
/// if (result.needsServerCheck) add(const CheckPaymentStatusEvent());
/// ```
class StripeSDK {
  static final StripeSDK _instance = StripeSDK._();

  factory StripeSDK() => _instance;

  StripeSDK._();

  StripeConfig? _config;
  String? _appliedKey;

  StripeConfig? get config => _config;

  /// يضبط SDK سترايب للدفعة القادمة. لا يُعيد التطبيق إلا إن تغيّر المفتاح.
  Future<void> initialize(StripeConfig config) async {
    if (!config.isValid) {
      throw StateError('Stripe publishable key is missing');
    }
    _config = config;
    Stripe.publishableKey = config.publishableKey;
    Stripe.urlScheme = config.urlScheme;
    Stripe.merchantIdentifier = config.merchantIdentifier;
    if (_appliedKey != config.publishableKey) {
      await Stripe.instance.applySettings();
      _appliedKey = config.publishableKey;
    }
  }

  /// بطاقة من نموذج التطبيق. 3DS — إن طلبه البنك — يعرضه SDK سترايب نفسه.
  Future<StripeTransactionResult> submitCardPayment({
    required String clientSecret,
    required StripeCardInfo card,
  }) async {
    if (!card.isComplete) {
      return StripeTransactionResult.error(message: 'بيانات البطاقة غير مكتملة', errorCode: 'incomplete_card');
    }
    return _run(() async {
      await Stripe.instance.dangerouslyUpdateCardDetails(
        CardDetails(number: card.digits, cvc: card.cvv.trim(), expirationMonth: card.month, expirationYear: card.year),
      );
      return Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
      );
    });
  }

  /// بطاقة محفوظة عند سترايب (`paymentMethodId` من ردّ الخادم) — العميل يعيد كتابة
  /// الـCVV فقط كما في هايبرباي، ويذهب مباشرةً إلى سترايب لا إلى خادمنا.
  Future<StripeTransactionResult> submitSavedCardPayment({
    required String clientSecret,
    required String paymentMethodId,
    required String cvv,
  }) async {
    final String cvc = cvv.trim();
    if (paymentMethodId.isEmpty || cvc.length < 3) {
      return StripeTransactionResult.error(message: 'بيانات البطاقة غير مكتملة', errorCode: 'incomplete_card');
    }
    return _run(
      () => Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.cardFromMethodId(
          paymentMethodData: PaymentMethodDataCardFromMethod(paymentMethodId: paymentMethodId, cvc: cvc),
        ),
      ),
    );
  }

  /// Google Pay بورقته الأصليّة. `currencyCode` عملة النيّة (SAR / AED / USD).
  Future<StripeTransactionResult> submitGooglePay({
    required String clientSecret,
    required String currencyCode,
  }) {
    final StripeConfig config = _requireConfig();
    return _run(
      () => Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: clientSecret,
        confirmParams: PlatformPayConfirmParams.googlePay(
          googlePay: GooglePayParams(
            testEnv: config.testEnv,
            merchantName: config.merchantName,
            merchantCountryCode: config.merchantCountry,
            currencyCode: currencyCode,
          ),
        ),
      ),
    );
  }

  /// Apple Pay عبر سترايب — يحتاج `merchantIdentifier` مسجَّلاً بشهادة سترايب.
  Future<StripeTransactionResult> submitApplePay({
    required String clientSecret,
    required String currencyCode,
    required String amount,
  }) {
    final StripeConfig config = _requireConfig();
    if (config.merchantIdentifier == null) {
      return Future.value(
        StripeTransactionResult.error(message: 'Apple Pay غير مهيّأ لهذه البوابة', errorCode: 'apple_pay_unconfigured'),
      );
    }
    return _run(
      () => Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: clientSecret,
        confirmParams: PlatformPayConfirmParams.applePay(
          applePay: ApplePayParams(
            merchantCountryCode: config.merchantCountry,
            currencyCode: currencyCode,
            cartItems: [ApplePayCartSummaryItem.immediate(label: config.merchantName, amount: amount)],
          ),
        ),
      ),
    );
  }

  /// هل محفظة المنصّة متاحة على هذا الجهاز؟ صامت الفشل: لا يكسر الشاشة أبداً.
  Future<bool> isWalletSupported() async {
    try {
      final StripeConfig? config = _config;
      return await Stripe.instance.isPlatformPaySupported(
        googlePay: IsGooglePaySupportedParams(testEnv: config?.testEnv ?? true),
      );
    } on Object catch (error) {
      log(error.toString(), name: 'StripeSDK.isWalletSupported');
      return false;
    }
  }

  StripeConfig _requireConfig() {
    final StripeConfig? config = _config;
    if (config == null) throw StateError('StripeSDK.initialize must run first');
    return config;
  }

  Future<StripeTransactionResult> _run(Future<PaymentIntent> Function() confirm) async {
    try {
      final PaymentIntent intent = await confirm();
      return switch (intent.status) {
        PaymentIntentsStatus.Succeeded ||
        PaymentIntentsStatus.RequiresCapture => StripeTransactionResult.succeeded(paymentIntentId: intent.id),
        PaymentIntentsStatus.Processing => StripeTransactionResult.processing(paymentIntentId: intent.id),
        PaymentIntentsStatus.Canceled => StripeTransactionResult.canceled(),
        _ => StripeTransactionResult.error(message: StripeErrorMessages.fallback, errorCode: intent.status.name),
      };
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) return StripeTransactionResult.canceled();
      return StripeTransactionResult.error(
        message: StripeErrorMessages.of(
          declineCode: error.error.declineCode,
          stripeErrorCode: error.error.stripeErrorCode,
          localizedMessage: error.error.localizedMessage,
        ),
        errorCode: error.error.declineCode ?? error.error.stripeErrorCode ?? error.error.code.name,
      );
    } on Object catch (error) {
      log(error.toString(), name: 'StripeSDK');
      return StripeTransactionResult.error(message: StripeErrorMessages.fallback, errorCode: 'exception');
    }
  }
}
