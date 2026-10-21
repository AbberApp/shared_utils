// أسماء الملفّات المرفوعة لا تتجاوز ٩٠ حرفاً.
//
// الخادم (Django `FileField`) يرفض اسماً يتجاوز ١٠٠ حرف، وفيديو معرض iOS بعد الضغط يُسمّى
// `image_picker_<GUID><الاسم><UUID>.mp4` (١٢٠ حرفاً)، فكانت الحالة تفشل. الإصلاح في `DioConsumer`
// نفسه، فيصل كلّ رفعٍ في كلّ تطبيق دون لمس كوده.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اسمٌ حقيقيّ كما يخرجه `video_compressor_plus` لفيديو من معرض iOS.
const String _iosVideo =
    'image_picker_920A1262-170A-4985-9229-934E7353DF2C-68026-000003D7C4B55FD0IMG_1234E621E1F8-C36C-495A-93FC-0C247A3E6E5F.mp4';

final RegExp _tagged = RegExp(r'^[0-9a-f]{16}(_|\.|$)');

/// محوِّل يلتقط جسم الطلب كما يخرج على السلك.
class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? options;
  final BytesBuilder body = BytesBuilder();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    this.options = options;
    if (requestStream != null) await requestStream.forEach(body.add);
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

(DioConsumer, _CaptureAdapter) _consumer() {
  final Dio client = Dio();
  final _CaptureAdapter adapter = _CaptureAdapter();
  final DioConsumer consumer = DioConsumer(
    client: client,
    appInterceptors: InterceptorsWrapper(),
    baseUrl: 'https://example.test',
    internalServerErrorCode: 500,
    allowBadCertificates: false,
  );
  client.httpClientAdapter = adapter;
  return (consumer, adapter);
}

/// أسماء الملفّات في جسم multipart كما وصلت.
List<String> _wireFileNames(_CaptureAdapter adapter) => RegExp(r'filename="([^"]*)"')
    .allMatches(utf8.decode(adapter.body.toBytes(), allowMalformed: true))
    .map((m) => m.group(1)!)
    .toList();

