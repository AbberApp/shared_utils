// توجيه أخطاء الحقول القادمة من الخادم إلى حقولها: [FieldErrors.apply]
// و[FieldErrors.clear].
//
// المحور هنا **قيمة الإرجاع**: هي وحدها ما يقرّر هل يرى المستخدم خطأه على
// الحقل أم رسالةً عامّة وسط الشاشة — و`false` كاذبة تُغرق الشاشة بحوارٍ لا
// يدلّ على حقل، و`true` كاذبة تكتم الخطأ كتماناً تامّاً.
//
// الاستيراد من البرميل وحده مقصود: هو ما يملكه المستهلك، وهو يُثبت أنّ
// `FieldErrors` مُصدَّرة فعلاً.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// حوضٌ يسجّل كلّ ما استُدعي به — رسالةً كان أو مسحاً (`null`) — فيُقاس به
/// عددُ الاستدعاءات وترتيبها، لا آخر قيمةٍ وحدها.
final class _Recorder {
  final List<String?> calls = <String?>[];

  /// `List.add` نفسه هو `void Function(String?)` أي [ValueSetter] مطلوبة.
  ValueSetter<String?> get sink => calls.add;

  int get count => calls.length;
  String? get last => calls.last;
}

/// فشلٌ بحقولٍ مرتّبة — الحالة الغالبة: مفتاحٌ واحد لكلّ حقل.
Failure _failure(
  Map<String, String> fields, {
  int code = 400,
  String? message = 'من فضلك صحّح البيانات',
}) => Failure(
  code: code,
  message: message,
  fields: <FieldError>[
    for (final MapEntry<String, String> e in fields.entries)
      FieldError(field: e.key, message: e.value),
  ],
);

/// مفتاحٌ غير مركّب: `currentState` فيه `null`، وهو حال كلّ اختبارٍ لا يبني
/// شجرة عناصر — ومحاكاةٌ صادقة لنموذجٍ أُزيل من الشجرة قبل وصول الرد.
GlobalKey<FormState> _key() => GlobalKey<FormState>();

