import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    SentryBootstrap.debugResetAppHangTracking();
  });

  test('عتبة التوقّف خمس ثوانٍ لا الافتراضيّ ثانيتان', () {
    expect(SentryBootstrap.appHangTimeout, const Duration(seconds: 5));
  });

  test('الإيقاف والاستئناف على iOS بلا تهيئة Sentry لا يرميان، ويتكرّران بأمان',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await SentryBootstrap.pauseAppHangTracking();
    await SentryBootstrap.pauseAppHangTracking();
    await SentryBootstrap.resumeAppHangTracking();
    await SentryBootstrap.resumeAppHangTracking();
  });

  test('على أندرويد لا يُنادى SentryFlutter أصلاً — تأكيده يرمي في التطوير',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await expectLater(SentryBootstrap.pauseAppHangTracking(), completes);
    await expectLater(SentryBootstrap.resumeAppHangTracking(), completes);
  });
}
