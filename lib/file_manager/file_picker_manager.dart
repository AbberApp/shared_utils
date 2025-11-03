import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../widgets/toast_widget.dart';

class FilePickerManager {
  FilePickerManager._();

  static Future<File?> pickAudioFile(BuildContext context) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: audioFileTypes,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (_isAudioFile(result.files.single.extension)) {
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

  static bool _isAudioFile(String? extension) {
    if (extension == null) return false;
    return audioFileTypes.contains(extension.toLowerCase());
  }

  static List<String> audioFileTypes = [
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

  static Future<File?> pickVideoFile(BuildContext context) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: videoFileTypes,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (_isVideoFile(result.files.single.extension)) {
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

  static bool _isVideoFile(String? extension) {
    if (extension == null) return false;
    return videoFileTypes.contains(extension.toLowerCase());
  }

  static List<String> videoFileTypes = ['mp4', 'mkv', 'avi', 'mov', 'wmv'];
}
