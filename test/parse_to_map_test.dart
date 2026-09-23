import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار شامل لـ [parseToMap] — المحوّل الخام إلى `Map<String, dynamic>`.
///
/// هذه الدالّة كانت تُتلف الحمولات صامتةً (تُرجع `{}` أو تغيّر أنواع القيم بلا
/// خطأ)، فالتركيز هنا على **عدم الإتلاف**: أن يصل ما دخل كما هو نوعاً وقيمةً،
/// وأن يكون الفشل محصوراً في الحقل لا في الخريطة كلّها.
void main() {
  group('JSON صحيح — المسار الخام بلا أيّ تنظيف', () {
    test('خريطة بسيطة: النصّ والعدد والمنطقيّ تحفظ أنواعها', () {
      final result = parseToMap('{"name":"Ali","age":30,"active":true}');
      expect(result['name'], 'Ali');
      expect(result['age'], 30);
      expect(result['age'], isA<int>());
      expect(result['active'], isTrue);
      expect(result['active'], isA<bool>());
    });

    test('النوع المُعاد Map<String, dynamic> دائماً', () {
      expect(parseToMap('{"a":1}'), isA<Map<String, dynamic>>());
      expect(parseToMap(null), isA<Map<String, dynamic>>());
    });

    test('خريطة فارغة تبقى فارغة لا null', () {
      expect(parseToMap('{}'), isEmpty);
      expect(parseToMap('{"a":{}}')['a'], isEmpty);
    });

    test('مسافات وأسطر جديدة حول JSON لا تمنع فكّه', () {
      expect(parseToMap('   {"a":1}   ')['a'], 1);
      expect(parseToMap('{\n "a" : 1 \n}')['a'], 1);
    });

    test('تداخل عميق (٣٠ مستوى) يُفكّ تكراريّاً', () {
      final deep = '${'{"a":' * 30}1${'}' * 30}';
      dynamic node = parseToMap(deep);
      for (var i = 0; i < 29; i++) {
        node = (node as Map)['a'];
        expect(node, isA<Map>());
      }
      expect((node as Map)['a'], 1);
    });

    test('قائمة داخل الخريطة تُعالَج عنصراً عنصراً', () {
      final result = parseToMap('{"items":[{"ok":"true"},{"ok":"False"}]}');
      final items = result['items'] as List;
      expect(items, hasLength(2));
      expect((items[0] as Map)['ok'], isTrue);
      expect((items[1] as Map)['ok'], isFalse);
    });

    test('قائمة داخل قائمة تُعالَج إلى العمق', () {
      final result = parseToMap('{"a":[[{"b":"True"}]]}');
      final inner = ((result['a'] as List)[0] as List)[0] as Map;
      expect(inner['b'], isTrue);
    });

    test('مفتاح فارغ وقيمة فارغة يُحفظان لا يُحذفان', () {
      expect(parseToMap('{"":"v"}')[''], 'v');
      expect(parseToMap('{"a":""}')['a'], '');
      expect(parseToMap('{"a":" "}')['a'], ' ');
    });

    test('مفتاح مكرّر: الأخير يفوز (سلوك jsonDecode)', () {
      expect(parseToMap('{"a":1,"a":2}')['a'], 2);
    });

    test('خريطة جاهزة (لا نصّ) تمرّ بالمعالجة التكراريّة', () {
      final result = parseToMap({
        'a': 'True',
        'b': 1,
        'c': [
          {'d': 'False'},
        ],
      });
      expect(result['a'], isTrue);
      expect(result['b'], 1);
      expect(((result['c'] as List)[0] as Map)['d'], isFalse);
    });

    test('مفاتيح غير نصّية في خريطة جاهزة تُحوَّل إلى نصّ', () {
      final result = parseToMap({1: 'a', true: 'b'});
      expect(result['1'], 'a');
      expect(result['true'], 'b');
    });

    test('قيمة null تبقى null ولا يسقط المفتاح', () {
      final result = parseToMap('{"x": null}');
      expect(result.containsKey('x'), isTrue);
      expect(result['x'], isNull);
    });
  });

  group('الاقتباس المفرد وحرفيّات Python/Dart', () {
    test("قاموس Python: {'name': 'Ali', 'active': True}", () {
      final result = parseToMap("{'name': 'Ali', 'active': True}");
      expect(result['name'], 'Ali');
      expect(result['active'], isTrue);
      expect(result['active'], isA<bool>());
    });

    test('قاموس Python بقائمة وخريطة متداخلة', () {
      final result = parseToMap("{'id': 5, 'tags': ['a', 'b'], 'meta': {'x': 1}}");
      expect(result['id'], 5);
      expect(result['tags'], ['a', 'b']);
      expect((result['meta'] as Map)['x'], 1);
    });

    test('صيغة toString غير المقتبسة: {id: 5, name: Ali Hassan, ok: true}', () {
      final result = parseToMap('{id: 5, name: Ali Hassan, ok: true}');
      expect(result['id'], 5);
      expect(result['name'], 'Ali Hassan');
      expect(result['ok'], isTrue);
    });

    test('قيمة غير مقتبسة فيها نقطتان (وقت) لا تُقصّ', () {
      expect(parseToMap('{t: 12:30:00}')['t'], '12:30:00');
      expect(parseToMap('{date: 2024-01-05}')['date'], '2024-01-05');
    });

    test('رابط غير مقتبس يبقى كاملاً', () {
      expect(parseToMap('{url: https://a.b/c?d=1}')['url'], 'https://a.b/c?d=1');
    });

    test('خريطة متداخلة غير مقتبسة تُصلَح إلى العمق', () {
      final result = parseToMap('{a: {phone: 0501234567}}');
      expect((result['a'] as Map)['phone'], '0501234567');
    });
  });

  group('الأبوستروف داخل القيمة — الانحدار الذي كان يضيّع الحمولة كاملةً', () {
    test("JSON صحيح فيه أبوستروف لا يمرّ على التنظيف الهدّام", () {
      final result = parseToMap('{"name":"O\'Brien","note":"it\'s fine"}');
      expect(result['name'], "O'Brien");
      expect(result['note'], "it's fine");
    });

    test('أبوستروف داخل قيمة مع حقول أخرى: لا يضيع أيّ حقل', () {
      final result = parseToMap('{"a":"it\'s","b":"x","c":3}');
      expect(result, hasLength(3));
      expect(result['a'], "it's");
      expect(result['b'], 'x');
      expect(result['c'], 3);
    });

    test('أبوستروف داخل JSON مُضمَّن كنصّ يبقى سليماً', () {
      final result = parseToMap('{"a":"{\\"b\\":\\"it\'s\\"}"}');
      expect((result['a'] as Map)['b'], "it's");
    });

    test('علامات تنصيص مهرَّبة داخل قيمة تبقى', () {
      expect(parseToMap('{"a":"say \\"hi\\""}')['a'], 'say "hi"');
    });
  });

  group('True/False كسلسلة فرعية — لا استبدال أعمى', () {
    test('قيمة نصّية «TrueVision» لا تصير منطقيّة', () {
      expect(parseToMap('{"product":"TrueVision"}')['product'], 'TrueVision');
      expect(parseToMap('{product: TrueVision, x: 1}')['product'], 'TrueVision');
    });

    test('مفتاح isTrueOwner يبقى بحاله', () {
      final result = parseToMap('{"isTrueOwner": true}');
      expect(result.containsKey('isTrueOwner'), isTrue);
      expect(result['isTrueOwner'], isTrue);
    });

    test('مفتاح غير مقتبس isTrueOwner لا يُشوَّه اسمه', () {
      final result = parseToMap('{isTrueOwner: True}');
      expect(result.keys.single, 'isTrueOwner');
      expect(result['isTrueOwner'], isTrue);
    });

    test('«True» داخل جملة في JSON صحيح تبقى بحالة أحرفها', () {
      expect(parseToMap('{"msg":"That is True story"}')['msg'],
          'That is True story');
    });

    test('«True» داخل جملة مقتبسة اقتباساً مفرداً تبقى بحالة أحرفها', () {
      expect(parseToMap("{'msg': 'True story'}")['msg'], 'True story');
    });

    test('«TrueX» داخل قائمة نصّية لا يتحوّل', () {
      final list = parseToMap('{"a":["true","False","TrueX"]}')['a'] as List;
      expect(list, [true, false, 'TrueX']);
    });

    test('True/False صريحتان في قائمة Python تصيران منطقيّتين', () {
      expect(parseToMap('{"a": [True, False]}')['a'], [true, false]);
    });
  });

  group('الأرقام — الصفر البادئ لا يُبتلع', () {
    test('جوّال بصفر بادئ في JSON صحيح يبقى نصّاً', () {
      final result = parseToMap('{"phone":"0501234567"}');
      expect(result['phone'], '0501234567');
      expect(result['phone'], isA<String>());
    });

    test('جوّال بصفر بادئ غير مقتبس لا يُفهَم عدداً', () {
      final result = parseToMap('{phone: 0501234567}');
      expect(result['phone'], '0501234567');
      expect(result['phone'], isA<String>());
    });

    test('جوّال بصفر بادئ باقتباس مفرد يبقى نصّاً', () {
      expect(parseToMap("{'phone': '0501234567'}")['phone'], '0501234567');
    });

    test('«00» و«+5» غير المقتبسة ليست أرقام JSON فتبقى نصّاً', () {
      expect(parseToMap('{x: 00}')['x'], '00');
      expect(parseToMap('{x: +5}')['x'], '+5');
    });

    test('الصفر والسالب والعشريّ تبقى أعداداً', () {
      final result = parseToMap('{"z":0,"n":-5,"d":-0.5}');
      expect(result['z'], 0);
      expect(result['z'], isA<int>());
      expect(result['n'], -5);
      expect(result['d'], -0.5);
    });

    test('أعداد غير مقتبسة (سالب وعشريّ وأسّي) تُقرأ أعداداً', () {
      final result = parseToMap('{a: -5, b: 0.5, c: 1e3}');
      expect(result['a'], -5);
      expect(result['b'], 0.5);
      expect(result['c'], 1000.0);
    });

    test('«0» نصّاً يبقى نصّاً لا صفراً', () {
      final result = parseToMap('{"x":"0"}');
      expect(result['x'], '0');
      expect(result['x'], isA<String>());
    });
  });

  group('Infinity و NaN — لا تُسقط الخريطة كلّها', () {
    test('Infinity حرفيّة (ليست JSON) تُحفظ نصّاً ولا تضيع بقيّة الحقول', () {
      final result = parseToMap('{x: Infinity, y: 5}');
      expect(result['x'], 'Infinity');
      expect(result['x'], isA<String>());
      expect(result['y'], 5);
    });

    test('NaN حرفيّة تُحفظ نصّاً والخريطة تبقى', () {
      final result = parseToMap('{"x": NaN, "y": 1}');
      expect(result['x'], 'NaN');
      expect(result['y'], 1);
    });

    test('-Infinity حرفيّة تُحفظ نصّاً', () {
      expect(parseToMap('{x: -Infinity}')['x'], '-Infinity');
    });

    test('«Infinity» و«NaN» نصّاً مقتبساً تبقيان نصّاً', () {
      expect(parseToMap('{"x":"Infinity"}')['x'], 'Infinity');
      expect(parseToMap('{"x":"NaN"}')['x'], 'NaN');
    });

    test('عدد JSON يفيض إلى ما لا نهاية يبقى double', () {
      final x = parseToMap('{"x": 1e400}')['x'];
      expect(x, isA<double>());
      expect((x as double).isInfinite, isTrue);
    });
  });

  group('الفارغ وnull والمُدخل الذي ليس خريطة', () {
    test('نصّ فارغ يُرجع خريطة فارغة', () {
      expect(parseToMap(''), isEmpty);
    });

    test('نصّ مسافات فقط يُرجع خريطة فارغة', () {
      expect(parseToMap('   '), isEmpty);
    });

    test('null يُرجع خريطة فارغة', () {
      expect(parseToMap(null), isEmpty);
    });

    test('قائمة JSON (ليست خريطة) تُرجع خريطة فارغة', () {
      expect(parseToMap('[1,2,3]'), isEmpty);
      expect(parseToMap('["a","b"]'), isEmpty);
    });

    test('عدد أو منطقيّ أو نصّ عاديّ يُرجع خريطة فارغة', () {
      expect(parseToMap(42), isEmpty);
      expect(parseToMap(true), isEmpty);
      expect(parseToMap(3.5), isEmpty);
      expect(parseToMap('hello'), isEmpty);
    });

    test('قائمة Dart جاهزة (ليست خريطة) تُرجع خريطة فارغة', () {
      expect(parseToMap([1, 2, 3]), isEmpty);
    });

    test('JSON مشوّه (غير مغلق أو بفاصلة ذيليّة) يُرجع فارغاً لا يرمي', () {
      expect(parseToMap('{"a":1'), isEmpty);
      expect(parseToMap('{"a":1,}'), isEmpty);
      expect(parseToMap('{"a":1} extra'), isEmpty);
      expect(parseToMap('not json {'), isEmpty);
    });
  });

  group('coerceBooleanStrings — البوّابة تُحترم', () {
    test('افتراضاً: «true»/«False» نصّاً تصير منطقيّة', () {
      expect(parseToMap('{"a":"true","b":"False"}')['a'], isTrue);
      expect(parseToMap('{"a":"true","b":"False"}')['b'], isFalse);
    });

    test('مع false: النصّ يبقى نصّاً بحالة أحرفه', () {
      final result =
          parseToMap('{"a":"true","b":"True"}', coerceBooleanStrings: false);
      expect(result['a'], 'true');
      expect(result['a'], isA<String>());
      expect(result['b'], 'True');
    });

    test('مع false: عناصر القوائم أيضاً تبقى نصّاً', () {
      final list = parseToMap('{"a":["true","False"]}',
          coerceBooleanStrings: false)['a'] as List;
      expect(list, ['true', 'False']);
    });

    test('مع false: المنطقيّ الحقيقي في JSON يبقى منطقيّاً', () {
      final result = parseToMap('{"a":true}', coerceBooleanStrings: false);
      expect(result['a'], isTrue);
      expect(result['a'], isA<bool>());
    });

    test('«null» نصّاً لا يتحوّل إلى null في الحالتين', () {
      expect(parseToMap('{"a":"null"}')['a'], 'null');
      expect(parseToMap('{"a":"null"}', coerceBooleanStrings: false)['a'],
          'null');
    });
  });

  group('النصّ الذي يحمل JSON بداخله', () {
    test('قيمة نصّية تحوي خريطة JSON تُفكّ تكراريّاً', () {
      final result = parseToMap('{"data":"{\\"k\\":\\"0501\\"}"}');
      expect((result['data'] as Map)['k'], '0501');
    });

    test('قيمة نصّية تحوي قائمة JSON تُفكّ', () {
      expect(parseToMap('{"a":"[1, 2]"}')['a'], [1, 2]);
    });

    test('نصّ يبدأ بقوس لكنّه ليس JSON يبقى نصّاً كما هو', () {
      expect(parseToMap('{"a":"{bad json"}')['a'], '{bad json');
      expect(parseToMap('{"a":"[not json"}')['a'], '[not json');
    });

    test('أقواس داخل جملة عاديّة لا تُفسَّر', () {
      expect(parseToMap('{"note":"use {a} here"}')['note'], 'use {a} here');
    });
  });

  group('العربية والمحارف الخاصّة', () {
    test('مفاتيح وقيم عربية في JSON صحيح', () {
      final result = parseToMap('{"اسم":"محمد أحمد","المدينة":"الرياض"}');
      expect(result['اسم'], 'محمد أحمد');
      expect(result['المدينة'], 'الرياض');
    });

    test('مفاتيح وقيم عربية باقتباس مفرد', () {
      final result = parseToMap("{'اسم': 'محمد', 'المدينة': 'جدة'}");
      expect(result['اسم'], 'محمد');
      expect(result['المدينة'], 'جدة');
    });

    test('قيمة عربية غير مقتبسة بمسافات تبقى كاملة', () {
      expect(parseToMap('{name: محمد بن عبدالله}')['name'], 'محمد بن عبدالله');
    });

    test('رموز تعبيريّة وهروب يونيكود تبقى سليمة', () {
      expect(parseToMap('{"a":"🎉 نجاح"}')['a'], '🎉 نجاح');
      expect(parseToMap('{"a":"\\u0645"}')['a'], 'م');
    });
  });

  group('الحمولات الطويلة وسقف الإصلاح (حارس الـ ANR)', () {
    test('JSON صحيح طويل جدّاً (٣٠ ألف حرف) يُفكّ كاملاً', () {
      final value = 'ب' * 30000;
      final result = parseToMap('{"a":"$value"}');
      expect(result['a'], value);
    });

    test('خريطة بألفي مفتاح تُفكّ كاملة', () {
      final buffer = StringBuffer('{');
      for (var i = 0; i < 2000; i++) {
        if (i > 0) buffer.write(',');
        buffer.write('"k$i":"v$i"');
      }
      buffer.write('}');
      final result = parseToMap(buffer.toString());
      expect(result, hasLength(2000));
      expect(result['k1999'], 'v1999');
    });

    test('نصّ مشوّه فوق السقف (١٦ك) يُرفض فوراً بلا تجميد', () {
      final huge = '{a: ${'x y ' * 6000}}';
      expect(huge.length, greaterThan(16 * 1024));
      final sw = Stopwatch()..start();
      expect(parseToMap(huge), isEmpty);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('نصّ مشوّه تحت السقف لا يسبّب تراجعاً تربيعيّاً', () {
      final almost = '{a: ${'x y ' * 4000}';
      expect(almost.length, lessThan(16 * 1024));
      final sw = Stopwatch()..start();
      parseToMap(almost);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('toString طويل قابل للإصلاح (٥٠٠ حقل) يُصلَح كاملاً', () {
      final buffer = StringBuffer('{');
      for (var i = 0; i < 500; i++) {
        if (i > 0) buffer.write(', ');
        buffer.write('k$i: value number $i');
      }
      buffer.write('}');
      final result = parseToMap(buffer.toString());
      expect(result, hasLength(500));
      expect(result['k499'], 'value number 499');
    });
  });

  group('عيوب أُصلحت — انحدارات مثبَّتة', () {
    test('قيمة نصّية تبدأ بـ «True» لا تُخفَّض حالة أحرفها', () {
      // ‏_pythonBoolean يشترط حدّ كلمة فقط، والمسافة حدّ كلمة — فـ«True story»
      // تصير «true story». الصواب: التحويل حين تكون الكلمة هي القيمة كلّها
      // (يتلوها , أو } أو ] أو نهاية النصّ) لا حين تبدأ بها جملة.
      expect(parseToMap('{msg: True story}')['msg'], 'True story');
      expect(parseToMap('{msg: False alarm}')['msg'], 'False alarm');
    });

    test('None في قاموس Python تصير null لا نصّ «None»', () {
      // ‏_cleanRaw يعالج True/False ويغفل None، فتمرّ إلى مسار الإصلاح
      // وتُقتبس نصّاً: القيمة تصير غير-null فتنجو من كلّ فحوص الـ null.
      final result = parseToMap("{'a': None, 'b': 1}");
      expect(result.containsKey('a'), isTrue);
      expect(result['a'], isNull);
      expect(result['b'], 1);
    });

    test('مفاتيح عربية غير مقتبسة (toString) تُقرأ لا تُسقِط الحمولة', () {
      // نمط المفاتيح [A-Za-z_]\w* لاتينيّ صرف، فلا يقتبس المفتاح العربيّ
      // ويفشل فكّ الترميز وتُرجع {} — ضياع الحمولة كاملةً في مكتبة عربية.
      final result = parseToMap('{اسم: محمد, مدينة: الرياض}');
      expect(result['اسم'], 'محمد');
      expect(result['مدينة'], 'الرياض');
    });

    test('قائمة عناصرها نصوص غير مقتبسة (toString) لا تُسقِط الحمولة', () {
      // ‏_unquotedValue يقتبس ما بعد ':' فقط، فعناصر القائمة العارية تبقى
      // بلا اقتباس ويفشل فكّ الخريطة كلّها — لا الحقل وحده.
      final result = parseToMap('{tags: [red, blue], id: 5}');
      expect(result['tags'], ['red', 'blue']);
      expect(result['id'], 5);
    });
  });
}
