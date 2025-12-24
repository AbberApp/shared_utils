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

  try {
    final userAgent = await userAgentClientHintsHeader();

    final data = '''
${message ?? ''}
مراسلة الدعم الفني
رقم المستخدم: ${userId ?? 'مستخدم غير مسجل'}
النظام: ${userAgent["Sec-CH-UA-Platform"]}, ${userAgent["Sec-CH-UA-Model"]}, ${userAgent["Sec-CH-UA-Arch"]}
نسخة التطبيق: ${userAgent["Sec-CH-UA-Full-Version"]}
''';

    // ترميز النص للرابط
    final encodedText = Uri.encodeComponent(data);
    final url = Uri.parse('https://wa.me/$cleanedNumber?text=$encodedText');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    final url = Uri.parse('https://wa.me/$cleanedNumber');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

/// تحويل الأرقام العربية إلى إنجليزية (إعادة تصدير للتوافقية)
String convertArabicNumbers(String text) => convertArabicToEnglishNumbers(text);
