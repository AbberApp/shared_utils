import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبارات الـ widgets العامّة في `lib/src/ui/widgets/`.
///
/// ملاحظة على الأسلوب: `Skeletonizer` المفعَّل يُشغّل انيميشن لا ينتهي
/// (تكرار كل 900ms)، فلا يُستعمل `pumpAndSettle` مع أيّ شجرة فيها
/// `isLoading: true` — يُستعمل `pump()` بمُدد صريحة بدلاً منه.

// ═══════════════════════════════════════════════════════════════════════════
// أدوات مساعدة
// ═══════════════════════════════════════════════════════════════════════════

/// نموذج مُرقَّم حقيقي لاختبار [LoadMoreWidget.onScroll] — [BaseEntity] مجرّد.
class _Page extends BaseEntity<int> {
  _Page({required super.count, required super.next, required super.results});
}

/// لوحة ألوان ثابتة كي لا تتغيّر التوقّعات مع تغيّر ثيم فلاتر الافتراضي.
final ColorScheme _scheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF3355FF),
);

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? ThemeData(colorScheme: _scheme),
  home: Scaffold(body: child),
);

/// يُثبّت مقاس الشاشة كي لا تعتمد الحسابات على مقاس الجهاز المضيف.
void _fixScreen(WidgetTester tester, {Size size = const Size(400, 800)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// يقرأ لون بكسل واحد من `RepaintBoundary` — الطريقة الوحيدة للتحقّق ممّا
/// يرسمه `Skeletonizer` فعلاً، إذ يتدخّل في الرسم لا في شجرة الـ widgets.
///
/// `runAsync` ضروري: تحويل الطبقة إلى صورة يمرّ بمُشغّل مهامّ المحرّك، وساعة
/// الاختبار المزيّفة لا تُقدّمه فيعلق الـ Future إلى أن ينفد وقت الاختبار.
Future<Color> _pixelAt(WidgetTester tester, Key boundaryKey, Offset at) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));

  final ({ByteData bytes, int width}) shot = (await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData data =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final int width = image.width;
    image.dispose();
    return (bytes: data, width: width);
  }))!;

  final int i = (at.dy.round() * shot.width + at.dx.round()) * 4;
  return Color.fromARGB(
    shot.bytes.getUint8(i + 3),
    shot.bytes.getUint8(i),
    shot.bytes.getUint8(i + 1),
    shot.bytes.getUint8(i + 2),
  );
}

/// `Skeletonizer(...)` مُنشئٌ مصنعيّ يُرجع نوعاً خاصّاً، فـ `find.byType`
/// (يطابق النوع بالضبط) لا يجده — نطابق بالنوع الأعلى بدلاً منه.
Finder _skeletonizerFinder() =>
    find.byWidgetPredicate((Widget w) => w is Skeletonizer);

/// مقارنة ألوان بسماحية — مضادّ التعرّج وتقريب الـ premultiplied قد يزيحان
/// قناةً بوحدة أو اثنتين.
Matcher _nearColor(Color expected, {int tolerance = 4}) =>
    predicate<Color>((Color actual) {
      bool near(double a, double b) => ((a - b) * 255).abs() <= tolerance;
      return near(actual.a, expected.a) &&
          near(actual.r, expected.r) &&
          near(actual.g, expected.g) &&
          near(actual.b, expected.b);
    }, 'لون قريب من $expected');

