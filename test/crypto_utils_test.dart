import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار `CryptoUtils` — البديل المحلّيّ لحزمة `basic_utils`.
///
/// يحرس ثلاثة أمور: **تطابقَ التوقيع** مع الحزمة كي لا يُمسّ سطرٌ في
/// التطبيقات، و**صحّةَ المفتاح** بالصيغتين مقارنةً بما يقرؤه openssl نفسه، و**ألّا
/// يرمي المعطوب إلّا `FormatException`** — فالدالّة تُستدعى من
/// `PaymentModel.fromJson` تحت `on Exception`، وكانت الحزمة ترمي `TypeError`
/// و`ArgumentError` فتُسقط شاشة الدفع.
///
/// المفاتيح مولَّدةٌ لهذا الاختبار وحده:
///
/// ```sh
/// openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out a.pem
/// openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
///   -pkeyopt rsa_keygen_pubexp:3 -out b.pem
/// openssl pkey -in a.pem -pubout                       # SubjectPublicKeyInfo
/// openssl rsa -in a.pem -RSAPublicKey_out              # PKCS#1
/// openssl rsa -pubin -in a_spki.pem -text -noout       # Modulus وExponent
/// openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out ec.pem
/// ```
void main() {
  RSAPublicKey fromPem(String text) => CryptoUtils.rsaPublicKeyFromPem(text);

  /// [der] في غلاف PEM بسطرٍ واحد من base64.
  String pem(List<int> der) =>
      '-----BEGIN PUBLIC KEY-----\n${base64Encode(der)}\n-----END PUBLIC KEY-----\n';

  /// بايتات DER في [pemText] — ما بين سطرَي البداية والنهاية.
  Uint8List derOf(String pemText) {
    final List<String> lines = pemText.trim().split('\n');
    return base64Decode(lines.sublist(1, lines.length - 1).join());
  }

  final BigInt aModulus = BigInt.parse(_aModulusHex, radix: 16);
  final BigInt bModulus = BigInt.parse(_bModulusHex, radix: 16);

  group('توقيع الحزمة — لا يجوز أن ينحرف', () {
    test('rsaPublicKeyFromPem ساكنةٌ بنوعها', () {
      // إسنادٌ إلى نوعٍ صريح: لو تغيّر التوقيع لما صُرّف هذا الملفّ.
      final RSAPublicKey Function(String) rsaPublicKeyFromPem =
          CryptoUtils.rsaPublicKeyFromPem;
      expect(rsaPublicKeyFromPem(_aSpki), isA<RSAPublicKey>());
    });
  });

  group('الصيغتان — تطابقان openssl', () {
    test('SubjectPublicKeyInfo «BEGIN PUBLIC KEY» — ما يرسله الخادم', () {
      final RSAPublicKey key = fromPem(_aSpki);
      expect(key.modulus, aModulus);
      expect(key.exponent, BigInt.from(65537));
      expect(key.modulus!.bitLength, 2048);
    });

    test('PKCS#1 «BEGIN RSA PUBLIC KEY»', () {
      final RSAPublicKey key = fromPem(_aPkcs1);
      expect(key.modulus, aModulus);
      expect(key.exponent, BigInt.from(65537));
    });

    test('الأسّ يُقرأ ولا يُفترض 65537 — المفتاح الثاني أسّه 3', () {
      for (final String text in <String>[_bSpki, _bPkcs1]) {
        final RSAPublicKey key = fromPem(text);
        expect(key.modulus, bModulus);
        expect(key.exponent, BigInt.from(3));
      }
    });

    test('المفتاحان مختلفان، والصيغتان للمفتاح الواحد متساويتان', () {
      expect(fromPem(_aSpki), fromPem(_aPkcs1));
      expect(fromPem(_bSpki), fromPem(_bPkcs1));
      expect(fromPem(_aSpki), isNot(fromPem(_bSpki)));
    });

    test('أصغر بنيةٍ بالصيغتين: n = 5 و e = 3', () {
      const List<int> pkcs1 = <int>[0x30, 0x06, 0x02, 0x01, 0x05, 0x02, 0x01, 0x03];
      final List<int> spki = <int>[
        0x30, 0x0D, //
        0x30, 0x00, // AlgorithmIdentifier — لا يُفحص كما في الحزمة
        0x03, 0x09, 0x00, ...pkcs1, // BIT STRING بلا بتّاتٍ زائدة
      ];
      for (final List<int> der in <List<int>>[pkcs1, spki]) {
        final RSAPublicKey key = fromPem(pem(der));
        expect(key.modulus, BigInt.from(5));
        expect(key.exponent, BigInt.from(3));
      }
    });
  });

  group('النصّ كما يصل — كما في الحزمة', () {
    test('أسطر \\r\\n وفراغات حول كلّ سطر وأسطر فارغة', () {
      final String messy = _aSpki
          .split('\n')
          .map((String line) => ' \t$line  ')
          .join('\r\n\r\n');
      expect(messy, contains('\r\n'));
      expect(fromPem(messy).modulus, aModulus);
    });

    test('\\r وحده فاصلاً', () {
      expect(fromPem(_bPkcs1.trim().replaceAll('\n', '\r')).modulus, bModulus);
    });

    test('جسم base64 في سطرٍ واحد بلا تقسيم', () {
      final List<String> lines = _aPkcs1.trim().split('\n');
      final String oneLine = <String>[
        lines.first,
        lines.sublist(1, lines.length - 1).join(),
        lines.last,
      ].join('\n');
      expect(fromPem(oneLine).modulus, aModulus);
    });

    test('اسم الكتلة لا يُفحص — المحتوى يحدّد الصيغة', () {
      // PKCS#1 بغلاف «PUBLIC KEY» — خلطٌ شائع في الخوادم.
      expect(fromPem(pem(derOf(_aPkcs1))).modulus, aModulus);
    });
  });

  group('المعطوب يرمي FormatException — لا TypeError ولا ArgumentError', () {
    void expectFormatException(String text) {
      expect(() => fromPem(text), throwsFormatException, reason: 'المدخل: «$text»');
    }

    test('نصٌّ ليس PEM', () {
      for (final String text in <String>[
        '',
        ' \r\n\t\n',
        'not a key',
        'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA', // base64 بلا غلاف
        '-----BEGIN PUBLIC KEY-----', // سطرٌ واحد
        '-----BEGIN PUBLIC KEY-----\nMIIB\n', // بلا END
        'MIIB\n-----END PUBLIC KEY-----', // بلا BEGIN
      ]) {
        expectFormatException(text);
      }
    });

    test('جسمٌ ليس base64', () {
      for (final String body in <String>[
        '!!!!',
        'MIIBIjAN BgkqhkiG', // مسافةٌ داخل السطر
        'MIIBIjANB', // طولٌ لا يكون base64
        'Proc-Type: 4,ENCRYPTED',
      ]) {
        expectFormatException(
          '-----BEGIN PUBLIC KEY-----\n$body\n-----END PUBLIC KEY-----',
        );
      }
    });

    test('base64 سليمٌ لكنّه ليس DER', () {
      final Uint8List aDer = derOf(_aSpki);
      for (final List<int> der in <List<int>>[
        <int>[], // جسمٌ فارغ
        utf8.encode('hello world'),
        <int>[0x30], // وسمٌ بلا طول
        <int>[0x30, 0x06, 0x02, 0x01, 0x05], // طولٌ يتجاوز البايتات
        <int>[0x30, 0x84, 0x7F, 0xFF, 0xFF, 0xFF], // طولٌ بملياري بايت
        <int>[0x30, 0x85, 0x01, 0x02, 0x03, 0x04, 0x05], // خمسة بايتات للطول
        // طولٌ غير محدّد — BER لا DER
        <int>[0x30, 0x80, 0x02, 0x01, 0x05, 0x02, 0x01, 0x03, 0x00, 0x00],
        aDer.sublist(0, aDer.length - 1), // مفتاحٌ حقيقيّ مقطوع
      ]) {
        expectFormatException(pem(der));
      }
    });

    test('DER سليمٌ لكنّه ليس مفتاح RSA عامّاً', () {
      for (final String text in <String>[
        _ecSpki, // مفتاح منحنًى إهليلجيّ: BIT STRING فيه نقطةٌ لا SEQUENCE
        pem(<int>[0x05, 0x00]), // NULL
        pem(<int>[0x30, 0x00]), // SEQUENCE فارغ
        pem(<int>[0x30, 0x03, 0x02, 0x01, 0x05]), // عددٌ واحد
        pem(<int>[0x30, 0x06, 0x02, 0x01, 0x00, 0x02, 0x01, 0x03]), // معاملٌ صفر
        pem(<int>[0x30, 0x06, 0x02, 0x01, 0x80, 0x02, 0x01, 0x03]), // معاملٌ سالب
        pem(<int>[0x30, 0x06, 0x02, 0x00, 0x02, 0x02, 0x01, 0x03]), // INTEGER فارغ
        // ثلاثة أعداد أوّلها صفر — شكل RSAPrivateKey: كانت الحزمة تُرجعه
        // «مفتاحاً عامّاً» معاملُه رقم الإصدار.
        pem(<int>[0x30, 0x09, 0x02, 0x01, 0x00, 0x02, 0x01, 0x05, 0x02, 0x01, 0x03]),
        // ثلاثة أعداد موجبة: PKCS#1 عددان بالضبط.
        pem(<int>[0x30, 0x09, 0x02, 0x01, 0x05, 0x02, 0x01, 0x03, 0x02, 0x01, 0x07]),
        // BIT STRING مركّبٌ فيه INTEGER: ASN1Parser نفسه يرمي عليه TypeError.
        pem(<int>[0x30, 0x05, 0x23, 0x03, 0x02, 0x01, 0x00]),
        // SPKI ببتّاتٍ زائدة في BIT STRING — لا يكون DER كاملاً.
        pem(<int>[
          0x30, 0x0D, 0x30, 0x00, 0x03, 0x09, 0x01, //
          0x30, 0x06, 0x02, 0x01, 0x05, 0x02, 0x01, 0x03,
        ]),
        // مفتاحٌ حقيقيّ بعده بايتٌ زائد.
        pem(<int>[...derOf(_aSpki), 0x00]),
      ]) {
        expectFormatException(text);
      }
    });
  });

  group('يصلح لما يفعله payment_encryptor', () {
    test('OAEP-SHA256 على مفتاح 2048 بتّاً يُخرج 256 بايتاً', () {
      final OAEPEncoding cipher = OAEPEncoding.withSHA256(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(fromPem(_aSpki)));
      // 32 لمفتاح AES و12 للـIV — كما في payment_encryptor.dart.
      expect(cipher.process(Uint8List(44)), hasLength(256));
    });
  });
}

