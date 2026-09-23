import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار [BaseEntity] — أساس كل نموذجٍ مُرقَّم (pagination) في المكتبة.
///
/// الصنف مجرّد، فيُعرَّف هنا صنفٌ ملموسٌ يرثه ([_Page]) مع عنصرٍ بسيط ([_Item])
/// قد يكون مفتاحه null، ليُسلَك مسارُ «العناصر بلا مفتاح» في [BaseEntity.merge].

/// عنصرُ اختبار. [id] قد يكون null كمعرّفٍ اختياريّ لم يُثبّته الخادم بعد.
class _Item {
  const _Item(this.id, [this.name = '']);

  final Object? id;
  final String name;

  @override
  String toString() => '_Item($id, $name)';
}

/// صفحةٌ ملموسة ترث [BaseEntity].
class _Page extends BaseEntity<_Item> {
  _Page({required super.count, required super.next, required super.results});

  /// صفحةٌ بقائمةٍ غير قابلة للتعديل — كالتي تصل من `const []` أو من
  /// `List.unmodifiable`؛ وهي الحالة التي كانت ترمي `UnsupportedError`.
  factory _Page.frozen({
    int count = 0,
    String next = '',
    List<_Item> results = const <_Item>[],
  }) => _Page(
    count: count,
    next: next,
    results: List<_Item>.unmodifiable(results),
  );
}

/// مفاتيح العناصر بالترتيب — أوضح في رسائل الفشل من مقارنة الكائنات.
List<Object?> _ids(BaseEntity<_Item> page) =>
    page.results.map((_Item item) => item.id).toList();

/// أسماء العناصر بالترتيب.
List<String> _names(BaseEntity<_Item> page) =>
    page.results.map((_Item item) => item.name).toList();

/// مفتاح الدمج المعتاد: [_Item.id] (قد يكون null).
Object? _byId(_Item item) => item.id;

