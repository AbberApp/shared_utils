import 'package:flutter/material.dart';
import 'package:ua_client_hints/ua_client_hints.dart';
import 'package:url_launcher/url_launcher.dart';

import '../formatters/number_formatter.dart';

/// إخفاء لوحة المفاتيح
void dismissKeyboard(BuildContext context) {
  final currentFocus = FocusScope.of(context);
  if (!currentFocus.hasPrimaryFocus) {
    currentFocus.unfocus();
  }
}

/// الحصول على الاسم الأول من الاسم الكامل
String getFirstName(String fullName) {
  final parts = fullName.split(' ');
  return parts.isNotEmpty ? parts[0] : fullName;
}

/// فتح واتساب مع رسالة دعم فني
Future<void> launchWhatsApp({
  required String phoneNumber,
  String? userId,
  String? message,
}) async {
  // إزالة علامة + وأي رموز أخرى من رقم الهاتف (wa.me يتطلب أرقام فقط)
  final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

  String? encodedText;
  try {
    final userAgent = await userAgentClientHintsHeader();

    final data = '''
${message ?? ''}
مراسلة الدعم الفني
رقم المستخدم: ${userId ?? 'مستخدم غير مسجل'}
النظام: ${userAgent["Sec-CH-UA-Platform"]}, ${userAgent["Sec-CH-UA-Model"]}, ${userAgent["Sec-CH-UA-Arch"]}
نسخة التطبيق: ${userAgent["Sec-CH-UA-Full-Version"]}
''';
    encodedText = Uri.encodeComponent(data);
  } catch (_) {}

  // محاولة فتح تطبيق واتساب مباشرة (أفضل لـ iOS)
  final whatsappUri = Uri.parse(
    'whatsapp://send?phone=$cleanedNumber${encodedText != null ? '&text=$encodedText' : ''}',
  );

  if (await canLaunchUrl(whatsappUri)) {
    await launchUrl(whatsappUri);
    return;
  }

  // fallback إلى wa.me
  final webUri = Uri.parse(
    'https://wa.me/$cleanedNumber${encodedText != null ? '?text=$encodedText' : ''}',
  );
  await launchUrl(webUri, mode: LaunchMode.externalApplication);
}

/// تحويل الأرقام العربية إلى إنجليزية (إعادة تصدير للتوافقية)
String convertArabicNumbers(String text) => convertArabicToEnglishNumbers(text);
