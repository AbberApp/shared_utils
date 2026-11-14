import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// حالة [CustomTimerController] — يقرؤها التطبيق من `state.value`.
enum CustomTimerState {
  /// لم يبدأ العدّ، أو أعاده [CustomTimerController.reset]: المتبقّي `begin`.
  reset,

  /// يعدّ الآن.
  counting,

  /// بلغ `end`: المتبقّي `end` والعدّ متوقّف.
  finished,
}

/// كم مرّةً يُحدَّث المتبقّي ويُشعَر المستمعون.
///
/// قيمةٌ واحدة لأنّها وحدها ما تمرّره التطبيقات أو تتركه افتراضياً، والمعامل
/// باقٍ لتوافق المصدر. وحُذف `seconds` و`minutes` إذ لم يستعملهما أحد.
enum CustomTimerInterval {
  /// في كلّ إطار.
  milliseconds,
}

/// الوقت المتبقّي — أو المنقضي في العدّ التصاعديّ — كما يتلقّاه `builder`.
@immutable
class CustomTimerRemainingTime {
  const CustomTimerRemainingTime({required this.duration});

  /// المدّة كاملةً. وحقولها `inMinutes` وأخواتها قد تتجاوز 59، بخلاف ما يلي.
  final Duration duration;

  /// الساعات بخانتين، بعد طرح الأيّام: `25:00:00` تُعرض `01`.
  String get hours => _twoDigits(duration.inHours.remainder(24));

  /// الدقائق بخانتين: `00`–`59`.
  String get minutes => _twoDigits(duration.inMinutes.remainder(60));

  /// الثواني بخانتين، والكسر محذوف: `34.9` تُعرض `34`.
  String get seconds => _twoDigits(duration.inSeconds.remainder(60));

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

/// متحكّم مؤقّتٍ يعدّ من `begin` إلى `end` — تنازلياً إن كان `begin` أكبر،
/// وتصاعدياً إن كان أصغر.
///
/// بديلٌ محلّيّ لحزمة `custom_timer` 0.2.3: مئتان وثمانية وسبعون سطراً لم
/// تُحدَّث منذ 2023-01، وقيدُها `sdk: <3.0.0` يستثني Dart 3 على الورق. ولم
/// تستعمل التطبيقات منها إلّا مؤقّتَ إعادة الإرسال في شاشة رمز التحقّق (سبعة
/// تطبيقات) والعدَّ إلى موعد البثّ في بطاقته (عبر ومنام).
///
/// **التواقيع مطابقةٌ لما تستعمله التطبيقات** — المُنشئ بمعاملاته وقيمه
/// الافتراضية، و[start] و[reset]، و`state.value` و`remaining.value`،
/// و`CustomTimer(controller:, builder:)` — فلا يُمسّ سطرٌ فيها. وما لم يستعمله
/// أحدٌ حُذف: `pause` و`finish` و`jumpTo` و`add` و`subtract`، وضابطا `begin`
/// و`end`، وحالة `paused`.
///
/// ```dart
/// _timerController = CustomTimerController(
///   vsync: this,
///   begin: const Duration(seconds: 35),
///   end: const Duration(),
///   initialState: CustomTimerState.finished,
///   interval: CustomTimerInterval.milliseconds,
/// );
/// _timerController.addListener(() {
///   if (_timerController.remaining.value.duration == Duration.zero) {
///     setState(() {});
///   }
/// });
///
/// // عند إرسال الرمز:
/// _timerController
///   ..reset()
///   ..start();
/// ```
///
/// **والفوارق عن الحزمة مقصودة:**
///
/// * **الزمن حقيقيٌّ ولو أُطفئت الحركات.** كانت الحزمة تبني على
///   `AnimationController` بسلوكه الافتراضيّ، وهو يقصّر مدّته عشرين ضعفاً متى
///   طلب الجهاز إطفاء الحركات (`disableAnimations`، ومنه «إزالة الرسوم
///   المتحرّكة» في أندرويد) — فينتهي مؤقّت الخمس والثلاثين ثانية في ثانيةٍ
///   وثلاثة أرباع ويُفتح زرّ إعادة الإرسال. والآن `Ticker` مباشرةً.
/// * **`begin == end` ينتهي فوراً.** كانت الحزمة تُتمّ الحركة الصفرية داخل
///   `start()` ثمّ تكتب فوقها `counting`، فيبقى المؤقّت «يعدّ» إلى الأبد —
///   وهي حال بطاقة بثٍّ فات موعده.
/// * **الانتهاء إشعارٌ واحدٌ متّسق:** المتبقّي `end` والحالة `finished` معاً.
///   كانت الحزمة تُشعر بالصفر والحالة ما زالت `counting`، ثمّ بالانتهاء.
/// * **[state] و[remaining] للقراءة وحدها** (`ValueListenable`). كانتا
///   `ValueNotifier` يكتب فيهما أيّ أحدٍ فيفصلهما عن المؤقّت. والقراءة
///   بـ`.value` كما هي.
/// * **[dispose] يُغلق كلّ شيء:** الـ`Ticker` والمُبلِّغَين الداخليَّين، وكانت
///   الحزمة تتركهما. و[start] أو [reset] بعده خطأٌ صريح في وضع التطوير، ولا
///   شيء في الإصدار — فلا يُبعث مؤقّتٌ بعد موت صاحبه.
/// * **مدّةٌ سالبة ترمي [ArgumentError]** بدل أرقامٍ كـ`-5` في الواجهة.
class CustomTimerController extends ChangeNotifier {
  /// [vsync] مزوّد الإطارات — `this` في `State` يمزج
  /// `SingleTickerProviderStateMixin`، ولا يُطلب منه إلّا `Ticker` واحد.
  ///
  /// [initialState]: `reset` (الافتراضيّ) ينتظر [start]، و`counting` يبدأ
  /// فوراً، و`finished` يبدأ منتهياً والمتبقّي `end`.
  ///
  /// [interval] باقٍ لتوافق المصدر؛ انظر [CustomTimerInterval].
  ///
  /// يرمي [ArgumentError] إن كان [begin] أو [end] سالباً.
  CustomTimerController({
    required TickerProvider vsync,
    required Duration begin,
    required Duration end,
    CustomTimerState initialState = CustomTimerState.reset,
    CustomTimerInterval interval = CustomTimerInterval.milliseconds,
  }) : _begin = _notNegative(begin, 'begin'),
       _end = _notNegative(end, 'end'),
       _state = ValueNotifier<CustomTimerState>(
         initialState == CustomTimerState.finished
             ? CustomTimerState.finished
             : CustomTimerState.reset,
       ),
       _remaining = ValueNotifier<CustomTimerRemainingTime>(
         CustomTimerRemainingTime(
           duration: initialState == CustomTimerState.finished ? end : begin,
         ),
       ) {
    _ticker = vsync.createTicker(_tick);
    if (initialState == CustomTimerState.counting) start();
  }

