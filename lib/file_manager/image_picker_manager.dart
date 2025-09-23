import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ua_client_hints/ua_client_hints.dart';

import '../widgets/toast_widget.dart';

class ImagePickerManager {
  ImagePickerManager._();

  static Future<int> _getAndroidSdkVersion() async {
    if (Platform.isAndroid) {
      final UserAgentData uaData = await userAgentData();

      return int.parse(uaData.platformVersion);
    }
    return 0;
  }

  static Future<bool> checkAndRequestCameraPermissions(
    ImageSource source, {
    required BuildContext context,
    IconData icon = Icons.camera_alt_outlined,
  }) async {
    try {
      final PermissionStatus status = await Permission.photos.status;
      if (status.isPermanentlyDenied) {
        // ImagePickerManager.showOpenAppSettingDialog(
        //   context ,
        //   icon,
        // );
        return false;
      } else if (source == ImageSource.camera) {
        return await _handleCameraPermission();
      } else if (source == ImageSource.gallery) {
        return await _handleGalleryPermission();
      }
      return false;
    } catch (e) {
      debugPrint('خطأ في التصريحات: $e');
      return false;
    }
  }

  static Future<bool> _handleCameraPermission() async {
    final PermissionStatus status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      showToast('يجب السماح للكاميرا من الإعدادات');
      // await openAppSettings();
      return false;
    }

    final PermissionStatus result = await Permission.camera.request();

    if (result.isPermanentlyDenied) {
      showToast('يجب السماح للكاميرا من الإعدادات');
      // await openAppSettings();
      return false;
    }

    return result.isGranted;
  }

  static Future<bool> _handleGalleryPermission() async {
    if (Platform.isAndroid) {
      return await _handleAndroidGalleryPermission();
    } else if (Platform.isIOS) {
      return await _handleIOSGalleryPermission();
    }
    return false;
  }

  static Future<bool> _handleAndroidGalleryPermission() async {
    final int sdkVersion = await _getAndroidSdkVersion();

    // Android 13+ (API level 33+)
    if (sdkVersion >= 13) {
      return await _requestPermissionWithFallback([Permission.photos, Permission.videos]);
    }
    // Android 10-12 (API level 29-32)
    else if (sdkVersion >= 10) {
      // تجربة الصور أولاً، ثم التخزين كبديل
      final bool photosGranted = await _requestSinglePermission(Permission.photos);
      if (!photosGranted) {
        return await _requestSinglePermission(Permission.storage);
      }
      return photosGranted;
    }
    // Android 9 وأقل (API level 28-)
    else {
      return await _requestSinglePermission(Permission.storage);
    }
  }

  static Future<bool> _handleIOSGalleryPermission() async {
    return await _requestSinglePermission(Permission.photos);
  }

  static Future<bool> _requestSinglePermission(Permission permission) async {
    final PermissionStatus status = await permission.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      showToast('يجب السماح للوصول للصور من الإعدادات');
      // await openAppSettings();
      return false;
    }

    final PermissionStatus result = await permission.request();

    if (result.isPermanentlyDenied) {
      showToast('يجب السماح للوصول للصور من الإعدادات');
      // await openAppSettings();
      return false;
    }

    return result.isGranted;
  }

  static Future<bool> _requestPermissionWithFallback(List<Permission> permissions) async {
    final Map<Permission, PermissionStatus> statuses = await permissions.request();

    final bool hasAnyGranted = statuses.values.any((status) => status.isGranted);

    if (hasAnyGranted) {
      return true;
    }

    final bool hasPermanentlyDenied = statuses.values.any((status) => status.isPermanentlyDenied);

    if (hasPermanentlyDenied) {
      showToast('يجب السماح للوصول للصور من الإعدادات');
      // await openAppSettings();
      return false;
    }

    return false;
  }

  static Future<File?> pickImage(
    ImageSource source, {
    required BuildContext context,
    int imageQuality = 85,
  }) async {
    if (await checkAndRequestCameraPermissions(source, context: context)) {
      try {
        final XFile? image = await ImagePicker().pickImage(
          source: source,
          imageQuality: imageQuality,
        );
        if (image == null) return null;
        return File(image.path);
      } on PlatformException catch (e) {
        debugPrint('خطأ في اختيار الصورة: $e');
        showToast('حدث خطأ أثناء اختيار الصورة');
        return null;
      }
    } else {
      // showToast('يجب تحديد الصلاحيات');

      return null;
    }
  }

  static Future<XFile?> pickImageXFile(
    ImageSource source, {
    bool useCrop = false,
    int imageQuality = 85,
    required BuildContext context,
  }) async {
    if (await checkAndRequestCameraPermissions(source, context: context)) {
      try {
        final XFile? image = await ImagePicker().pickImage(
          source: source,
          imageQuality: imageQuality,
        );

        if (image == null) return null;

        if (useCrop) {
          return await cropAndScale(image.path, imageQuality: imageQuality);
        }
        return image;
      } on PlatformException catch (e) {
        debugPrint('خطأ في اختيار الصورة: $e');
        showToast('حدث خطأ أثناء اختيار الصورة');
        return null;
      }
    } else {
      showToast('يجب تحديد الصلاحيات');
      return null;
    }
  }

  static Future<XFile?> cropAndScale(String path, {int imageQuality = 85}) async {
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
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'تحريك وتغيير الحجم',
            cropStyle: CropStyle.circle,
            rotateButtonsHidden: true,
            aspectRatioLockEnabled: true,
            resetButtonHidden: false,
            aspectRatioPickerButtonHidden: true,
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

  static Future<List<XFile>?> pickMultipleImages({required BuildContext context}) async {
    if (await checkAndRequestCameraPermissions(ImageSource.gallery, context: context)) {
      try {
        final List<XFile> images = await ImagePicker().pickMultiImage(imageQuality: 85);
        return images;
      } on PlatformException catch (e) {
        debugPrint('خطأ في اختيار الصور: $e');
        showToast('حدث خطأ أثناء اختيار الصور');
        return null;
      }
    } else {
      showToast('يجب تحديد الصلاحيات');
      return null;
    }
  }

  // static void showOpenAppSettingDialog(BuildContext context, IconData icon) {
  //   AppAlert.customDialog(
  //     context,
  //     dismissOldDialog: false,
  //     icon: icon,
  //     iconColor: AppColors.of(context).primary,
  //     title: ' يتطلب تصريح الصور',
  //     subTitle: 'يحتاج التطبيق إلى تصريح الوصول للصور',
  //     confirmText: 'التصريح',
  //     onConfirm: () async {
  //       // Check if we can request permission from within the app
  //       final PermissionStatus photosStatus = await Permission.photos.status;

  //       if (photosStatus.isDenied) {
  //         // If denied but can be requested within app
  //         final requestResult = await Permission.photos.request();

  //         // If still denied after request, user might need to go to settings
  //         if (requestResult.isDenied || requestResult.isPermanentlyDenied) {
  //           await openAppSettings();
  //         }
  //       } else if (photosStatus.isPermanentlyDenied) {
  //         // Permission is permanently denied, open app settings
  //         await openAppSettings();
  //       } else {
  //         // Permission is already granted or restricted
  //         showToast('تم التصريح بالوصول للصور');
  //       }
  //     },
  //   );
  // }
}
