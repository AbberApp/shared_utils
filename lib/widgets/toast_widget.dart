import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';


 void showToast(
  String text, {
  bool long = false,
  ToastGravity gravity = ToastGravity.BOTTOM,
  Color backgroundColor = Colors.black87,
}) {
  Fluttertoast.showToast(
    msg: text,
    toastLength: long ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
    gravity: gravity,
    timeInSecForIosWeb: long ? 5 : 1,
    backgroundColor: backgroundColor,
    textColor:  Color(0xFFFFFFFF),
    fontSize: 16.0,
  );
}