void main() {
  group('قيمة الإرجاع — حقلٌ أم رسالةٌ عامّة', () {
    test('مطابقةٌ واحدة على الأقلّ تعيد true', () {
      final _Recorder name = _Recorder();
      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{'name': name.sink},
        ),
        isTrue,
      );
    });

    test('فشلٌ بلا حقولٍ أصلاً يعيد false — الرسالة العامّة هي المخرج', () {
      final _Recorder name = _Recorder();
      expect(
        FieldErrors.apply(
          failure: const Failure(code: 500, message: 'خطأ في الخادم'),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{'name': name.sink},
        ),
        isFalse,
      );
    });

    test('قائمة حقولٍ فارغة صراحةً تعيد false', () {
      final _Recorder name = _Recorder();
      expect(
        FieldErrors.apply(
          failure: const Failure(code: 400, fields: <FieldError>[]),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{'name': name.sink},
        ),
        isFalse,
      );
    });

    test('حقلٌ لا يطابق أيّ مفتاح يعيد false — وإلّا ضاع الخطأ صامتاً', () {
      final _Recorder name = _Recorder();
      expect(
        FieldErrors.apply(
          // الخادم اشتكى من `captcha` والنموذج لا يعرفه: لا حقل يُعرض عليه
          // الخطأ، فلا بدّ من الرسالة العامّة.
          failure: _failure(<String, String>{'captcha': 'تحقّقٌ فاشل'}),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{'name': name.sink},
        ),
        isFalse,
      );
    });

    test('مطابقةٌ واحدة وسط حقولٍ مجهولة تكفي لـ true', () {
      final _Recorder email = _Recorder();
      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{
            'captcha': 'تحقّقٌ فاشل',
            'email': 'بريدٌ مستعمل',
            'tenant': 'غير مسموح',
          }),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{'email': email.sink},
        ),
        isTrue,
      );
      expect(email.last, 'بريدٌ مستعمل');
    });

    test('أحواضٌ فارغة مع فشلٍ بحقول تعيد false — لا حقل يستقبل شيئاً', () {
      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
          formKey: _key(),
          sinks: const <String, ValueSetter<String?>>{},
        ),
        isFalse,
      );
    });

    test('رمز الحالة لا يغيّر القرار — 429 و500 و0 كـ400 سواء', () {
      for (final int code in <int>[0, 400, 422, 429, 500, -1]) {
        final _Recorder name = _Recorder();
        expect(
          FieldErrors.apply(
            failure: _failure(<String, String>{
              'name': 'الاسم مستعمل',
            }, code: code),
            formKey: _key(),
            sinks: <String, ValueSetter<String?>>{'name': name.sink},
          ),
          isTrue,
          reason: 'الرمز $code لا علاقة له بوجود أخطاء حقول',
        );
      }
    });

    test('رسالةٌ عامّة null لا تمنع توجيه خطأ الحقل', () {
      final _Recorder name = _Recorder();
      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{
            'name': 'الاسم مستعمل',
          }, message: null),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{'name': name.sink},
        ),
        isTrue,
      );
      expect(name.last, 'الاسم مستعمل');
    });
  });

  group('توزيع الرسائل على الأحواض', () {
    test('الحوض المطابق يتلقّى الرسالة نصّاً كما هي', () {
      final _Recorder name = _Recorder();
      FieldErrors.apply(
        failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
        formKey: _key(),
        sinks: <String, ValueSetter<String?>>{'name': name.sink},
      );
      expect(name.calls, <String?>['الاسم مستعمل']);
    });

    test('الحوض غير المطابق يتلقّى null — أي يُمسح لا يُترك', () {
      final _Recorder name = _Recorder();
      final _Recorder email = _Recorder();
      FieldErrors.apply(
        failure: _failure(<String, String>{'email': 'بريدٌ مستعمل'}),
        formKey: _key(),
        sinks: <String, ValueSetter<String?>>{
          'name': name.sink,
          'email': email.sink,
        },
      );
      expect(name.calls, <String?>[null]);
      expect(email.calls, <String?>['بريدٌ مستعمل']);
    });

    test('كلّ حوضٍ يُستدعى مرّةً واحدة بالضبط', () {
      final _Recorder name = _Recorder();
      final _Recorder email = _Recorder();
      final _Recorder phone = _Recorder();
      FieldErrors.apply(
        failure: _failure(<String, String>{
          'name': 'الاسم مستعمل',
          'email': 'بريدٌ مستعمل',
        }),
        formKey: _key(),
        sinks: <String, ValueSetter<String?>>{
          'name': name.sink,
          'email': email.sink,
          'phone': phone.sink,
        },
      );
      expect(name.count, 1);
      expect(email.count, 1);
      expect(phone.count, 1); // مُسِح بـ null، لكن مرّةً واحدة
    });

    test('عند تكرار اسم الحقل تفوز أوّل مدخلة', () {
      final _Recorder name = _Recorder();
      FieldErrors.apply(
        failure: const Failure(
          code: 400,
          fields: <FieldError>[
            FieldError(field: 'name', message: 'الأولى'),
            FieldError(field: 'name', message: 'الثانية'),
          ],
        ),
        formKey: _key(),
        sinks: <String, ValueSetter<String?>>{'name': name.sink},
      );
      expect(name.last, 'الأولى');
    });

    test('اسم حقلٍ عربيّ يطابق كما يطابق اللاتينيّ', () {
      final _Recorder recorder = _Recorder();
      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{'الاسم': 'مستعمل'}),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{'الاسم': recorder.sink},
        ),
        isTrue,
      );
      expect(recorder.last, 'مستعمل');
    });

    test('رسالةٌ عربية طويلة جداً تصل كاملةً بلا قصّ', () {
      final String long = 'الاسم مستعمل مسبقاً. ' * 500; // ~10 آلاف محرف
      final _Recorder name = _Recorder();
      FieldErrors.apply(
        failure: _failure(<String, String>{'name': long}),
        formKey: _key(),
        sinks: <String, ValueSetter<String?>>{'name': name.sink},
      );
      expect(name.last, long);
      expect(name.last!.length, long.length);
    });

    test('المطابقة حسّاسة لحالة الأحرف والفراغات', () {
      final _Recorder upper = _Recorder();
      final _Recorder padded = _Recorder();
      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{
            'Name': upper.sink,
            ' name': padded.sink,
          },
        ),
        isFalse,
        reason: 'اسم الحقل مفتاحُ بروتوكولٍ يُطابَق حرفيّاً، لا نصُّ عرض',
      );
      expect(upper.last, isNull);
      expect(padded.last, isNull);
    });

    test('اسم حقلٍ فارغ يطابق مفتاحاً فارغاً', () {
      // `Failure.fromJson` تُسقط الحقول بلا اسم، لكنّ النموذج يُبنى مباشرةً
      // أيضاً — فالسلوك هنا مطابقةٌ نصّيةٌ بحتة بلا استثناء للفارغ.
      final _Recorder recorder = _Recorder();
      expect(
        FieldErrors.apply(
          failure: const Failure(
            code: 400,
            fields: <FieldError>[FieldError(field: '', message: 'بلا اسم')],
          ),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{'': recorder.sink},
        ),
        isTrue,
      );
      expect(recorder.last, 'بلا اسم');
    });
  });

  group('clear — قبل كلّ إرسالٍ جديد', () {
    test('يمسح كلّ حوضٍ بـ null', () {
      final _Recorder name = _Recorder();
      final _Recorder email = _Recorder();
      FieldErrors.clear(<String, ValueSetter<String?>>{
        'name': name.sink,
        'email': email.sink,
      });
      expect(name.calls, <String?>[null]);
      expect(email.calls, <String?>[null]);
    });

    test('يستدعي كلّ حوضٍ مرّةً واحدة', () {
      final _Recorder name = _Recorder();
      FieldErrors.clear(<String, ValueSetter<String?>>{'name': name.sink});
      expect(name.count, 1);
    });

    test('خريطةٌ فارغة لا ترمي ولا تفعل شيئاً', () {
      expect(
        () => FieldErrors.clear(const <String, ValueSetter<String?>>{}),
        returnsNormally,
      );
    });

    test('clear بعد apply يرفع الرسالة المعلّقة', () {
      String? nameError;
      final Map<String, ValueSetter<String?>> sinks =
          <String, ValueSetter<String?>>{'name': (String? m) => nameError = m};
      FieldErrors.apply(
        failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
        formKey: _key(),
        sinks: sinks,
      );
      expect(nameError, 'الاسم مستعمل');
      FieldErrors.clear(sinks);
      expect(nameError, isNull);
    });
  });

  group('apply مرّتين متتاليتين', () {
    test('الثاني يمسح خطأ الأوّل ويضع خطأه على حقلٍ آخر', () {
      String? nameError;
      String? emailError;
      final Map<String, ValueSetter<String?>> sinks =
          <String, ValueSetter<String?>>{
            'name': (String? m) => nameError = m,
            'email': (String? m) => emailError = m,
          };

      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
          formKey: _key(),
          sinks: sinks,
        ),
        isTrue,
      );
      expect(nameError, 'الاسم مستعمل');
      expect(emailError, isNull);

      // ردٌّ ثانٍ يشتكي من البريد وحده: الاسم صُحِّح فلا يجوز بقاء خطئه.
      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{'email': 'بريدٌ مستعمل'}),
          formKey: _key(),
          sinks: sinks,
        ),
        isTrue,
      );
      expect(nameError, isNull);
      expect(emailError, 'بريدٌ مستعمل');
    });

    test('نفس الفشل مرّتين: نفس القرار ونفس الرسالة', () {
      final _Recorder name = _Recorder();
      final Failure failure = _failure(<String, String>{
        'name': 'الاسم مستعمل',
      });
      final Map<String, ValueSetter<String?>> sinks =
          <String, ValueSetter<String?>>{'name': name.sink};

      final bool first = FieldErrors.apply(
        failure: failure,
        formKey: _key(),
        sinks: sinks,
      );
      final bool second = FieldErrors.apply(
        failure: failure,
        formKey: _key(),
        sinks: sinks,
      );
      expect(<bool>[first, second], <bool>[true, true]);
      expect(name.calls, <String?>['الاسم مستعمل', 'الاسم مستعمل']);
    });

    test('الثاني بحقولٍ مجهولة كلّها يمسح خطأ الأوّل ويعيد false', () {
      String? nameError;
      final Map<String, ValueSetter<String?>> sinks =
          <String, ValueSetter<String?>>{'name': (String? m) => nameError = m};

      FieldErrors.apply(
        failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
        formKey: _key(),
        sinks: sinks,
      );
      expect(nameError, 'الاسم مستعمل');

      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{'captcha': 'تحقّقٌ فاشل'}),
          formKey: _key(),
          sinks: sinks,
        ),
        isFalse,
      );
      expect(nameError, isNull);
    });

    test(
      'الثاني بفشلٍ بلا حقول يمسح خطأ الأوّل — وإلّا بقي معلّقاً على حقلٍ صحيح',
      () {
        String? nameError;
        final Map<String, ValueSetter<String?>> sinks =
            <String, ValueSetter<String?>>{
              'name': (String? m) => nameError = m,
            };

        FieldErrors.apply(
          failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
          formKey: _key(),
          sinks: sinks,
        );
        expect(nameError, 'الاسم مستعمل');

        // إرسالٌ ثانٍ بعد تصحيح الاسم، فسقط الخادم برمز 500 بلا أخطاء حقول:
        // تُعرض الرسالة العامّة (false)، ولا يجوز أن يبقى «الاسم مستعمل»
        // معلّقاً على حقلٍ لم يعد الخادم يشتكي منه.
        expect(
          FieldErrors.apply(
            failure: const Failure(code: 500, message: 'خطأ في الخادم'),
            formKey: _key(),
            sinks: sinks,
          ),
          isFalse,
        );
        expect(nameError, isNull);
      },
    );
  });

  group('حدودٌ: نموذجٌ غير مركّب ورسائل فارغة', () {
    test('مفتاح نموذجٍ بلا currentState لا يرمي', () {
      final _Recorder name = _Recorder();
      expect(
        () => FieldErrors.apply(
          failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
          formKey: _key(), // لم يُركّب في شجرةٍ قطّ
          sinks: <String, ValueSetter<String?>>{'name': name.sink},
        ),
        returnsNormally,
      );
      expect(name.last, 'الاسم مستعمل');
    });

    test('مفتاحٌ غير مركّب لا يمنع قيمة الإرجاع الصحيحة', () {
      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{'name': (String? _) {}},
        ),
        isTrue,
      );
    });

    test(
      'رسالة حقلٍ فارغة لا تُعدّ خطأً معروضاً — القرار يبقى للرسالة العامّة',
      () {
        // حالٌ واقعيّة: الخادم سمّى الحقل ولم يُرسل رسالة، فبقي في النموذج
        // حقلٌ برسالةٍ فارغة. ويُبنى هنا مباشرةً لا من جسمٍ خام: الموضوع
        // `apply` لا قراءةُ `Failure.fromJson`.
        const Failure failure = Failure(
          code: 400,
          message: 'من فضلك صحّح البيانات',
          fields: <FieldError>[FieldError(field: 'name', message: '')],
        );
        expect(failure.hasFields, isTrue);
        expect(failure.fieldError('name'), '');

        String? nameError;
        // `''` نصٌّ غير null: `Form` يعدّ الحقل غير صالح ويرسم سطر خطأ فارغاً،
        // فلا المستخدم يقرأ شيئاً ولا الرسالة العامّة تُعرض — كتمانٌ تامّ.
        expect(
          FieldErrors.apply(
            failure: failure,
            formKey: _key(),
            sinks: <String, ValueSetter<String?>>{
              'name': (String? m) => nameError = m,
            },
          ),
          isFalse,
        );
        expect(nameError, isNull);
      },
    );

    test('رسالة حقلٍ من فراغاتٍ فقط — نفس الكتمان', () {
      String? nameError;
      expect(
        FieldErrors.apply(
          failure: _failure(<String, String>{'name': '   '}),
          formKey: _key(),
          sinks: <String, ValueSetter<String?>>{
            'name': (String? m) => nameError = m,
          },
        ),
        isFalse,
      );
      expect(nameError, isNull);
    });
  });

  group('على نموذجٍ حيّ — هل يرى المستخدم الخطأ فعلاً؟', () {
    /// نموذجٌ بحقلٍ واحد، ومُتحقِّقه يعيد الرسالة المعلّقة كما في التوثيق.
    Future<void> pumpForm(
      WidgetTester tester,
      GlobalKey<FormState> formKey,
      String? Function() error,
    ) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: TextFormField(validator: (String? _) => error()),
          ),
        ),
      ),
    );

    testWidgets('apply يُعيد التحقّق فيظهر النصّ على الحقل', (
      WidgetTester tester,
    ) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      String? nameError;
      await pumpForm(tester, formKey, () => nameError);

      expect(find.text('الاسم مستعمل'), findsNothing);

      FieldErrors.apply(
        failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
        formKey: formKey,
        sinks: <String, ValueSetter<String?>>{
          'name': (String? m) => nameError = m,
        },
      );
      await tester.pump();

      expect(find.text('الاسم مستعمل'), findsOneWidget);
    });

    testWidgets('clear ثمّ تحقّقٌ يدويّ يرفع النصّ عن الحقل', (
      WidgetTester tester,
    ) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      String? nameError;
      await pumpForm(tester, formKey, () => nameError);

      final Map<String, ValueSetter<String?>> sinks =
          <String, ValueSetter<String?>>{'name': (String? m) => nameError = m};
      FieldErrors.apply(
        failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
        formKey: formKey,
        sinks: sinks,
      );
      await tester.pump();
      expect(find.text('الاسم مستعمل'), findsOneWidget);

      // `clear` لا تلمس النموذج — الإرسال التالي هو من يُعيد التحقّق.
      FieldErrors.clear(sinks);
      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('الاسم مستعمل'), findsNothing);
    });

    testWidgets('حقولٌ مجهولة بعد خطأٍ معروض ترفع النصّ القديم عن الشاشة', (
      WidgetTester tester,
    ) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      String? nameError;
      await pumpForm(tester, formKey, () => nameError);

      final Map<String, ValueSetter<String?>> sinks =
          <String, ValueSetter<String?>>{'name': (String? m) => nameError = m};
      FieldErrors.apply(
        failure: _failure(<String, String>{'name': 'الاسم مستعمل'}),
        formKey: formKey,
        sinks: sinks,
      );
      await tester.pump();
      expect(find.text('الاسم مستعمل'), findsOneWidget);

      // ردٌّ ثانٍ بحقلٍ لا يخصّ النموذج: المتغيّر يُمسح فعلاً…
      FieldErrors.apply(
        failure: _failure(<String, String>{'captcha': 'تحقّقٌ فاشل'}),
        formKey: formKey,
        sinks: sinks,
      );
      await tester.pump();
      expect(nameError, isNull);

      // …ويُعاد التحقّق ولو لم تقع مطابقة، فيرتفع النصّ المرسوم عن الحقل:
      // لا يبقى خطأٌ معروضاً على حقلٍ لم يعد الخادم يشتكي منه.
      expect(find.text('الاسم مستعمل'), findsNothing);
    });
  });
}
