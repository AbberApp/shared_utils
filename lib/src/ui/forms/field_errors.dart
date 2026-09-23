import 'package:flutter/widgets.dart';

import '../../network/api/models/failure.dart';

/// يوجّه أخطاء الحقول القادمة من الخادم إلى حقولها في النموذج.
///
/// `Failure` يحمل `fields: [{field, message}]` منذ زمن، و[Failure.fieldError]
/// يقرأ واحدها — لكنّ الربط بين ذلك وبين `Form` كان متروكاً لكلّ تطبيق، فكُتب
/// في كلٍّ منها بيدٍ مختلفة أو لم يُكتب أصلاً: فيُعرض «الاسم مستعمل» حواراً
/// وسط الشاشة، والمستخدم لا يعرف **أيّ** حقلٍ يصلح فيخمّن.
///
/// الاستعمال في مستمع الحالة:
/// ```dart
/// if (state is XFailureState) {
///   if (FieldErrors.apply(
///     failure: state.failure,
///     formKey: _formKey,
///     sinks: {'name': (m) => setState(() => nameError = m)},
///   )) return;                       // عُرضت على الحقول
///   showError(state.failure);        // وإلّا فرسالةٌ عامّة
/// }
/// ```
///
/// والمُتحقِّق يعيد الرسالة المعلّقة:
/// ```dart
/// validator: (value) => value!.isEmpty ? 'مطلوب' : nameError,
/// ```
abstract final class FieldErrors {
  /// يوزّع أخطاء [failure] على الحقول المسجّلة في [sinks].
  ///
  /// يعيد `true` إن وُجّه **خطأ واحد على الأقلّ** إلى حقلٍ معروف — وعندها لا
  /// تُعرض الرسالة العامّة. ويعيد `false` إن لم يكن في الفشل أخطاء حقول، أو
  /// كانت لحقولٍ لا تخصّ هذا النموذج، أو كانت رسائلها فارغة — فالرسالة
  /// العامّة هي المخرج الوحيد حينئذٍ، وإلّا ضاع الخطأ صامتاً.
  ///
  /// وفي الحالات كلّها يُمسح ما لا خطأ له ويُعاد التحقّق، فلا يبقى نصٌّ قديم
  /// مرسوماً على حقلٍ لم يعد الخادم يشتكي منه.
  static bool apply({
    required Failure failure,
    required GlobalKey<FormState> formKey,
    required Map<String, ValueSetter<String?>> sinks,
  }) {
    bool matched = false;
    // لا خروج مبكّر عند فشلٍ بلا حقول: الأحواض تُمسح في هذا المسار كما تُمسح
    // في مسار «حقولٌ لا تطابق»، وإلّا بقي خطأٌ قديم معلّقاً على حقلٍ صحّحه
    // المستخدم لمجرّد أنّ الرد التالي جاء بلا أخطاء حقول.
    for (final MapEntry<String, ValueSetter<String?>> entry in sinks.entries) {
      final String? raw = failure.fieldError(entry.key);
      // رسالةٌ فارغة أو فراغاتٌ كلّها ليست خطأً معروضاً: تمريرها نصّاً يجعل
      // `Form` يعدّ الحقل غير صالحٍ بسطرٍ لا نصّ فيه، فلا المستخدم يقرأ شيئاً
      // ولا الرسالة العامّة تُعرض. تُعامَل معاملة «لا خطأ» كما تفعل
      // `Failure.fromJson` بالرسالة العامّة البيضاء.
      final String? message = (raw == null || raw.trim().isEmpty) ? null : raw;
      entry.value(message);
      if (message != null) matched = true;
    }

    // التحقّق يُعاد عند المطابقة ليظهر النصّ الجديد، وعند عدمها ليرتفع نصٌّ
    // قديم مرسوم — فالمسح في الحوض وحده لا يُعيد رسم الحقل.
    if (sinks.isNotEmpty) formKey.currentState?.validate();
    return matched;
  }

  /// يمسح ما عُلّق على الحقول قبل إرسالٍ جديد — وإلّا بقي خطأٌ قديم معروضاً
  /// على حقلٍ صحّحه المستخدم.
  static void clear(Map<String, ValueSetter<String?>> sinks) {
    for (final ValueSetter<String?> sink in sinks.values) {
      sink(null);
    }
  }
}
