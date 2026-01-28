import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../widgets/toast.dart';

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
class FilePickerManager {
  const FilePickerManager._();

  /// اختيار ملف
  static Future<File?> pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      showToast('حدث خطأ أثناء اختيار الملف: $e');
      return null;
    }
  }

  // pick svg file
  static Future<File?> pickSvg() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svg'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      showToast('حدث خطاء اثناء اختيار الملف: $e');
      return null;
    }
  }

  /// اختيار ملف صوتي
  static Future<File?> pickAudio() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedAudioTypes,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final extension = result.files.single.extension?.toLowerCase();

        if (_isValidAudio(extension)) {
          return file;
        } else {
          showToast('الرجاء اختيار ملف صوتي فقط');
        }
      }
      return null;
    } catch (e) {
      showToast('حدث خطأ أثناء اختيار الملف: $e');
      return null;
    }
  }

  /// اختيار ملف فيديو
  static Future<File?> pickVideo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedVideoTypes,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final extension = result.files.single.extension?.toLowerCase();

        if (_isValidVideo(extension)) {
          return file;
        } else {
          showToast('الرجاء اختيار ملف فيديو فقط');
        }
      }
      return null;
    } catch (e) {
      showToast('حدث خطأ أثناء اختيار الملف: $e');
      return null;
    }
  }

  static bool _isValidAudio(String? extension) {
    return extension != null && supportedAudioTypes.contains(extension);
  }

  static bool _isValidVideo(String? extension) {
    return extension != null && supportedVideoTypes.contains(extension);
  }
}
