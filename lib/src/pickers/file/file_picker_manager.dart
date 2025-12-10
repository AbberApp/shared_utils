import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
const List<String> supportedVideoTypes = [
  'mp4',
  'mkv',
  'avi',
  'mov',
  'wmv',
];

/// مدير اختيار الملفات
class FilePickerManager {
  const FilePickerManager._();

  /// اختيار ملف صوتي
  static Future<File?> pickAudio(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
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
  static Future<File?> pickVideo(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
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
