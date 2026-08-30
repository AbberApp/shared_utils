import 'package:bloc/bloc.dart';

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
  @override
  void emit(S state) {
    if (isClosed) return;
    // `Bloc.emit` موسومة @visibleForTesting (تفويضٌ محض إلى `BlocBase.emit`)،
    // فنداؤها من مزيجٍ على `Bloc` يُطلق التحذير. الاستدعاء هنا مقصود وهو جوهر
    // المزيج، ولا بديل عنه إلا حراسة كل نداء على حدة.
    // ignore: invalid_use_of_visible_for_testing_member
    super.emit(state);
  }

  @override
  void add(E event) {
    if (isClosed) return;
    super.add(event);
  }
}
