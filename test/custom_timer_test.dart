import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_utils/shared_utils.dart';

/// اختبار `CustomTimer` — البديل المحلّيّ لحزمة `custom_timer`.
///
/// يحرس **تطابقَ التواقيع** مع ما تستعمله التطبيقات، و**الدلالةَ** التي تبني
/// عليها شاشة رمز التحقّق: العدّ يتقدّم، والانتهاء يُطفئ زرّ الانتظار، و`reset`
/// يُعيد البداية — ثمّ **ألّا يبقى مؤقّتٌ معلّقٌ** بعد `dispose`، وهو ما يُفشل
/// به `flutter_test` الاختبارَ إن وقع.
///
/// ملاحظة على الأسلوب: الـ`Ticker` يحسب الزمن من أوّل إطارٍ بعد `start()`. فإن
/// نُودي خارج إطار — من جسم الاختبار — لزم `pump()` قبل `pump(Duration)` كي
/// يُحسب الزمن من لحظةٍ معلومة. والمتحكّم المبنيّ في `initState` يبدأ من إطار
/// `pumpWidget` نفسه.
void main() {
  group('تواقيع الحزمة كما تستعملها التطبيقات — لا يجوز أن تنحرف', () {
    testWidgets('المُنشئان بمعاملاتهما، والقيم الافتراضية', (tester) async {
      // إسنادٌ إلى نوعٍ صريح: لو تغيّر اسمٌ أو نوعٌ أو صار معاملٌ اختياريّ
      // إلزامياً لما صُرّف هذا الملفّ.
      final CustomTimerController Function({
        required TickerProvider vsync,
        required Duration begin,
        required Duration end,
        CustomTimerState initialState,
        CustomTimerInterval interval,
      })
      create = CustomTimerController.new;
      final CustomTimer Function({
        Key? key,
        required CustomTimerController controller,
        required Widget Function(CustomTimerState, CustomTimerRemainingTime)
        builder,
      })
      widget = CustomTimer.new;

      // بلا initialState ولا interval: `reset` والمتبقّي `begin` ولا عدّ.
      final CustomTimerController c = create(
        vsync: const TestVSync(),
        begin: const Duration(seconds: 35),
        end: const Duration(),
      );
      final ValueListenable<CustomTimerState> state = c.state;
      final ValueListenable<CustomTimerRemainingTime> remaining = c.remaining;
      // `addListener` و`removeListener` من `ChangeNotifier`، كما في التطبيقات.
      int notified = 0;
      void listener() => notified++;
      c
        ..addListener(listener)
        ..reset()
        ..removeListener(listener)
        ..reset();
      expect(notified, 1);
      expect(state.value, CustomTimerState.reset);
      expect(remaining.value.duration, const Duration(seconds: 35));
      expect(tester.binding.transientCallbackCount, 0);

      // الحقول الأربعة التي تقرؤها التطبيقات من المتبقّي، بأنواعها.
      final Duration duration = remaining.value.duration;
      final String hours = remaining.value.hours;
      final String minutes = remaining.value.minutes;
      final String seconds = remaining.value.seconds;
      expect(<Object>[duration, hours, minutes, seconds], hasLength(4));

      // القيم التي تكتبها التطبيقات صراحةً.
      expect(<Object>[
        CustomTimerState.reset,
        CustomTimerState.counting,
        CustomTimerState.finished,
        CustomTimerInterval.milliseconds,
      ], hasLength(4));

      await tester.pumpWidget(
        _ltr(
          widget(
            controller: c,
            builder: (_, CustomTimerRemainingTime time) =>
                Text('${time.minutes}:${time.seconds}'),
          ),
        ),
      );
      expect(find.text('00:35'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  });

  group('CustomTimerRemainingTime — خانتان لكلّ حقل', () {
    test('تُملأ بالأصفار', () {
      const CustomTimerRemainingTime t = CustomTimerRemainingTime(
        duration: Duration(seconds: 5),
      );
      expect(<String>[t.hours, t.minutes, t.seconds], <String>['00', '00', '05']);
    });

    test('كلّ حقلٍ باقي ما فوقه — والساعات بعد طرح الأيّام كما في الحزمة', () {
      const CustomTimerRemainingTime t = CustomTimerRemainingTime(
        duration: Duration(hours: 25, minutes: 3, seconds: 4),
      );
      expect(<String>[t.hours, t.minutes, t.seconds], <String>['01', '03', '04']);
      expect(t.duration, const Duration(hours: 25, minutes: 3, seconds: 4));
    });

    test('الكسر محذوفٌ لا مُقرَّب', () {
      const CustomTimerRemainingTime t = CustomTimerRemainingTime(
        duration: Duration(minutes: 1, seconds: 59, milliseconds: 999),
      );
      expect('${t.minutes}:${t.seconds}', '01:59');
    });
  });

  group('العدّ', () {
    testWidgets('شاشة رمز التحقّق: من الانتهاء إلى العدّ إلى الانتهاء', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(hideWhenIdle: true));
      final _HostState host = _host(tester);
      final CustomTimerController c = host.controller;

      // `initialState: finished`: المتبقّي `end` وزرّ الإرسال ظاهر.
      expect(c.state.value, CustomTimerState.finished);
      expect(c.remaining.value.duration, Duration.zero);
      expect(find.text(_Host.idle), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);

      host.resend();
      await tester.pump();
      expect(find.text('00:35'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:34'), findsOneWidget);

      await tester.pump(const Duration(seconds: 33));
      expect(find.text('00:01'), findsOneWidget);
      expect(c.state.value, CustomTimerState.counting);

      // الصفر يُعيد بناء الشاشة من مستمِعها فيختفي المؤقّت ويعود الزرّ.
      await tester.pump(const Duration(seconds: 1));
      expect(c.state.value, CustomTimerState.finished);
      expect(c.remaining.value.duration, Duration.zero);
      expect(find.byType(CustomTimer), findsNothing);
      expect(find.text(_Host.idle), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0, reason: 'العدّ توقّف');

      // إعادة الإرسال بعد الانتهاء — `reset()..start()` — تبدأ من أوّلها.
      host.resend();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:34'), findsOneWidget);
    });

    testWidgets('builder يتلقّى الحالة والمتبقّي الصحيحين', (tester) async {
      await tester.pumpWidget(
        const _Host(
          begin: Duration(seconds: 10),
          initialState: CustomTimerState.reset,
        ),
      );
      final _HostState host = _host(tester);
      expect(host.built.last, (CustomTimerState.reset, const Duration(seconds: 10)));

      host.controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));
      expect(host.built.last, (
        CustomTimerState.counting,
        const Duration(milliseconds: 7500),
      ));
      expect(find.text('00:07'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 7500));
      expect(host.built.last, (CustomTimerState.finished, Duration.zero));
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('begin < end: عدٌّ تصاعديّ ينتهي عند end', (tester) async {
      await tester.pumpWidget(
        const _Host(
          begin: Duration.zero,
          end: Duration(seconds: 10),
          initialState: CustomTimerState.reset,
        ),
      );
      final CustomTimerController c = _host(tester).controller;

      c.start();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(c.remaining.value.duration, const Duration(seconds: 3));
      expect(find.text('00:03'), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      expect(c.state.value, CustomTimerState.finished);
      expect(c.remaining.value.duration, const Duration(seconds: 10));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('الانتهاء إشعارٌ واحد: الصفر والحالة finished معاً', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host());
      final CustomTimerController c = _host(tester).controller;
      final List<CustomTimerState> atZero = <CustomTimerState>[];
      void listener() {
        if (c.remaining.value.duration == Duration.zero) {
          atZero.add(c.state.value);
        }
      }

      c
        ..addListener(listener)
        ..reset()
        ..start();
      await tester.pump();
      await tester.pump(const Duration(seconds: 35));
      // الحزمة كانت تُشعر بالصفر والحالة `counting`، ثمّ بالانتهاء.
      expect(atZero, <CustomTimerState>[CustomTimerState.finished]);
      c.removeListener(listener);
    });

    testWidgets('initialState: counting — بطاقة البثّ تعدّ من إطارها الأوّل', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(
          begin: Duration(hours: 2, minutes: 5, seconds: 7),
          initialState: CustomTimerState.counting,
          showHours: true,
        ),
      );
      final CustomTimerController c = _host(tester).controller;
      expect(c.state.value, CustomTimerState.counting);
      expect(find.text('02:05:07'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('02:05:06'), findsOneWidget);
      await tester.pump(const Duration(minutes: 5, seconds: 7));
      expect(find.text('01:59:59'), findsOneWidget);
    });

    testWidgets('begin == end ينتهي فوراً — لا «يعدّ» إلى الأبد', (tester) async {
      // بطاقة بثٍّ فات موعده: begin يُقصّ إلى الصفر.
      await tester.pumpWidget(
        const _Host(
          begin: Duration.zero,
          initialState: CustomTimerState.counting,
          showHours: true,
        ),
      );
      final CustomTimerController c = _host(tester).controller;
      expect(c.state.value, CustomTimerState.finished);
      expect(c.remaining.value.duration, Duration.zero);
      expect(find.text('00:00:00'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);

      // ومن `reset` كذلك.
      c.reset();
      expect(c.state.value, CustomTimerState.reset);
      c.start();
      expect(c.state.value, CustomTimerState.finished);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('reset و start', () {
    testWidgets('reset أثناء العدّ يُعيد begin ويوقف العدّ', (tester) async {
      await tester.pumpWidget(
        const _Host(initialState: CustomTimerState.counting),
      );
      final CustomTimerController c = _host(tester).controller;
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('00:30'), findsOneWidget);

      c.reset();
      await tester.pump();
      expect(c.state.value, CustomTimerState.reset);
      expect(c.remaining.value.duration, const Duration(seconds: 35));
      expect(find.text('00:35'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('00:35'), findsOneWidget, reason: 'لا عدّ بعد reset');

      c.start();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:33'), findsOneWidget);
    });

    testWidgets('start أثناء العدّ لا يُعيده من أوّله', (tester) async {
      await tester.pumpWidget(
        const _Host(initialState: CustomTimerState.counting),
      );
      final CustomTimerController c = _host(tester).controller;
      await tester.pump(const Duration(seconds: 5));

      c.start();
      await tester.pump(const Duration(seconds: 1));
      expect(c.state.value, CustomTimerState.counting);
      expect(c.remaining.value.duration, const Duration(seconds: 29));
    });
  });

  group('الإصلاحات عن الحزمة', () {
    testWidgets('إطفاء الحركات لا يُسرّع المؤقّت', (tester) async {
      debugSemanticsDisableAnimations = true;
      addTearDown(() => debugSemanticsDisableAnimations = null);

      // الأصل الذي بنت عليه الحزمة: يقصّر مدّته عشرين ضعفاً.
      final AnimationController animation = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 35),
      );
      await tester.pumpWidget(const _Host());
      final CustomTimerController c = _host(tester).controller;

      animation.forward();
      c.start();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(animation.isCompleted, isTrue, reason: '35 ثانية × 0.05 = 1.75');
      expect(c.state.value, CustomTimerState.counting);
      expect(c.remaining.value.duration, const Duration(seconds: 33));
      animation.dispose();
    });

    testWidgets('CustomTimer يتبع المتحكّم الجديد ويترك القديم', (tester) async {
      final CustomTimerController first = CustomTimerController(
        vsync: const TestVSync(),
        begin: const Duration(seconds: 10),
        end: Duration.zero,
      );
      final CustomTimerController second = CustomTimerController(
        vsync: const TestVSync(),
        begin: const Duration(seconds: 20),
        end: Duration.zero,
      );
      Widget timer(CustomTimerController controller) => _ltr(
        CustomTimer(
          controller: controller,
          builder: (_, CustomTimerRemainingTime time) =>
              Text('${time.minutes}:${time.seconds}'),
        ),
      );

      await tester.pumpWidget(timer(first));
      expect(find.text('00:10'), findsOneWidget);

      await tester.pumpWidget(timer(second));
      expect(find.text('00:20'), findsOneWidget);

      // الحزمة كانت ما تزال مستمعةً إلى الأوّل فيتجمّد الرقم على 00:10.
      first.dispose();
      second.start();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:19'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      second.dispose();
    });

    testWidgets('dispose أثناء العدّ لا يترك مؤقّتاً ولا مُبلِّغاً مفتوحاً', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(initialState: CustomTimerState.counting),
      );
      final CustomTimerController c = _host(tester).controller;
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, greaterThan(0), reason: 'يعدّ الآن');

      // إزالة الشاشة تُغلق المتحكّم في dispose كما في التطبيقات.
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);

      // المُبلِّغان الداخليّان مُغلقان — كانت الحزمة تتركهما.
      expect(() => c.state.addListener(() {}), throwsFlutterError);
      expect(() => c.remaining.addListener(() {}), throwsFlutterError);

      // الاستعمال بعد الإغلاق خطأٌ صريح في وضع التطوير، ولا يُبعث مؤقّت.
      expect(c.start, throwsFlutterError);
      expect(c.reset, throwsFlutterError);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
    });

    test('مدّةٌ سالبة ترمي ArgumentError', () {
      expect(
        () => CustomTimerController(
          vsync: const TestVSync(),
          begin: const Duration(seconds: -1),
          end: Duration.zero,
        ),
        throwsArgumentError,
      );
      expect(
        () => CustomTimerController(
          vsync: const TestVSync(),
          begin: Duration.zero,
          end: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });
  });
}

Widget _ltr(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

_HostState _host(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host));

/// يحاكي شاشة رمز التحقّق حرفياً: المتحكّم يُبنى في `initState` بمزج
/// `SingleTickerProviderStateMixin` ويُغلق في `dispose`، والمستمِع يُعيد البناء
/// عند الصفر، و[hideWhenIdle] يُظهر المؤقّت أثناء العدّ وحده.
class _Host extends StatefulWidget {
  const _Host({
    this.begin = const Duration(seconds: 35),
    this.end = Duration.zero,
    this.initialState = CustomTimerState.finished,
    this.hideWhenIdle = false,
    this.showHours = false,
  });

  static const String idle = 'إعادة الإرسال';

  final Duration begin;
  final Duration end;
  final CustomTimerState initialState;
  final bool hideWhenIdle;

  /// صيغة بطاقة البثّ `hh:mm:ss` بدل صيغة التحقّق `mm:ss`.
  final bool showHours;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final CustomTimerController controller;

  /// كلّ ما تلقّاه `builder`، بترتيبه.
  final List<(CustomTimerState, Duration)> built =
      <(CustomTimerState, Duration)>[];

  @override
  void initState() {
    super.initState();
    controller = CustomTimerController(
      vsync: this,
      begin: widget.begin,
      end: widget.end,
      initialState: widget.initialState,
      interval: CustomTimerInterval.milliseconds,
    );
    controller.addListener(_onTimerTick);
  }

  void _onTimerTick() {
    if (controller.remaining.value.duration == Duration.zero) setState(() {});
  }

  /// زرّ «إعادة الإرسال» في التطبيقات.
  void resend() {
    controller
      ..reset()
      ..start();
    setState(() {});
  }

  @override
  void dispose() {
    controller
      ..removeListener(_onTimerTick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool counting = controller.state.value == CustomTimerState.counting;
    if (widget.hideWhenIdle && !counting) return _ltr(const Text(_Host.idle));
    return _ltr(
      CustomTimer(
        controller: controller,
        builder: (CustomTimerState state, CustomTimerRemainingTime time) {
          built.add((state, time.duration));
          return Text(
            widget.showHours
                ? '${time.hours}:${time.minutes}:${time.seconds}'
                : '${time.minutes}:${time.seconds}',
          );
        },
      ),
    );
  }
}
