import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

// [ToastGravity] يظهر في توقيع [showToast] العلنيّ، فيُصدَّر معه: وإلّا اضطُرّ
// كلّ تطبيقٍ يريد `gravity: ToastGravity.TOP` أن يضيف fluttertoast إلى
// pubspec الخاصّ به رغم أنّ المكتبة هي من فرض النوع عليه.
export 'package:fluttertoast/fluttertoast.dart' show ToastGravity;

/// خلفية التوست الموحّدة (تصميم عبر: --toast-bg #1A2530) وأخضر النجاح (#34C759).
const Color _kToastBg = Color(0xFF1A2530);
const Color _kToastSuccess = Color(0xFF34C759);

/// عرض رسالة Toast.
///
/// - بلا [context]: توست النظام النصّي (السلوك القديم — متوافق مع كل النداءات).
/// - مع [context]: توست غنيّ على شكل حبّة داكنة (تصميم ش15-توست) — نصّ أبيض
///   + ظلّ، وأيقونة صحّ خضراء عند [success] (أو [icon] مخصّصة) — بلا تلوين
///   الخلفية بالحالة (الأخضر للأيقونة فقط كما في التصميم).
///
/// عرض الإشعار لا يُسقط مسار المستدعي أبداً: إن تعذّر التوست الغنيّ (سياق
/// مُتخلَّص منه، أو غياب Overlay فوقه) سقطنا تلقائياً إلى توست النظام.
void showToast(
  String message, {
  bool isLong = false,
  ToastGravity gravity = ToastGravity.BOTTOM,
  Color backgroundColor = _kToastBg,
  Color textColor = Colors.white,
  BuildContext? context,
  bool success = false,
  IconData? icon,
  Color? iconColor,
}) {
  // حارس `mounted`: الحزمة تقرأ MediaQuery.of(context) عند الجاذبية السفلية
  // قبل أيّ فحصٍ للتركيب، فسياق شاشةٍ أُغلقت (النمط الشائع: احفظ ← توست ← pop)
  // يرمي "Looking up a deactivated widget's ancestor is unsafe".
  if (context != null && context.mounted) {
    final IconData? effectiveIcon = icon ?? (success ? Icons.check_circle_rounded : null);
    final Color effectiveIconColor = iconColor ?? (success ? _kToastSuccess : textColor);
    final Duration toastDuration = Duration(seconds: isLong ? 4 : 2);
    final FToast fToast = FToast()..init(context);
    try {
      fToast.showToast(
        gravity: gravity,
        toastDuration: toastDuration,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20.0),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 9.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20.0,
                offset: const Offset(0.0, 8.0),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (effectiveIcon != null) ...[
                Icon(effectiveIcon, size: 15.0, color: effectiveIconColor),
                const SizedBox(width: 8.0),
              ],
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(color: textColor, fontSize: 12.0, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      // الحزمة ترمي String خاماً (لا Exception) حين يتعذّر Overlay.of — وهو ما
      // لا يلتقطه `on Exception` عند المستدعي. نلتقط كلّ شيء ونسقط إلى النظام.
      _showSystemToast(
        message,
        isLong: isLong,
        gravity: gravity,
        backgroundColor: backgroundColor,
        textColor: textColor,
      );
      return;
    }
    _releaseToastContext(fToast, context, toastDuration);
    return;
  }

  _showSystemToast(
    message,
    isLong: isLong,
    gravity: gravity,
    backgroundColor: backgroundColor,
    textColor: textColor,
  );
}

/// توست المنصّة النصّي — مسار السقوط الآمن.
void _showSystemToast(
  String message, {
  required bool isLong,
  required ToastGravity gravity,
  required Color backgroundColor,
  required Color textColor,
}) {
  // الحزمة ترفع العلم الساكن [Fluttertoast.isCurrentlyShowingToast] قبل نداء
  // القناة ولا تخفضه إلّا بعد نجاحه؛ فإن رمى النداء (MissingPluginException على
  // سطح المكتب وفي الاختبارات، أو أيّ عطبٍ في القناة) بقي العلم مرفوعاً أبداً.
  // وهو العلم نفسه الذي يحرس تحرير سياق FToast أدناه، فيسقط التحرير للأبد على
  // المنصّات غير المدعومة. نحفظ قيمته قبل النداء ونعيدها عند الفشل — والحزمة
  // تكتب هذا العلم ولا تقرؤه في أيّ منطقٍ لها، فإعادته لا تغيّر سلوكها.
  final bool wasShowingToast = Fluttertoast.isCurrentlyShowingToast;
  // نداءٌ غير مُنتظَر: الحزمة تدعم android/ios/web فقط، فعلى سطح المكتب ترمي
  // MissingPluginException وتصير Future مرفوضاً غير ملتقَط يصل إلى الـ zone.
  unawaited(
    Fluttertoast.showToast(
      msg: message,
      toastLength: isLong ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
      gravity: gravity,
      timeInSecForIosWeb: isLong ? 5 : 1,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: 16.0,
    ).catchError((Object _) {
      Fluttertoast.isCurrentlyShowingToast = wasShowingToast;
      return null;
    }),
  );
}

/// سقف محاولات التحرير الإضافية بعد المحاولة الأولى (ثانية بين كلّ محاولتين).
const int _kReleaseRetries = 8;

/// تحرير الـ BuildContext من مفرد [FToast] بعد انتهاء العرض.
///
/// `FToast()` مفردٌ ساكن و`init` يسند السياق إلى حقلٍ فيه، فيبقى عنصر الشاشة
/// (وشجرتها) محتجزاً بعد إغلاقها إلى أن يُستدعى توستٌ من شاشةٍ أخرى. نحرّره
/// بشرطين يمنعان كسر طابور الحزمة: أن يكون المخزَّن سياقَنا نفسه (فلم يُعِد
/// أحدٌ التهيئة بعدنا)، وألّا يكون توستٌ قيد العرض أو في الطابور.
///
/// لكنّ علم «قيد العرض» ساكنٌ واحد تكتبه الحزمة من مسارَين: مسار الـOverlay
/// الغنيّ ومسار توست النظام. فتوستٌ نصّيّ من موضعٍ آخر (اختيار صورة، فتح
/// واتساب…) يقع داخل نافذتنا يرفع العلم فيُتخطّى التحرير — ومحاولةٌ واحدة لا
/// تكفي عندئذٍ. لذلك نعيد الكرّة كلّ ثانية بسقفٍ محدود بدل التخلّي عن التحرير.
void _releaseToastContext(FToast fToast, BuildContext context, Duration toastDuration) {
  Timer(toastDuration + const Duration(seconds: 1), () {
    if (_tryReleaseToastContext(fToast, context)) return;
    int attempts = 0;
    Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      attempts++;
      if (_tryReleaseToastContext(fToast, context) || attempts >= _kReleaseRetries) {
        timer.cancel();
      }
    });
  });
}

/// محاولةٌ واحدة للتحرير. تُعيد `true` إذا انتهى الأمر: إمّا حُرّر السياق، وإمّا
/// لم يعد المخزَّن سياقَنا (أعاد غيرُنا التهيئة، أو حُرّر أصلاً) فلا شأن لنا به.
/// وتُعيد `false` إذا كان توستٌ قيد العرض فيلزم تكرار المحاولة لاحقاً.
bool _tryReleaseToastContext(FToast fToast, BuildContext context) {
  if (!identical(fToast.context, context)) return true;
  if (Fluttertoast.isCurrentlyShowingToast) return false;
  fToast.context = null;
  return true;
}
