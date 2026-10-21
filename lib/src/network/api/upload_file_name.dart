import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// أقصى طولٍ لاسم ملفٍ يُرفع. حقول الملفّات في الخادم (Django `FileField`)
/// ترفض اسماً يتجاوز ١٠٠ حرف («تأكد أن طول اسم الملف لا يتجاوز 100 حرف»)،
/// و٩٠ تترك هامشاً. الأسماء تتجاوزها فعلاً: فيديو معرض iOS بعد الضغط يُسمّى
/// `image_picker_<GUID><الاسم><UUID>.mp4` فيبلغ ١٢٠–١٥٣ حرفاً، وملفّات
/// `file_picker` تحمل اسم المستخدم الأصليّ بلا حدّ.
const int kMaxUploadFileNameLength = 90;

final RegExp _pathSeparator = RegExp(r'[/\\]');

/// `"` يُرمَّز على السلك `%22` فيطول الاسم، ومحارف التحكّم (ومنها `\r\n`) تُرمَّز
/// أو تكسر الترويسة.
final RegExp _unsafeChars = RegExp(r'["\x00-\x1F\x7F]');

final RegExp _extension = RegExp(r'^[A-Za-z0-9]{1,10}$');

/// اسمٌ آمن لملفٍ يُرفع: الاسم وحده بلا مسار، بلا محارف تحكّم ولا `"`، وطوله
/// لا يتجاوز [maxLength].
///
/// الاسم الذي يحقّق ذلك يعود **كما هو** (يبقى اسم المرفق الظاهر في المحادثة
/// والدعم). والأطول يصير `<بصمة>_<بداية الاسم>.<الامتداد>`:
/// - الامتداد محفوظ (الخادم والتخزين يستنتجان نوع الملفّ منه).
/// - البصمة ١٦ حرفاً ثابتة من الاسم الأصليّ كاملاً، في **أوّل** الاسم: إن قصّ
///   الخادم ذيل المسار (Django يقصّه عند ١٠٠ مع المجلّد) بقي ما يميّز الملفّين،
///   فلا يكتب أحدهما فوق الآخر. والاسم نفسه يعطي النتيجة نفسها دائماً.
/// - القصّ بالحروف (runes) فلا يُشطر حرفٌ مركّب كالإيموجي.
///
/// الطول بـ`String.length` (وحدات UTF-16)، وهو أكبر من عدد الحروف عند الخادم
/// أو يساويه، فالحدّ مضمون من جهته.
String safeUploadFileName(String name, {int maxLength = kMaxUploadFileNameLength}) {
  final String base = name.split(_pathSeparator).last.replaceAll(_unsafeChars, '_');
  if (base.isNotEmpty && base.length <= maxLength) return base;

  final int dot = base.lastIndexOf('.');
  final String ext = dot > 0 && _extension.hasMatch(base.substring(dot + 1)) ? base.substring(dot) : '';
  final String root = ext.isEmpty ? base : base.substring(0, dot);
  final String tag = const Uuid().v5(Namespace.url.value, name).replaceAll('-', '').substring(0, 16);

  final int room = maxLength - tag.length - 1 - ext.length;
  final StringBuffer kept = StringBuffer();
  for (final int rune in root.runes) {
    final String char = String.fromCharCode(rune);
    if (kept.length + char.length > room) break;
    kept.write(char);
  }
  return kept.isEmpty ? '$tag$ext' : '${tag}_$kept$ext';
}

extension SafeUploadMultipartFile on MultipartFile {
  /// الملفّ نفسه باسمٍ من [safeUploadFileName]، أو هو نفسه إن كان اسمه آمناً.
  ///
  /// `filename` في dio نهائيّ، فيُبنى ملفٌّ جديد يقرأ المحتوى من نسخةٍ (`clone`)
  /// في كلّ مرّة: إعادة إرسال الطلب لا ترمي «already finalized». ونوع المحتوى
  /// يُنقل كما هو فلا يُعاد استنتاجه من الاسم الجديد.
  MultipartFile withSafeFileName({int maxLength = kMaxUploadFileNameLength}) {
    final String? name = filename;
    if (name == null) return this;
    final String safe = safeUploadFileName(name, maxLength: maxLength);
    if (safe == name) return this;
    return MultipartFile.fromStream(
      () => clone().finalize(),
      length,
      filename: safe,
      contentType: contentType,
      headers: headers,
    );
  }
}

/// جسم multipart من [body]، وكلّ ملفّ فيه (ولو داخل قائمة أو خريطة متداخلة)
/// باسمٍ آمن.
FormData safeUploadFormData(Map<String, dynamic> body) {
  final FormData formData = FormData.fromMap(body);
  for (int i = 0; i < formData.files.length; i++) {
    final MapEntry<String, MultipartFile> entry = formData.files[i];
    final MultipartFile safe = entry.value.withSafeFileName();
    if (!identical(safe, entry.value)) formData.files[i] = MapEntry(entry.key, safe);
  }
  return formData;
}

/// هل في [value] ملفٌّ (`MultipartFile`) ولو متداخلاً في قائمة أو خريطة.
bool containsUploadFile(Object? value) => switch (value) {
      MultipartFile() => true,
      Map() => value.values.any(containsUploadFile),
      Iterable() => value.any(containsUploadFile),
      _ => false,
    };
