import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../ui/widgets/toast.dart';

/// أنواع الملفات الصوتية المدعومة
const List<String> supportedAudioTypes = [
  'mp3',
  'wav',
  'm4a',
  'aac',
  'amr',
  'opus',
  'wma',
  '3gp',
  'ogg',
];

/// أنواع الملفات المرئية المدعومة
const List<String> supportedVideoTypes = ['mp4', 'mkv', 'avi', 'mov', 'wmv'];

/// مدير اختيار الملفات
///
/// مبنيّ على `FilePicker.pickFile` **المفردة** لا `pickFiles(allowMultiple: false)`:
/// كل دوالّ هذا الصنف تُعيد ملفاً واحداً، فالمفردة تُعبّر عن النيّة مباشرةً وتُغني
/// عن `.files.single` التي كانت ترمي `StateError` لو عاد أكثر من ملف.
class FilePickerManager {
  const FilePickerManager._();

  /// امتداد الملف من اسمه، بحروف صغيرة، أو `null` إن لم يكن له امتداد.
  ///
  /// `PlatformFile` لم يعد يوفّر `extension` في file_picker 12، والاسم هو
  /// المصدر الوحيد المتاح. نأخذ ما بعد آخر نقطة، ونتجاهل الاسم الذي يبدأ بنقطة
  /// بلا امتداد حقيقي (مثل `.gitignore`).
  static String? _extensionOf(String name) {
    final int dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  /// يفتح المُنتقي ويُعيد الملف المختار، أو `null` عند الإلغاء أو الخطأ.
  static Future<File?> _pick({
    required FileType type,
    List<String>? allowedExtensions,
    bool Function(String? extension)? validate,
    String? invalidMessage,
  }) async {
    try {
      final PlatformFile? picked = await FilePicker.pickFile(
        type: type,
        allowedExtensions: allowedExtensions,
      );

      final String? path = picked?.path;
      if (picked == null || path == null) return null;

      if (validate != null && !validate(_extensionOf(picked.name))) {
        showToast(invalidMessage!);
        return null;
      }
      return File(path);
    } on Exception catch (e) {
      showToast('حدث خطأ أثناء اختيار الملف: $e');
      return null;
    }
  }

  /// اختيار ملف
  static Future<File?> pickFile() => _pick(type: FileType.any);

  /// اختيار ملف svg
  static Future<File?> pickSvg() =>
      _pick(type: FileType.custom, allowedExtensions: const ['svg']);

  /// اختيار ملف صوتي
  static Future<File?> pickAudio() => _pick(
    type: FileType.custom,
    allowedExtensions: supportedAudioTypes,
    validate: _isValidAudio,
    invalidMessage: 'الرجاء اختيار ملف صوتي فقط',
  );

  /// اختيار ملف فيديو
  static Future<File?> pickVideo() => _pick(
    type: FileType.custom,
    allowedExtensions: supportedVideoTypes,
    validate: _isValidVideo,
    invalidMessage: 'الرجاء اختيار ملف فيديو فقط',
  );

  static bool _isValidAudio(String? extension) =>
      extension != null && supportedAudioTypes.contains(extension);

  static bool _isValidVideo(String? extension) =>
      extension != null && supportedVideoTypes.contains(extension);
}
