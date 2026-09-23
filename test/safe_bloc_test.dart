// اختبار [SafeCubit] و[SafeBloc] — المزيجان اللذان كلّ عملهما منع انهيار
// `emit`/`add` بعد الإغلاق. فالمقياس الأوّل هنا ليس «هل تصل الحالة» بل **هل
// يبقى التطبيق حيّاً**: كلّ اختبار إسقاطٍ مقرونٌ باختبار «لا يرمي»، ولكلّ حراسةٍ
// اختبارٌ مقابلٌ على صنفٍ **بلا المزيج** يثبت أنّ العاري يرمي فعلاً — بدونه قد
// يمرّ الملفّ كلّه على مزيجٍ لا يفعل شيئاً.
//
// `bloc_test` ليست في التبعيات، فالاختبارات مكتوبة يدوياً — وهي هنا أدقّ:
// `blocTest` يبني ويُغلق نيابةً عنك، ونحن نختبر لحظة الإغلاق نفسها.
//
// `emit` محميّة (@protected)، فكلّ صنفٍ اختباريّ يفتحها بـ `push` — كما يفعل
// الكود الحقيقي حين يُصدر حالةً من دالّةٍ عامّة.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

// ───────────────────────────── أصناف اختباريّة ─────────────────────────────

/// كيوبت عدديّ: للصفر والسالب والتتابع.
class _CounterCubit extends Cubit<int> with SafeCubit<int> {
  _CounterCubit([super.initialState = 0]);

  void push(int value) => emit(value);
}

/// كيوبت حالته nullable: لـ null والفارغ والنصّ العربي الطويل.
class _TextCubit extends Cubit<String?> with SafeCubit<String?> {
  _TextCubit([super.initialState = 'البداية']);

  void push(String? value) => emit(value);
}

/// كيوبت **بلا** المزيج — شاهد النفي.
class _PlainCubit extends Cubit<int> {
  _PlainCubit() : super(0);

  void push(int value) => emit(value);
}

sealed class _Event {
  const _Event();
}

final class _Echo extends _Event {
  const _Echo(this.value);

  final String? value;
}

final class _Slow extends _Event {
  const _Slow();
}

/// بلوك المزيج الكامل.
class _EchoBloc extends Bloc<_Event, String?> with SafeBloc<_Event, String?> {
  _EchoBloc([super.initialState = 'البداية']) {
    on<_Echo>((event, emit) {
      handled.add('echo:${event.value}');
      emit(event.value);
    });

    // معالجٌ طويل يُحاكي طلباً شبكياً: يبدأ، ثمّ يستأنف بعد الإغلاق — وهو
    // النمط الذي رصده Sentry بالضبط.
    on<_Slow>((event, emit) async {
      handled.add('slow-start');
      await gate.future;
      handled.add('slow-resume:isDone=${emit.isDone}');
      try {
        emit('حالةٌ متأخّرة');
        handled.add('emit-ok');
      } on Object catch (e) {
        handled.add('emit-threw:${e.runtimeType}');
      }
      try {
        add(const _Echo('حدثٌ من داخل المعالج'));
        handled.add('add-ok');
      } on Object catch (e) {
        handled.add('add-threw:${e.runtimeType}');
      }
      finished.complete();
    });
  }

  /// سجلّ ما جرى فعلاً — لا استنتاج من الحالة وحدها.
  final List<String> handled = <String>[];

  /// بوّابة المعالج الطويل: يفتحها الاختبار متى شاء.
  final Completer<void> gate = Completer<void>();

  /// يكتمل حين ينتهي المعالج الطويل.
  final Completer<void> finished = Completer<void>();

  void push(String? value) => emit(value);
}

/// بلوك **بلا** المزيج — شاهد النفي.
class _PlainBloc extends Bloc<_Event, String?> {
  _PlainBloc() : super('البداية') {
    on<_Echo>((event, emit) => emit(event.value));
  }

  void push(String? value) => emit(value);
}

/// بلوك مخلوطٌ بـ [SafeCubit] خطأً — يترجم بلا شكوى، ولذلك يلزم إثبات فرقه.
class _CubitMixedBloc extends Bloc<_Event, String?> with SafeCubit<String?> {
  _CubitMixedBloc() : super('البداية') {
    on<_Echo>((event, emit) => emit(event.value));
  }