void main() {
  group('addAll — ضمّ الصفحة التالية', () {
    test('يضمّ الصفحة الثانية إلى الأولى ويحدّث count وnext', () {
      final _Page page = _Page(
        count: 4,
        next: 'https://api.com/orders/?offset=2',
        results: <_Item>[const _Item(1), const _Item(2)],
      );

      page.addAll(
        _Page(
          count: 4,
          next: '',
          results: <_Item>[const _Item(3), const _Item(4)],
        ),
      );

      expect(_ids(page), <Object?>[1, 2, 3, 4]);
      expect(page.count, 4);
      expect(page.next, '');
    });

    test('قائمة `const []` غير قابلة للتعديل: لا UnsupportedError', () {
      final _Page page = _Page(count: 1, next: '', results: const <_Item>[]);

      expect(
        () => page.addAll(
          _Page(count: 1, next: '', results: <_Item>[const _Item(1)]),
        ),
        returnsNormally,
      );
      expect(_ids(page), <Object?>[1]);
    });

    test('قائمة List.unmodifiable: لا UnsupportedError', () {
      final _Page page = _Page.frozen(
        count: 3,
        next: 'https://api.com/?offset=1',
        results: <_Item>[const _Item(1)],
      );

      expect(
        () => page.addAll(
          _Page(count: 3, next: '', results: <_Item>[const _Item(2)]),
        ),
        returnsNormally,
      );
      expect(_ids(page), <Object?>[1, 2]);
    });

    test('الناتج قابل للنموّ: addAll مرّتين متتاليتين على قائمةٍ مجمّدة', () {
      final _Page page = _Page.frozen(count: 9, next: 'n');

      page
        ..addAll(_Page(count: 9, next: 'n', results: <_Item>[const _Item(1)]))
        ..addAll(_Page(count: 9, next: '', results: <_Item>[const _Item(2)]));

      expect(_ids(page), <Object?>[1, 2]);
    });

    test('لا يمسّ الصفحة الجديدة: قائمتها وعدّادها كما هما', () {
      final _Page page = _Page(
        count: 2,
        next: 'n',
        results: <_Item>[const _Item(1)],
      );
      final _Page incoming = _Page(
        count: 2,
        next: '',
        results: <_Item>[const _Item(2)],
      );

      page.addAll(incoming);

      expect(_ids(incoming), <Object?>[2]);
      expect(incoming.count, 2);
      expect(incoming.next, '');
    });

    test('لا يمسّ القائمة المُمرَّرة من خارج الصنف (لا مشاركة مرجع)', () {
      final List<_Item> original = <_Item>[const _Item(1)];
      final _Page page = _Page(count: 2, next: 'n', results: original);

      page.addAll(
        _Page(count: 2, next: '', results: <_Item>[const _Item(2)]),
      );

      expect(original, hasLength(1), reason: 'القائمة الأصليّة تغيّرت');
      expect(_ids(page), <Object?>[1, 2]);
    });

    test('صفحة جديدة فارغة: العناصر كما هي وcount/next يُحدَّثان', () {
      final _Page page = _Page(
        count: 5,
        next: 'https://api.com/?offset=1',
        results: <_Item>[const _Item(1)],
      );

      page.addAll(_Page(count: 1, next: '', results: const <_Item>[]));

      expect(_ids(page), <Object?>[1]);
      expect(page.count, 1);
      expect(page.next, '');
    });

    test('الضمّ إلى صفحةٍ فارغة يعطي عناصر الجديدة بالضبط', () {
      final _Page page = _Page(count: 0, next: '', results: const <_Item>[]);

      page.addAll(
        _Page(
          count: 2,
          next: 'https://api.com/?offset=2',
          results: <_Item>[const _Item(7), const _Item(8)],
        ),
      );

      expect(_ids(page), <Object?>[7, 8]);
      expect(page.count, 2);
      expect(page.next, 'https://api.com/?offset=2');
    });

    test('لا يزيل التكرار — إزالته شغل merge وحده', () {
      final _Page page = _Page(
        count: 2,
        next: 'n',
        results: <_Item>[const _Item(1)],
      );

      page.addAll(
        _Page(count: 2, next: '', results: <_Item>[const _Item(1)]),
      );

      expect(_ids(page), <Object?>[1, 1]);
    });

    test('يعيد الكائن نفسه لا نسخةً عنه', () {
      final _Page page = _Page(count: 0, next: '', results: const <_Item>[]);

      final BaseEntity<_Item> returned = page.addAll(
        _Page(count: 0, next: '', results: const <_Item>[]),
      );

      expect(identical(returned, page), isTrue);
    });

    test('قائمة طويلة جداً (٢٠٠٠ عنصر) تُضمّ كاملةً وبترتيبها', () {
      final _Page page = _Page(
        count: 2000,
        next: 'n',
        results: List<_Item>.generate(1000, (int i) => _Item(i)),
      );

      page.addAll(
        _Page(
          count: 2000,
          next: '',
          results: List<_Item>.generate(1000, (int i) => _Item(1000 + i)),
        ),
      );

      expect(page.length, 2000);
      expect(page.results.first.id, 0);
      expect(page.results.last.id, 1999);
    });

    test('عناصر بأسماء عربيّة: النصّ يمرّ كما هو', () {
      final _Page page = _Page(
        count: 2,
        next: 'n',
        results: <_Item>[const _Item(1, 'طلبٌ أوّل')],
      );

      page.addAll(
        _Page(count: 2, next: '', results: <_Item>[const _Item(2, 'طلبٌ ثانٍ')]),
      );

      expect(_names(page), <String>['طلبٌ أوّل', 'طلبٌ ثانٍ']);
    });
  });

  group('merge — دمجٌ بالمفتاح مع تجنّب التكرار', () {
    test('يزيل التكرار بالمفتاح ويُبقي النسخة الأحدث', () {
      final _Page page = _Page(
        count: 3,
        next: 'n',
        results: <_Item>[const _Item(1, 'قديم'), const _Item(2, 'ب')],
      );

      page.merge(
        _Page(
          count: 3,
          next: '',
          results: <_Item>[const _Item(1, 'جديد'), const _Item(3, 'ج')],
        ),
        _byId,
      );

      expect(_ids(page), <Object?>[1, 2, 3]);
      expect(page.results.first.name, 'جديد');
    });

    test('العنصر المُحدَّث يبقى في موضعه الأوّل (لا يقفز إلى الآخر)', () {
      final _Page page = _Page(
        count: 3,
        next: 'n',
        results: <_Item>[
          const _Item(1, 'أ'),
          const _Item(2, 'ب'),
          const _Item(3, 'ج'),
        ],
      );

      page.merge(
        _Page(count: 3, next: '', results: <_Item>[const _Item(1, 'أ٢')]),
        _byId,
      );

      expect(_ids(page), <Object?>[1, 2, 3]);
      expect(_names(page), <String>['أ٢', 'ب', 'ج']);
    });

    test('مفاتيح مكرّرة داخل الصفحة الواحدة: الأخير يفوز', () {
      final _Page page = _Page(count: 1, next: '', results: const <_Item>[]);

      page.merge(
        _Page(
          count: 1,
          next: '',
          results: <_Item>[const _Item(1, 'أوّل'), const _Item(1, 'أخير')],
        ),
        _byId,
      );

      expect(page.length, 1);
      expect(page.results.single.name, 'أخير');
    });

    test('مفاتيح null لا يدهس بعضها بعضاً', () {
      final _Page page = _Page(count: 0, next: '', results: const <_Item>[]);

      page.merge(
        _Page(
          count: 3,
          next: '',
          results: <_Item>[
            const _Item(null, 'أ'),
            const _Item(null, 'ب'),
            const _Item(null, 'ج'),
          ],
        ),
        _byId,
      );

      expect(page.length, 3);
      expect(_names(page), <String>['أ', 'ب', 'ج']);
    });

    test('كل المفاتيح null: لا دمج ممكن فتُحفظ الصفحتان كاملتين', () {
      final _Page page = _Page(
        count: 2,
        next: 'n',
        results: <_Item>[const _Item(null, 'أ')],
      );

      page.merge(
        _Page(count: 2, next: '', results: <_Item>[const _Item(null, 'أ')]),
        _byId,
      );

      // بلا مفتاحٍ لا سبيل إلى معرفة أنّهما عنصرٌ واحد — تبقى النسختان.
      expect(page.length, 2);
    });

    test('مفاتيح نصّية عربية تُدمج كغيرها', () {
      final _Page page = _Page(
        count: 2,
        next: 'n',
        results: <_Item>[const _Item('الرياض', 'قديم')],
      );

      page.merge(
        _Page(
          count: 2,
          next: '',
          results: <_Item>[
            const _Item('الرياض', 'جديد'),
            const _Item('جدّة', 'ج'),
          ],
        ),
        _byId,
      );

      expect(_ids(page), <Object?>['الرياض', 'جدّة']);
      expect(page.results.first.name, 'جديد');
    });

    test('مفاتيح مختلطة الأنواع (int وString) لا تتصادم', () {
      final _Page page = _Page(
        count: 2,
        next: '',
        results: <_Item>[const _Item(1, 'رقم'), const _Item('1', 'نصّ')],
      );

      page.merge(
        _Page(count: 2, next: '', results: const <_Item>[]),
        _byId,
      );

      expect(page.length, 2);
    });

    test('يحدّث count وnext من الصفحة الجديدة', () {
      final _Page page = _Page(
        count: 99,
        next: 'https://api.com/?offset=1',
        results: <_Item>[const _Item(1)],
      );

      page.merge(
        _Page(
          count: 7,
          next: 'https://api.com/?offset=2',
          results: <_Item>[const _Item(2)],
        ),
        _byId,
      );

      expect(page.count, 7);
      expect(page.next, 'https://api.com/?offset=2');
    });

    test('صفحة جديدة فارغة لا تُفقد أيّ عنصر', () {
      final _Page page = _Page(
        count: 2,
        next: 'n',
        results: <_Item>[const _Item(1), const _Item(2)],
      );

      page.merge(_Page(count: 2, next: '', results: const <_Item>[]), _byId);

      expect(_ids(page), <Object?>[1, 2]);
    });

    test('يعمل على قائمةٍ غير قابلة للتعديل', () {
      final _Page page = _Page.frozen(
        count: 2,
        next: 'n',
        results: <_Item>[const _Item(1)],
      );

      expect(
        () => page.merge(
          _Page(count: 2, next: '', results: <_Item>[const _Item(2)]),
          _byId,
        ),
        returnsNormally,
      );
      expect(_ids(page), <Object?>[1, 2]);
    });

    test('لا يمسّ قائمة الصفحة الجديدة', () {
      final _Page page = _Page(
        count: 2,
        next: '',
        results: <_Item>[const _Item(1)],
      );
      final _Page incoming = _Page(
        count: 2,
        next: '',
        results: <_Item>[const _Item(1), const _Item(2)],
      );

      page.merge(incoming, _byId);

      expect(_ids(incoming), <Object?>[1, 2]);
    });

    test('يعيد الكائن نفسه لا نسخةً عنه', () {
      final _Page page = _Page(count: 0, next: '', results: const <_Item>[]);

      final BaseEntity<_Item> returned = page.merge(
        _Page(count: 0, next: '', results: const <_Item>[]),
        _byId,
      );

      expect(identical(returned, page), isTrue);
    });

    test('الدمج مع صفحةٍ فارغة لا يُعيد ترتيب العناصر', () {
      final _Page page = _Page(
        count: 2,
        next: '',
        results: <_Item>[
          const _Item(null, 'بلا مفتاح'),
          const _Item(1, 'بمفتاح'),
        ],
      );

      page.merge(_Page(count: 2, next: '', results: const <_Item>[]), _byId);

      // دمجٌ بلا بياناتٍ جديدة يجب أن يكون عمليّةً محايدة على الترتيب.
      expect(_names(page), <String>['بلا مفتاح', 'بمفتاح']);
    });

    test('العناصر بلا مفتاح تحفظ موضعها بين العناصر ذات المفاتيح', () {
      final _Page page = _Page(
        count: 4,
        next: 'n',
        results: <_Item>[
          const _Item(1, 'أ'),
          const _Item(null, 'ب'),
          const _Item(2, 'ج'),
        ],
      );

      page.merge(
        _Page(count: 4, next: '', results: <_Item>[const _Item(3, 'د')]),
        _byId,
      );

      // الترتيب المتوقّع: ترتيب اللقاء نفسه، ثمّ عناصر الصفحة الجديدة.
      expect(_names(page), <String>['أ', 'ب', 'ج', 'د']);
    });
  });

  group('hasNext و canLoadMore', () {
    test('next فارغ: hasNext false وcanLoadMore false', () {
      final _Page page = _Page(
        count: 100,
        next: '',
        results: <_Item>[const _Item(1)],
      );

      expect(page.hasNext, isFalse);
      expect(page.canLoadMore, isFalse);
    });

    test('رابطٌ تالٍ وcount أكبر من الطول: canLoadMore true', () {
      final _Page page = _Page(
        count: 10,
        next: 'https://api.com/?offset=1',
        results: <_Item>[const _Item(1)],
      );

      expect(page.hasNext, isTrue);
      expect(page.canLoadMore, isTrue);
    });

    test('count يساوي الطول: canLoadMore false ولو بقي الرابط (لا حلقة لانهائية)', () {
      final _Page page = _Page(
        count: 2,
        next: 'https://api.com/?offset=2',
        results: <_Item>[const _Item(1), const _Item(2)],
      );

      expect(page.hasNext, isTrue);
      expect(page.canLoadMore, isFalse);
    });

    test('count أقلّ من الطول (حذفٌ في الخادم): canLoadMore false', () {
      final _Page page = _Page(
        count: 1,
        next: 'https://api.com/?offset=2',
        results: <_Item>[const _Item(1), const _Item(2)],
      );

      expect(page.canLoadMore, isFalse);
    });

    test('count صفر مع رابطٍ تالٍ: canLoadMore false', () {
      final _Page page = _Page(
        count: 0,
        next: 'https://api.com/?offset=1',
        results: const <_Item>[],
      );

      expect(page.canLoadMore, isFalse);
    });

    test('count سالب (استجابة مشوّهة): canLoadMore false', () {
      final _Page page = _Page(
        count: -5,
        next: 'https://api.com/?offset=1',
        results: const <_Item>[],
      );

      expect(page.canLoadMore, isFalse);
    });

    test('قائمة فارغة مع رابطٍ تالٍ وcount موجب: canLoadMore true', () {
      final _Page page = _Page(
        count: 20,
        next: 'https://api.com/?offset=0',
        results: const <_Item>[],
      );

      expect(page.canLoadMore, isTrue);
    });

    test('بعد addAll لآخر صفحة: canLoadMore يصير false', () {
      final _Page page = _Page(
        count: 4,
        next: 'https://api.com/?offset=2',
        results: <_Item>[const _Item(1), const _Item(2)],
      );

      expect(page.canLoadMore, isTrue);

      page.addAll(
        _Page(
          count: 4,
          next: '',
          results: <_Item>[const _Item(3), const _Item(4)],
        ),
      );

      expect(page.canLoadMore, isFalse);
    });

    test('hasNext فحصٌ نصّيّ محض: مسافةٌ واحدة تُعدّ رابطاً وnextOffset يبقى null', () {
      final _Page page = _Page(
        count: 10,
        next: ' ',
        results: <_Item>[const _Item(1)],
      );

      expect(page.hasNext, isTrue);
      expect(page.canLoadMore, isTrue);
      expect(page.nextOffset, isNull);
    });

    test('ترقيم بالمؤشّر (cursor): canLoadMore true بينما nextOffset null', () {
      final _Page page = _Page(
        count: 10,
        next: 'https://api.com/orders/?cursor=abc',
        results: <_Item>[const _Item(1)],
      );

      expect(page.canLoadMore, isTrue);
      expect(page.nextOffset, isNull);
    });
  });

  group('nextOffset — استخراج offset من رابط الصفحة التالية', () {
    _Page pageWith(String next, {int count = 100, int items = 1}) => _Page(
      count: count,
      next: next,
      results: List<_Item>.generate(items, (int i) => _Item(i)),
    );

    test('رابطٌ معتاد: offset=20 → 20', () {
      expect(
        pageWith('https://api.com/orders/?limit=20&offset=20').nextOffset,
        20,
      );
    });

    test('next فارغ → null', () {
      expect(pageWith('').nextOffset, isNull);
    });

    test('قائمةٌ فارغة مع رابطٍ تالٍ: الحارس يخصّ next لا القائمة', () {
      expect(
        pageWith('https://api.com/?offset=20', items: 0).nextOffset,
        20,
        reason: 'صفحةٌ فارغة برابطٍ تالٍ ما زالت قابلة للترقيم',
      );
    });

    test('رابطٌ بلا offset → null', () {
      expect(pageWith('https://api.com/orders/?limit=20').nextOffset, isNull);
    });

    test('offset=0 → صفر لا null', () {
      expect(pageWith('https://api.com/?offset=0').nextOffset, 0);
    });

    test('offset غير رقميّ → null', () {
      expect(pageWith('https://api.com/?offset=abc').nextOffset, isNull);
    });

    test('offset عربيّ الأرقام (٢٠) → null', () {
      expect(pageWith('https://api.com/?offset=٢٠').nextOffset, isNull);
    });

    test('offset عشريّ (20.5) → null', () {
      expect(pageWith('https://api.com/?offset=20.5').nextOffset, isNull);
    });

    test('offset فارغ القيمة (offset=) → null', () {
      expect(pageWith('https://api.com/?offset=').nextOffset, isNull);
    });

    test('offset يتجاوز سعة int (٢٠ خانة) → null لا انهيار', () {
      expect(
        pageWith('https://api.com/?offset=99999999999999999999').nextOffset,
        isNull,
      );
    });

    test('رابطٌ نسبيّ (بلا مضيف) يعمل', () {
      expect(pageWith('/api/orders/?offset=40').nextOffset, 40);
    });

    test('offset مكرّر في الرابط: الأخير يفوز', () {
      expect(pageWith('https://api.com/?offset=20&offset=40').nextOffset, 40);
    });

    test('offset حسّاس لحالة الأحرف: OFFSET لا يُقرأ', () {
      expect(pageWith('https://api.com/?OFFSET=20').nextOffset, isNull);
    });

    test('offset في الـ fragment لا في الـ query → null', () {
      expect(pageWith('https://api.com/orders/#offset=20').nextOffset, isNull);
    });

    test('fragment بعد query صحيح لا يُفسد الاستخراج', () {
      expect(
        pageWith('https://api.com/?limit=20&offset=20#page').nextOffset,
        20,
      );
    });

    test('معاملات عربية في الرابط لا تُفسد الاستخراج', () {
      expect(pageWith('https://api.com/?بحث=مرحبا&offset=15').nextOffset, 15);
    });

    test('قيمةٌ مُرمَّزة (%32%30) تُفكّ إلى 20', () {
      expect(pageWith('https://api.com/?offset=%32%30').nextOffset, 20);
    });

    test('رابطٌ مشوّه تماماً (::::) → null بلا رمي استثناء', () {
      final _Page page = pageWith('::::');

      expect(() => page.nextOffset, returnsNormally);
      expect(page.nextOffset, isNull);
    });

    test('offset سالب يُنقل كما هو — الاستخراج نصّيّ لا يتحقّق من المعقوليّة', () {
      // توثيقٌ لعقدٍ قائم: على المستدعي التحقّق قبل إرسال الطلب.
      expect(pageWith('https://api.com/?offset=-5').nextOffset, -5);
    });

    test('يتغيّر مع next بعد addAll', () {
      final _Page page = pageWith('https://api.com/?offset=20');

      page.addAll(
        _Page(
          count: 100,
          next: 'https://api.com/?offset=40',
          results: <_Item>[const _Item(9)],
        ),
      );

      expect(page.nextOffset, 40);
    });
  });

  group('isEmpty و isNotEmpty و length', () {
    test('قائمة فارغة: isEmpty true وisNotEmpty false وlength صفر', () {
      final _Page page = _Page(count: 0, next: '', results: const <_Item>[]);

      expect(page.isEmpty, isTrue);
      expect(page.isNotEmpty, isFalse);
      expect(page.length, 0);
    });

    test('عنصرٌ واحد: isEmpty false وisNotEmpty true وlength واحد', () {
      final _Page page = _Page(
        count: 1,
        next: '',
        results: <_Item>[const _Item(1)],
      );

      expect(page.isEmpty, isFalse);
      expect(page.isNotEmpty, isTrue);
      expect(page.length, 1);
    });

    test('الطول يتبع القائمة لا count المُعلن من الخادم', () {
      final _Page page = _Page(
        count: 500,
        next: 'n',
        results: <_Item>[const _Item(1), const _Item(2)],
      );

      expect(page.length, 2);
      expect(page.isNotEmpty, isTrue);
    });

    test('الطول يتحدّث بعد addAll', () {
      final _Page page = _Page(count: 0, next: '', results: const <_Item>[]);

      expect(page.isEmpty, isTrue);

      page.addAll(
        _Page(
          count: 2,
          next: '',
          results: <_Item>[const _Item(1), const _Item(2)],
        ),
      );

      expect(page.length, 2);
      expect(page.isEmpty, isFalse);
    });

    test('الطول يتحدّث بعد merge المُزيل للتكرار', () {
      final _Page page = _Page(
        count: 1,
        next: '',
        results: <_Item>[const _Item(1, 'قديم')],
      );

      page.merge(
        _Page(count: 1, next: '', results: <_Item>[const _Item(1, 'جديد')]),
        _byId,
      );

      expect(page.length, 1);
    });

    test('قائمة طويلة جداً: length دقيق', () {
      final _Page page = _Page(
        count: 5000,
        next: '',
        results: List<_Item>.generate(5000, (int i) => _Item(i)),
      );

      expect(page.length, 5000);
      expect(page.isNotEmpty, isTrue);
    });
  });
}
