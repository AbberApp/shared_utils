import 'package:json_annotation/json_annotation.dart';

abstract class BaseEntity<ResultType> {
  @JsonKey(defaultValue: 0)
  int count;
  @JsonKey(defaultValue: '')
  String next;
  @JsonKey(defaultValue: [])
  List<ResultType> results;

  BaseEntity({required this.count, required this.next, required this.results});

  /// هل يوجد رابط للصفحة التالية
  bool get hasNext => next.isNotEmpty;

  /// هل يمكن تحميل المزيد من البيانات
  // شرط `count > length` هو نفسه حارس `LoadMoreWidget.onScroll`؛ بدونه يبقى هذا
  // الـ getter صادقاً بعد اكتمال آخر صفحة إن ظلّ `next` قائماً، فتتوالى الطلبات بلا نهاية
  bool get canLoadMore => hasNext && count > length;

  /// هل القائمة فارغة
  bool get isEmpty => results.isEmpty;

  /// هل القائمة تحتوي على بيانات
  bool get isNotEmpty => results.isNotEmpty;

  // عدد البيانات
  int get length => results.length;

  /// استخراج الـ offset من رابط الصفحة التالية
  /// مثال: "https://api.com/orders/?limit=20&offset=20" -> 20
  int? get nextOffset {
    // الحارس يخصّ `next` لا القائمة: صفحة فارغة مع رابط تالٍ ما زالت قابلة للترقيم
    if (!hasNext) return null;

    try {
      final uri = Uri.parse(next);
      final offsetStr = uri.queryParameters['offset'];
      return offsetStr != null ? int.tryParse(offsetStr) : null;
    } on Object catch (_) {
      return null;
    }
  }

  /// إضافة البيانات الجديدة مع تحديث الـ pagination
  BaseEntity<ResultType> addAll(BaseEntity<ResultType> newData) {
    // قائمة جديدة بدل التعديل في المكان: القائمة الأولى غالباً `const []` فيرمي
    // `addAll` عليها UnsupportedError، كما أن التعديل في المكان يطال نسخة المستدعي نفسها
    results = [...results, ...newData.results];
    count = newData.count;
    next = newData.next;
    return this;
  }

  /// دمج البيانات مع تجنب التكرار باستخدام key
  BaseEntity<ResultType> merge(
    BaseEntity<ResultType> newData,
    dynamic Function(ResultType item) getKey,
  ) {
    // مرورٌ واحد يحفظ ترتيب اللقاء: القائمة تُبنى بالتتابع وتُحفظ مواضع المفاتيح في
    // فهرس، فالعنصر المكرّر يُستبدل في موضعه الأصلي بدل أن يُنقل إلى الذيل. جمع
    // العناصر بلا مفتاح في قائمةٍ منفصلة كان يقذفها كلّها إلى آخر القائمة، فتقفز
    // الرسالة المتفائلة (id لم يُثبَّت بعد) أسفلَ الصفحة التالية ثمّ تعود فجأةً
    final merged = <ResultType>[];
    final keyIndexes = <Object, int>{};

    void put(ResultType item) {
      final key = getKey(item);
      // بلا مفتاح لا سبيل إلى المطابقة: يُضاف في موضعه كما هو، ولو دخل الفهرس
      // لتشارك العناصر كلّها المفتاح null ودهس بعضها بعضاً بلا أثر
      if (key == null) {
        merged.add(item);
        return;
      }
      final existingIndex = keyIndexes[key as Object];
      if (existingIndex != null) {
        merged[existingIndex] = item;
        return;
      }
      keyIndexes[key] = merged.length;
      merged.add(item);
    }

    results.forEach(put);
    newData.results.forEach(put);

    results = merged;
    count = newData.count;
    next = newData.next;
    return this;
  }
}
