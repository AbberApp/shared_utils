import 'dart:async';

// fake_async تصل عبر flutter_test (تبعية غير مباشرة) لا عبر pubspec مباشرة،
// فالوصول إليها مقصود هنا: هي الطريقة الوحيدة لاختبار مؤقّت بلا انتظارٍ حقيقي.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار [DelayHandler] — معالج التأخير (Debounce).
///
/// كلّ اختبارٍ يجري داخل [fakeAsync] فلا وقت حقيقيّ يمضي: نتحكّم بالساعة
/// بالمللي ثانية الواحدة، فنميّز «قبل المهلة» من «عندها» تمييزاً قاطعاً،
/// ونتحقّق كذلك من أنّ المؤقّتات تُلغى فعلاً (`nonPeriodicTimerCount`)
/// لا أن يُكتفى بأنّ الإجراء لم يُستدعَ.
void main() {
  group('التأخير الأساسي', () {
    test('run لا يُنفّذ الإجراء فوراً', () {
      fakeAsync((fake) {
        var calls = 0;
        DelayHandler(defaultDelayMs: 100).run(() => calls++);
        // لا شيء بعد — ولا حتّى بعد تفريغ المهامّ الدقيقة.
        fake.flushMicrotasks();
        expect(calls, 0);
        fake.elapse(const Duration(milliseconds: 100));
        expect(calls, 1);
      });
    });

    test('المهلة الافتراضية ٨٠٠ ملّي: ٧٩٩ لا تكفي والـ٨٠٠ تكفي', () {
      fakeAsync((fake) {
        var calls = 0;
        DelayHandler().run(() => calls++);
        fake.elapse(const Duration(milliseconds: 799));
        expect(calls, 0, reason: 'نُفِّذ قبل انقضاء المهلة الافتراضية');
        fake.elapse(const Duration(milliseconds: 1));
        expect(calls, 1);
      });
    });

    test('المهلة الافتراضية المخصّصة في المُنشئ تُحترم', () {
      fakeAsync((fake) {
        var calls = 0;
        DelayHandler(defaultDelayMs: 250).run(() => calls++);
        fake.elapse(const Duration(milliseconds: 249));
        expect(calls, 0);
        fake.elapse(const Duration(milliseconds: 1));
        expect(calls, 1);
      });
    });

    test('delayMs يتجاوز المهلة الافتراضية لهذا الاستدعاء وحده', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 800);
        var fast = 0;
        var normal = 0;

        delay.run(() => fast++, delayMs: 50);
        fake.elapse(const Duration(milliseconds: 50));
        expect(fast, 1, reason: 'delayMs لم يتجاوز الافتراضيّ');

        // والاستدعاء التالي بلا delayMs يعود إلى الافتراضيّ.
        delay.run(() => normal++);
        fake.elapse(const Duration(milliseconds: 50));
        expect(normal, 0, reason: 'الافتراضيّ لم يعد بعد استدعاءٍ مخصّص');
        fake.elapse(const Duration(milliseconds: 750));
        expect(normal, 1);
      });
    });

    test('الإجراء يُستدعى مرّة واحدة بالضبط (المؤقّت ليس دوريّاً)', () {
      fakeAsync((fake) {
        var calls = 0;
        DelayHandler(defaultDelayMs: 100).run(() => calls++);
        fake.elapse(const Duration(hours: 5));
        expect(calls, 1);
        expect(fake.nonPeriodicTimerCount, 0);
        expect(fake.periodicTimerCount, 0);
      });
    });
  });

  group('الاستدعاءات المتتابعة (Debounce)', () {
    test('ثلاثة استدعاءات متلاحقة: الأخير وحده يُنفَّذ', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 100);
        final executed = <String>[];

        delay.run(() => executed.add('الأول'));
        fake.elapse(const Duration(milliseconds: 40));
        delay.run(() => executed.add('الثاني'));
        fake.elapse(const Duration(milliseconds: 40));
        delay.run(() => executed.add('الثالث'));

        // مضى ٨٠ ملّي منذ الأول، ومع ذلك لا شيء: كلٌّ ألغى سابقه.
        expect(executed, isEmpty);
        fake.elapse(const Duration(milliseconds: 100));
        expect(executed, ['الثالث']);
      });
    });

    test('المهلة تُستأنف من الاستدعاء الأخير لا من الأول', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 100);
        var calls = 0;

        delay.run(() => calls++);
        fake.elapse(const Duration(milliseconds: 99));
        delay.run(() => calls++); // إعادة ضبطٍ قبل مللي واحدة من الانطلاق
        fake.elapse(const Duration(milliseconds: 99));
        expect(calls, 0, reason: 'لم تُستأنف المهلة من الاستدعاء الأخير');
        fake.elapse(const Duration(milliseconds: 1));
        expect(calls, 1);
      });
    });

    test('مهلة الاستدعاء الأخير هي الحاكمة ولو كانت أقصر', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 800);
        final executed = <String>[];

        delay.run(() => executed.add('طويل'), delayMs: 5000);
        delay.run(() => executed.add('قصير'), delayMs: 20);

        fake.elapse(const Duration(milliseconds: 20));
        expect(executed, ['قصير']);
        // والطويل لا يعود أبداً مهما طال الوقت.
        fake.elapse(const Duration(seconds: 30));
        expect(executed, ['قصير']);
      });
    });

    test('الاستدعاء الجديد يُلغي مؤقّت السابق فلا تتراكم المؤقّتات', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 100);
        for (var i = 0; i < 50; i++) {
          delay.run(() {});
          expect(
            fake.nonPeriodicTimerCount,
            1,
            reason: 'تراكم مؤقّت إضافي عند التكرار رقم $i',
          );
        }
        delay.dispose();
      });
    });

    test('ألف استدعاء متلاحق لا يُنفّذ إلّا الأخير', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 300);
        var calls = 0;
        var last = -1;

        for (var i = 0; i < 1000; i++) {
          delay.run(() {
            calls++;
            last = i;
          });
          fake.elapse(const Duration(milliseconds: 1));
        }

        expect(calls, 0, reason: 'نُفِّذ شيء أثناء الدفقة المتلاحقة');
        fake.elapse(const Duration(milliseconds: 300));
        expect(calls, 1);
        expect(last, 999);
      });
    });

    test('المعالج قابل لإعادة الاستعمال بعد تنفيذٍ مكتمل', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 100);
        final executed = <String>[];

        delay.run(() => executed.add('أ'));
        fake.elapse(const Duration(milliseconds: 100));
        delay.run(() => executed.add('ب'));
        fake.elapse(const Duration(milliseconds: 100));
        delay.run(() => executed.add('ج'));
        fake.elapse(const Duration(milliseconds: 100));

        expect(executed, ['أ', 'ب', 'ج']);
      });
    });

    test('run من داخل الإجراء يجدول دورةً جديدة بلا تكرارٍ لانهائي', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 100);
        var calls = 0;

        void action() {
          calls++;
          if (calls < 3) delay.run(action);
        }

        delay.run(action);
        fake.elapse(const Duration(milliseconds: 100));
        expect(calls, 1);
        fake.elapse(const Duration(milliseconds: 100));
        expect(calls, 2);
        fake.elapse(const Duration(milliseconds: 100));
        expect(calls, 3);
        fake.elapse(const Duration(seconds: 10));
        expect(calls, 3, reason: 'استمرّت الجدولة بعد شرط التوقّف');
      });
    });

    test('معالجان مستقلّان لا يتداخلان', () {
      fakeAsync((fake) {
        final first = DelayHandler(defaultDelayMs: 100);
        final second = DelayHandler(defaultDelayMs: 100);
        final executed = <String>[];

        first.run(() => executed.add('الأول'));
        second.run(() => executed.add('الثاني'));
        fake.elapse(const Duration(milliseconds: 100));
        expect(executed, ['الأول', 'الثاني']);

        // وdispose أحدهما لا يمسّ الآخر.
        first.run(() => executed.add('الأول مجدّداً'));
        second.run(() => executed.add('الثاني مجدّداً'));
        first.dispose();
        fake.elapse(const Duration(milliseconds: 100));
        expect(executed, ['الأول', 'الثاني', 'الثاني مجدّداً']);
      });
    });
  });

  group('dispose', () {
    test('dispose قبل انقضاء المهلة يمنع التنفيذ', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 100);
        var calls = 0;

        delay.run(() => calls++);
        fake.elapse(const Duration(milliseconds: 99));
        delay.dispose();
        fake.elapse(const Duration(seconds: 10));

        expect(calls, 0, reason: 'dispose لم يمنع الإجراء المؤجَّل');
      });
    });

    test('dispose يُلغي المؤقّت فعلاً فلا يبقى مؤقّتٌ معلّق', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 100);
        delay.run(() {});
        expect(fake.nonPeriodicTimerCount, 1);
        delay.dispose();
        expect(
          fake.nonPeriodicTimerCount,
          0,
          reason: 'بقي مؤقّت معلّق بعد dispose (تسريب)',
        );
      });
    });

    test('dispose على معالجٍ لم يُستعمل قطّ آمن', () {
      fakeAsync((fake) {
        expect(DelayHandler().dispose, returnsNormally);
        expect(fake.nonPeriodicTimerCount, 0);
      });
    });

    test('dispose مرّتين متتاليتين آمن', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 100);
        delay.run(() {});
        delay.dispose();
        expect(delay.dispose, returnsNormally);
        fake.elapse(const Duration(seconds: 1));
      });
    });

    test('dispose بعد اكتمال التنفيذ لا يتراجع عمّا نُفِّذ', () {
      fakeAsync((fake) {
        final delay = DelayHandler(defaultDelayMs: 100);
        var calls = 0;

        delay.run(() => calls++);
        fake.elapse(const Duration(milliseconds: 100));
        expect(calls, 1);
        delay.dispose();
        fake.elapse(const Duration(seconds: 1));
        expect(calls, 1);
      });
    });

    test(
      'run بعد dispose لا يُنفِّذ شيئاً — dispose نهائيّ',
      () {
        fakeAsync((fake) {
          final delay = DelayHandler(defaultDelayMs: 100);
          var calls = 0;

          delay.dispose();
          delay.run(() => calls++);

          // السلوك الصحيح: كائنٌ مُتخلَّص منه لا يجدول شيئاً بعدُ، وإلّا انطلق
          // الإجراء على State/Bloc مُتخلَّص منه بعد أن أُغلقت الشاشة.
          expect(
            fake.nonPeriodicTimerCount,
            0,
            reason: 'run بعد dispose جدول مؤقّتاً جديداً',
          );
          fake.elapse(const Duration(seconds: 10));
          expect(calls, 0, reason: 'نُفِّذ إجراء بعد dispose');
        });
      },
    );
  });

  group('الحالات الحدّية', () {
    test('مهلة صفر: تأجيلٌ لدورة الحدث لا تنفيذٌ متزامن', () {
      fakeAsync((fake) {
        var calls = 0;
        DelayHandler(defaultDelayMs: 800).run(() => calls++, delayMs: 0);
        expect(calls, 0, reason: 'نُفِّذ متزامناً مع run');
        fake.elapse(Duration.zero);
        expect(calls, 1);
      });
    });

    test('مهلة سالبة لا ترمي وتُعامل معاملة الصفر', () {
      fakeAsync((fake) {
        var calls = 0;
        final delay = DelayHandler(defaultDelayMs: 800);
        expect(() => delay.run(() => calls++, delayMs: -100), returnsNormally);
        expect(calls, 0, reason: 'نُفِّذ متزامناً مع run');
        fake.elapse(Duration.zero);
        expect(calls, 1);
      });
    });

    test('defaultDelayMs سالب في المُنشئ لا يرمي', () {
      fakeAsync((fake) {
        var calls = 0;
        expect(() => DelayHandler(defaultDelayMs: -5).run(() => calls++),
            returnsNormally);
        fake.elapse(Duration.zero);
        expect(calls, 1);
      });
    });

    test('مهلة طويلة جدّاً (يوم كامل) تُحترم بدقّة المللي', () {
      fakeAsync((fake) {
        const dayMs = 24 * 60 * 60 * 1000;
        var calls = 0;
        DelayHandler(defaultDelayMs: dayMs).run(() => calls++);
        fake.elapse(const Duration(days: 1) - const Duration(milliseconds: 1));
        expect(calls, 0);
        fake.elapse(const Duration(milliseconds: 1));
        expect(calls, 1);
      });
    });

    test('نصّ عربي طويل يصل إلى الإجراء سليماً بلا تشويه', () {
      fakeAsync((fake) {
        final query = 'بحثٌ عن «مُنتَجٍ» ٢٠٢٤ — نصٌّ طويل ' * 500;
        String? received;

        DelayHandler(defaultDelayMs: 100).run(() => received = query);
        fake.elapse(const Duration(milliseconds: 100));

        expect(received, query);
        expect(received!.length, greaterThan(15000));
        expect(received, startsWith('بحثٌ'));
      });
    });

    test('استثناء داخل الإجراء لا يُفسد المعالج ولا يمنع ما بعده', () {
      final errors = <Object>[];
      runZonedGuarded(
        () {
          fakeAsync((fake) {
            final delay = DelayHandler(defaultDelayMs: 100);
            var calls = 0;

            delay.run(() => throw StateError('انفجار داخل الإجراء'));
            fake.elapse(const Duration(milliseconds: 100));

            // المعالج لم يُترك في حالةٍ فاسدة: الاستدعاء التالي يعمل.
            delay.run(() => calls++);
            fake.elapse(const Duration(milliseconds: 100));
            expect(calls, 1);
          });
        },
        (error, stack) => errors.add(error),
      );

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });
  });
}