const String _aSpki = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwb+la334MCDbybnin2oq
WlrLTUfiEMzJhgO59EVB/bRG2MLc7e96lapJX2Y96jWww9iR9KxniMUBDpMjaOjj
LDalVBab6sb4p8XqnSS5A1Exns9XicojTFI61IqtgoqG38mK8LLzyNoYL/bHpK0S
59OD8EhjyccFAGsiH8GcVEFDL87IM/as3x6sL4EF4SqSEAV282tRzLN3pwzbho5d
1+5UEGV4H+kVm5wRoekwgvs78Q+u2wRvXZG9fO+S5Eydw/+lFGLjXmqBinsN/g+S
tNPvrfq6MDlMuQAwX6kZk35qEuFbChaUYGrlZ0/K3VqU32E1LoOrC74LVt55FbEj
IwIDAQAB
-----END PUBLIC KEY-----
''';

const String _aPkcs1 = '''
-----BEGIN RSA PUBLIC KEY-----
MIIBCgKCAQEAwb+la334MCDbybnin2oqWlrLTUfiEMzJhgO59EVB/bRG2MLc7e96
lapJX2Y96jWww9iR9KxniMUBDpMjaOjjLDalVBab6sb4p8XqnSS5A1Exns9Xicoj
TFI61IqtgoqG38mK8LLzyNoYL/bHpK0S59OD8EhjyccFAGsiH8GcVEFDL87IM/as
3x6sL4EF4SqSEAV282tRzLN3pwzbho5d1+5UEGV4H+kVm5wRoekwgvs78Q+u2wRv
XZG9fO+S5Eydw/+lFGLjXmqBinsN/g+StNPvrfq6MDlMuQAwX6kZk35qEuFbChaU
YGrlZ0/K3VqU32E1LoOrC74LVt55FbEjIwIDAQAB
-----END RSA PUBLIC KEY-----
''';

/// `Modulus` المفتاح الأوّل كما يطبعه `openssl rsa -pubin -text -noout`
/// (بلا الصفر البادئ ولا النقطتين)، و`Exponent: 65537 (0x10001)`.
const String _aModulusHex =
    'C1BFA56B7DF83020DBC9B9E29F6A2A5A5ACB4D47E210CCC98603B9F44541FDB4'
    '46D8C2DCEDEF7A95AA495F663DEA35B0C3D891F4AC6788C5010E932368E8E32C'
    '36A554169BEAC6F8A7C5EA9D24B90351319ECF5789CA234C523AD48AAD828A86'
    'DFC98AF0B2F3C8DA182FF6C7A4AD12E7D383F04863C9C705006B221FC19C5441'
    '432FCEC833F6ACDF1EAC2F8105E12A92100576F36B51CCB377A70CDB868E5DD7'
    'EE541065781FE9159B9C11A1E93082FB3BF10FAEDB046F5D91BD7CEF92E44C9D'
    'C3FFA51462E35E6A818A7B0DFE0F92B4D3EFADFABA30394CB900305FA919937E'
    '6A12E15B0A1694606AE5674FCADD5A94DF61352E83AB0BBE0B56DE7915B12323';

const String _bSpki = '''
-----BEGIN PUBLIC KEY-----
MIIBIDANBgkqhkiG9w0BAQEFAAOCAQ0AMIIBCAKCAQEA4sNxJue400zLim3y/IqR
h4f0QujQv4WmMZ3/pBsvta5TAtSHlEnEgze74PlT+M6AtUQ8drDdabgvnji+U2FV
wAhZsyGWaz5TbOQBWbqPh1cV74kyQKG9HG/TXrNWNGViTKg+Vw9RLRuMx4uqIpbG
TNthzx3FkgYxLFYLCnL7vsWfzyB95kwDzShGRSpdNGTXmFwKZiOTzfiQZk2WgFpv
swRx931KU6+EnLq27p4HhR6F1qZN6KYBcR1ZDvXE9o/XEyEjzlEXLUg1IR4ubHr1
kgKF0MI1alylhMr2MadCp2zaSHHZa0eIz52/So8QGetWpmDuG0wc0CmhzzbT7Kc/
VwIBAw==
-----END PUBLIC KEY-----
''';

const String _bPkcs1 = '''
-----BEGIN RSA PUBLIC KEY-----
MIIBCAKCAQEA4sNxJue400zLim3y/IqRh4f0QujQv4WmMZ3/pBsvta5TAtSHlEnE
gze74PlT+M6AtUQ8drDdabgvnji+U2FVwAhZsyGWaz5TbOQBWbqPh1cV74kyQKG9
HG/TXrNWNGViTKg+Vw9RLRuMx4uqIpbGTNthzx3FkgYxLFYLCnL7vsWfzyB95kwD
zShGRSpdNGTXmFwKZiOTzfiQZk2WgFpvswRx931KU6+EnLq27p4HhR6F1qZN6KYB
cR1ZDvXE9o/XEyEjzlEXLUg1IR4ubHr1kgKF0MI1alylhMr2MadCp2zaSHHZa0eI
z52/So8QGetWpmDuG0wc0CmhzzbT7Kc/VwIBAw==
-----END RSA PUBLIC KEY-----
''';

/// `Modulus` المفتاح الثاني من openssl، و`Exponent: 3 (0x3)`.
const String _bModulusHex =
    'E2C37126E7B8D34CCB8A6DF2FC8A918787F442E8D0BF85A6319DFFA41B2FB5AE'
    '5302D4879449C48337BBE0F953F8CE80B5443C76B0DD69B82F9E38BE536155C0'
    '0859B321966B3E536CE40159BA8F875715EF893240A1BD1C6FD35EB356346562'
    '4CA83E570F512D1B8CC78BAA2296C64CDB61CF1DC59206312C560B0A72FBBEC5'
    '9FCF207DE64C03CD2846452A5D3464D7985C0A662393CDF890664D96805A6FB3'
    '0471F77D4A53AF849CBAB6EE9E07851E85D6A64DE8A601711D590EF5C4F68FD7'
    '132123CE51172D4835211E2E6C7AF5920285D0C2356A5CA584CAF631A742A76C'
    'DA4871D96B4788CF9DBF4A8F1019EB56A660EE1B4C1CD029A1CF36D3ECA73F57';

/// مفتاح P-256 عامّ — SubjectPublicKeyInfo سليمٌ لكنّه ليس RSA.
const String _ecSpki = '''
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEwVLHJLwgMBRHONEWnfs+dMeltgVq
6Aap+lVzXuFvSHOVa9eposfa/8V6ulNZqAYiv793NP82PE4n03+CuIMBBw==
-----END PUBLIC KEY-----
''';
