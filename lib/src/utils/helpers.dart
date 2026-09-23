import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../device/device_info_manager.dart';
import '../ui/formatters/number_formatter.dart';
import '../ui/widgets/toast.dart';

/// إخفاء لوحة المفاتيح
void dismissKeyboard(BuildContext context) {
  final currentFocus = FocusScope.of(context);
  if (!currentFocus.hasPrimaryFocus) {
    currentFocus.unfocus();
  }
}

/// الحصول على الاسم الأول من الاسم الكامل
String getFirstName(String fullName) {
  // `''.split(' ')` يعيد `['']` لا قائمة فارغة، فحارس isNotEmpty لا يقي من شيء:
  // القصّ والشطر على أيّ فراغ يمنعان «  محمد» و«» من العودة نصّاً فارغاً.
  final parts = fullName.trim().split(RegExp(r'\s+'));
  // لا حارس `first.isEmpty ? fullName : first` هنا: بعد القصّ لا يعود الشطر
  // عنصراً أوّلَ فارغاً إلّا حين يخلو المُدخل من اسمٍ أصلاً («   » أو «»)،
  // وإعادة المُدخل عندئذٍ كانت تُسرّب مسافاته غير مقصوصة إلى الواجهة.
  return parts.isEmpty ? '' : parts.first;
}

/// فتح واتساب مع رسالة دعم فني
Future<void> launchWhatsApp({
  required String phoneNumber,
  required DeviceInfoManager deviceInfo,
  String? userId,
  String? message,
}) async {
  // إزالة علامة + وأي رموز أخرى من رقم الهاتف (wa.me يتطلب أرقام فقط).
  // `\d` في Dart لاتينيّ فقط، فرقمٌ بالأرقام العربية-الهندية كان يُمحى بتمامه
  // ويُفتح واتساب بلا جهة اتصال: نوحّد الأرقام أوّلاً ثمّ نُزيل ما عداها.
  final cleanedNumber = convertArabicToEnglishNumbers(
    phoneNumber,
  ).replaceAll(RegExp(r'[^0-9]'), '');

  if (cleanedNumber.isEmpty) {
    showToast('رقم الدعم الفني غير صالح');
    return;
  }

  // لا نكتفي بقراءة infoOrNull: التوثيق يوصي بنداء initialize() بلا await في
  // main، فمن يضغط «تواصل مع الدعم» في الثواني الأولى بعد الإقلاع — أو على
  // جهازٍ بطيء — كانت تصله رسالة نصّها حرفياً «النظام: null, null, null»،
  // فيفقد الدعم بالضبط ما وُضع الوسيط الإلزامي من أجله بلا أيّ خطأ ظاهر.
  // ننتظر التهيئة بمهلةٍ قصيرة كي لا يتجمّد الزرّ إن تعطّلت قناة المنصّة.
  try {
    await deviceInfo.ensureInitialized().timeout(const Duration(seconds: 3));
  } on Object catch (e) {
    // المدير يبتلع فشل القنوات ويُرجع نموذجاً ناقصاً، لكن المهلة ترمي — ولا
    // يجوز أن يمنع ذلك المستخدم من مراسلة الدعم أصلاً.
    debugPrint('تعذّر انتظار معلومات الجهاز لرسالة الدعم: $e');
  }

  // بديلٌ مقروء بدل تسريب «null» إلى نصٍّ يقرأه إنسان
  const unknown = 'غير معروف';
  final info = deviceInfo.infoOrNull;
  final system = info?.system;

  final data =
      '''
${message ?? ''}
مراسلة الدعم الفني
رقم المستخدم: ${userId ?? 'مستخدم غير مسجل'}
النظام: ${system?.osName ?? unknown}, ${system?.osVersion ?? unknown}, ${system?.platform ?? unknown}
نسخة التطبيق: ${info?.app.fullVersion ?? unknown}
''';
  final encodedText = Uri.encodeComponent(data);

  // canLaunchUrl/launchUrl قناتا منصّة ترميان PlatformException (مانيفست بلا
  // `<queries>`، أو رفض النظام الفتح) — والدالة `Future<void>` فيتسرّب الرفض
  // غير ملتقَط ويُسقط التطبيق. نلتقط Object لا Exception وحدها لأنّ ما يصعد
  // من القناة قد يكون Error، ونقرأ قيمة launchUrl المرجَعة بدل إهمالها.
  try {
    // محاولة فتح تطبيق واتساب مباشرة (أفضل لـ iOS)
    final whatsappUri = Uri.parse('whatsapp://send?phone=$cleanedNumber&text=$encodedText');
    if (await canLaunchUrl(whatsappUri) && await launchUrl(whatsappUri)) {
      return;
    }

    // fallback إلى wa.me
    final webUri = Uri.parse('https://wa.me/$cleanedNumber?text=$encodedText');
    if (await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
      return;
    }

    showToast('تعذّر فتح واتساب');
  } on Object catch (_) {
    showToast('تعذّر فتح واتساب');
  }
}

/// تحويل الأرقام العربية إلى إنجليزية (إعادة تصدير للتوافقية)
String convertArabicNumbers(String text) => convertArabicToEnglishNumbers(text);
