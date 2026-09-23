import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../ui/widgets/toast.dart';

/// `XFile` جزءٌ من توقيع `pickMultipleImages` و`cropImage`، فنصدّره من هنا
/// صراحةً بدل الاتّكال على إعادة تصديره ضمناً عبر `share_plus`.
export 'package:image_picker/image_picker.dart' show XFile;

/// مصدر اختيار الصورة
enum ImagePickerSource { camera, gallery }

/// مدير اختيار الصور
class ImagePickerManager {
  const ImagePickerManager._();

  /// اختيار صورة واحدة
  static Future<File?> pickImage(
    ImagePickerSource source, {
    int imageQuality = 85,
    bool useCrop = false,
  }) async {
    final quality = _safeQuality(imageQuality);
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source == ImagePickerSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: quality,
      );

      if (image == null) return null;

      if (useCrop) {
        final cropped = await cropImage(image.path, imageQuality: quality);
        return cropped != null ? File(cropped.path) : null;
      }

      return File(image.path);
    } on Object catch (e) {
      debugPrint('خطأ في اختيار الصورة: $e');
      showToast('حدث خطأ أثناء اختيار الصورة');
      return null;
    }
  }

  /// اختيار صور متعددة
  static Future<List<XFile>?> pickMultipleImages({
    int imageQuality = 85,
  }) async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: _safeQuality(imageQuality),
      );
      return images;
    } on Object catch (e) {
      debugPrint('خطأ في اختيار الصور: $e');
      showToast('حدث خطأ أثناء اختيار الصور');
      return null;
    }
  }

  /// حصر الجودة في 0..100 — `image_picker` يتحقّق منها ويرمي `ArgumentError`
  /// لا `PlatformException`، فيعبر أي التقاطٍ ضيّق ويُسقط التطبيق. نحصرها هنا
  /// ليبقى السلوك آمناً في الإصدار، و`assert` يكشف القيمة الخاطئة في التطوير.
  static int _safeQuality(int imageQuality) {
    assert(
      imageQuality >= 0 && imageQuality <= 100,
      'imageQuality يجب أن تكون بين 0 و 100، والقيمة المُمرَّرة: $imageQuality',
    );
    return imageQuality.clamp(0, 100);
  }

  /// قص الصورة
  static Future<XFile?> cropImage(
    String path, {
    int imageQuality = 85,
  }) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
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
    } on Object catch (e) {
      debugPrint('خطأ في قص الصورة: $e');
      showToast('حدث خطأ أثناء قص الصورة');
      return null;
    }
  }
}