// ═══════════════════════════════════════════════════════════════════════════

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  group('SkeletonizerWidget', () {
    const Key boundary = Key('حدود-الرسم');
    const Color containers = Color(0xFFFF0000); // أحمر — لون الحاويات المطلوب
    const Color real = Color(0xFF0000FF); // أزرق — اللون الفعلي للحاوية
    const Color page = Color(0xFFFFFFFF); // أبيض — خلفية ما وراء الحاوية

    /// حاوية ملوّنة **لها ابن** — الحاوية بلا ابن يعاملها Skeletonizer كعظمة
    /// (bone) لا كحاوية، فلا يمسّها `containersColor` أصلاً.
    Widget tree({
      required bool isLoading,
      required bool ignoreContainers,
      Color? containersColor,
    }) => _app(
      Center(
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: page,
            child: SkeletonizerWidget(
              isLoading: isLoading,
              ignoreContainers: ignoreContainers,
              containersColor: containersColor,
              child: Container(
                width: 200.0,
                height: 120.0,
                color: real,
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: Text('نصّ'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('الابن يُعرض سواء كان التحميل جارياً أم لا', (tester) async {
      _fixScreen(tester);

      await tester.pumpWidget(
        tree(isLoading: false, ignoreContainers: false),
      );
      expect(find.text('نصّ'), findsOneWidget);

      await tester.pumpWidget(tree(isLoading: true, ignoreContainers: false));
      await tester.pump();
      expect(find.text('نصّ'), findsOneWidget);
    });

    testWidgets('isLoading يُمرَّر إلى Skeletonizer.enabled', (tester) async {
      _fixScreen(tester);

      await tester.pumpWidget(tree(isLoading: false, ignoreContainers: false));
      expect(tester.widget<Skeletonizer>(_skeletonizerFinder()).enabled,
          isFalse);

      await tester.pumpWidget(tree(isLoading: true, ignoreContainers: true));
      await tester.pump();
      final Skeletonizer sk =
          tester.widget<Skeletonizer>(_skeletonizerFinder());
      expect(sk.enabled, isTrue);
      expect(sk.ignoreContainers, isTrue);
      expect(sk.ignorePointers, isTrue);
      expect(sk.justifyMultiLineText, isTrue);
    });

    testWidgets(
      'containersColor يُطبَّق مع ignoreContainers: false (الحاويات تُرسم)',
      (tester) async {
        _fixScreen(tester);
        await tester.pumpWidget(
          tree(
            isLoading: true,
            ignoreContainers: false,
            containersColor: containers,
          ),
        );
        await tester.pump();

        // نقطة في أعلى يسار الحاوية، بعيدة عن النصّ (عظمة) في الأسفل.
        expect(
          await _pixelAt(tester, boundary, const Offset(10.0, 10.0)),
          _nearColor(containers),
        );
      },
    );

    testWidgets(
      'containersColor يُتجاهَل مع ignoreContainers: true (لا حاويات تُرسم)',
      (tester) async {
        _fixScreen(tester);
        await tester.pumpWidget(
          tree(
            isLoading: true,
            ignoreContainers: true,
            containersColor: containers,
          ),
        );
        await tester.pump();

        // لا الأحمر المطلوب ولا الأزرق الفعلي: الحاوية لم تُرسم إطلاقاً.
        expect(
          await _pixelAt(tester, boundary, const Offset(10.0, 10.0)),
          _nearColor(page),
        );
      },
    );

    testWidgets(
      'بلا containersColor تبقى الحاوية بلونها الفعلي أثناء التحميل',
      (tester) async {
        _fixScreen(tester);
        await tester.pumpWidget(
          tree(isLoading: true, ignoreContainers: false),
        );
        await tester.pump();

        expect(
          await _pixelAt(tester, boundary, const Offset(10.0, 10.0)),
          _nearColor(real),
        );
      },
    );

    testWidgets(
      'مع isLoading: false لا يُلوَّن شيء ولو مُرِّر containersColor',
      (tester) async {
        _fixScreen(tester);
        await tester.pumpWidget(
          tree(
            isLoading: false,
            ignoreContainers: false,
            containersColor: containers,
          ),
        );

        expect(
          await _pixelAt(tester, boundary, const Offset(10.0, 10.0)),
          _nearColor(real),
        );
      },
    );

    testWidgets('shimmerBaseColor الافتراضي = colorScheme.surfaceTint', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(tree(isLoading: true, ignoreContainers: false));
      await tester.pump();

      final ShimmerEffect effect =
          tester.widget<Skeletonizer>(_skeletonizerFinder()).effect!
              as ShimmerEffect;
      expect(effect.colors.first, _scheme.surfaceTint);
      expect(effect.duration, const Duration(milliseconds: 900));
    });

    testWidgets('shimmerBaseColor المُمرَّر يتقدّم على الثيم', (tester) async {
      _fixScreen(tester);
      const Color custom = Color(0xFF00FF00);
      await tester.pumpWidget(
        _app(
          const SkeletonizerWidget(
            isLoading: true,
            shimmerBaseColor: custom,
            child: Text('س'),
          ),
        ),
      );
      await tester.pump();

      final ShimmerEffect effect =
          tester.widget<Skeletonizer>(_skeletonizerFinder()).effect!
              as ShimmerEffect;
      expect(effect.colors.first, custom);
    });

    testWidgets('ابن فارغ (SizedBox.shrink) لا يرمي', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        _app(
          const SkeletonizerWidget(
            isLoading: true,
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('LoadMoreWidget — العرض', () {
    testWidgets('isLoadMore: false ⇒ فراغ بارتفاع 40 بلا مؤشر', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        _app(const Center(child: LoadMoreWidget(isLoadMore: false))),
      );

      expect(find.byType(LoadMoreIndicatorWidget), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(tester.getSize(find.byType(LoadMoreWidget)).height, 40.0);
    });

    testWidgets('isLoadMore: true ⇒ مؤشر داخل حشوة 24 أعلى و64 أسفل', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        _app(const Center(child: LoadMoreWidget(isLoadMore: true))),
      );

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(LoadMoreWidget),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.only(bottom: 64.0, top: 24.0));
      // 44 ارتفاع المؤشر + 24 + 64
      expect(tester.getSize(find.byType(LoadMoreWidget)).height, 132.0);
    });

    testWidgets('topPadding: 0 مقبول', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        _app(
          const Center(child: LoadMoreWidget(isLoadMore: true, topPadding: 0)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(LoadMoreWidget)).height, 108.0);
    });

    testWidgets('topPadding سالب يُرفض (حشوة فلاتر لا تقبل السالب)', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        _app(
          const Center(
            child: LoadMoreWidget(isLoadMore: true, topPadding: -8.0),
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('الألوان الافتراضية من colorScheme (primary/secondary)', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        _app(const Center(child: LoadMoreWidget(isLoadMore: true))),
      );

      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(LoadMoreIndicatorWidget),
          matching: find.byType(Container),
        ),
      );
      expect((box.decoration! as BoxDecoration).color, _scheme.secondary);
      expect(
        tester
            .widget<CupertinoActivityIndicator>(
              find.byType(CupertinoActivityIndicator),
            )
            .color,
        _scheme.primary,
      );
    });

    testWidgets('الألوان المُمرَّرة تتقدّم على الثيم', (tester) async {
      _fixScreen(tester);
      const Color fg = Color(0xFF123456);
      const Color bg = Color(0xFF654321);
      await tester.pumpWidget(
        _app(
          const Center(
            child: LoadMoreWidget(
              isLoadMore: true,
              indicatorColor: fg,
              indicatorBackgroundColor: bg,
            ),
          ),
        ),
      );

      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(LoadMoreIndicatorWidget),
          matching: find.byType(Container),
        ),
      );
      expect((box.decoration! as BoxDecoration).color, bg);
      expect(
        tester
            .widget<CupertinoActivityIndicator>(
              find.byType(CupertinoActivityIndicator),
            )
            .color,
        fg,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('LoadMoreWidget.onScroll', () {
    late ScrollController controller;
    late int calls;

    /// يبني قائمة طويلة مربوطة بـ [controller] كي يصير له `position` حقيقي.
    Future<void> pumpList(WidgetTester tester) async {
      _fixScreen(tester);
      controller = ScrollController();
      addTearDown(controller.dispose);
      calls = 0;
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              height: 300.0,
              width: 400.0,
              child: ListView.builder(
                controller: controller,
                itemCount: 20,
                itemBuilder: (_, _) => const SizedBox(height: 100.0),
              ),
            ),
          ),
        ),
      );
    }

    _Page full() =>
        _Page(count: 40, next: 'https://x/?offset=20', results: List.filled(20, 0));

    testWidgets('عند الاقتراب من النهاية يُطلق onLoadMore', (tester) async {
      await pumpList(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      LoadMoreWidget.onScroll(
        controller: controller,
        base: full(),
        isLoadMore: false,
        onLoadMore: () => calls++,
      );
      expect(calls, 1);
    });

    testWidgets('بعيداً عن النهاية لا يُطلق شيء', (tester) async {
      await pumpList(tester);
      controller.jumpTo(0.0);
      await tester.pump();

      LoadMoreWidget.onScroll(
        controller: controller,
        base: full(),
        isLoadMore: false,
        onLoadMore: () => calls++,
      );
      expect(calls, 0);
    });

    testWidgets('لا يُطلق أثناء تحميل جارٍ (isLoadMore: true)', (tester) async {
      await pumpList(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      LoadMoreWidget.onScroll(
        controller: controller,
        base: full(),
        isLoadMore: true,
        onLoadMore: () => calls++,
      );
      expect(calls, 0);
    });

    testWidgets('قائمة فارغة لا تُطلق تحميلاً', (tester) async {
      await pumpList(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      LoadMoreWidget.onScroll(
        controller: controller,
        base: _Page(count: 40, next: 'https://x/?offset=20', results: const []),
        isLoadMore: false,
        onLoadMore: () => calls++,
      );
      expect(calls, 0);
    });

    testWidgets('count == 0 لا يُطلق تحميلاً', (tester) async {
      await pumpList(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      LoadMoreWidget.onScroll(
        controller: controller,
        base: _Page(count: 0, next: 'https://x/?offset=20', results: const [1]),
        isLoadMore: false,
        onLoadMore: () => calls++,
      );
      expect(calls, 0);
    });

    testWidgets('next فارغ (آخر صفحة) لا يُطلق تحميلاً', (tester) async {
      await pumpList(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      LoadMoreWidget.onScroll(
        controller: controller,
        base: _Page(count: 40, next: '', results: List.filled(20, 0)),
        isLoadMore: false,
        onLoadMore: () => calls++,
      );
      expect(calls, 0);
    });

    testWidgets('count يساوي المعروض (اكتملت الصفحات) لا يُطلق تحميلاً', (
      tester,
    ) async {
      await pumpList(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      LoadMoreWidget.onScroll(
        controller: controller,
        base: _Page(
          count: 20,
          next: 'https://x/?offset=20',
          results: List.filled(20, 0),
        ),
        isLoadMore: false,
        onLoadMore: () => calls++,
      );
      expect(calls, 0);
    });

    testWidgets('count مشوّه (أقلّ من المعروض) لا يُطلق تحميلاً', (
      tester,
    ) async {
      await pumpList(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      LoadMoreWidget.onScroll(
        controller: controller,
        base: _Page(
          count: 5,
          next: 'https://x/?offset=20',
          results: List.filled(20, 0),
        ),
        isLoadMore: false,
        onLoadMore: () => calls++,
      );
      expect(calls, 0);
    });

    testWidgets('متحكّم بلا clients لا يرمي ولا يُطلق تحميلاً', (tester) async {
      _fixScreen(tester);
      final ScrollController orphan = ScrollController();
      addTearDown(orphan.dispose);
      int n = 0;

      LoadMoreWidget.onScroll(
        controller: orphan,
        base: full(),
        isLoadMore: false,
        onLoadMore: () => n++,
      );
      expect(n, 0);
    });

    testWidgets('offsetFromBottom مخصّص يوسّع منطقة الإطلاق', (tester) async {
      await pumpList(tester);
      // 2000 = 20×100، والنافذة 300 ⇒ maxScrollExtent = 1700
      controller.jumpTo(1000.0);
      await tester.pump();

      LoadMoreWidget.onScroll(
        controller: controller,
        base: full(),
        isLoadMore: false,
        onLoadMore: () => calls++,
      );
      expect(calls, 0, reason: 'المتبقّي 700 > 200 الافتراضية');

      LoadMoreWidget.onScroll(
        controller: controller,
        base: full(),
        isLoadMore: false,
        offsetFromBottom: 800.0,
        onLoadMore: () => calls++,
      );
      expect(calls, 1, reason: 'المتبقّي 700 ≤ 800');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('PaginatedListView', () {
    /// يقرأ عدد عناصر الـ ListView الداخلي دون الاعتماد على أنواع خاصّة.
    int listItemCount(WidgetTester tester) {
      final ListView list = tester.widget<ListView>(find.byType(ListView));
      return (list.childrenDelegate as SliverChildBuilderDelegate).childCount!;
    }

    Widget build({
      required List<int> items,
      bool isLoading = false,
      bool isLoadMore = false,
      bool canLoadMore = false,
      VoidCallback? onLoadMore,
      Future<void> Function()? onRefresh,
      int skeletonItemCount = 6,
      Widget Function(BuildContext)? skeletonItemBuilder,
      ScrollController? scrollController,
    }) => _app(
      PaginatedListView<int>(
        items: items,
        isLoading: isLoading,
        isLoadMore: isLoadMore,
        canLoadMore: canLoadMore,
        onLoadMore: onLoadMore ?? () {},
        onRefresh: onRefresh,
        scrollController: scrollController,
        skeletonItemCount: skeletonItemCount,
        skeletonItemBuilder: skeletonItemBuilder,
        itemBuilder: (_, int item) =>
            SizedBox(height: 100.0, child: Text('عنصر $item')),
      ),
    );

    testWidgets('الحالة الفارغة: لا عناصر، وذيل القائمة وحده معروض', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(build(items: const []));

      expect(find.textContaining('عنصر'), findsNothing);
      expect(listItemCount(tester), 1, reason: 'ذيل LoadMoreWidget فقط');
      expect(find.byType(LoadMoreWidget), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('الحالة الفارغة لا تعرض RefreshIndicator إن لم يُمرَّر', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(build(items: const []));
      expect(find.byType(RefreshIndicator), findsNothing);

      await tester.pumpWidget(
        build(items: const [], onRefresh: () async {}),
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('التحميل الأوّلي يرسم skeletonItemCount عنصراً وهمياً', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(build(items: const [], isLoading: true));
      await tester.pump();

      expect(listItemCount(tester), 6);
      expect(find.byType(LoadMoreWidget), findsNothing);
      expect(
        tester.widget<Skeletonizer>(_skeletonizerFinder()).enabled,
        isTrue,
      );
    });

    testWidgets('التحميل الأوّلي يستعمل skeletonItemBuilder المخصّص', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        build(
          items: const [],
          isLoading: true,
          skeletonItemCount: 3,
          skeletonItemBuilder: (_) =>
              const SizedBox(height: 90.0, child: Text('هيكل')),
        ),
      );
      await tester.pump();

      expect(listItemCount(tester), 3);
      expect(find.text('هيكل'), findsWidgets);
    });

    testWidgets('skeletonItemCount: 0 ⇒ قائمة خالية أثناء التحميل', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        build(items: const [], isLoading: true, skeletonItemCount: 0),
      );
      await tester.pump();

      expect(listItemCount(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('skeletonItemCount سالب يُرفض عند الإنشاء', (tester) async {
      expect(
        () => PaginatedListView<int>(
          items: const [],
          isLoading: true,
          isLoadMore: false,
          canLoadMore: false,
          onLoadMore: () {},
          skeletonItemCount: -1,
          itemBuilder: (_, _) => const SizedBox.shrink(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets('التحميل الأوّلي مع عناصر موجودة يبقي العناصر الحقيقية', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        build(items: List<int>.generate(3, (int i) => i), isLoading: true),
      );
      await tester.pump();

      expect(listItemCount(tester), 4, reason: '3 عناصر + الذيل');
      expect(find.text('عنصر 0'), findsOneWidget);
    });

    testWidgets('تحميل المزيد: بلوغ النهاية يُطلق onLoadMore مرّة واحدة', (
      tester,
    ) async {
      _fixScreen(tester);
      int calls = 0;
      await tester.pumpWidget(
        build(
          items: List<int>.generate(30, (int i) => i),
          canLoadMore: true,
          onLoadMore: () => calls++,
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0.0, -4000.0));
      await tester.pump();
      expect(calls, 1);

      // سحبة أخرى في المنطقة نفسها بلا تغيّر حالة: لا طلب مكرّر.
      await tester.drag(find.byType(ListView), const Offset(0.0, -200.0));
      await tester.pump();
      expect(calls, 1, reason: 'الحارس يمنع الطلبات المتتالية');
    });

    testWidgets('الخروج من منطقة العتبة ثمّ العودة يسمح بطلبٍ جديد', (
      tester,
    ) async {
      _fixScreen(tester);
      int calls = 0;
      await tester.pumpWidget(
        build(
          items: List<int>.generate(30, (int i) => i),
          canLoadMore: true,
          onLoadMore: () => calls++,
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0.0, -4000.0));
      await tester.pump();
      expect(calls, 1);

      await tester.drag(find.byType(ListView), const Offset(0.0, 1500.0));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0.0, -4000.0));
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('canLoadMore: false يمنع الطلب مهما بلغ التمرير', (
      tester,
    ) async {
      _fixScreen(tester);
      int calls = 0;
      await tester.pumpWidget(
        build(
          items: List<int>.generate(30, (int i) => i),
          onLoadMore: () => calls++,
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0.0, -4000.0));
      await tester.pump();
      expect(calls, 0);
    });

    testWidgets('isLoading أثناء التحديث يمنع طلب صفحة تالية بالتوازي', (
      tester,
    ) async {
      _fixScreen(tester);
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      final List<int> items = List<int>.generate(30, (int i) => i);
      int calls = 0;

      // تحريك المتحكّم مباشرةً لا بالسحب: الـ Skeletonizer المفعَّل يغلّف
      // القائمة بـ IgnorePointer، فسحبةٌ باللمس لا تبلغها أصلاً وكان الاختبار
      // سينجح لسببٍ خاطئ (حجب المؤشّر) لا لأنّ حارس isLoading يعمل.
      await tester.pumpWidget(
        build(
          items: items,
          isLoading: true,
          canLoadMore: true,
          onLoadMore: () => calls++,
          scrollController: controller,
        ),
      );
      await tester.pump();

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(calls, 0, reason: 'الصفحة الأولى ما تزال قيد التحميل');

      // والحارس هو isLoading فعلاً: ما إن ينتهي التحميل حتّى يُقبل الطلب.
      controller.jumpTo(0.0);
      await tester.pump();
      await tester.pumpWidget(
        build(
          items: items,
          canLoadMore: true,
          onLoadMore: () => calls++,
          scrollController: controller,
        ),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('isLoadMore: true يعرض المؤشر في الذيل', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        build(items: const <int>[1], isLoadMore: true, canLoadMore: true),
      );

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('متحكّم خارجي لا يُتخلَّص منه عند إزالة القائمة', (
      tester,
    ) async {
      _fixScreen(tester);
      final ScrollController external = ScrollController();
      addTearDown(external.dispose);

      await tester.pumpWidget(
        build(
          items: List<int>.generate(5, (int i) => i),
          scrollController: external,
        ),
      );
      expect(external.hasClients, isTrue);

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(() => external.addListener(() {}), returnsNormally);
    });

    testWidgets('استبدال المتحكّم يُعيد الربط بالمتحكّم الجديد', (
      tester,
    ) async {
      _fixScreen(tester);
      final ScrollController first = ScrollController();
      final ScrollController second = ScrollController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      int calls = 0;

      await tester.pumpWidget(
        build(
          items: List<int>.generate(30, (int i) => i),
          canLoadMore: true,
          onLoadMore: () => calls++,
          scrollController: first,
        ),
      );
      await tester.pumpWidget(
        build(
          items: List<int>.generate(30, (int i) => i),
          canLoadMore: true,
          onLoadMore: () => calls++,
          scrollController: second,
        ),
      );

      expect(second.hasClients, isTrue);
      await tester.drag(find.byType(ListView), const Offset(0.0, -4000.0));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('padding الافتراضي 20 أفقياً و32 عمودياً', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(build(items: const <int>[1]));

      expect(
        tester.widget<ListView>(find.byType(ListView)).padding,
        const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
      );
    });

    testWidgets('عنوان عربي طويل جداً لا يُسقط التخطيط', (tester) async {
      _fixScreen(tester);
      final String long = 'مرحباً بالعالم ' * 80;
      await tester.pumpWidget(
        _app(
          PaginatedListView<String>(
            items: <String>[long],
            isLoading: false,
            isLoadMore: false,
            canLoadMore: false,
            onLoadMore: () {},
            itemBuilder: (_, String item) => Text(item),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('ResponsiveGridView', () {
    const GridConfig config = GridConfig(itemWidth: 160.0, itemHeight: 200.0);

    Widget grid({
      GridConfig cfg = config,
      int itemCount = 12,
      double width = 400.0,
    }) => _app(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 700.0,
          child: ResponsiveGridView(
            config: cfg,
            itemCount: itemCount,
            itemBuilder: (_, int i) => Text('خ$i'),
          ),
        ),
      ),
    );

    int columns(WidgetTester tester) {
      final GridView view = tester.widget<GridView>(find.byType(GridView));
      return (view.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount;
    }

    int shown(WidgetTester tester) {
      final GridView view = tester.widget<GridView>(find.byType(GridView));
      return (view.childrenDelegate as SliverChildBuilderDelegate).childCount!;
    }

    testWidgets('بعرض صفر يهبط إلى minCrossAxisCount بلا انهيار', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(grid(width: 0.0));

      expect(tester.takeException(), isNull);
      expect(columns(tester), 2);
    });

    testWidgets('العرض المعتاد يحسب الأعمدة من عرض العنصر', (tester) async {
      _fixScreen(tester, size: const Size(1200, 800));
      await tester.pumpWidget(grid(width: 900.0));
      // (900 + 12) / (160 + 12) = 5.30 ⇒ 5
      expect(columns(tester), 5);
    });

    testWidgets('عرض ضخم يُقصّ عند maxCrossAxisCount', (tester) async {
      _fixScreen(tester, size: const Size(6000, 800));
      await tester.pumpWidget(grid(width: 5000.0));
      expect(columns(tester), 6);
    });

    testWidgets('عرض ضيّق جداً يُرفع إلى minCrossAxisCount', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(grid(width: 30.0));
      expect(columns(tester), 2);
    });

    testWidgets('itemCount: 0 ⇒ شبكة خالية', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(grid(itemCount: 0));

      expect(shown(tester), 0);
      expect(find.textContaining('خ'), findsNothing);
    });

    testWidgets('rowCount يحدّ المعروض بعدد الصفوف × الأعمدة', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        grid(
          cfg: const GridConfig(
            itemWidth: 160.0,
            itemHeight: 200.0,
            rowCount: 1,
          ),
        ),
      );
      // (400 + 12) / 172 = 2.39 ⇒ 2 عمود × صفّ واحد
      expect(columns(tester), 2);
      expect(shown(tester), 2);
    });

    testWidgets('rowCount: 0 ⇒ لا يُعرض شيء', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        grid(
          cfg: const GridConfig(
            itemWidth: 160.0,
            itemHeight: 200.0,
            rowCount: 0,
          ),
        ),
      );
      expect(shown(tester), 0);
    });

    testWidgets('rowCount سالب يُقصّ إلى صفر لا إلى قيمة سالبة', (
      tester,
    ) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        grid(
          cfg: const GridConfig(
            itemWidth: 160.0,
            itemHeight: 200.0,
            rowCount: -3,
          ),
        ),
      );
      expect(shown(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rowCount أكبر من المتاح لا يتجاوز itemCount', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(
        grid(
          cfg: const GridConfig(
            itemWidth: 160.0,
            itemHeight: 200.0,
            rowCount: 99,
          ),
          itemCount: 5,
        ),
      );
      expect(shown(tester), 5);
    });

    testWidgets('childAspectRatio = العرض ÷ الارتفاع', (tester) async {
      expect(
        const GridConfig(itemWidth: 160.0, itemHeight: 200.0).childAspectRatio,
        0.8,
      );
      expect(
        const GridConfig(itemWidth: 100.0, itemHeight: 100.0).childAspectRatio,
        1.0,
      );
    });

    testWidgets(
      'minCrossAxisCount: 0 لا ينهار على الشاشات الضيّقة',
      (tester) async {
        _fixScreen(tester);
        await tester.pumpWidget(
          grid(
            cfg: const GridConfig(
              itemWidth: 160.0,
              itemHeight: 200.0,
              minCrossAxisCount: 0,
            ),
            width: 30.0,
          ),
        );
        expect(tester.takeException(), isNull);
      },
      // يحرس انحداراً: بلا رفع الحدّ الأدنى إلى 1 يصير crossAxisCount صفراً
      // فينفجر assert داخل SliverGridDelegateWithFixedCrossAxisCount.
    );

    testWidgets(
      'min > max يُرفض عند إنشاء GridConfig برسالة واضحة',
      (tester) async {
        expect(
          () => GridConfig(
            itemWidth: 160.0,
            itemHeight: 200.0,
            minCrossAxisCount: 6,
            maxCrossAxisCount: 2,
          ),
          throwsAssertionError,
        );
      },
      // الخطأ عند الإنشاء بدل ArgumentError غامض من clamp أثناء البناء.
    );

    testWidgets(
      'itemWidth: 0 يُرفض عند إنشاء GridConfig',
      (tester) async {
        expect(
          () => GridConfig(itemWidth: 0.0, itemHeight: 200.0),
          throwsAssertionError,
        );
      },
      // بلا هذا الحارس ينفجر المدخل لاحقاً على assert(childAspectRatio > 0)
      // داخل مندوب الشبكة — بعيداً عن موضع الخطأ الحقيقي.
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('PageIndicator', () {
    const Color dot = Color(0xFF9E9E9E);
    const Color active = Color(0xFF3355FF);

    Finder dots() => find.descendant(
      of: find.byType(PageIndicator),
      matching: find.byType(GestureDetector),
    );

    Widget indicator({
      required PageController controller,
      required int count,
      VoidCallback? onDotClicked,
      Axis axis = Axis.horizontal,
      bool fillPreviousDots = false,
      Duration animationDuration = Duration.zero,
    }) => _app(
      Center(
        child: PageIndicator(
          controller: controller,
          count: count,
          dotColor: dot,
          activeDotColor: active,
          onDotClicked: onDotClicked,
          axis: axis,
          fillPreviousDots: fillPreviousDots,
          animationDuration: animationDuration,
        ),
      ),
    );

    /// شجرة فيها `PageView` حقيقي كي يصير للمتحكّم `page` و`hasClients`.
    Widget withPageView(PageController controller, int count,
            {bool fillPreviousDots = false,
            Duration animationDuration = Duration.zero}) =>
        _app(
          Column(
            children: <Widget>[
              SizedBox(
                height: 200.0,
                child: PageView(
                  controller: controller,
                  children: List<Widget>.generate(
                    count,
                    (int i) => Center(child: Text('ص$i')),
                  ),
                ),
              ),
              PageIndicator(
                controller: controller,
                count: count,
                dotColor: dot,
                activeDotColor: active,
                fillPreviousDots: fillPreviousDots,
                animationDuration: animationDuration,
              ),
            ],
          ),
        );

    List<Size> dotSizes(WidgetTester tester) => <Size>[
      for (int i = 0; i < dots().evaluate().length; i++)
        tester.getSize(dots().at(i)),
    ];

    List<Color> dotColors(WidgetTester tester) => tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(PageIndicator),
            matching: find.byType(Container),
          ),
        )
        .map((Container c) => (c.decoration! as BoxDecoration).color!)
        .toList();

    testWidgets('count == 0 ⇒ لا شيء يُرسم', (tester) async {
      _fixScreen(tester);
      final PageController controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(indicator(controller: controller, count: 0));

      expect(dots(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PageIndicator),
          matching: find.byType(Flex),
        ),
        findsNothing,
      );
      expect(tester.getSize(find.byType(PageIndicator)), Size.zero);
      expect(tester.takeException(), isNull);
    });

    testWidgets('count سالب ⇒ لا شيء يُرسم', (tester) async {
      _fixScreen(tester);
      final PageController controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(indicator(controller: controller, count: -5));

      expect(dots(), findsNothing);
      expect(tester.getSize(find.byType(PageIndicator)), Size.zero);
    });

    testWidgets('count == 1 ⇒ نقطة واحدة موسّعة بلا فواصل', (tester) async {
      _fixScreen(tester);
      final PageController controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(indicator(controller: controller, count: 1));

      expect(dots(), findsOneWidget);
      expect(dotSizes(tester).single, const Size(32.0, 8.0));
      expect(tester.getSize(find.byType(PageIndicator)).width, 32.0);
    });

    testWidgets('count == 3 ⇒ النقطة الأولى نشطة وموسّعة والباقي صغير', (
      tester,
    ) async {
      _fixScreen(tester);
      final PageController controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(indicator(controller: controller, count: 3));

      expect(dots(), findsNWidgets(3));
      expect(dotSizes(tester), const <Size>[
        Size(32.0, 8.0),
        Size(8.0, 8.0),
        Size(8.0, 8.0),
      ]);
      expect(dotColors(tester), const <Color>[active, dot, dot]);
      // 2×(8+8) + 32 = 64
      expect(tester.getSize(find.byType(PageIndicator)).width, 64.0);
    });

    testWidgets('initialPage غير الصفر يجعل النقطة المقابلة هي النشطة', (
      tester,
    ) async {
      _fixScreen(tester);
      final PageController controller = PageController(initialPage: 2);
      addTearDown(controller.dispose);

      await tester.pumpWidget(indicator(controller: controller, count: 4));

      expect(dotSizes(tester)[2], const Size(32.0, 8.0));
      expect(dotColors(tester)[2], active);
      expect(dotColors(tester)[0], dot);
    });

    testWidgets('المحور العمودي يقلب الأبعاد', (tester) async {
      _fixScreen(tester);
      final PageController controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        indicator(controller: controller, count: 3, axis: Axis.vertical),
      );

      expect(dotSizes(tester).first, const Size(8.0, 32.0));
      expect(tester.getSize(find.byType(PageIndicator)).height, 64.0);
    });

    testWidgets('النقر على نقطة يستدعي onDotClicked', (tester) async {
      _fixScreen(tester);
      final PageController controller = PageController();
      addTearDown(controller.dispose);
      int taps = 0;

      await tester.pumpWidget(
        indicator(controller: controller, count: 3, onDotClicked: () => taps++),
      );
      await tester.tap(dots().at(1));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('بلا onDotClicked النقر لا يرمي', (tester) async {
      _fixScreen(tester);
      final PageController controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(indicator(controller: controller, count: 3));
      await tester.tap(dots().first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('الانتقال بين الصفحات ينقل النقطة النشطة', (tester) async {
      _fixScreen(tester);
      final PageController controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(withPageView(controller, 3));
      await tester.pumpAndSettle();
      expect(dotColors(tester), const <Color>[active, dot, dot]);

      controller.jumpToPage(1);
      await tester.pumpAndSettle();

      expect(dotColors(tester), const <Color>[dot, active, dot]);
      expect(dotSizes(tester)[1], const Size(32.0, 8.0));
    });

    testWidgets('fillPreviousDots يلوّن السابقات بلون النشط وبحجم صغير', (
      tester,
    ) async {
      _fixScreen(tester);
      final PageController controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        withPageView(controller, 4, fillPreviousDots: true),
      );
      await tester.pumpAndSettle();

      controller.jumpToPage(2);
      await tester.pumpAndSettle();

      expect(dotColors(tester), const <Color>[active, active, active, dot]);
      expect(dotSizes(tester), const <Size>[
        Size(8.0, 8.0),
        Size(8.0, 8.0),
        Size(32.0, 8.0),
        Size(8.0, 8.0),
      ]);
    });

    testWidgets(
      'animationDuration يتحكّم في مدّة الانتقال',
      (tester) async {
        _fixScreen(tester);
        final PageController controller = PageController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          withPageView(
            controller,
            3,
            animationDuration: const Duration(milliseconds: 1200),
          ),
        );
        await tester.pumpAndSettle();

        controller.jumpToPage(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // نصف المدّة المطلوبة فقط ⇒ لا يجوز أن يكون الانتقال قد اكتمل
        expect(dotSizes(tester)[1].width, lessThan(32.0));
        await tester.pumpAndSettle();
      },
      // يحرس انحداراً: _DotState كان يثبّت 400ms في initState ويتجاهل الوسيط.
    );

    testWidgets(
      'عدد صفحات كبير لا يُفيض التخطيط',
      (tester) async {
        _fixScreen(tester);
        final PageController controller = PageController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(indicator(controller: controller, count: 60));
        expect(tester.takeException(), isNull);
      },
      // يحرس انحداراً: totalSize = (count-1)×(dotSize+spacing)+expandedSize
      // يتجاوز عرض الشاشة، فبلا تصغيرٍ يرمي RenderFlex overflow.
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('showToast', () {
    setUp(() {
      // FToast مفردٌ ساكن: تنظيفه بين الاختبارات يمنع تسرّب حالةٍ بينها.
      try {
        FToast().removeQueuedCustomToasts();
      } on Object catch (_) {
        // لا شيء — الشجرة قد تكون أُزيلت أصلاً
      }
      FToast().context = null;
      Fluttertoast.isCurrentlyShowingToast = false;
    });

    testWidgets('بلا سياق: لا يرمي ولو غاب الـ plugin', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(_app(const SizedBox.shrink()));

      expect(() => showToast('تم الحفظ'), returnsNormally);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('نصّ فارغ بلا سياق لا يرمي', (tester) async {
      _fixScreen(tester);
      await tester.pumpWidget(_app(const SizedBox.shrink()));

      expect(() => showToast(''), returnsNormally);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('مع سياق: يعرض التوست الغنيّ بنصّه', (tester) async {
      _fixScreen(tester);
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      showToast('تم الحفظ بنجاح', context: ctx);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('تم الحفظ بنجاح'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('success: true يضيف أيقونة صحّ خضراء', (tester) async {
      _fixScreen(tester);
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      showToast('نجحت العملية', context: ctx, success: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.check_circle_rounded);
      expect(icon.color, const Color(0xFF34C759));

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('أيقونة مخصّصة تتقدّم على أيقونة النجاح', (tester) async {
      _fixScreen(tester);
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      showToast(
        'تنبيه',
        context: ctx,
        success: true,
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFFFA000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.warning_amber_rounded);
      expect(icon.color, const Color(0xFFFFA000));

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('نصّ عربي طويل جداً لا يُفيض التوست', (tester) async {
      _fixScreen(tester);
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      showToast('تعذّر إتمام العملية، ' * 30, context: ctx);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('سياق غير مركّب يسقط إلى توست النظام بلا رمي', (tester) async {
      _fixScreen(tester);
      late BuildContext stale;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext c) {
              stale = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // إزالة الشجرة: السياق يصير غير مركّب (النمط الشائع: احفظ ← توست ← pop)
      await tester.pumpWidget(_app(const Text('شاشة أخرى')));
      expect(stale.mounted, isFalse);

      expect(() => showToast('بعد الإغلاق', context: stale), returnsNormally);
      await tester.pump();

      expect(find.text('بعد الإغلاق'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('isLong يمدّ العرض إلى 4 ثوانٍ بدل 2', (tester) async {
      _fixScreen(tester);
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      showToast('رسالة طويلة', context: ctx, isLong: true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('رسالة طويلة'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('رسالة طويلة'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('السياق يُحرَّر من مفرد FToast بعد انتهاء العرض', (
      tester,
    ) async {
      _fixScreen(tester);
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      showToast('محتجز', context: ctx);
      await tester.pump();
      expect(FToast().context, isNotNull);

      // مدّة العرض (2ث) + ثانية الأمان
      await tester.pump(const Duration(seconds: 4));
      expect(
        FToast().context,
        isNull,
        reason: 'بقاؤه يحتجز شجرة الشاشة كلّها بعد إغلاقها',
      );
    });

    testWidgets(
      'السياق يُحرَّر حتّى لو سبقه توست نظام فاشل',
      (tester) async {
        _fixScreen(tester);
        late BuildContext ctx;
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (BuildContext c) {
                ctx = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // توست نظام على منصّة بلا plugin (سطح مكتب/اختبار): يفشل بصمت
        showToast('نظام');
        await tester.pump();

        showToast('غنيّ', context: ctx);
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));

        expect(FToast().context, isNull);
      },
      // يحرس انحداراً: الحزمة ترفع isCurrentlyShowingToast قبل نداء القناة
      // ولا تخفضه حين يفشل النداء، فبلا إعادة العلم يسقط تحرير السياق أبداً
      // على المنصّات غير المدعومة.
    );
  });
}
