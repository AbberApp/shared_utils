// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:io';

// import 'functions.dart';

// class PermissionHandler {
//   static Future<bool> checkPermission(
//     BuildContext context,
//     Permission permission, {
//     String? customTitle,
//     String? customMessage,
//   }) async {
//     try {
//       final status = await permission.request();

//       if (status.isGranted) {
//         printLog('${_getPermissionName(permission)} permission granted');
//         return true;
//       } else {
//         if (context.mounted) {
//           await _handlePermissionDenied(
//             context,
//             permission,
//             status,
//             customTitle: customTitle,
//             customMessage: customMessage,
//           );
//         }
//         return false;
//       }
//     } catch (e) {
//       printLog(e.toString());
//       return false;
//     }
//   }

//   static Future<Map<Permission, bool>> checkMultiplePermissions(
//     BuildContext context,
//     List<Permission> permissions,
//   ) async {
//     final Map<Permission, PermissionStatus> statuses = await permissions.request();
//     final Map<Permission, bool> results = {};

//     for (var permission in permissions) {
//       final status = statuses[permission]!;
//       if (status.isGranted) {
//         printLog('${_getPermissionName(permission)} permission granted');
//         results[permission] = true;
//       } else {
//         results[permission] = false;
//         if (context.mounted) {
//           await _handlePermissionDenied(context, permission, status);
//         }
//       }
//     }

//     return results;
//   }

//   static Future<void> _handlePermissionDenied(
//     BuildContext context,
//     Permission permission,
//     PermissionStatus status, {
//     String? customTitle,
//     String? customMessage,
//   }) async {
//     // Use your custom dialog for handling permission denied
//     showOpenAppSettingDialog(context, permission, status);
//   }

//   static void showOpenAppSettingDialog(
//     BuildContext context,
//     Permission permission,
//     PermissionStatus status,
//   ) {
//     // final permissionName = _getPermissionName(permission);
//     final permissionIcon = _getPermissionIcon(permission, denied: true);

//     AppAlert.customDialog(
//       context,
//       icon: permissionIcon,
//       iconColor: AppColors.of(context).primary,
//       title: _getPermissionTitle(permission),
//       subTitle: _getPermissionMessage(permission, status),
//       confirmText: _getConfirmText(status),
//       onConfirm: () async {

//         // Check current permission status
//         final currentStatus = await permission.status;

//         if (currentStatus.isDenied) {
//           // If denied but can be requested within app
//           final requestResult = await permission.request();

//           // If still denied after request, user might need to go to settings
//           if (requestResult.isDenied || requestResult.isPermanentlyDenied) {
//             await openAppSettings();
//           } else if (requestResult.isGranted) {
//             showToast(_getSuccessMessage(permission));
//           }
//         } else if (currentStatus.isPermanentlyDenied) {
//           // Permission is permanently denied, open app settings
//           await openAppSettings();
//         } else if (currentStatus.isGranted) {
//           // Permission is already granted
//           showToast(_getSuccessMessage(permission));
//         } else {
//           // Permission is restricted or other status
//           showToast(_getRestrictedMessage(permission));
//         }
//       },
//     );
//   }

//   static String _getPermissionTitle(Permission permission) {
//     switch (permission) {
//       case Permission.microphone:
//         return 'تصريح الميكروفون';
//       case Permission.camera:
//         return 'تصريح الكاميرا';
//       case Permission.location:
//       case Permission.locationWhenInUse:
//       case Permission.locationAlways:
//         return 'تصريح الموقع';
//       case Permission.storage:
//         return 'تصريح التخزين';
//       case Permission.contacts:
//         return 'تصريح جهات الاتصال';
//       case Permission.photos:
//         return 'تصريح الصور';
//       case Permission.phone:
//         return 'تصريح الهاتف';
//       case Permission.notification:
//         return 'تصريح الإشعارات';
//       case Permission.bluetooth:
//       case Permission.bluetoothScan:
//       case Permission.bluetoothAdvertise:
//       case Permission.bluetoothConnect:
//         return 'تصريح البلوتوث';
//       default:
//         return 'تصريح ${_getPermissionName(permission)}';
//     }
//   }

//   static String _getPermissionMessage(
//     Permission permission,
//     PermissionStatus status,
//   ) {
//     final permissionName = _getPermissionName(permission);

