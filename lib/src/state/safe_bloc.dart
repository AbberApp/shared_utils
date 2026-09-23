import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

/// يمنع `emit` بعد إغلاق الكيوبت بدل أن ينهار.
///
/// النمط الذي يُنتج الانهيار واحد ويتكرّر في كل تطبيقات المجموعة:
///
/// ```dart
/// final result = await useCase.execute();   // المستخدم يغادر الشاشة هنا
/// result.fold(
///   (failure) => emit(FailureState(failure)),   // الكيوبت أُغلق ← StateError
///   (data) => emit(SuccessState(data)),
/// );
/// ```
///
/// أي طلبٍ شبكيّ يبدأ ثمّ يغادر المستخدم قبل أن يعود. رصده Sentry في تطبيق
/// «عبر» بمئات الأحداث، ومسحُ التطبيقات الثمانية أظهر **١٤٤ صنفاً** معرَّضاً له.
///
/// حراسة كل كتلة على حدة تعالج الماضي وتترك المستقبل: أوّل كتلةٍ جديدة تُكتب
/// تعيد العيب. فالحارس هنا في الأساس، ويرثه الصنف بكلمة واحدة.
///
/// إسقاط الحالة بعد الإغلاق هو التصرّف الصحيح — لا مستمع لها أصلاً.
///
/// ⚠️ لكنّه يمنع **الانهيار** لا **ضياع النتيجة**. فمسارٌ يجب أن يكتمل حتى لو
/// غادر المستخدم يحتاج فوق ذلك أن يخرج من دورة حياة الكيوبت، لا أن يُسكِت خطأه.
///
/// ```dart
/// class MyCubit extends Cubit<MyState> with SafeCubit<MyState> { … }
/// ```
///
/// للبلوكات استعمل [SafeBloc] — فهو يغطّي `add` أيضاً.
mixin SafeCubit<S> on BlocBase<S> {
  // الوسمان ليسا نافلة: `BlocBase.emit` موسومة بهما، والوسوم لا تُورَّث إلى
  // التجاوز. فتجاوزٌ عارٍ يرفع `emit` إلى عضوٍ عامّ بلا أيّ تحذير، ويصير
  // `context.read<MyCubit>().emit(…)` من الواجهة يمرّ نظيفاً في `flutter
  // analyze` — تخطٍّ لطبقة الحالة كلّها. إعادتهما تُعيد تحذير المحلّل.
  @protected
  @visibleForTesting
  @override
  void emit(S state) {
    if (isClosed) return;
    super.emit(state);
  }
}

/// [SafeCubit] زائداً حراسة `add` — للبلوكات.
///
/// مزيجٌ واحد يغطّي المدخلين. ولم يصحّ جمعهما في اسمٍ واحد يخدم النوعين:
/// `emit` معرَّفة في `BlocBase` فتراها الكيوبتات والبلوكات، أمّا `add` فمعرَّفة
/// في `Bloc` وحده — فمزيجٌ يغطّيهما لا تستطيع الكيوبتات استعماله أصلاً.
///
/// وحراسة `add` ليست تزيّداً: انهيار الدفع الذي رصده Sentry مكدّسه `Bloc.add`
/// لا `emit` — بلوكٌ يضيف حدثاً لنفسه من داخل `fold` بعد الإغلاق.
///
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> with SafeBloc<MyEvent, MyState> { … }
/// ```
mixin SafeBloc<E, S> on Bloc<E, S> {
  /// هل بدأ الإغلاق؟ تُرفع في أوّل سطرٍ من [close].
  ///
  /// لا تصلح حارساً وحدها، لكنّها تميّز `StateError` الإغلاق — الذي نبتلعه —
  /// عن أيّ `StateError` آخر يخرج من `emit` (من تجاوزٍ لـ `onChange` مثلاً)
  /// فلا نبتلع خطأً ليس لنا.
  bool _closing = false;

  /// هل أُغلق متحكّم الحالة فعلاً؟
  ///
  /// `Bloc.isClosed` لا يصلح حارساً لـ `emit` هنا: تعريفه
  /// `_eventController.isClosed || super.isClosed`، ومتحكّم الأحداث يُغلق في
  /// **أوّل** سطرٍ من `close()` بينما متحكّم الحالة لا يُغلق إلا في آخرها.
  /// فالحراسة بـ `isClosed` تُسقط كلّ `emit` يقع في تلك النافذة، ومتحكّم
  /// الحالة ما يزال يقبله ويقرأه من بيده الكيوبت. و`super.isClosed` لا
  /// يُخرجنا من المأزق: من داخل المزيج يحلّ إلى تجاوز `Bloc` نفسه لا إلى
  /// `BlocBase`.
  ///
  /// فنرصد الإغلاق الحقيقيّ بأنفسنا: لا يكتمل إلا باكتمال `close()`.
  bool _stateClosed = false;

  @override
  Future<void> close() {
    _closing = true;
    return super.close().whenComplete(() {
      _stateClosed = true;
    });
  }

  /// للوسمين سببهما — انظر [SafeCubit.emit].
  @protected
  @visibleForTesting
  @override
  void emit(S state) {
    if (_stateClosed) return;
    try {
      // `Bloc.emit` موسومة @visibleForTesting (تفويضٌ محض إلى `BlocBase.emit`)،
      // فنداؤها من مزيجٍ على `Bloc` يُطلق التحذير. الاستدعاء هنا مقصود وهو
      // جوهر المزيج، ولا بديل عنه إلا حراسة كل نداء على حدة.
      // ignore: invalid_use_of_visible_for_testing_member
      super.emit(state);
    } on StateError {
      // بين إغلاق متحكّم الحالة (في آخر `close()`) ورفع `_stateClosed` (في
      // `whenComplete` بعده) نافذةٌ بطول دورتَي مهامٍ صغرى أو ثلاث. واستئنافُ
      // `await` معلّقٍ داخلها — وهو النمط الذي وُجد المزيج لأجله بالضبط —
      // يمرّ من الحارس ثمّ يرمي في `BlocBase.emit`. ولا سبيل إلى قراءة
      // `_stateController.isClosed` من هنا (`isClosed` يشمل متحكّم الأحداث،
      // و`super.isClosed` هو نفسه)، فنرصد الإغلاق بالخطأ نفسه ونغلق الباب
      // بعده. الكلفة الوحيدة نداءٌ واحد لـ `onError` على المراقب قبل أن
      // نبتلع الخطأ — لا انهيار.
      if (!_closing) rethrow;
      _stateClosed = true;
    }
  }

  @override
  void add(E event) {
    // هنا `isClosed` هو الحارس الصحيح: `add` تكتب في متحكّم الأحداث نفسه.
    if (isClosed) return;
    super.add(event);
  }
}