void main() {
  group('safeUploadFileName', () {
    test('الاسم القصير يعود كما هو', () {
      expect(safeUploadFileName('IMG_1234.MOV'), 'IMG_1234.MOV');
      expect(safeUploadFileName('مقطع الحالة.mp4'), 'مقطع الحالة.mp4');
      expect(safeUploadFileName('a' * 86 + '.mp4'), hasLength(90), reason: '٩٠ بالضبط لا يُمسّ');
      expect(safeUploadFileName('a' * 86 + '.mp4'), 'a' * 86 + '.mp4');
    });

    test('٩١ حرفاً فأكثر يُقصّ إلى ٩٠ ويحفظ الامتداد', () {
      final String name = safeUploadFileName('a' * 87 + '.mp4');
      expect(name.length, lessThanOrEqualTo(kMaxUploadFileNameLength));
      expect(name, endsWith('.mp4'));
      expect(name, matches(_tagged));
    });

    test('فيديو معرض iOS بعد الضغط (١٢٠ حرفاً)', () {
      expect(_iosVideo.length, greaterThan(100));
      final String name = safeUploadFileName(_iosVideo);
      expect(name.length, lessThanOrEqualTo(90));
      expect(name, endsWith('.mp4'));
      expect(name, contains('_image_picker_920A1262'), reason: 'بداية الاسم الأصليّ محفوظة بعد البصمة');
    });

    test('اسم عربيّ طويل، وإيموجي لا يُشطر', () {
      final String arabic = safeUploadFileName('${'مستند طويل جداً ' * 10}.pdf');
      expect(arabic.length, lessThanOrEqualTo(90));
      expect(arabic, endsWith('.pdf'));

      final String emoji = safeUploadFileName('${'😀' * 70}.png');
      expect(emoji.length, lessThanOrEqualTo(90));
      expect(utf8.decode(utf8.encode(emoji)), isNot(contains('\uFFFD')), reason: 'لا زوج surrogate مكسور');
    });

    test('بلا امتداد، أو بامتدادٍ غير صالح', () {
      final String plain = safeUploadFileName('x' * 120);
      expect(plain.length, lessThanOrEqualTo(90));
      expect(plain, isNot(contains('.')));

      final String odd = safeUploadFileName('${'y' * 100}.not an ext');
      expect(odd.length, lessThanOrEqualTo(90));
    });

    test('المسار يُحذف، و`"` ومحارف التحكّم تُستبدل', () {
      expect(safeUploadFileName('/private/var/tmp/video.mp4'), 'video.mp4');
      expect(safeUploadFileName(r'C:\Users\a\doc.pdf'), 'doc.pdf');
      expect(safeUploadFileName('a"b\r\nc.mp4'), 'a_b__c.mp4');
    });

    test('ثابتٌ للاسم نفسه، ومختلفٌ لاسمين يفترقان في آخرهما', () {
      final String a = '${'z' * 100}_one.mp4';
      final String b = '${'z' * 100}_two.mp4';
      expect(safeUploadFileName(a), safeUploadFileName(a));
      expect(safeUploadFileName(a), isNot(safeUploadFileName(b)), reason: 'البصمة في الأوّل تميّزهما ولو قُصّ الذيل');
      expect(safeUploadFileName(a).substring(0, 16), isNot(safeUploadFileName(b).substring(0, 16)));
    });

    test('تطبيقه مرّتين لا يغيّره', () {
      final String once = safeUploadFileName(_iosVideo);
      expect(safeUploadFileName(once), once);
    });
  });

  group('DioConsumer', () {
    final List<int> bytes = List<int>.generate(1000, (i) => i % 256);

    test('post برفع ملفٍّ: الاسم على السلك ≤ ٩٠ والمحتوى سليم', () async {
      final (consumer, adapter) = _consumer();
      await consumer.post('/stories/', formDataIsEnabled: true, body: {
        'type': 'video',
        'media': MultipartFile.fromBytes(bytes, filename: _iosVideo, contentType: DioMediaType('video', 'mp4')),
      });

      final List<String> names = _wireFileNames(adapter);
      expect(names, hasLength(1));
      expect(names.single.length, lessThanOrEqualTo(90));
      expect(names.single, endsWith('.mp4'));
      final String wire = latin1.decode(adapter.body.toBytes());
      expect(wire, contains('content-type: video/mp4'));
      expect(wire, contains(latin1.decode(bytes)), reason: 'محتوى الملفّ كما هو');
    });

    test('upload وput وpatch، وملفّات داخل قائمة', () async {
      final (consumer, adapter) = _consumer();
      await consumer.upload('/chat/v2/files/', body: {
        'files': [
          MultipartFile.fromBytes(bytes, filename: _iosVideo),
          MultipartFile.fromBytes(bytes, filename: 'short.jpg'),
        ],
      });
      expect(_wireFileNames(adapter), [safeUploadFileName(_iosVideo), 'short.jpg']);

      final (putConsumer, putAdapter) = _consumer();
      await putConsumer.put('/x/', formDataIsEnabled: true, body: {
        'image': MultipartFile.fromBytes(bytes, filename: '${'p' * 140}.png'),
      });
      expect(_wireFileNames(putAdapter).single.length, lessThanOrEqualTo(90));

      final (patchConsumer, patchAdapter) = _consumer();
      await patchConsumer.patch('/x/', formDataIsEnabled: true, body: {
        'image': MultipartFile.fromBytes(bytes, filename: '${'q' * 140}.png'),
      });
      expect(_wireFileNames(patchAdapter).single.length, lessThanOrEqualTo(90));
    });

    test('ملفٌّ في الجسم بلا formDataIsEnabled يُرسَل multipart لا JSON', () async {
      final (consumer, adapter) = _consumer();
      await consumer.post('/announcements/', body: {
        'title': 'إعلان',
        'image': MultipartFile.fromBytes(bytes, filename: 'banner.png'),
      });
      expect(adapter.options!.contentType, startsWith('multipart/form-data'));
      expect(_wireFileNames(adapter), ['banner.png']);
    });

    test('جسمٌ بلا ملفّات يبقى JSON', () async {
      final (consumer, adapter) = _consumer();
      await consumer.post('/x/', body: {'a': 1});
      expect(adapter.options!.data, {'a': 1});
    });

    test('إعادة إرسال الطلب نفسه (clone) لا ترمي «already finalized»', () async {
      final FormData formData = safeUploadFormData({'media': MultipartFile.fromBytes(bytes, filename: _iosVideo)});
      final List<int> first = await formData.clone().readAsBytes();
      final List<int> second = await formData.clone().readAsBytes();
      expect(second.length, first.length);
    });
  });
}
