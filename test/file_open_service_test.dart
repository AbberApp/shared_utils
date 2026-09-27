// استنتاج نوع MIME وترجمة نتيجة الفتح.
//
// `FileOpenService.open` نفسه ينادي قناةً أصليّة فلا يُختبر بلا جهاز؛ أمّا الجزءان اللذان يقع
// فيهما الخطأ فحسابٌ خالص: امتدادٌ يُترجم إلى نوعٍ يفهمه أندرويد، ونتيجةٌ تُترجم إلى حصيلةٍ لها
// رسالة. ومن أخطأ في الأوّل رأى «لا يوجد تطبيق» على ملفٍّ يفتحه جهازه، ومن أهمل الثاني رأى
// الضغطة تذهب بلا أثر.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

void main() {
  group('mimeTypeOf', () {
    test('الامتدادات الشائعة تُترجم إلى أنواعها', () {
      expect(FileOpenService.mimeTypeOf('/tmp/invoice.pdf'), 'application/pdf');
      expect(FileOpenService.mimeTypeOf('/tmp/user_11.vcf'), 'text/x-vcard');
      expect(FileOpenService.mimeTypeOf('/tmp/statement.xlsx'),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      expect(FileOpenService.mimeTypeOf('/tmp/voice.m4a'), 'audio/mp4');
    });

    test('حالة الأحرف لا تغيّر النتيجة — الاسم يأتي من الخادم كما كتبه صاحبه', () {
      expect(FileOpenService.mimeTypeOf('/tmp/INVOICE.PDF'), 'application/pdf');
      expect(FileOpenService.mimeTypeOf('/tmp/Photo.JPeG'), 'image/jpeg');
    });

    test('مسارٌ فيه نقاطٌ كثيرة: الامتداد هو ما بعد آخر نقطة', () {
      expect(FileOpenService.mimeTypeOf('/tmp/2026.09.27.report.csv'), 'text/csv');
    });

    test('null لما لا امتداد له أو لامتدادٍ غير معروف — فيتصرّف النظام باستنتاجه', () {
      expect(FileOpenService.mimeTypeOf('/tmp/receipt'), isNull);
      expect(FileOpenService.mimeTypeOf('/tmp/archive.rar'), isNull);
      expect(FileOpenService.mimeTypeOf('/tmp/trailing.'), isNull);
      expect(FileOpenService.mimeTypeOf(''), isNull);
    });

    test('مجلّدٌ فيه نقطة ولا نقطة في الاسم لا يُقرأ امتدادًا', () {
      // الالتقاط بآخر نقطةٍ في المسار كلّه يعطي هنا «d/receipt» لا امتدادًا معروفًا.
      expect(FileOpenService.mimeTypeOf('/tmp/v1.0/receipt'), isNull);
    });
  });

  group('outcomeOf', () {
    test('كلّ نتيجةٍ لها حصيلتها', () {
      expect(FileOpenService.outcomeOf(ResultType.done), FileOpenOutcome.opened);
      expect(FileOpenService.outcomeOf(ResultType.fileNotFound), FileOpenOutcome.notFound);
      expect(FileOpenService.outcomeOf(ResultType.noAppToOpen), FileOpenOutcome.noApp);
      expect(
          FileOpenService.outcomeOf(ResultType.permissionDenied), FileOpenOutcome.permissionDenied);
      expect(FileOpenService.outcomeOf(ResultType.error), FileOpenOutcome.failed);
    });

    test('isOpened للنجاح وحده', () {
      expect(FileOpenOutcome.opened.isOpened, isTrue);
      for (final FileOpenOutcome outcome in FileOpenOutcome.values) {
        if (outcome == FileOpenOutcome.opened) continue;
        expect(outcome.isOpened, isFalse, reason: '$outcome ليست فتحًا ناجحًا');
      }
    });

    test('كلّ حصيلةٍ تحمل رسالةً غير فارغة — تُعرض كما هي', () {
      for (final FileOpenOutcome outcome in FileOpenOutcome.values) {
        expect(outcome.message, isNotEmpty, reason: '$outcome بلا رسالة');
      }
    });
  });
}
