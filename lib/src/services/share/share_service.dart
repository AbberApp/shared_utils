import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// ورقة المشاركة والحافظة — مصدرٌ واحد بدل تكرار `SharePlus.instance.share(...)` في كلّ شاشة.
///
/// **`origin` ليس تفصيلاً تجميلياً:** على iPad تُعرَض الورقة popover، ويطلب النظام المستطيلَ الذي خرجت
/// منه. من لم يمرّره رأى الورقة تخرج من زاوية الشاشة، وفي حالاتٍ رمى النظام استثناءً. مرّر
/// `context.shareOrigin` من العنصر الذي ضغطه المستخدم — انظر `ShareOrigin`.
abstract final class ShareService {
  /// نسخٌ إلى حافظة الجهاز.
  static Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));

  /// مشاركة نصّ. `subject` عنوان الرسالة في البريد، و`title` عنوان ورقة المشاركة على أندرويد.
  static Future<ShareResult> shareText(
    String text, {
    String? subject,
    String? title,
    Rect? origin,
  }) =>
      SharePlus.instance.share(
        ShareParams(text: text, subject: subject, title: title, sharePositionOrigin: origin),
      );

  /// مشاركة ملفٍ من بايتاته: يُكتب في المجلّد المؤقّت أوّلاً لأنّ ورقة المشاركة تحتاج مسارًا على القرص.
  /// الاسم يصل كما هو (`fileNameOverrides`) فلا يظهر للمستخدم اسمٌ عشوائيّ من المجلّد المؤقّت.
  static Future<ShareResult> shareBytes(
    List<int> bytes,
    String fileName,
    String mimeType, {
    String? text,
    String? subject,
    Rect? origin,
  }) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return shareFiles([file.path],
        mimeTypes: [mimeType], fileNames: [fileName], text: text, subject: subject, origin: origin);
  }

  /// مشاركة ملفٍّ أو أكثر موجودٍ على القرص.
  static Future<ShareResult> shareFiles(
    List<String> paths, {
    List<String>? mimeTypes,
    List<String>? fileNames,
    String? text,
    String? subject,
    Rect? origin,
  }) =>
      SharePlus.instance.share(
        ShareParams(
          files: [
            for (int i = 0; i < paths.length; i++)
              XFile(paths[i], mimeType: mimeTypes != null && i < mimeTypes.length ? mimeTypes[i] : null),
          ],
          fileNameOverrides: fileNames,
          text: text,
          subject: subject,
          sharePositionOrigin: origin,
        ),
      );
}

/// مصدر ورقة المشاركة: مستطيل العنصر الذي ضغطه المستخدم، بإحداثيات الشاشة.
///
/// يُقرأ من سياق العنصر نفسه لا من سياق الصفحة، وإلّا خرجت الورقة من مكانٍ لا علاقة له بالزرّ.
/// يعيد `null` حين لا يكون للعنصر حجمٌ بعد — وعندها يتصرّف النظام بافتراضه بدل أن يرمي.
extension ShareOrigin on BuildContext {
  Rect? get shareOrigin {
    final RenderObject? object = findRenderObject();
    if (object is! RenderBox || !object.hasSize) return null;
    return object.localToGlobal(Offset.zero) & object.size;
  }
}
