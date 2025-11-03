import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/toast_widget.dart';

enum ImagePickerSource { camera, gallery }

class ImagePickerManager {
  ImagePickerManager._();

  static Future<File?> pickImage(
    ImagePickerSource source, {
    required BuildContext context,
    int imageQuality = 85,
    bool useCrop = false,
  }) async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: source == ImagePickerSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: imageQuality,
      );

      if (image == null) return null;

      if (useCrop) {
        final cropped = await cropAndScale(
          image.path,
          imageQuality: imageQuality,
        );
        return cropped != null ? File(cropped.path) : null;
      }

      return File(image.path);
    } on PlatformException catch (e) {
      debugPrint('خطأ في اختيار الصورة: $e');
      showToast('حدث خطأ أثناء اختيار الصورة');
      return null;
    }
  }

  static Future<XFile?> cropAndScale(
    String path, {
    int imageQuality = 85,
  }) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: imageQuality,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'تحريك وتغيير الحجم',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: Colors.white,
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'تحريك وتغيير الحجم',
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile != null) {
        return XFile(croppedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('خطأ في قص الصورة: $e');
      showToast('حدث خطأ أثناء قص الصورة');
      return null;
    }
  }

  static Future<List<XFile>?> pickMultipleImages({
    required BuildContext context,
  }) async {
    try {
      final List<XFile> images = await ImagePicker().pickMultiImage(
        imageQuality: 85,
      );
      return images;
    } on PlatformException catch (e) {
      debugPrint('خطأ في اختيار الصور: $e');
      showToast('حدث خطأ أثناء اختيار الصور');
      return null;
    }
  }
}
