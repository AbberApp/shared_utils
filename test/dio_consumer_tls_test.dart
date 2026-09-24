// من يقبل الشهادات ومن يتحقّق منها.
//
// `DioConsumer` يقبل كلّ شهادة بتركيب `createHttpClient` على محوِّل `Dio`، وهو الافتراض. و`badCertificateCallback`
// في dart:io يُضبط ولا يُقرأ، فالشاهد الممكن هو المحوِّل نفسه: أُركّب عليه شيء أم تُرك كما هو. وتركُه كما هو يعني
// بقاءَ تحقّق dart:io الافتراضيّ، أي رفض الشهادة المزوّرة أو المنتهية أو التي لاسمِ نطاقٍ آخر.
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

DioConsumer _consumer(Dio client, {bool? allowBadCertificates}) => DioConsumer(
      client: client,
      appInterceptors: InterceptorsWrapper(),
      baseUrl: 'https://example.test',
      internalServerErrorCode: 500,
      allowBadCertificates: allowBadCertificates ?? true,
    );

IOHttpClientAdapter _adapter(Dio client) => client.httpClientAdapter as IOHttpClientAdapter;

void main() {
  test('الافتراض يركّب محوِّلاً يقبل كلّ شهادة — سلوك المشاريع القائمة لا يتغيّر', () {
    final Dio client = Dio();
    _consumer(client);
    expect(_adapter(client).createHttpClient, isNotNull);
    expect(_adapter(client).createHttpClient!(), isNotNull, reason: 'المصنع يبني عميلاً صالحاً');
  });

  test('`allowBadCertificates: false` لا يمسّ المحوِّل، فيبقى تحقّق dart:io', () {
    final Dio client = Dio();
    _consumer(client, allowBadCertificates: false);
    expect(_adapter(client).createHttpClient, isNull);
  });

  test('بقيّة الإعداد واحدةٌ في الحالتين', () {
    final Dio permissive = Dio();
    final Dio verifying = Dio();
    _consumer(permissive);
    _consumer(verifying, allowBadCertificates: false);

    for (final Dio client in [permissive, verifying]) {
      expect(client.options.baseUrl, 'https://example.test');
      expect(client.options.responseType, ResponseType.plain);
      expect(client.options.followRedirects, isTrue);
      expect(client.options.maxRedirects, 5);
      expect(client.options.validateStatus(499), isTrue);
      expect(client.options.validateStatus(500), isFalse);
    }
  });
}
