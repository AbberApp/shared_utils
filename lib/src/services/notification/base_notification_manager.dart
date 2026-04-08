import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'notification_delegate.dart';

/// مدير الإشعارات الأساسي في shared_utils
/// يحتوي على المنطق العام المشترك بين جميع المشاريع
/// المنطق الخاص بكل مشروع يُفوَّض إلى [NotificationDelegate]
class BaseNotificationManager {
  BaseNotificationManager(this._delegate);

  final NotificationDelegate _delegate;

  bool _isRequestingPermission = false;

  VoidCallback? _onNewNotification;

  NotificationDelegate get delegate => _delegate;

  void setOnNewNotification(VoidCallback callback) {
    _onNewNotification = callback;
  }

  void notifyNewNotification() {
    _onNewNotification?.call();
  }

  Future<String> getNotificationToken() async {
    try {
      final String token = await FirebaseMessaging.instance.getToken() ?? '';
      log('Notification token: $token', name: 'BaseNotificationManager');
      return token;
    } catch (e) {
      log('$e', name: 'BaseNotificationManager');
      return '';
    }
  }

  void subscribeToTopic(String topic) {
    try {
      FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (e) {
      log('$e', name: 'BaseNotificationManager');
    }
  }

  void unsubscribeFromTopic(String topic) {
    try {
      FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (e) {
      log('$e', name: 'BaseNotificationManager');
    }
  }

  Future<void> checkNotificationPermission({
    VoidCallback? notOnGranted,
    Future<void> Function()? onAfterPermissionCheck,
  }) async {
    if (_isRequestingPermission) {
      log('Permission request already in progress, skipping', name: 'BaseNotificationManager');
      return;
    }

    log('checkNotificationPermission', name: 'BaseNotificationManager');
    try {
      final bool isIOSPlatform = Platform.isIOS;

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: isIOSPlatform,
        badge: true,
        sound: true,
      );

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: true,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      log(
        'Notification permission status: ${settings.authorizationStatus}',
        name: 'BaseNotificationManager',
      );

      final bool isGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      _isRequestingPermission = isGranted;

      if (!isGranted) {
        notOnGranted?.call();
      }

      await onAfterPermissionCheck?.call();
    } catch (e) {
      log('Error checking notification permission: $e', name: 'BaseNotificationManager');
    } finally {
      _isRequestingPermission = false;
    }
  }

  Future<void> navigatorRoutes(String? payload) async {
    // يُفوَّض للـ delegate
  }

  Future<void> checkAndNavigationInitialNotification() async {
    log('Handle initial notification', name: 'BaseNotificationManager');
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _delegate.handleInitialMessage(initialMessage);
    }
  }
}
