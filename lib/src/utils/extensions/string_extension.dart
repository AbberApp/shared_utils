/// Extensions على String
extension StringExtension on String {
  /// التحقق من أن النص يحتوي على أرقام فقط
  bool get isAllDigits {
    if (isEmpty) return false;
    return RegExp(r'^[0-9]+$').hasMatch(this);
  }

  /// التحقق من أن النص يحتوي على أرقام ونقطة عشرية فقط
  bool get isValidDecimal {
    if (isEmpty) return false;
    // يشترط رقماً واحداً على الأقل مع نقطة عشرية واحدة كحد أقصى، لأن النمط
    // السابق كان يقبل النقطة المنفردة '.' فيسقط double.parse عند المستدعي.
    return RegExp(r'^(?:[0-9]+\.?[0-9]*|\.[0-9]+)$').hasMatch(this);
  }

  /// إزالة الأقواس من النص (مفيد للقوائم)
  String get withoutBrackets {
    if (length < 2) return this;
    // لا نقتطع الطرفين إلا إذا كانا قوسين متطابقين فعلاً، لأن الخادم قد يرجع
    // القيمة بلا أقواس فيؤدي الاقتطاع الأعمى إلى إتلاف صامت للبيانات.
    final int open = codeUnitAt(0);
    final int close = codeUnitAt(length - 1);
    const int openSquare = 0x5B; // [
    const int closeSquare = 0x5D; // ]
    const int openRound = 0x28; // (
    const int closeRound = 0x29; // )
    final bool bracketed =
        (open == openSquare && close == closeSquare) ||
        (open == openRound && close == closeRound);
    if (!bracketed) return this;
    // تطابقُ النوعين في الطرفين لا يعني أنّهما زوجٌ واحد: «[a],[b]» يبدأ بـ '['
    // وينتهي بـ ']' وليسا متقابلين، فالاقتطاع يُنتج «a],[b» — إتلافٌ صامت مثل
    // اقتطاع نصٍّ بلا أقواس. لذا نتتبّع العمق: إن بلغ صفراً قبل المحرف الأخير
    // فالقوس الأوّل أُغلق في الوسط، وإن لم يبلغ صفراً في نهايته فالنصّ مشوّه؛
    // وفي الحالتين نترك النصّ كما هو.
    int depth = 0;
    for (int i = 0; i < length; i++) {
      final int unit = codeUnitAt(i);
      if (unit == open) {
        depth++;
      } else if (unit == close) {
        depth--;
        if (depth == 0 && i != length - 1) return this;
      }
    }
    if (depth != 0) return this;
    return substring(1, length - 1);
  }

  /// التحقق من صحة البريد الإلكتروني
  bool get isValidEmail {
    // مقاطع المضيف تبدأ وتنتهي بحرفٍ أو رقم ولا تبدأ ولا تنتهي بشرطة
    // (RFC 1123)، فالنمط السابق `[a-zA-Z\-0-9]+` كان يقبل «-email.com»
    // و«email-.com» ويمرّر نطاقاً لا وجود له. الشرطة مسموحة في الوسط فقط.
    return RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|((?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}))$',
    ).hasMatch(this);
  }

  /// تحويل الحرف الأول إلى حرف كبير
  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