//     switch (permission) {
//       case Permission.microphone:
//         if (status == PermissionStatus.permanentlyDenied) {
//           return 'تم رفض تصريح الميكروفون نهائياً. يرجى تفعيله من إعدادات التطبيق لتمكين تسجيل الرسائل الصوتية';
//         }
//         return 'يحتاج التطبيق إلى تصريح الوصول للميكروفون للسماح بتسجيل الرسائل الصوتية';

//       case Permission.camera:
//         if (status == PermissionStatus.permanentlyDenied) {
//           return 'تم رفض تصريح الكاميرا نهائياً. يرجى تفعيله من إعدادات التطبيق لتمكين التصوير';
//         }
//         return 'يحتاج التطبيق إلى تصريح الوصول للكاميرا للسماح بالتصوير ومشاركة الصور';

//       case Permission.location:
//       case Permission.locationWhenInUse:
//       case Permission.locationAlways:
//         if (status == PermissionStatus.permanentlyDenied) {
//           return 'تم رفض تصريح الموقع نهائياً. يرجى تفعيله من إعدادات التطبيق لتمكين خدمات الموقع';
//         }
//         return 'يحتاج التطبيق إلى تصريح الوصول للموقع لتوفير خدمات محددة حسب موقعك';

//       case Permission.storage:
//         if (status == PermissionStatus.permanentlyDenied) {
//           return 'تم رفض تصريح التخزين نهائياً. يرجى تفعيله من إعدادات التطبيق لحفظ الملفات';
//         }
//         return 'يحتاج التطبيق إلى تصريح الوصول للتخزين لحفظ وقراءة الملفات';

//       case Permission.photos:
//         if (status == PermissionStatus.permanentlyDenied) {
//           return 'تم رفض تصريح الصور نهائياً. يرجى تفعيله من إعدادات التطبيق للوصول إلى معرض الصور';
//         }
//         return 'يحتاج التطبيق إلى تصريح الوصول للصور لمشاركة الصور من معرض الهاتف';

//       default:
//         if (status == PermissionStatus.permanentlyDenied) {
//           return 'تم رفض تصريح $permissionName نهائياً. يرجى تفعيله من إعدادات التطبيق';
//         }
//         return 'يحتاج التطبيق إلى تصريح الوصول لـ$permissionName لاستخدام هذه الميزة';
//     }
//   }

//   static String _getConfirmText(PermissionStatus status) {
//     switch (status) {
//       case PermissionStatus.permanentlyDenied:
//         return 'فتح الإعدادات';
//       case PermissionStatus.restricted:
//         return 'حسناً';
//       default:
//         return 'التصريح';
//     }
//   }

//   static String _getSuccessMessage(Permission permission) {
//     switch (permission) {
//       case Permission.microphone:
//         return 'تم التصريح بالوصول للميكروفون';
//       case Permission.camera:
//         return 'تم التصريح بالوصول للكاميرا';
//       case Permission.location:
//       case Permission.locationWhenInUse:
//       case Permission.locationAlways:
//         return 'تم التصريح بالوصول للموقع';
//       case Permission.storage:
//         return 'تم التصريح بالوصول للتخزين';
//       case Permission.photos:
//         return 'تم التصريح بالوصول للصور';
//       default:
//         final permissionName = _getPermissionName(permission);
//         return 'تم التصريح بالوصول لـ$permissionName';
//     }
//   }

//   static String _getRestrictedMessage(Permission permission) {
//     final permissionName = _getPermissionName(permission);
//     return 'تصريح $permissionName مقيد على هذا الجهاز';
//   }

//   static Future<void> showPermissionBottomSheet(
//     BuildContext context,
//     Permission permission,
//     PermissionStatus status,
//   ) async {
//     final permissionName = _getPermissionName(permission);
//     String message = '';
//     IconData icon = _getPermissionIcon(permission, denied: true);

//     switch (status) {
//       case PermissionStatus.denied:
//         message =
//             'We need ${permissionName.toLowerCase()} access to use this feature. Tap "Grant Permission" to continue.';
//         break;
//       case PermissionStatus.permanentlyDenied:
//         message =
//             '$permissionName permission has been permanently denied. Please enable it in your device settings.';
//         icon = HugeIcons.strokeRoundedSettings01;
//         break;
//       case PermissionStatus.restricted:
//         message = '$permissionName access is restricted on this device.';
//         icon = HugeIcons.strokeRoundedBlocked;
//         break;
//       default:
//         message = 'Unable to access ${permissionName.toLowerCase()}.';
//     }

