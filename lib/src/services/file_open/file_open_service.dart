import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// فتح ملفٍّ بتطبيق النظام — مصدرٌ واحد بدل `OpenFile.open(...)` في كلّ شاشة.
///
/// **النتيجة ليست تفصيلاً:** `OpenFile.open` يعيد `OpenResult` ولا يرمي، فمن أهملها رأى الضغطة
/// تذهب بلا فتحٍ ولا رسالة — والسبب الشائع أنّ الجهاز بلا تطبيقٍ يفتح هذا النوع. تُعيد دوالّ هذه
/// الخدمة [FileOpenOutcome] ومعها [FileOpenOutcome.message] جاهزةً للعرض، والقرار للمستدعي.
///
/// **والنوع كذلك:** أندرويد يحتاج نوع MIME ليختار التطبيق، ومن تركه رأى «لا يوجد تطبيق» على ملفٍّ
/// يفتحه جهازه فعلاً. يُستنتج هنا من الامتداد عبر [mimeTypeOf]، ويُمرَّر `type` لتجاوز الاستنتاج.
abstract final class FileOpenService {
  /// فتح ملفٍّ موجودٍ على القرص. النوع يُستنتج من الامتداد إن لم يُمرَّر.
  static Future<FileOpenOutcome> open(String path, {String? type}) async {
    final OpenResult result = await OpenFile.open(path, type: type ?? mimeTypeOf(path));
    return outcomeOf(result.type);
  }

  /// فتح ملفٍّ من بايتاته: يُكتب في المجلّد المؤقّت أوّلاً لأنّ تطبيق النظام يحتاج مسارًا على القرص.
  /// الاسم يصل كما هو، فلا يظهر للمستخدم اسمٌ عشوائيّ ولا يضيع الامتداد الذي يُستنتج منه النوع.
  static Future<FileOpenOutcome> openBytes(
    List<int> bytes,
    String fileName, {
    String? type,
  }) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return open(file.path, type: type);
  }

  /// فتح نصٍّ كملفّ — بطاقة vCard، أو CSV، أو أيّ محتوًى نصيّ يُسلَّم لتطبيقٍ آخر.
  static Future<FileOpenOutcome> openText(
    String text,
    String fileName, {
    String? type,
  }) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/$fileName');
    await file.writeAsString(text, flush: true);
    return open(file.path, type: type);
  }

  /// نوع MIME من امتداد المسار، و`null` لامتدادٍ غير معروف — وعندها يتصرّف النظام باستنتاجه.
  ///
  /// الجدول مقصورٌ على ما يفتحه المستخدم فعلًا في تطبيقاتنا: الفواتير وكشوف الحساب والبطاقات
  /// والمرفقات. وزيادتُه سطرٌ واحد، بينما ورقةٌ كاملة من أنواع MIME تُصان بلا مستهلك.
  static String? mimeTypeOf(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    return _mimeTypes[path.substring(dot + 1).toLowerCase()];
  }

  /// ترجمة نتيجة الإضافة إلى حصيلةٍ لها رسالةٌ عربيّة. عامّةٌ لأنّ المستدعي قد يفتح بنفسه.
  static FileOpenOutcome outcomeOf(ResultType type) => switch (type) {
        ResultType.done => FileOpenOutcome.opened,
        ResultType.fileNotFound => FileOpenOutcome.notFound,
        ResultType.noAppToOpen => FileOpenOutcome.noApp,
        ResultType.permissionDenied => FileOpenOutcome.permissionDenied,
        ResultType.error => FileOpenOutcome.failed,
      };

  static const Map<String, String> _mimeTypes = <String, String>{
    'pdf': 'application/pdf',
    'vcf': 'text/x-vcard',
    'csv': 'text/csv',
    'txt': 'text/plain',
    'json': 'application/json',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/wav',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'zip': 'application/zip',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };
}

/// حصيلة محاولة الفتح، ومعها رسالةٌ عربيّة جاهزة للعرض.
enum FileOpenOutcome {
  opened('تم فتح الملف'),
  noApp('لا يوجد تطبيق على جهازك يفتح هذا الملف'),
  notFound('تعذر العثور على الملف'),
  permissionDenied('لا توجد صلاحية لفتح هذا الملف'),
  failed('تعذر فتح الملف');

  const FileOpenOutcome(this.message);

  /// رسالةٌ عربيّة تصلح لـ`showToast` كما هي.
  final String message;

  /// هل فُتح الملفّ فعلًا — الشرط الوحيد الذي لا يحتاج رسالة.
  bool get isOpened => this == FileOpenOutcome.opened;
}
