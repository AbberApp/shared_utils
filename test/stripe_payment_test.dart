import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

void main() {
  group('StripeConfig.fromServer', () {
    test('reads the server block and keeps no secret', () {
      final config = StripeConfig.fromServer(
        {
          'client_secret': 'pi_1_secret',
          'publishable_key': 'pk_test_123',
          'merchant_country': 'AE',
          'merchant_identifier': '',
          'live_mode': false,
        },
        urlScheme: 'abber',
        merchantName: 'عبر',
      );
      expect(config.publishableKey, 'pk_test_123');
      expect(config.merchantCountry, 'AE');
      expect(config.merchantIdentifier, isNull);
      expect(config.testEnv, isTrue);
      expect(config.isValid, isTrue);
    });

    test('live keys turn the Google Pay test environment off', () {
      final config = StripeConfig.fromServer(
        {'publishable_key': 'pk_live_1', 'live_mode': true, 'merchant_identifier': 'merchant.x'},
        urlScheme: 'manam',
        merchantName: 'منام',
      );
      expect(config.testEnv, isFalse);
      expect(config.merchantIdentifier, 'merchant.x');
    });

    test('a missing key is not usable', () {
      expect(StripeConfig.fromServer({}, urlScheme: 'abber', merchantName: 'عبر').isValid, isFalse);
    });
  });

  group('StripeCardInfo', () {
    test('normalises the fields the HyperPay form already collects', () {
      const card = StripeCardInfo(cardNumber: '4242 4242 4242 4242', cvv: '123', expiryMonth: '07', expiryYear: '29');
      expect(card.digits, '4242424242424242');
      expect(card.month, 7);
      expect(card.year, 2029);
      expect(card.isComplete, isTrue);
    });

    test('four-digit years and incomplete cards', () {
      expect(const StripeCardInfo(cardNumber: '4242', cvv: '1', expiryMonth: '1', expiryYear: '2030').year, 2030);
      expect(const StripeCardInfo(cardNumber: '4242', cvv: '123', expiryMonth: '1', expiryYear: '30').isComplete, isFalse);
    });
  });

  group('StripeErrorMessages', () {
    test('decline code first, then Stripe error code, then the SDK text', () {
      expect(StripeErrorMessages.of(declineCode: 'insufficient_funds'), 'رصيد البطاقة غير كافٍ');
      expect(StripeErrorMessages.of(stripeErrorCode: 'expired_card'), 'البطاقة منتهية الصلاحية');
      expect(StripeErrorMessages.of(localizedMessage: 'Your card was declined.'), 'Your card was declined.');
      expect(StripeErrorMessages.of(), StripeErrorMessages.fallback);
    });
  });

  group('StripeTransactionResult', () {
    test('succeeded and processing both send the app to the server', () {
      expect(StripeTransactionResult.succeeded(paymentIntentId: 'pi_1').needsServerCheck, isTrue);
      expect(StripeTransactionResult.processing().needsServerCheck, isTrue);
      expect(StripeTransactionResult.canceled().needsServerCheck, isFalse);
      expect(StripeTransactionResult.error(message: 'x').status, StripeTransactionStatus.error);
    });
  });
}