//     showModalBottomSheet(
//       context: context,
//       isDismissible: status != PermissionStatus.permanentlyDenied,
//       builder: (BuildContext context) {
//         return Container(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               HugeIcon(icon: icon, size: 48, color: Colors.orange),
//               const SizedBox(height: 16),
//               Text(
//                 '$permissionName Permission',
//                 style: Theme.of(context).textTheme.headlineSmall,
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 message,
//                 textAlign: TextAlign.center,
//                 style: Theme.of(context).textTheme.bodyMedium,
//               ),
//               const SizedBox(height: 20),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   if (status != PermissionStatus.restricted) ...[
//                     TextButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       child: const Text('Cancel'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () async {
//                         Navigator.of(context).pop();
//                         if (status == PermissionStatus.permanentlyDenied) {
//                           await openAppSettings();
//                         } else {
//                           await checkPermission(context, permission);
//                         }
//                       },
//                       child: Text(
//                         status == PermissionStatus.permanentlyDenied
//                             ? 'Open Settings'
//                             : 'Grant Permission',
//                       ),
//                     ),
//                   ] else ...[
//                     ElevatedButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       child: const Text('OK'),
//                     ),
//                   ],
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   static Future<PermissionStatus> getPermissionStatus(
//     Permission permission,
//   ) async {
//     return await permission.status;
//   }

//   static Future<bool> shouldShowRequestPermissionRationale(
//     Permission permission,
//   ) async {
//     if (Platform.isAndroid) {
//       return await permission.shouldShowRequestRationale;
//     }
//     return false;
//   }

//   static String _getPermissionName(Permission permission) {
//     switch (permission) {
//       case Permission.microphone:
//         return 'Microphone';
//       case Permission.camera:
//         return 'Camera';
//       case Permission.location:
//         return 'Location';
//       case Permission.storage:
//         return 'Storage';
//       case Permission.contacts:
//         return 'Contacts';
//       case Permission.phone:
//         return 'Phone';
//       case Permission.photos:
//         return 'Photos';
//       case Permission.notification:
//         return 'Notification';
//       case Permission.bluetooth:
//         return 'Bluetooth';
//       case Permission.bluetoothScan:
//         return 'Bluetooth Scan';
//       case Permission.bluetoothAdvertise:
//         return 'Bluetooth Advertise';
//       case Permission.bluetoothConnect:
//         return 'Bluetooth Connect';
//       case Permission.locationWhenInUse:
//         return 'Location';
//       case Permission.locationAlways:
//         return 'Location';
//       default:
//         return permission.toString().split('.').last.capitalize();
//     }
//   }

//   static IconData _getPermissionIcon(
//     Permission permission, {
//     bool denied = false,
//   }) {
//     // Replace with your HugeIcons equivalents
//     switch (permission) {
//       case Permission.microphone:
//         return HugeIcons.strokeRoundedMic01; // or HugeIcons.strokeRoundedMicOff01 for denied
//       case Permission.camera:
//         return HugeIcons.strokeRoundedCamera01; // or similar
//       case Permission.location:
//         return HugeIcons.strokeRoundedLocation01; // or similar
//       case Permission.storage:
//         return HugeIcons.strokeRoundedFolder01; // or similar
//       case Permission.contacts:
//         return HugeIcons.strokeRoundedContact01; // or similar
//       case Permission.phone:
//         return HugeIcons.strokeRoundedCall; // or similar
//       case Permission.photos:
//         return HugeIcons.strokeRoundedImage01; // or similar
//       case Permission.notification:
//         return HugeIcons.strokeRoundedNotification01; // or similar
//       case Permission.bluetooth:
//       case Permission.bluetoothScan:
//       case Permission.bluetoothAdvertise:
//       case Permission.bluetoothConnect:
//         return HugeIcons.strokeRoundedBluetooth; // or similar
//       default:
//         return HugeIcons.strokeRoundedSecurity; // or similar fallback icon
//     }
//   }
// }

// extension StringExtension on String {
//   String capitalize() {
//     return '${this[0].toUpperCase()}${substring(1)}';
//   }
// }