  void push(String? value) => emit(value);
}

// ───────────────────────────── مُعينات ─────────────────────────────

/// نصّ عربي طويل جداً (≈ ٢٠ ألف محرف) — الحالة قد تكون أيّ شيء.
final String _longArabic = 'نصٌّ عربيٌّ طويلٌ جداً ' * 1000;

/// مُدخل مشوّه: محرف فارغ، وعلامات اتجاه، وسطور، ورموز.
const String _malformed = '\u0623\u0000\u0628\u200F\u062C\n\u062F\t\u{1F642}\u202E\u0647\u0640';

/// يلتقط ما يصل إلى المستمعين فعلاً — الإسقاط غير الكتم.
List<T> _watch<T>(Stream<T> stream) {
  final seen = <T>[];
  final sub = stream.listen(seen.add);
  addTearDown(sub.cancel);
  return seen;
}

/// يُمرّر دورة أحداثٍ واحدة كي تصل حالات البثّ إلى المستمعين.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('SafeCubit — الحالة تُسلَّم قبل الإغلاق', () {
    test('emit يُحدّث الحالة ويصل إلى المستمع', () async {
      final cubit = _CounterCubit();
      addTearDown(cubit.close);
      final seen = _watch(cubit.stream);

      cubit.push(7);
      await _settle();

      expect(cubit.state, 7);
      expect(seen, <int>[7]);
    });

    test('تتابع الحالات يصل بالترتيب نفسه بلا نقصان', () async {
      final cubit = _CounterCubit();
      addTearDown(cubit.close);
      final seen = _watch(cubit.stream);

      for (final value in <int>[1, 2, 3, 4, 5]) {
        cubit.push(value);
      }
      await _settle();

      expect(seen, <int>[1, 2, 3, 4, 5]);
      expect(cubit.state, 5);
    });

    test('الصفر والسالب حالتان كغيرهما', () async {
      final cubit = _CounterCubit(5);
      addTearDown(cubit.close);
      final seen = _watch(cubit.stream);

      cubit.push(0);
      cubit.push(-1);
      cubit.push(-2147483648);
      await _settle();

      expect(seen, <int>[0, -1, -2147483648]);
      expect(cubit.state, -2147483648);
    });

    test('أوّل emit بقيمةٍ تساوي الحالة الأوّليّة يمرّ (لا يُبتلع)', () async {
      final cubit = _CounterCubit();
      addTearDown(cubit.close);
      final seen = _watch(cubit.stream);

      cubit.push(0); // نفس الأوّليّة، لكنّها أوّل إصدار
      await _settle();

      expect(seen, <int>[0]);
    });

    test('الحالة المكرّرة بعد أوّل إصدار تُهمل — المزيج لا يعطّل هذا', () async {
      final cubit = _CounterCubit();
      addTearDown(cubit.close);
      final seen = _watch(cubit.stream);

      cubit.push(3);
      cubit.push(3);
      cubit.push(3);
      await _settle();

      expect(seen, <int>[3]);
    });

    test('null حالةٌ صالحة ولا تُعامل كإسقاط', () async {
      final cubit = _TextCubit();
      addTearDown(cubit.close);
      final seen = _watch(cubit.stream);

      cubit.push(null);
      await _settle();

      expect(cubit.state, isNull);
      expect(seen, <String?>[null]);
    });

    test('النصّ الفارغ يُسلَّم كما هو', () async {
      final cubit = _TextCubit();
      addTearDown(cubit.close);
      final seen = _watch(cubit.stream);

      cubit.push('');
      await _settle();

      expect(cubit.state, '');
      expect(seen, <String?>['']);
    });

    test('نصّ عربي طويل جداً ومُدخل مشوّه يمرّان بلا تشويه', () async {
      final cubit = _TextCubit();
      addTearDown(cubit.close);
      final seen = _watch(cubit.stream);

      cubit.push(_longArabic);
      cubit.push(_malformed);
      await _settle();

      expect(seen, <String?>[_longArabic, _malformed]);
      expect(cubit.state, _malformed);
      expect((seen.first as String).length, greaterThan(10000));
    });
  });

  group('SafeCubit — emit بعد الإغلاق لا يرمي', () {
    test('emit واحد بعد الإغلاق لا يرمي', () async {
      final cubit = _CounterCubit();
      cubit.push(1);
      await cubit.close();

      expect(() => cubit.push(2), returnsNormally);
    });

    test('الحالة تبقى آخر ما سبق الإغلاق', () async {
      final cubit = _CounterCubit();
      cubit.push(1);
      await cubit.close();

      cubit.push(2);

      expect(cubit.state, 1);
    });

    test('مئة emit بعد الإغلاق لا ترمي ولا تغيّر الحالة', () async {
      final cubit = _TextCubit();
      cubit.push('قبل');
      await cubit.close();

      expect(() {
        for (var i = 0; i < 100; i++) {
          cubit.push('بعد $i');
        }
      }, returnsNormally);
      expect(cubit.state, 'قبل');
    });

    test('القيم الحدّية بعد الإغلاق لا ترمي: null والفارغ والطويل والمشوّه', () async {
      final cubit = _TextCubit();
      await cubit.close();

      expect(() {
        cubit
          ..push(null)
          ..push('')
          ..push(_longArabic)
          ..push(_malformed);
      }, returnsNormally);
      expect(cubit.state, 'البداية');
    });

    test('البثّ منتهٍ بعد الإغلاق فلا يصل شيء إلى مستمعٍ جديد', () async {
      final cubit = _CounterCubit();
      await cubit.close();

      cubit.push(9);

      await expectLater(cubit.stream, emitsDone);
    });

    test('isClosed يصير true، وهو حارس MIXIN نفسه', () async {
      final cubit = _CounterCubit();
      expect(cubit.isClosed, isFalse);

      await cubit.close();

      expect(cubit.isClosed, isTrue);
    });

    test('شاهد النفي: كيوبت بلا المزيج يرمي StateError', () async {
      final plain = _PlainCubit();
      await plain.close();

      expect(() => plain.push(1), throwsStateError);
    });

    test('emit فور بدء الإغلاق (بلا await) يُسقَط ولا يرمي', () async {
      final cubit = _CounterCubit();
      cubit.push(1);

      final Future<void> closing = cubit.close(); // بلا await عمداً
      expect(() => cubit.push(2), returnsNormally);
      await closing;

      // متحكّم الحالة في الكيوبت يُغلق في أوّل سطرٍ من close، فلا نافذة تسليم.
      expect(cubit.state, 1);
    });
  });

  group('SafeCubit — الإغلاق المزدوج', () {
    test('close مرّتين متتاليتين لا يرمي', () async {
      final cubit = _CounterCubit();
      await cubit.close();

      await expectLater(cubit.close(), completes);
      expect(cubit.isClosed, isTrue);
    });

    test('close مرّتين متزامنتين (بلا await بينهما) لا يرمي', () async {
      final cubit = _CounterCubit();

      final Future<void> first = cubit.close();
      final Future<void> second = cubit.close();

      await expectLater(Future.wait(<Future<void>>[first, second]), completes);
    });

    test('ثلاث إغلاقات ثمّ emit — لا شيء يرمي والحالة محفوظة', () async {
      final cubit = _TextCubit();
      cubit.push('آخر حالة');
      await cubit.close();
      await cubit.close();
      await cubit.close();

      expect(() => cubit.push('بعد الإغلاق'), returnsNormally);
      expect(cubit.state, 'آخر حالة');
    });
  });

  group('SafeBloc — add', () {
    test('add قبل الإغلاق يُعالَج ويُسلّم الحالة', () async {
      final bloc = _EchoBloc();
      addTearDown(bloc.close);
      final seen = _watch(bloc.stream);

      bloc.add(const _Echo('مرحباً'));
      await _settle();

      expect(bloc.state, 'مرحباً');
      expect(seen, <String?>['مرحباً']);
      expect(bloc.handled, <String>['echo:مرحباً']);
    });

    test('add بعد الإغلاق لا يرمي', () async {
      final bloc = _EchoBloc();
      await bloc.close();

      expect(() => bloc.add(const _Echo('بعد')), returnsNormally);
    });

    test('add بعد الإغلاق لا يُعالَج أصلاً', () async {
      final bloc = _EchoBloc();
      await bloc.close();

      bloc.add(const _Echo('بعد'));
      await _settle();

      expect(bloc.handled, isEmpty);
      expect(bloc.state, 'البداية');
    });

    test('مئة add بعد الإغلاق لا ترمي', () async {
      final bloc = _EchoBloc();
      await bloc.close();

      expect(() {
        for (var i = 0; i < 100; i++) {
          bloc.add(_Echo('حدث $i'));
        }
      }, returnsNormally);
      expect(bloc.handled, isEmpty);
    });

    test('أحداث بقيمٍ حدّية بعد الإغلاق لا ترمي: null والفارغ والطويل', () async {
      final bloc = _EchoBloc();
      await bloc.close();

      expect(() {
        bloc
          ..add(const _Echo(null))
          ..add(const _Echo(''))
          ..add(_Echo(_longArabic))
          ..add(const _Echo(_malformed));
      }, returnsNormally);
    });

    test('شاهد النفي: بلوك بلا المزيج يرمي StateError عند add بعد الإغلاق', () async {
      final plain = _PlainBloc();
      await plain.close();

      expect(() => plain.add(const _Echo('بعد')), throwsStateError);
    });

    test('add فور بدء الإغلاق (بلا await) لا يرمي ولا يُعالَج', () async {
      final bloc = _EchoBloc();

      final Future<void> closing = bloc.close();
      expect(() => bloc.add(const _Echo('أثناء')), returnsNormally);
      await closing;
      await _settle();

      expect(bloc.handled, isEmpty);
    });

    test('add من داخل معالجٍ استأنف بعد الإغلاق لا يرمي — نمط Sentry', () async {
      final bloc = _EchoBloc();
      bloc.add(const _Slow());
      await _settle();
      expect(bloc.handled, contains('slow-start'));

      await bloc.close(); // المستخدم غادر الشاشة
      bloc.gate.complete(); // ثمّ عاد الطلب الشبكي
      await bloc.finished.future;

      expect(bloc.handled, contains('add-ok'));
      expect(
        bloc.handled.where((e) => e.startsWith('add-threw')),
        isEmpty,
        reason: 'add بعد الإغلاق يجب أن يُسقَط لا أن يرمي',
      );
    });
  });

  group('SafeBloc — emit', () {
    test('emit قبل الإغلاق يُسلّم الحالة ويصل إلى المستمع', () async {
      final bloc = _EchoBloc();
      addTearDown(bloc.close);
      final seen = _watch(bloc.stream);

      bloc.push('حالة');
      await _settle();

      expect(bloc.state, 'حالة');
      expect(seen, <String?>['حالة']);
    });

    test('emit بعد الإغلاق لا يرمي ولا يغيّر الحالة', () async {
      final bloc = _EchoBloc();
      bloc.push('قبل');
      await bloc.close();

      expect(() => bloc.push('بعد'), returnsNormally);
      expect(bloc.state, 'قبل');
    });

    test('مئة emit بعد الإغلاق لا ترمي', () async {
      final bloc = _EchoBloc();
      await bloc.close();

      expect(() {
        for (var i = 0; i < 100; i++) {
          bloc.push('حالة $i');
        }
      }, returnsNormally);
      expect(bloc.state, 'البداية');
    });

    test('القيم الحدّية بعد الإغلاق لا ترمي: null والفارغ والطويل والمشوّه', () async {
      final bloc = _EchoBloc();
      await bloc.close();

      expect(() {
        bloc
          ..push(null)
          ..push('')
          ..push(_longArabic)
          ..push(_malformed);
      }, returnsNormally);
      expect(bloc.state, 'البداية');
    });

    test('شاهد النفي: بلوك بلا المزيج يرمي StateError عند emit بعد الإغلاق', () async {
      final plain = _PlainBloc();
      await plain.close();

      expect(() => plain.push('بعد'), throwsStateError);
    });

    test('emit فور بدء الإغلاق يُسلَّم — هذا كلّ سبب `_stateClosed`', () async {
      final bloc = _EchoBloc();
      final seen = _watch(bloc.stream);

      final Future<void> closing = bloc.close(); // بلا await عمداً
      bloc.push('حالةٌ في النافذة');
      await closing;
      await _settle();

      // متحكّم الأحداث أُغلق (isClosed صار true) بينما متحكّم الحالة لم يُغلق
      // بعد، فالحراسة بـ isClosed كانت ستُسقط هذه الحالة.
      expect(bloc.state, 'حالةٌ في النافذة');
      expect(seen, contains('حالةٌ في النافذة'));
    });

    test('معالجٌ جارٍ استأنف بعد الإغلاق: emit منه لا يرمي ولا يغيّر الحالة', () async {
      final bloc = _EchoBloc();
      bloc.add(const _Slow());
      await _settle();

      await bloc.close();
      // `close()` لا ينتظر المعالج الجاري: يُلغي مُصدِراته ثمّ يعود فوراً.
      expect(
        bloc.handled.where((e) => e.startsWith('slow-resume')),
        isEmpty,
        reason: 'المعالج ما يزال واقفاً عند بوّابته بعد اكتمال الإغلاق',
      );

      bloc.gate.complete();
      await bloc.finished.future;

      // المُصدِر أُلغي، فـ `emit` من المعالج يُبتلع صامتاً — لا انهيار.
      expect(bloc.handled, contains('slow-resume:isDone=true'));
      expect(bloc.handled, contains('emit-ok'));
      expect(
        bloc.handled.where((e) => e.startsWith('emit-threw')),
        isEmpty,
        reason: 'emit المعالج بعد الإغلاق يجب أن يُسقَط لا أن يرمي',
      );
      expect(bloc.state, 'البداية');
    });

    test('isClosed للبلوك يصير true بعد الإغلاق', () async {
      final bloc = _EchoBloc();
      expect(bloc.isClosed, isFalse);

      await bloc.close();

      expect(bloc.isClosed, isTrue);
    });
  });

  group('SafeBloc — الإغلاق المزدوج', () {
    test('close مرّتين متتاليتين لا يرمي', () async {
      final bloc = _EchoBloc();
      await bloc.close();

      await expectLater(bloc.close(), completes);
      expect(bloc.isClosed, isTrue);
    });

    test('close مرّتين متزامنتين (بلا await بينهما) لا يرمي', () async {
      final bloc = _EchoBloc();

      final Future<void> first = bloc.close();
      final Future<void> second = bloc.close();

      await expectLater(Future.wait(<Future<void>>[first, second]), completes);
    });

    test('إغلاقٌ مزدوج ومعالجٌ جارٍ معاً: لا شيء يرمي', () async {
      final bloc = _EchoBloc();
      bloc.add(const _Slow());
      await _settle();

      await bloc.close();
      await bloc.close();
      bloc.gate.complete();
      await bloc.finished.future;

      expect(
        bloc.handled.where((e) => e.contains('threw')),
        isEmpty,
        reason: 'الإغلاق المزدوج لا يُبطل الحراسة',
      );
    });

    test('add وemit بعد الإغلاق المزدوج لا يرميان', () async {
      final bloc = _EchoBloc();
      bloc.push('آخر حالة');
      await bloc.close();
      await bloc.close();

      expect(() => bloc.add(const _Echo('بعد')), returnsNormally);
      expect(() => bloc.push('بعد'), returnsNormally);
      expect(bloc.state, 'آخر حالة');
    });
  });

  group('لماذا مزيجان لا مزيج واحد', () {
    test('SafeCubit على بلوك يُسقط حالة نافذة الإغلاق التي يُسلّمها SafeBloc', () async {
      // نفس السيناريو حرفياً على الصنفين، والفرق كلّه في الحارس:
      // `isClosed` في البلوك يشمل متحكّم الأحداث، فيَصدُق باكراً.
      final mixedWrong = _CubitMixedBloc();
      final Future<void> closingWrong = mixedWrong.close();
      mixedWrong.push('في النافذة');
      await closingWrong;

      final mixedRight = _EchoBloc();
      final Future<void> closingRight = mixedRight.close();
      mixedRight.push('في النافذة');
      await closingRight;

      expect(mixedWrong.state, 'البداية', reason: 'SafeCubit أسقطها');
      expect(mixedRight.state, 'في النافذة', reason: 'SafeBloc سلّمها');
    });

    test('SafeCubit على بلوك يحمي emit لكنّه لا يحمي add', () async {
      final mixedWrong = _CubitMixedBloc();
      await mixedWrong.close();

      expect(() => mixedWrong.push('بعد'), returnsNormally);
      expect(
        () => mixedWrong.add(const _Echo('بعد')),
        throwsStateError,
        reason: 'add غير محروس إلا في SafeBloc',
      );
    });
  });

  group('نافذة الإغلاق — حراسة انحدار', () {
    test(
      'emit في أيّ لحظة بعد بدء إغلاق البلوك لا يرمي',
      () async {
        // المزيج يرصد الإغلاق بـ `_stateClosed` التي تُضبط في `whenComplete`
        // بعد اكتمال `close()`. لكنّ متحكّم الحالة يُغلق **قبل** ذلك بدورة
        // مهامٍ صغرى، فبينهما نافذةٌ يكون فيها `_stateClosed == false`
        // والمتحكّم مغلقاً — كان `emit` يمرّ فيها إلى `super.emit` فيرمي
        // StateError. النافذة ضيّقة لكنّها حقيقيّة: يكفي أن تستأنف دالّةٌ غير
        // منتظَرة (نتيجة طلبٍ شبكيّ مثلاً) في تلك الدورة بالذات ليعود الانهيار
        // الذي وُضع المزيج لمنعه. الحارس الآن يلتقط ذلك الـStateError ويبتلعه.
        for (var ticks = 0; ticks <= 8; ticks++) {
          final bloc = _EchoBloc();
          unawaited(bloc.close());
          for (var i = 0; i < ticks; i++) {
            await null;
          }
          expect(
            () => bloc.push('بعد $ticks'),
            returnsNormally,
            reason: 'رمى بعد $ticks دورة مهامٍ صغرى من بدء الإغلاق',
          );
        }
      },
    );

    test(
      'emit من مستمعٍ عند انتهاء البثّ (onDone) لا يرمي',
      () async {
        // إعادةٌ حتميّة للحالة نفسها بلا اعتمادٍ على عدد دورات: `onDone`
        // يُسلَّم أثناء إغلاق متحكّم الحالة، أي داخل النافذة تماماً.
        final bloc = _EchoBloc();
        Object? thrown;
        bloc.stream.listen(
          null,
          onDone: () {
            try {
              bloc.push('من onDone');
            } on Object catch (e) {
              thrown = e;
            }
          },
        );

        await bloc.close();
        await _settle();

        expect(thrown, isNull, reason: 'المزيج وُضع ليمنع هذا الانهيار بالذات');
      },
    );

    test('الإغلاق لا ينتظر المعالج الجاري — وحالته المتأخّرة تُبتلع', () async {
      // قد يُظنّ أنّ النافذة موجودة كي يفي bloc بإتمام المعالجات الجارية
      // وتسليم حالاتها. الواقع خلاف ذلك في 9.2.1: `Bloc.close()` يُلغي كلّ
      // المُصدِرات (`emitter.cancel()`) **قبل** انتظارها، فيعود فوراً وتُبتلع
      // حالات أيّ معالجٍ يستأنف بعده.
      //
      // فما يحفظه `_stateClosed` (بدل `isClosed`) هو نداء `emit` المباشر في
      // تلك النافذة وحده — لا حالات المعالجات. وهذا الاختبار يثبّت الواقع كي
      // لا يعود التعليل الخاطئ إلى التوثيق.
      final bloc = _EchoBloc();
      bloc.add(const _Slow());
      await _settle();

      await bloc.close();

      expect(
        bloc.handled.where((e) => e.startsWith('slow-resume')),
        isEmpty,
        reason: 'الإغلاق لم ينتظر المعالج الجاري',
      );

      bloc.gate.complete();
      await bloc.finished.future;

      expect(
        bloc.state,
        'البداية',
        reason: 'حالة المعالج الجاري لم تُسلَّم — خلافاً لتعليل التوثيق',
      );
    });
  });
}
