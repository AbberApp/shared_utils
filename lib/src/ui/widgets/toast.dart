import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// عرض رسالة Toast
void showToast(
  String message, {
  bool isLong = false,
  ToastGravity gravity = ToastGravity.BOTTOM,
  Color backgroundColor = Colors.black87,
  Color textColor = Colors.white,
}) {
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
