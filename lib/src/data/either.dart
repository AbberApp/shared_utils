/// `Either` — قيمةٌ إمّا يسارٌ (خطأ) أو يمينٌ (نجاح).
///
/// بديلٌ محلّيّ لما كانت المكتبة تُصدّره من حزمة `dartz`، كُتب لا نُسخ:
/// `Either` هناك يُنفّذ `TraversableMonadOps` فيجرّ `Monad` و`Applicative`
/// و`Functor` و`Traversable` و`Foldable` وعملياتها، ومعها `map2`…`map20`
/// التي تجرّ `Tuple2`…`Tuple20` — سبعة آلاف سطرٍ لم تستعمل التطبيقات منها
/// إلّا `fold` و`getOrElse` و`isLeft` و`isRight`. والحزمة لم تُحدَّث منذ
/// 2021-12-03.
///
/// **التواقيع مطابقةٌ لـ`dartz` حرفياً** كي لا يُمسّ سطرٌ في التطبيقات
/// المستهلِكة: `isLeft()` و`isRight()` **دالّتان لا getters**، و`getOrElse`
/// تأخذ **دالّةً لا قيمة**، والمُنشئان `const` لأنّ `const Right(unit)` مكتوبةٌ
/// في عشرات المستودعات.
///
/// والمكسب على `dartz`: `sealed` يجعل المحلّل يتحقّق من شمول `switch`:
///
/// ```dart
/// final String message = switch (result) {
///   Left(value: final f) => f.displayMessage,
///   Right(value: final data) => 'نجح: $data',
/// };
/// ```
///
/// ```dart
/// Future<Either<Failure, UserModel>> login(...) async {
///   if (await _connectionStatus.isNotConnected) {
///     return Left(ErrorType.noInternetConnection.toFailure());
///   }
///   try {
///     return Right(UserModel.fromJson(handleJsonResponse(response)));
///   } on Exception catch (e) {
///     return Left(ErrorHandler.handle(e).failure);
///   }
/// }
///
/// result.fold(
///   (failure) => emit(FailureState(failure)),
///   (user) => emit(SuccessState(user)),
/// );
/// ```
sealed class Either<L, R> {
  const Either();

  /// يفكّ القيمة: [ifLeft] للخطأ و[ifRight] للنجاح. وهي العملية الوحيدة
  /// التي يلزم كلَّ فرعٍ تنفيذُها، وسائرُ الأعضاء مبنيّةٌ عليها.
  B fold<B>(B Function(L l) ifLeft, B Function(R r) ifRight);

  /// قيمة اليمين، أو ناتج [dflt] إن كانت يساراً.
  ///
  /// تأخذ دالّةً لا قيمةً — كما في `dartz` — فلا يُحسب البديل إلّا عند الحاجة.
  R getOrElse(R Function() dflt) => fold((_) => dflt(), (R r) => r);

  /// مرادفُ [getOrElse] بقيمةٍ جاهزة: `result | fallback`.
  R operator |(R dflt) => getOrElse(() => dflt);

  /// دالّةٌ لا getter — مطابقةً لـ`dartz`.
  bool isLeft() => fold((_) => true, (_) => false);

  /// دالّةٌ لا getter — مطابقةً لـ`dartz`.
  bool isRight() => fold((_) => false, (_) => true);
}

/// الفرع اليساريّ — الخطأ عادةً.
final class Left<L, R> extends Either<L, R> {
  const Left(this.value);

  final L value;

  @override
  B fold<B>(B Function(L l) ifLeft, B Function(R r) ifRight) => ifLeft(value);

  /// المقارنة على القيمة وحدها بلا نظرٍ إلى وسيطَي النوع — كما في `dartz`،
  /// وتغييرُها يكسر أيّ `expect(result, Left(failure))` قائم.
  @override
  bool operator ==(Object other) => other is Left && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Left($value)';
}

/// الفرع اليمينيّ — النجاح عادةً.
final class Right<L, R> extends Either<L, R> {
  const Right(this.value);

  final R value;

  @override
  B fold<B>(B Function(L l) ifLeft, B Function(R r) ifRight) => ifRight(value);

  @override
  bool operator ==(Object other) => other is Right && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Right($value)';
}

/// نوعٌ بقيمةٍ واحدة — لعمليةٍ تنجح بلا أن تُرجع شيئاً: `Either<Failure, Unit>`.
///
/// أوضحُ من `void` لأنّه نوعٌ حقيقيّ يصلح وسيطاً لـ[Either]، ومن `bool`
/// لأنّه لا يُوحي بأنّ ثمّ صواباً وخطأ.
class Unit {
  const Unit._internal();

  @override
  String toString() => '()';
}

/// القيمة الوحيدة لـ[Unit]: `return const Right(unit);`
const Unit unit = Unit._internal();
