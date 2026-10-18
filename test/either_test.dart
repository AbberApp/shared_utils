import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار `Either` — البديل المحلّيّ لما كان يأتي من `dartz`.
///
/// أكثرُ ما يحرسه هنا **تطابقُ التواقيع** لا صحّةُ المنطق: `isLeft()` دالّةٌ
/// لا getter، و`getOrElse` تأخذ دالّةً لا قيمة، والمُنشئان `const`. أيّ انحرافٍ
/// في واحدةٍ منها يكسر آلاف المواضع في التطبيقات المستهلِكة بلا أن يُنبّه
/// المحلّلُ على المكتبة نفسها.
void main() {
  group('fold — العملية الأساس', () {
    test('اليسار يُنفّذ ifLeft وحده', () {
      const Either<String, int> e = Left<String, int>('خطأ');
      int rightCalls = 0;
      final String out = e.fold((String l) => 'يسار: $l', (int r) {
        rightCalls++;
        return 'يمين';
      });
      expect(out, 'يسار: خطأ');
      expect(rightCalls, 0, reason: 'ifRight يجب ألّا يُنفَّذ على يسار');
    });

    test('اليمين يُنفّذ ifRight وحده', () {
      const Either<String, int> e = Right<String, int>(7);
      int leftCalls = 0;
      final String out = e.fold((String l) {
        leftCalls++;
        return 'يسار';
      }, (int r) => 'يمين: $r');
      expect(out, 'يمين: 7');
      expect(leftCalls, 0);
    });

    test('النمط السائد في التطبيقات: (failure, data)', () {
      final List<String> emitted = <String>[];
      const Either<String, List<int>> ok = Right<String, List<int>>(<int>[1, 2]);
      ok.fold(
        (String failure) => emitted.add('فشل'),
        (List<int> data) => emitted.add('نجح ${data.length}'),
      );
      expect(emitted, <String>['نجح 2']);
    });

    test('fold يُرجع نوعاً مستقلّاً عن L وR', () {
      const Either<String, int> e = Right<String, int>(3);
      expect(e.fold((_) => false, (_) => true), isTrue);
    });
  });

  group('تواقيعُ `dartz` التي لا يجوز أن تنحرف', () {
    test('isLeft و isRight دالّتان لا getters', () {
      const Either<String, int> l = Left<String, int>('x');
      const Either<String, int> r = Right<String, int>(1);
      // استدعاءٌ بالأقواس: لو صارتا getters لما صُرّف هذا السطر.
      expect(l.isLeft(), isTrue);
      expect(l.isRight(), isFalse);
      expect(r.isLeft(), isFalse);
      expect(r.isRight(), isTrue);
    });

    test('getOrElse تأخذ دالّةً لا قيمة، ولا تُنفّذها على يمين', () {
      int calls = 0;
      int fallback() {
        calls++;
        return -1;
      }

      const Either<String, int> r = Right<String, int>(5);
      expect(r.getOrElse(fallback), 5);
      expect(calls, 0, reason: 'البديل لا يُحسب إلّا عند الحاجة');

      const Either<String, int> l = Left<String, int>('خطأ');
      expect(l.getOrElse(fallback), -1);
      expect(calls, 1);
    });

    test('operator | مرادفٌ بقيمةٍ جاهزة', () {
      const Either<String, int> l = Left<String, int>('خطأ');
      const Either<String, int> r = Right<String, int>(9);
      expect(l | 0, 0);
      expect(r | 0, 9);
    });

    test('المُنشئان const — و`const Right(unit)` مكتوبةٌ في عشرات المواضع', () {
      const Either<String, Unit> done = Right<String, Unit>(unit);
      expect(done.isRight(), isTrue);
      expect(identical(const Left<int, int>(1), const Left<int, int>(1)), isTrue,
          reason: 'القيم الثابتة تُوحَّد — دليلُ أنّ المُنشئ const فعلاً');
    });

    test('value متاحٌ على كلّ فرع', () {
      expect(const Left<String, int>('ف').value, 'ف');
      expect(const Right<String, int>(4).value, 4);
    });
  });

  group('المساواة — كما في dartz: على القيمة بلا وسيطَي النوع', () {
    test('يساران بالقيمة نفسها متساويان', () {
      expect(const Left<String, int>('x'), const Left<String, int>('x'));
      expect(const Left<String, int>('x').hashCode,
          const Left<String, int>('x').hashCode);
    });

    test('يمينان بالقيمة نفسها متساويان', () {
      expect(const Right<String, int>(3), const Right<String, int>(3));
    });

    test('اليسار لا يساوي اليمين ولو تطابقت القيمة', () {
      // التنبيه مقصودٌ إسكاتُه — تقاطعُ الفرعين هو عينُ ما نختبره.
      // ignore: unrelated_type_equality_checks
      expect(const Left<int, int>(1) == const Right<int, int>(1), isFalse);
    });

    test('المساواة لا تنظر إلى وسيطَي النوع', () {
      // سلوكُ dartz نفسه: تغييرُه يكسر أيّ expect(result, Left(failure)).
      // والتنبيه مقصودٌ إسكاتُه — المقارنةُ عبر نوعين هي عينُ ما نختبره.
      // ignore: unrelated_type_equality_checks
      expect(const Left<String, int>('x') == const Left<String, bool>('x'),
          isTrue);
    });
  });

  group('Unit', () {
    test('قيمةٌ واحدة لا غير — المُنشئ خاصّ فلا تُصنع ثانيةٌ', () {
      expect(identical(unit, unit), isTrue);
      expect(unit, isA<Unit>());
    });

    test('toString يطابق dartz', () {
      expect(unit.toString(), '()');
    });

    test('تصلح وسيطاً لعمليةٍ تنجح بلا قيمة', () {
      const Either<String, Unit> ok = Right<String, Unit>(unit);
      expect(ok.fold((_) => 'فشل', (Unit u) => 'نجح'), 'نجح');
    });
  });

  group('sealed — المكسب على dartz', () {
    test('switch شاملٌ بلا default', () {
      String describe(Either<String, int> e) => switch (e) {
            Left<String, int>(value: final String f) => 'فشل: $f',
            Right<String, int>(value: final int v) => 'نجح: $v',
          };
      expect(describe(const Left<String, int>('شبكة')), 'فشل: شبكة');
      expect(describe(const Right<String, int>(2)), 'نجح: 2');
    });
  });

  group('toString', () {
    test('يكشف الفرع والقيمة', () {
      expect(const Left<String, int>('خطأ').toString(), 'Left(خطأ)');
      expect(const Right<String, int>(5).toString(), 'Right(5)');
    });
  });
}
