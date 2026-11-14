import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asymmetric/api.dart' show RSAPublicKey;

/// يقرأ مفتاح RSA العامّ من نصّ PEM.
///
/// بديلٌ محلّيّ لحزمة `basic_utils` 5.8.2: مكتبةٌ جامعة — نصوصٌ وتواريخ وDNS
/// وشهادات X.509 ومنحنيات إهليلجية، تجرّ معها `http` و`logging` و`archive`،
/// وتُعرّف `DateUtils` باسم أداة Flutter نفسها فلم تُصدَّر إلّا بـ`show`. ولم
/// تستعمل التطبيقات منها إلّا [rsaPublicKeyFromPem]، في `payment_encryptor.dart`:
/// تقرأ `public_key` من ردّ إنشاء الدفع، ثمّ يُشفَّر به مفتاحُ AES بـOAEP-SHA256
/// قبل أن تُرسل بيانات البطاقة.
///
/// **التوقيع مطابقٌ للحزمة** — الاسم نفسه والدالّة الساكنة بنوعها، و[RSAPublicKey]
/// هو صنف `pointycastle` نفسه الذي يُصدّره البرميل — فلا يُمسّ سطرٌ في التطبيقات.
///
/// والصيغتان كلتاهما كما في الحزمة:
///
/// * SubjectPublicKeyInfo («BEGIN PUBLIC KEY») — ما يرسله الخادم، من
///   `PublicFormat.SubjectPublicKeyInfo` في مكتبة `cryptography` لبايثون.
/// * PKCS#1 («BEGIN RSA PUBLIC KEY»).
///
/// ويُشذَّب كلّ سطرٍ وتُسقط الأسطر الفارغة، فتمرّ `\r\n` والمسافات الزائدة
/// حول المفتاح كما يُلصق في لوحة الإدارة.
///
/// ```dart
/// static RSAPublicKey parseRSAPublicKeyFromPem(String pem) =>
///     CryptoUtils.rsaPublicKeyFromPem(pem);
/// ```
///
/// **والفارق مقصود: كلُّ مدخلٍ معطوب يرمي [FormatException] وحدها.** كانت
/// الحزمة ترمي `ArgumentError` على نصٍّ بلا سطرَي البداية والنهاية، و`TypeError`
/// أو `RangeError` على DER معطوب (`as ASN1Sequence` عمياء). وكلّها `Error` لا
/// `Exception`، فلا يلتقطها `on Exception` في مستودعات الدفع، ويُستدعى هذا من
/// `PaymentModel.fromJson` — فمفتاحٌ تالفٌ من الخادم كان يُسقط شاشة الدفع بدل
/// أن يصير `Failure` تعرضه.
///
/// ولذلك لا يُبنى على `ASN1Parser` من `pointycastle`: متسامحٌ يقرأ طولاً يتجاوز
/// البايتات، ويرمي بنفسه `RangeError`، و`TypeError` على `BIT STRING` مركّبٍ
/// (`30 05 23 03 02 01 00`: يُجري `as ASN1BitString` على ما فيه). فالبنيتان
/// تُقرآن بقارئ DER صارمٍ صغير، ولا `catch` في الطريق.
///
/// وصرامةٌ أخرى مقصودة: مفتاح PKCS#1 عددان صحيحان موجبان **بالضبط**، ولا بايت
/// بعد آخر البنية. كانت الحزمة تأخذ أوّل عنصرين أيّاً كانا — فمفتاحٌ خاصّ
/// (`RSAPrivateKey`) يُلصق خطأً يصير «عامّاً» معاملُه رقمُ الإصدار صفر.
abstract final class CryptoUtils {
  /// وسوم DER الثلاثة التي يتألّف منها مفتاح RSA العامّ بصيغتيه.
  static const int _integer = 0x02;
  static const int _bitString = 0x03;
  static const int _sequence = 0x30;

  /// مفتاح RSA العامّ في [pem] — بصيغة SubjectPublicKeyInfo أو PKCS#1.
  ///
  /// يرمي [FormatException] إن لم يبدأ [pem] بسطر `-----BEGIN` وينتهِ بسطر
  /// `-----END`، أو لم يكن ما بينهما base64، أو لم يكن DER لمفتاح RSA عامّ
  /// بعددين صحيحين موجبين.
  static RSAPublicKey rsaPublicKeyFromPem(String pem) =>
      _rsaPublicKeyFromDer(_derFromPem(pem));

