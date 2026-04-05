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
  bool get canLoadMore => hasNext && count > 0;

  /// هل القائمة فارغة
  bool get isEmpty => results.isEmpty;

  /// هل القائمة تحتوي على بيانات
  bool get isNotEmpty => results.isNotEmpty;

  // عدد البيانات
  int get length => results.length;

  /// استخراج الـ offset من رابط الصفحة التالية
  /// مثال: "https://api.com/orders/?limit=20&offset=20" -> 20
  int? get nextOffset {
    if (isEmpty) return null;

    try {
      final uri = Uri.parse(next);
      final offsetStr = uri.queryParameters['offset'];
      return offsetStr != null ? int.tryParse(offsetStr) : null;
    } catch (_) {
      return null;
    }
  }

  /// إضافة البيانات الجديدة مع تحديث الـ pagination
  BaseEntity<ResultType> addAll(BaseEntity<ResultType> newData) {
    results.addAll(newData.results);
    count = newData.count;
    next = newData.next;
    return this;
  }

  /// دمج البيانات مع تجنب التكرار باستخدام key
  BaseEntity<ResultType> merge(
    BaseEntity<ResultType> newData,
    dynamic Function(ResultType item) getKey,
  ) {
    final existingMap = {for (final item in results) getKey(item): item};
    for (final item in newData.results) {
      existingMap[getKey(item)] = item;
    }
    results = existingMap.values.toList();
    count = newData.count;
    next = newData.next;
    return this;
  }
}
