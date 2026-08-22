/// تفاصيل الإصدار المتاح في المتجر.
///
/// تُبنى من استجابة iTunes Lookup — وهي المصدر **الوحيد المجاني وبلا مصادقة**
/// لملاحظات الإصدار: تكفيه طلبة `GET` واحدة بلا مفتاح ولا توقيع. أمّا Google
/// Play فلا يوفّر واجهة عامّة لملاحظات الإصدار؛ الحصول عليها يتطلّب إمّا
/// Play Developer API بحساب خدمة موقَّع (وصلاحيات نشر)، أو كشط صفحة المتجر —
/// وكلاهما ثقيل وهشّ. فنقرأ الملاحظات من آبل ونعرضها على المنصّتين، إذ نصّ
/// «ما الجديد» واحد في المتجرين عملياً.
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.releaseNotes,
    required this.releaseDate,
    required this.storeUrl,
    required this.isMandatory,
  });

  /// رقم الإصدار في المتجر (مثل `10.8.6`).
  final String version;

  /// نصّ «ما الجديد» كما كتبه الناشر. قد يكون فارغاً إن لم يُدخله.
  final String releaseNotes;

  /// تاريخ نشر هذا الإصدار في المتجر.
  final DateTime? releaseDate;

  /// رابط صفحة التطبيق في المتجر.
  final String storeUrl;

  /// هل التحديث إجباريّ (تغيّرت الخانة الكبرى أو الوسطى)؟
  final bool isMandatory;

  /// هل توجد ملاحظات صالحة للعرض؟ الحاوية تُخفى إن لم توجد بدل أن تظهر فارغة.
  bool get hasNotes => releaseNotes.trim().isNotEmpty;

  /// الملاحظات مقسّمة أسطراً، بعد إزالة الفراغات والرموز البادئة (`•`, `-`, `*`)
  /// كي يعرضها التطبيق بنقاطه الخاصّة بدل رموز الناشر المختلطة.
  List<String> get noteLines {
    if (!hasNotes) return const <String>[];
    return releaseNotes
        .split(RegExp(r'[\r\n]+'))
        .map((String line) => line.replaceFirst(RegExp(r'^\s*[•\-\*•]\s*'), '').trim())
        .where((String line) => line.isNotEmpty)
        .toList();
  }

  factory AppReleaseInfo.fromItunes(
    Map<String, dynamic> result, {
    required bool isMandatory,
  }) {
    return AppReleaseInfo(
      version: (result['version'] as String?)?.trim() ?? '',
      releaseNotes: (result['releaseNotes'] as String?)?.trim() ?? '',
      releaseDate: DateTime.tryParse(
        (result['currentVersionReleaseDate'] as String?) ?? '',
      ),
      storeUrl: (result['trackViewUrl'] as String?) ?? '',
      isMandatory: isMandatory,
    );
  }

  @override
  String toString() =>
      'AppReleaseInfo(version: $version, mandatory: $isMandatory, notes: ${noteLines.length} lines)';
}