  /// بايتات DER بين سطرَي البداية والنهاية — كما `getBytesFromPEMString` في
  /// الحزمة: يُشذَّب كلّ سطرٍ وتُسقط الفارغة، ولا يُفحص اسم الكتلة بعد `BEGIN`.
  static Uint8List _derFromPem(String pem) {
    final List<String> lines = LineSplitter.split(pem)
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2 ||
        !lines.first.startsWith('-----BEGIN') ||
        !lines.last.startsWith('-----END')) {
      throw const FormatException('Missing PEM begin/end markers');
    }
    // base64Decode ترمي FormatException بنفسها على ما ليس base64.
    return base64Decode(lines.sublist(1, lines.length - 1).join());
  }

  /// SubjectPublicKeyInfo (RFC 5280):
  /// `SEQUENCE { algorithm SEQUENCE, subjectPublicKey BIT STRING }`، وفي الـ
  /// `BIT STRING` مفتاح PKCS#1. وPKCS#1 (RFC 8017) وحده:
  /// `SEQUENCE { modulus INTEGER, publicExponent INTEGER }`.
  ///
  /// يُميَّز بينهما بأوّل عنصر: `SEQUENCE` في الأولى و`INTEGER` في الثانية.
  /// ولا يُفحص معرّف الخوارزمية — كما في الحزمة.
  static RSAPublicKey _rsaPublicKeyFromDer(Uint8List der) {
    final _DerReader document = _DerReader(der);
    final _DerReader outer = _DerReader(document.read(_sequence, 'SEQUENCE'));
    document.expectEnd();

    if (outer.nextTag != _sequence) return _readRsaPublicKey(outer);

    outer.read(_sequence, 'AlgorithmIdentifier');
    final Uint8List bits = outer.read(_bitString, 'subjectPublicKey');
    outer.expectEnd();
    // أوّل بايتٍ في BIT STRING عددُ البتّات الزائدة في آخره، وهو صفرٌ هنا لأنّ
    // ما فيه بنيةُ DER كاملة البايتات.
    if (bits.isEmpty || bits.first != 0) {
      throw const FormatException('Invalid subjectPublicKey BIT STRING');
    }
    final _DerReader content = _DerReader(Uint8List.sublistView(bits, 1));
    final _DerReader key = _DerReader(content.read(_sequence, 'RSAPublicKey'));
    content.expectEnd();
    return _readRsaPublicKey(key);
  }

  /// `modulus` ثمّ `publicExponent`، ولا شيء بعدهما.
  static RSAPublicKey _readRsaPublicKey(_DerReader key) {
    final BigInt modulus = _readPositiveInteger(key, 'modulus');
    final BigInt exponent = _readPositiveInteger(key, 'publicExponent');
    key.expectEnd();
    return RSAPublicKey(modulus, exponent);
  }

  /// INTEGER في DER متمّمٌ ثنائيّ والأكبرُ أوّلاً، فبتُّه الأعلى إشارة: لذلك
  /// يُسبَق المعاملُ بصفرٍ حين يبدأ ببتٍّ مرفوع. فالموجب هنا ما لم يكن صفراً
  /// ولا مرفوعَ البتّ الأوّل.
  static BigInt _readPositiveInteger(_DerReader reader, String name) {
    final Uint8List bytes = reader.read(_integer, name);
    final BigInt value = bytes.fold<BigInt>(
      BigInt.zero,
      (BigInt acc, int byte) => (acc << 8) | BigInt.from(byte),
    );
    // صفرٌ يشمل المحتوى الفارغ، فلا يُقرأ `bytes.first` إلّا وفيه بايت.
    if (value == BigInt.zero || bytes.first >= 0x80) {
      throw FormatException('RSA $name is not a positive INTEGER');
    }
    return value;
  }
}

/// قارئ DER صارمٌ بالقدر الذي يحتاجه مفتاحٌ عامّ: وسمٌ من بايتٍ واحد، وطولٌ
/// محدّد لا يتجاوز ما بقي من البايتات. وكلّ خللٍ [FormatException].
final class _DerReader {
  _DerReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  /// وسم العنصر التالي بلا تقدّم، أو `null` إن انتهت البايتات.
  int? get nextTag => _offset < _bytes.length ? _bytes[_offset] : null;

  /// محتوى العنصر التالي بلا وسمه وطوله، ويجب أن يكون وسمه [tag].
  ///
  /// [name] اسم العنصر في رسالة الخطأ.
  Uint8List read(int tag, String name) {
    if (_bytes.length - _offset < 2) {
      throw FormatException('Truncated DER: missing $name');
    }
    if (_bytes[_offset] != tag) {
      throw FormatException('Expected $name in DER');
    }
    int cursor = _offset + 1;
    int length = _bytes[cursor++];
    if (length >= 0x80) {
      // الشكل الطويل: البتّات السبعة الدنيا عددُ بايتات الطول التالية. وصفرٌ
      // طولٌ غير محدّد (BER لا DER)، وما فوق أربعة بايتات لا يحمله مفتاح.
      final int count = length & 0x7F;
      if (count == 0 || count > 4 || _bytes.length - cursor < count) {
        throw FormatException('Invalid DER length for $name');
      }
      final int end = cursor + count;
      length = 0;
      while (cursor < end) {
        length = length * 256 + _bytes[cursor++];
      }
    }
    if (_bytes.length - cursor < length) {
      throw FormatException('Truncated DER: $name');
    }
    _offset = cursor + length;
    return Uint8List.sublistView(_bytes, cursor, _offset);
  }

  /// يرمي إن بقي شيءٌ بعد آخر عنصرٍ قُرئ.
  void expectEnd() {
    if (_offset != _bytes.length) {
      throw const FormatException('Unexpected trailing data in DER');
    }
  }
}
