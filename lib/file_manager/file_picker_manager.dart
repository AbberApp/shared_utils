import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:image_picker/image_picker.dart';

import 'image_picker_manager.dart';
import '../widgets/toast_widget.dart';

class FilePickerManager {
  FilePickerManager._();

  static Future<File?> pickAudioFile(BuildContext context) async {
    try {
      if (await ImagePickerManager.checkAndRequestCameraPermissions(
        ImageSource.gallery,
        context: context,
      )) {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: audioFileTypes,
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          final File file = File(result.files.single.path!);
          final bool isAudio = _isAudioFile(result.files.single.extension);

          if (isAudio) {
            return file;
          } else {
            ToastWidget.showToast('Please select an audio file');
            return null;
          }
        }
      }
      return null;
    } catch (e) {
      ToastWidget.showToast('Error picking file: $e');
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
}
