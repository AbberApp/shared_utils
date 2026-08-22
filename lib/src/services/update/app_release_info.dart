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

  /// أقصى عدد نقاط تُعرض — البطاقة في التصميم موجزة، وقائمةٌ طويلة تكسر
  /// تناسبها وتدفع زرّ التحديث خارج الشاشة.
  static const int maxNotes = 6;

  static final RegExp _bulletGlyph = RegExp(r'^\s*[•\-\*·▪]\s*');

  /// الملاحظات كنقاط جاهزة للعرض.
  ///
  /// نصّ «ما الجديد» في المتاجر ليس نقاطاً خالصة: يبدأ عادةً بعنوانٍ ترويجي
  /// («عبر بحُلّة جديدة») وينتهي بدعوةٍ للتحديث — وكلاهما ليس ميزة. فنأخذ
  /// **الأسطر المعلَّمة برمز نقطة فقط** حين توجد، وهي ما قصده الناشر نقاطاً.
  /// وإن خلا النصّ من الرموز رجعنا لكل الأسطر غير الفارغة.
  List<String> get noteLines {
    if (!hasNotes) return const <String>[];
    final List<String> raw = releaseNotes
        .split(RegExp(r'[\r\n]+'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    final List<String> marked = raw
        .where((String line) => _bulletGlyph.hasMatch(line))
        .map((String line) => line.replaceFirst(_bulletGlyph, '').trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    final List<String> chosen = marked.isNotEmpty ? marked : raw;
    return chosen.take(maxNotes).toList();
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
