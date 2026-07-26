import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// خلفية التوست الموحّدة (تصميم عبر: --toast-bg #1A2530) وأخضر النجاح (#34C759).
const Color _kToastBg = Color(0xFF1A2530);
const Color _kToastSuccess = Color(0xFF34C759);

/// عرض رسالة Toast.
///
/// - بلا [context]: توست النظام النصّي (السلوك القديم — متوافق مع كل النداءات).
/// - مع [context]: توست غنيّ على شكل حبّة داكنة (تصميم ش15-توست) — نصّ أبيض
///   + ظلّ، وأيقونة صحّ خضراء عند [success] (أو [icon] مخصّصة) — بلا تلوين
///   الخلفية بالحالة (الأخضر للأيقونة فقط كما في التصميم).
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
  if (context != null) {
    final IconData? effectiveIcon = icon ?? (success ? Icons.check_circle_rounded : null);
    final Color effectiveIconColor = iconColor ?? (success ? _kToastSuccess : textColor);
    final FToast fToast = FToast()..init(context);
    fToast.showToast(
      gravity: gravity,
      toastDuration: Duration(seconds: isLong ? 4 : 2),
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
    return;
  }

  Fluttertoast.showToast(
    msg: message,
    toastLength: isLong ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
    gravity: gravity,
    timeInSecForIosWeb: isLong ? 5 : 1,
    backgroundColor: backgroundColor,
    textColor: textColor,
    fontSize: 16.0,
  );
}
