import 'package:flutter/material.dart';
import 'package:ua_client_hints/ua_client_hints.dart';
import 'package:url_launcher/url_launcher.dart';

String convertArabicNumbers(String text) {
  return text
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll('٣', '3')
      .replaceAll('٤', '4')
      .replaceAll('٥', '5')
      .replaceAll('٦', '6')
      .replaceAll('٧', '7')
      .replaceAll('٨', '8')
      .replaceAll('٩', '9')
      .replaceAll('٠', '0')
      .replaceAll('٫', '.')
      .replaceAll(',', '.');
}

void printLog(dynamic msg) {
  debugPrint('$msg');
}

void extractText(
  Map<String, dynamic> element,
  String key,
  Function(String) updateMessage,
) {
  if (element.containsKey(key)) {
    final List<String> extractedText = [];

    void extractData(dynamic value) {
      if (value is Map<String, dynamic>) {
        value.forEach((key, value) {
          extractData(value);
        });
      } else if (value is List<dynamic>) {
        for (var item in value) {
          extractData(item);
        }
      } else if (value is String) {
        extractedText.add(value.toString());
      }
    }

    extractData(element[key]);

    updateMessage(extractedText.join('\n'));
  }
}

void dismissKeyboard(BuildContext context) {
  final FocusScopeNode currentFocus = FocusScope.of(context);
  if (!currentFocus.hasPrimaryFocus) {
    currentFocus.unfocus();
  }
}

String getFirstName(String fullName) {
  // Split the string by space characters
  final List<String> nameParts = fullName.split(' ');

  // Return the first part (the first name)
  if (nameParts.isNotEmpty) {
    return nameParts[0];
  }

  // Return the original string if there are no spaces
  return fullName;
}

void launchWhatsApp({required String phoneNumber, String? id}) async {
  try {
    final userAgent = await userAgentClientHintsHeader();

    final String data =
        '''
مراسلة الدعم الفني
رقم المستخدم: ${id ?? 'مستخدم غير مسجل'}
النظام: ${userAgent["Sec-CH-UA-Platform"].toString()}, ${userAgent["Sec-CH-UA-Model"].toString()}, ${userAgent["Sec-CH-UA-Arch"].toString()}
نسخة التطبيق: ${userAgent["Sec-CH-UA-Full-Version"].toString()}
''';

    final url = Uri.parse('https://wa.me/$phoneNumber?text=$data');

    await launchUrl(url);
  } catch (e) {
    final url = Uri.parse('https://wa.me/$phoneNumber');

    await launchUrl(url);
  }
}
