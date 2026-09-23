// قراءةُ جسم الخطأ القادم من الخادم: [Failure.fromJson] و[FieldError.fromJson].
// الاستيراد من البرميل وحده مقصود: هو ما يملكه المستهلك، وهو يُثبت أنّ
// `Failure` و`FieldError` مُصدَّران فعلاً.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// النصّ الاحتياطي كما تُنتجه المكتبة فعلاً. تُقارن به بقيّةُ الاختبارات بدل
/// نسخِ حرفيّته، فيبقى موضعُ تعريفه وحده مرجعاً — وترميزُه محروسٌ في آخر مجموعة.
final String _fallback = const Failure(code: 0).displayMessage;

/// اختصارٌ للحالة الغالبة: خطأ عميلٍ برمز 400.
Failure _f(Map<String, dynamic> json, {int code = 400}) =>
    Failure.fromJson(code, json);

/// عنصر `fields` واحد — يختصر ضجيج الأقواس في كلّ اختبار.
Map<String, dynamic> _entry(Object? field, Object? message) =>
    <String, dynamic>{'field': field, 'message': message};

void main() {
  group('مفاتيح الرسالة — كلُّ مفتاحٍ على حدة', () {
    test('message وحده يُقرأ', () {
      expect(_f(<String, dynamic>{'message': 'رسالةٌ من message'}).message,
          'رسالةٌ من message');
    });

    test('error وحده يُقرأ', () {
      expect(_f(<String, dynamic>{'error': 'رسالةٌ من error'}).message,
          'رسالةٌ من error');
    });

    test('details وحده يُقرأ', () {
      expect(_f(<String, dynamic>{'details': 'رسالةٌ من details'}).message,
          'رسالةٌ من details');
    });

    test('detail وحده يُقرأ', () {
      expect(_f(<String, dynamic>{'detail': 'رسالةٌ من detail'}).message,
          'رسالةٌ من detail');
    });

    test('errors وحده يُقرأ', () {
      expect(_f(<String, dynamic>{'errors': 'رسالةٌ من errors'}).message,
          'رسالةٌ من errors');
    });

    test('مفتاحٌ لا تعرفه المكتبة لا يُقرأ', () {
      // `non_field_errors` و`title` ليسا في قائمة المفاتيح، فالرسالة تبقى null.
      final Failure f = _f(<String, dynamic>{
        'non_field_errors': 'لن تُقرأ',
        'title': 'ولا هذه',
      });
      expect(f.message, isNull);
      expect(f.displayMessage, _fallback);
    });
  });

  group('ترتيب الأولوية بين المفاتيح', () {
    test('message يسبق ما بعده جميعاً', () {
      final Failure f = _f(<String, dynamic>{
        'errors': 'خامسة',
        'detail': 'رابعة',
        'details': 'ثالثة',
        'error': 'ثانية',
        'message': 'أولى',
      });
      expect(f.message, 'أولى');
    });

    test('error يسبق details وdetail وerrors', () {
      final Failure f = _f(<String, dynamic>{
        'errors': 'خامسة',
        'detail': 'رابعة',
        'details': 'ثالثة',
        'error': 'ثانية',
      });
      expect(f.message, 'ثانية');
    });

    test('details يسبق detail (الجمع قبل المفرد)', () {
      final Failure f = _f(<String, dynamic>{
        'detail': 'رابعة',
        'details': 'ثالثة',
      });
      expect(f.message, 'ثالثة');
    });

    test('detail يسبق errors', () {
      final Failure f = _f(<String, dynamic>{
        'errors': 'خامسة',
        'detail': 'رابعة',
      });
      expect(f.message, 'رابعة');
    });

    test('ترتيب المفاتيح لا يتبع ترتيب ورودها في الخريطة', () {
      // `errors` أوّل الخريطة لكنّه آخر الأولوية.
      final Failure f = _f(<String, dynamic>{
        'errors': 'الأخيرة أولويةً',
        'message': 'الأولى أولويةً',
      });
      expect(f.message, 'الأولى أولويةً');
    });

    test('مفتاحٌ قيمته نصٌّ فارغ يُتخطّى إلى التالي', () {
      final Failure f = _f(<String, dynamic>{
        'message': '',
        'detail': 'الرسالة الحقيقية',
      });
      expect(f.message, 'الرسالة الحقيقية');
    });

    test('مفتاحٌ قيمته null يُتخطّى إلى التالي', () {
      final Failure f = _f(<String, dynamic>{
        'message': null,
        'error': null,
        'detail': 'الرسالة الحقيقية',
      });
      expect(f.message, 'الرسالة الحقيقية');
    });

    test('المفاتيح كلُّها فارغة أو null → لا رسالة', () {
      final Failure f = _f(<String, dynamic>{
        'message': '',
        'error': null,
        'details': '',
        'detail': null,
        'errors': '',
      });
      expect(f.message, isNull);
      expect(f.displayMessage, _fallback);
    });
  });

  group('قيمةٌ غير نصّية في مفاتيح الرسالة', () {
    test('رقمٌ في message لا يُقرأ ولا يمنع قراءة detail', () {
      // الانحدار الموثّق: `isNotEmpty` على رقمٍ كانت ترمي فتُهدَر بقيّة المفاتيح.
      final Failure f = _f(<String, dynamic>{
        'message': 400,
        'detail': 'غير مصرّح لك',
      });
      expect(f.message, 'غير مصرّح لك');
    });

    test('خريطةٌ في message لا تمنع قراءة errors', () {
      final Failure f = _f(<String, dynamic>{
        'message': <String, dynamic>{'code': 'invalid'},
        'errors': 'الطلب غير صالح',
      });
      expect(f.message, 'الطلب غير صالح');
    });

    test('قائمةٌ في message لا تمنع قراءة detail', () {
      final Failure f = _f(<String, dynamic>{
        'message': <String>['أ', 'ب'],
        'detail': 'الرسالة الصالحة',
      });
      expect(f.message, 'الرسالة الصالحة');
    });

    test('bool في message لا يمنع قراءة detail', () {
      final Failure f = _f(<String, dynamic>{
        'message': false,
        'detail': 'الرسالة الصالحة',
      });
      expect(f.message, 'الرسالة الصالحة');
    });

    test('المفاتيح كلُّها غير نصّية → لا رسالة ولا رمي', () {
      final Failure f = _f(<String, dynamic>{
        'message': 0,
        'error': <dynamic>[],
        'details': <String, dynamic>{},
        'detail': true,
        'errors': 3.14,
      });
      expect(f.message, isNull);
      expect(f.displayMessage, _fallback);
    });

    test('قائمةُ نصوصٍ في message تُقرأ كما تُقرأ في FieldError', () {
      // الخادم يُرسل الرسالة قائمةً كثيراً (DRF)، و[FieldError.fromJson] في
      // الملفّ نفسه يعالج هذا الشكل صراحةً — فإهمالها كان يُري المستخدم
      // «حدث خطأ غير متوقع» ورسالةُ الخادم في يده.
      // عنصرٌ واحد كي لا يفترض الاختبار صيغة الوصل.
      final Failure f = _f(<String, dynamic>{
        'message': <String>['رقم الجوال مستعمل'],
      });
      expect(f.message, 'رقم الجوال مستعمل');
    });

    test('رسالةٌ بيضاء (مسافاتٌ فقط) لا تُقبل ولا تحجب detail الصالح', () {
      // انحدارٌ موثّق: `isNotEmpty` تصدُق على المسافات، فكانت الرسالة البيضاء
      // تُقبل فتُعرض فراغاً وتحجب `detail` الصالحة بعدها.
      final Failure f = _f(<String, dynamic>{
        'message': '   ',
        'detail': 'الحساب موقوف',
      });
      expect(f.message, 'الحساب موقوف');
    });
  });

  group('الحالات الحدّية للرسالة', () {
    test('خريطةٌ فارغة → لا رسالة ولا حقول', () {
      final Failure f = _f(<String, dynamic>{});
      expect(f.message, isNull);
      expect(f.displayMessage, _fallback);
      expect(f.fields, isEmpty);
      expect(f.hasFields, isFalse);
    });

    test('رسالةٌ عربية طويلة جدّاً تُحفظ حرفياً', () {
      final String long = 'حدث خطأ أثناء معالجة طلبك. ' * 500;
      expect(_f(<String, dynamic>{'message': long}).message, long);
      expect(_f(<String, dynamic>{'message': long}).displayMessage, long);
    });

    test('رسالةٌ بحرفٍ واحد تُقبل', () {
      expect(_f(<String, dynamic>{'message': 'لا'}).message, 'لا');
    });

    test('رسالةٌ فيها أرقامٌ عربية وعلامات ورموز تُحفظ كما هي', () {
      const String m = 'المبلغ ١٢٣٤٫٥٠ ر.س — غير كافٍ ⚠';
      expect(_f(<String, dynamic>{'message': m}).message, m);
    });

    test('displayMessage يعيد الرسالة متى وُجدت', () {
      expect(_f(<String, dynamic>{'detail': 'موجود'}).displayMessage, 'موجود');
    });
  });

  group('الرمز code', () {
    test('الرمز يُنقل كما هو', () {
      expect(_f(<String, dynamic>{}, code: 422).code, 422);
    });

    test('الصفر رمزٌ مقبول (لا استجابة)', () {
      final Failure f = _f(<String, dynamic>{'detail': 'لا اتصال'}, code: 0);
      expect(f.code, 0);
      expect(f.isTooManyRequests, isFalse);
    });

    test('رمزٌ سالب يُنقل كما هو بلا حراسة', () {
      expect(_f(<String, dynamic>{}, code: -1).code, -1);
    });

    test('429 يرفع isTooManyRequests، وretryAfter يبقى null', () {
      // `retryAfter` من ترويسة Retry-After لا من الجسم، فلا يملؤه fromJson.
      final Failure f = _f(<String, dynamic>{'detail': 'أبطئ'}, code: 429);
      expect(f.isTooManyRequests, isTrue);
      expect(f.retryAfter, isNull);
    });

    test('رمزٌ آخر لا يرفع isTooManyRequests', () {
      expect(_f(<String, dynamic>{}, code: 428).isTooManyRequests, isFalse);
    });
  });

  group('fields — أشكالٌ صحيحة', () {
    test('قائمةٌ سليمة من عنصرين تُقرأ كاملةً', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          _entry('phone', 'رقم غير صالح'),
          _entry('email', 'بريدٌ مستعمل'),
        ],
      });
      expect(f.fields.length, 2);
      expect(f.hasFields, isTrue);
      expect(f.fields.first.field, 'phone');
      expect(f.fields.first.message, 'رقم غير صالح');
      expect(f.fields.last.field, 'email');
      expect(f.fields.last.message, 'بريدٌ مستعمل');
    });

    test('قائمةٌ فارغة → لا حقول', () {
      final Failure f = _f(<String, dynamic>{'fields': <dynamic>[]});
      expect(f.fields, isEmpty);
      expect(f.hasFields, isFalse);
    });

    test('رسالة الحقل قائمةً تُوصل بفاصلةٍ عربية', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          _entry('phone', <String>['مطلوب', 'قصير جدّاً']),
        ],
      });
      expect(f.fieldError('phone'), 'مطلوب، قصير جدّاً');
    });

    test('قائمةُ رسائلٍ فيها null تُسقط الفراغات وحدها', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          _entry('phone', <dynamic>[null, 'مطلوب', null]),
        ],
      });
      expect(f.fieldError('phone'), 'مطلوب');
    });

    test('اسم الحقل رقماً يصير نصّاً', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[_entry(5, 'خطأ')],
      });
      expect(f.fields.single.field, '5');
      expect(f.fieldError('5'), 'خطأ');
    });

    test('الرسالة قيمةً غير نصّية تصير نصّاً', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[_entry('age', 18)],
      });
      expect(f.fieldError('age'), '18');
    });

    test('أسماء الحقول ورسائلها بالعربية تُحفظ كما هي', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[_entry('الاسم', 'الاسمُ مطلوب')],
      });
      expect(f.fieldError('الاسم'), 'الاسمُ مطلوب');
    });

    test('قائمةٌ طويلة (مئة حقل) تُقرأ كاملةً', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          for (int i = 0; i < 100; i++) _entry('f$i', 'خطأ $i'),
        ],
      });
      expect(f.fields.length, 100);
      expect(f.fieldError('f99'), 'خطأ 99');
    });
  });

  group('fields — أشكالٌ خاطئة', () {
    test('fields غائبة → لا حقول ولا رمي', () {
      expect(_f(<String, dynamic>{'detail': 'خطأ'}).fields, isEmpty);
    });

    test('fields = null → لا حقول', () {
      expect(_f(<String, dynamic>{'fields': null}).fields, isEmpty);
    });

    test('fields نصّاً → لا حقول', () {
      expect(_f(<String, dynamic>{'fields': 'phone'}).fields, isEmpty);
    });

    test('fields خريطةً → لا حقول', () {
      // شكلُ DRF المعتاد `{"phone": ["مطلوب"]}` غير مدعوم هنا.
      final Failure f = _f(<String, dynamic>{
        'fields': <String, dynamic>{'phone': 'مطلوب'},
      });
      expect(f.fields, isEmpty);
      expect(f.hasFields, isFalse);
    });

    test('fields رقماً → لا حقول', () {
      expect(_f(<String, dynamic>{'fields': 3}).fields, isEmpty);
    });

    test('حقلٌ بلا اسم يُسقط (اسمٌ فارغ لا يطابقه fieldError أبداً)', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[_entry('', 'رسالةٌ يتيمة')],
      });
      expect(f.fields, isEmpty);
      expect(f.hasFields, isFalse);
    });

    test('اسم الحقل null → يُسقط', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[_entry(null, 'رسالةٌ يتيمة')],
      });
      expect(f.fields, isEmpty);
    });

    test('مفتاح field مفقودٌ بالكلّية → يُسقط', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          <String, dynamic>{'message': 'رسالةٌ يتيمة'},
        ],
      });
      expect(f.fields, isEmpty);
    });

    test('العناصر كلُّها فاسدة → لا حقول، والرسالة تبقى مقروءة', () {
      final Failure f = _f(<String, dynamic>{
        'detail': 'الطلب غير صالح',
        'fields': <dynamic>[null, 'نصّ', 7, <dynamic>[]],
      });
      expect(f.fields, isEmpty);
      expect(f.message, 'الطلب غير صالح');
    });
  });

  group('عنصرٌ فاسد وسط قائمةٍ صحيحة', () {
    test('null وسط القائمة لا يُسقط الصحيحين', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          _entry('phone', 'رقم غير صالح'),
          null,
          _entry('email', 'بريدٌ مستعمل'),
        ],
      });
      expect(f.fields.length, 2);
      expect(f.fieldError('phone'), 'رقم غير صالح');
      expect(f.fieldError('email'), 'بريدٌ مستعمل');
    });

    test('نصٌّ ورقمٌ وقائمةٌ وسط القائمة تُتخطّى وحدها', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          'phone',
          _entry('phone', 'رقم غير صالح'),
          42,
          <dynamic>['email'],
          _entry('email', 'بريدٌ مستعمل'),
        ],
      });
      expect(f.fields.length, 2);
      expect(f.fieldError('email'), 'بريدٌ مستعمل');
    });

    test('عنصرٌ بلا اسمٍ وسط القائمة يُسقط وحده', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          _entry('phone', 'رقم غير صالح'),
          <String, dynamic>{'message': 'بلا اسم'},
          _entry('email', 'بريدٌ مستعمل'),
        ],
      });
      expect(f.fields.length, 2);
      expect(f.fieldError('phone'), 'رقم غير صالح');
      expect(f.fieldError('email'), 'بريدٌ مستعمل');
    });

    test('الفساد في الرسالة لا في الاسم: الحقل يبقى برسالةٍ منصوصة', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          _entry('phone', <String, dynamic>{'code': 'invalid'}),
          _entry('email', 'بريدٌ مستعمل'),
        ],
      });
      expect(f.fields.length, 2);
      expect(f.fieldError('phone'), '{code: invalid}');
    });

    test('عنصرٌ بخريطةٍ غير مُنمَّطة يُتخطّى', () {
      // توثيقٌ لا مباركة: `jsonDecode` يُنتج `Map<String, dynamic>` دائماً،
      // فهذا الشكل لا يأتي من الخادم — لكنّه يأتي من بناءٍ يدويّ.
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          <dynamic, dynamic>{'field': 'phone', 'message': 'رقم غير صالح'},
          _entry('email', 'بريدٌ مستعمل'),
        ],
      });
      expect(f.fields.length, 1);
      expect(f.fieldError('email'), 'بريدٌ مستعمل');
      expect(f.fieldError('phone'), isNull);
    });

    test('الرسالة والحقول تُقرآن معاً في الاستجابة ذاتها', () {
      final Failure f = _f(<String, dynamic>{
        'message': 'تحقّق من البيانات',
        'fields': <dynamic>[
          _entry('phone', 'رقم غير صالح'),
          null,
        ],
      }, code: 422);
      expect(f.code, 422);
      expect(f.message, 'تحقّق من البيانات');
      expect(f.fields.single.field, 'phone');
    });
  });

  group('FieldError.fromJson مباشرةً', () {
    test('خريطةٌ فارغة → اسمٌ ورسالةٌ فارغان بلا رمي', () {
      final FieldError e = FieldError.fromJson(<String, dynamic>{});
      expect(e.field, '');
      expect(e.message, '');
    });

    test('message مفقود → رسالةٌ فارغة', () {
      final FieldError e = FieldError.fromJson(<String, dynamic>{
        'field': 'phone',
      });
      expect(e.field, 'phone');
      expect(e.message, '');
    });

    test('message = null → رسالةٌ فارغة', () {
      expect(FieldError.fromJson(_entry('phone', null)).message, '');
    });

    test('message قائمةً فارغة → رسالةٌ فارغة', () {
      expect(FieldError.fromJson(_entry('phone', <dynamic>[])).message, '');
    });

    test('message قائمةً من عنصرٍ واحد → بلا فاصلة', () {
      expect(
        FieldError.fromJson(_entry('phone', <String>['مطلوب'])).message,
        'مطلوب',
      );
    });

    test('message قائمةً من ثلاثة → فاصلتان عربيتان', () {
      expect(
        FieldError.fromJson(_entry('phone', <String>['أ', 'ب', 'ج'])).message,
        'أ، ب، ج',
      );
    });

    test('message قائمةً فيها أرقام → تُنصَّص', () {
      expect(
        FieldError.fromJson(_entry('age', <dynamic>[18, 'سنة'])).message,
        '18، سنة',
      );
    });

    test('message قائمةً كلُّها null → رسالةٌ فارغة', () {
      expect(
        FieldError.fromJson(_entry('phone', <dynamic>[null, null])).message,
        '',
      );
    });

    test('اسمٌ ورسالةٌ عربيّان يُحفظان حرفياً', () {
      final FieldError e = FieldError.fromJson(
        _entry('رقم_الجوال', 'أدخل رقماً سعودياً'),
      );
      expect(e.field, 'رقم_الجوال');
      expect(e.message, 'أدخل رقماً سعودياً');
    });

    test('رسالةٌ طويلة جدّاً تُحفظ كاملةً', () {
      final String long = 'حرفٌ ' * 2000;
      expect(FieldError.fromJson(_entry('x', long)).message, long);
    });

    test('bool في الاسم والرسالة يصير نصّاً', () {
      final FieldError e = FieldError.fromJson(_entry(true, false));
      expect(e.field, 'true');
      expect(e.message, 'false');
    });
  });

  group('fieldError()', () {
    Failure sample() => _f(<String, dynamic>{
      'fields': <dynamic>[
        _entry('phone', 'رقم غير صالح'),
        _entry('email', 'بريدٌ مستعمل'),
      ],
    });

    test('يعيد رسالة الحقل المطابق', () {
      expect(sample().fieldError('email'), 'بريدٌ مستعمل');
    });

    test('يعيد null لحقلٍ غير موجود', () {
      expect(sample().fieldError('name'), isNull);
    });

    test('المطابقة حسّاسةٌ لحالة الأحرف', () {
      expect(sample().fieldError('Phone'), isNull);
    });

    test('لا مطابقة بالجزء: اسمٌ مطابقٌ تمامًا أو لا شيء', () {
      expect(sample().fieldError('phon'), isNull);
      expect(sample().fieldError('phone '), isNull);
    });

    test('سلسلةٌ فارغة تعيد null (الأسماء الفارغة مُسقطة أصلاً)', () {
      expect(sample().fieldError(''), isNull);
      final Failure withBlank = _f(<String, dynamic>{
        'fields': <dynamic>[_entry('', 'يتيمة')],
      });
      expect(withBlank.fieldError(''), isNull);
    });

    test('الأوّل يفوز عند تكرار الاسم', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          _entry('phone', 'الأولى'),
          _entry('phone', 'الثانية'),
        ],
      });
      expect(f.fields.length, 2);
      expect(f.fieldError('phone'), 'الأولى');
    });

    test('فشلٌ بلا حقول يعيد null دائماً', () {
      final Failure f = _f(<String, dynamic>{'detail': 'خطأ عام'});
      expect(f.hasFields, isFalse);
      expect(f.fieldError('phone'), isNull);
    });

    test('اسمٌ عربيّ يُطابَق', () {
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[_entry('الاسم', 'مطلوب')],
      });
      expect(f.fieldError('الاسم'), 'مطلوب');
    });

    test('حقلٌ بلا رسالة لا يعيد رسالةً فارغة', () {
      // `FieldErrors.apply` يحسب كلّ قيمةٍ غير null «توجيهاً ناجحاً» فيكتم
      // الرسالة العامّة، والمُتحقِّق يعرض نصّاً فارغاً: يضيع الخطأ صامتاً —
      // وهو بعينه ما كُتب `FieldErrors` لمنعه. وfromJson يُسقط الاسم الفارغ
      // لأنّه «ضجيجٌ لا فائدة فيه»، والرسالة الفارغة مثله وأضرّ.
      final Failure f = _f(<String, dynamic>{
        'fields': <dynamic>[
          <String, dynamic>{'field': 'phone'},
        ],
      });
      expect(f.fieldError('phone'), isNull);
      expect(f.fields, isEmpty);
    });
  });

  group('النصّ الاحتياطي displayMessage', () {
    test('يُستعمل كلّما غابت الرسالة، ولا يُستعمل متى حضرت', () {
      expect(_f(<String, dynamic>{}).displayMessage, _fallback);
      expect(_f(<String, dynamic>{'detail': 'حاضرة'}).displayMessage, 'حاضرة');
      expect(_fallback, isNotEmpty);
    });

    test('مكتوبٌ بالهمزة المركّبة كسائر المكتبة', () {
      // انحدارٌ موثّق: «خطأ» كانت في هذا الموضع وحده من المكتبة مكتوبةً
      // متحلّلةً (ا U+0627 + همزة علوية U+0654) بدل أ (U+0623). النصّان
      // متطابقان في العين مختلفان في الذاكرة: مقارنةُ مستهلكٍ بالنصّ المكتوب
      // طبيعياً تفشل، و`grep 'خطأ'` لا يجد السطر.
      expect(const Failure(code: 0).displayMessage, 'حدث خطأ غير متوقع');
      expect(_fallback.contains('\u0654'), isFalse);
    });
  });
}