  final Duration _begin;
  final Duration _end;
  final ValueNotifier<CustomTimerState> _state;
  final ValueNotifier<CustomTimerRemainingTime> _remaining;
  late final Ticker _ticker;
  bool _disposed = false;

  /// الحالة الآن.
  ValueListenable<CustomTimerState> get state => _state;

  /// الوقت المتبقّي الآن.
  ValueListenable<CustomTimerRemainingTime> get remaining => _remaining;

  bool get _countsDown => _begin > _end;

  /// المسافة بين الطرفين — مدّة العدّ كاملاً.
  Duration get _span => _countsDown ? _begin - _end : _end - _begin;

  /// يبدأ العدّ من `begin`.
  ///
  /// من `reset` أو `finished` يبدأ من أوّله. وأثناء العدّ لا يفعل شيئاً — كما
  /// كان أثره في الحزمة: يُكمل من حيث هو.
  void start() {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    if (_disposed || _state.value == CustomTimerState.counting) return;
    if (_span == Duration.zero) {
      _finish();
      return;
    }
    _ticker.start();
    _remaining.value = CustomTimerRemainingTime(duration: _begin);
    _state.value = CustomTimerState.counting;
    notifyListeners();
  }

  /// يوقف العدّ ويُعيد المتبقّي إلى `begin` والحالة إلى `reset`.
  void reset() {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    if (_disposed) return;
    _ticker.stop();
    _remaining.value = CustomTimerRemainingTime(duration: _begin);
    _state.value = CustomTimerState.reset;
    notifyListeners();
  }

  /// [elapsed] منذ أوّل إطارٍ بعد [start] — زمنٌ حقيقيّ لا يتأثّر بإطفاء
  /// الحركات.
  void _tick(Duration elapsed) {
    if (elapsed >= _span) {
      _finish();
      return;
    }
    _remaining.value = CustomTimerRemainingTime(
      duration: _countsDown ? _begin - elapsed : _begin + elapsed,
    );
    notifyListeners();
  }

  /// المتبقّي قبل الحالة: من يستمع إلى [state] فيرى `finished` يجد المتبقّي
  /// `end` سلفاً.
  void _finish() {
    _ticker.stop();
    _remaining.value = CustomTimerRemainingTime(duration: _end);
    _state.value = CustomTimerState.finished;
    notifyListeners();
  }

  @override
  void dispose() {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    _disposed = true;
    _ticker.dispose();
    _state.dispose();
    _remaining.dispose();
    super.dispose();
  }

  static Duration _notNegative(Duration value, String name) {
    if (value.isNegative) {
      throw ArgumentError.value(value, name, 'must not be negative');
    }
    return value;
  }
}

/// يعرض مؤقّت [controller] بـ[builder]، ويُعيد البناء مع كلّ إشعارٍ منه.
///
/// يتبع المتحكّم إن تبدّل: كانت الحزمة تحفظ أوّلَ متحكّمٍ في حقلٍ `late` فتبقى
/// مستمعةً إليه — ولو أُغلق — وتتجاهل الجديد، فيتجمّد الرقم المعروض.
class CustomTimer extends StatelessWidget {
  const CustomTimer({
    super.key,
    required this.controller,
    required this.builder,
  });

  /// المتحكّم الذي يملكه الأب ويُغلقه في `dispose`.
  final CustomTimerController controller;

  /// يتلقّى الحالة والمتبقّي: `(state, time) => Text('${time.minutes}:${time.seconds}')`.
  final Widget Function(CustomTimerState, CustomTimerRemainingTime) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) =>
          builder(controller.state.value, controller.remaining.value),
    );
  }
}
