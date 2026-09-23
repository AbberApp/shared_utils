/// Extensions لتحويل الأرقام اللاتينية (0-9) إلى الأرقام العربية-الهندية (٠-٩).
///
/// تُستخدم للعدّات النصّية في الواجهات العربية (مؤشّرات الخطوات، «٣ عناصر»،
/// «متبقي ٦»). **لا تُطبَّق على الأسعار/العملة** — إذ يُبقيها التصميم عادةً
/// بالأرقام اللاتينية (استخدم `toCurrency` للعملة).
extension ArabicDigitsString on String {
  static const List<String> _eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// يستبدل كل رقم لاتيني (U+0030..U+0039) بنظيره العربي-الهندي، ويترك سواه كما هو.
  String get toArabicDigits {
    final StringBuffer buffer = StringBuffer();
    for (final int unit in runes) {
      if (unit >= 0x30 && unit <= 0x39) {
        buffer.write(_eastern[unit - 0x30]);
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  /// الاتجاه العكسي: يُعيد كلّ رقمٍ عربي-هنديّ (٠-٩) أو فارسيّ ممتدّ (۰-۹) إلى
  /// نظيره اللاتيني، ويترك سواه كما هو.
  ///
  /// لازمٌ لما يكتبه المستخدم بلوحةٍ عربية: «٥٠٠» لا يمرّ على `int.parse` ولا
  /// على تحقّق الهاتف ولا على تنسيق المبلغ ما لم يُعَد لاتينياً أولاً. والنطاق
  /// الفارسيّ مشمولٌ هنا وحده — لا في الاتجاه الطالع — لأنّ المُدخَل قد يأتي
  /// بأيّ اللوحتين، بينما الإخراج يلزمه شكلٌ واحدٌ مُحدَّد.
  String get toLatinDigits {
    final StringBuffer buffer = StringBuffer();
    for (final int unit in runes) {
      if (unit >= 0x0660 && unit <= 0x0669) {
        buffer.writeCharCode(0x30 + (unit - 0x0660));
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        buffer.writeCharCode(0x30 + (unit - 0x06F0));
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }
}

extension ArabicDigitsInt on int {
  /// تمثيل العدد بالأرقام العربية-الهندية (٥ · ١٢).
  String get toArabicDigits => toString().toArabicDigits;
}
