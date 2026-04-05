import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Extension لتنسيق التواريخ
extension DateFormatExtension on DateTime {
  /// إضافة فارق التوقيت المحلي
  DateTime get _localDateTime {
    final duration = DateTime.now().timeZoneOffset;
    return add(Duration(hours: duration.inHours));
  }

  /// تنسيق: yyyy-MM-dd
  String get toDateString => DateFormat('yyyy-MM-dd').format(_localDateTime);

  /// تنسيق كامل: MMMM d, yyyy, h:mm a بالعربية
  String get toFullDateTime {
    initializeDateFormatting('ar', null);
    return DateFormat('MMMM d, yyyy, h:mm a', 'ar').format(_localDateTime);
  }

  /// تنسيق: d MMMM بالعربية (اليوم والشهر فقط)
  String get toDayMonth {
    initializeDateFormatting('ar', null);
    return DateFormat('d MMMM', 'ar').format(_localDateTime);
  }

  /// تنسيق: d MMMM yyyy بالعربية لعناوين المحادثات
  String get toChatHeaderDate {
    initializeDateFormatting('ar', null);
    return DateFormat('d MMMM yyyy', 'ar').format(_localDateTime);
  }

  /// تنسيق: h:mm a بالعربية لرسائل المحادثات
  String get toChatMessageTime {
    initializeDateFormatting('ar', null);
    return DateFormat('h:mm a', 'ar').format(_localDateTime);
  }

  /// تنسيق على طريقة واتساب: اليوم، أمس، اسم اليوم، أو التاريخ الكامل
  String get toWhatsAppStyle {
    initializeDateFormatting('ar', null);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(_localDateTime.year, _localDateTime.month, _localDateTime.day);

    // اليوم
    if (_isSameDay(dateToCheck, today)) return 'اليوم';

    // أمس
    if (_isSameDay(dateToCheck, yesterday)) return 'أمس';

    // ضمن الأسبوع الحالي
    if (today.difference(dateToCheck).inDays < 7) {
      const arabicDays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      return arabicDays[dateToCheck.weekday - 1];
    }

    // تاريخ كامل
    return DateFormat('yyyy/MM/dd', 'ar').format(_localDateTime);
  }

  /// تنسيق مختصر للوقت
  /// - رسائل اليوم: الوقت فقط
  /// - رسائل هذه السنة: التاريخ والوقت
  /// - رسائل السنوات الأخرى: السنة والتاريخ والوقت
  String get toShortDateTime {
    initializeDateFormatting('ar', null);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(_localDateTime.year, _localDateTime.month, _localDateTime.day);
    final time = DateFormat('H:mm', 'ar').format(_localDateTime);

    // اليوم
    if (dateToCheck.isAtSameMomentAs(today)) return time;

    // نفس السنة
    if (dateToCheck.year == now.year) {
      final date = DateFormat('MM/dd', 'ar').format(_localDateTime);
      return '$time $date';
    }

    // سنة مختلفة
    final fullDate = DateFormat('yyyy/MM/dd', 'ar').format(_localDateTime);
    return '$time $fullDate';
  }

  /// حساب العمر من تاريخ الميلاد
  int get toAge {
    final today = DateTime.now();
    int age = today.year - _localDateTime.year;

    if (today.month < _localDateTime.month ||
        (today.month == _localDateTime.month && today.day < _localDateTime.day)) {
      age--;
    }

    return age;
  }

  /// تنسيق "منذ..." مخصص
  String get toTimeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 10) return 'الآن';
    if (diff.inSeconds < 60) return '${diff.inSeconds} ث';
    if (diff.inMinutes < 60) return '${diff.inMinutes} د';

    if (diff.inHours < 24) {
      final minutes = diff.inMinutes % 60;
      return minutes > 0 ? '${diff.inHours} س و $minutes د' : '${diff.inHours} س';
    }

    if (diff.inDays < 30) {
      final hours = diff.inHours % 24;
      return hours > 0 ? '${diff.inDays} ي و $hours س' : '${diff.inDays} ي';
    }

    if (diff.inDays < 365) {
      final months = diff.inDays ~/ 30;
      final days = diff.inDays % 30;
      return days > 0 ? '$months ش و $days ي' : '$months ش';
    }

    final years = diff.inDays ~/ 365;
    final months = (diff.inDays % 365) ~/ 30;
    return months > 0 ? '$years س و $months ش' : '$years س';
  }

  /// تنسيق "منذ..." بالعربية الكاملة
  String get toTimeAgoArabic {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) {
      return 'الآن';
    }

    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      if (minutes == 1) return 'منذ دقيقة';
      if (minutes == 2) return 'منذ دقيقتين';
      if (minutes <= 10) return 'منذ $minutes دقائق';
      return 'منذ $minutes دقيقة';
    }

    if (diff.inHours < 24) {
      final hours = diff.inHours;
      if (hours == 1) return 'منذ ساعة';
      if (hours == 2) return 'منذ ساعتين';
      if (hours <= 10) return 'منذ $hours ساعات';
      return 'منذ $hours ساعة';
    }

    if (diff.inDays < 30) {
      final days = diff.inDays;
      if (days == 1) return 'منذ يوم';
      if (days == 2) return 'منذ يومين';
      if (days <= 10) return 'منذ $days أيام';
      return 'منذ $days يوم';
    }

    if (diff.inDays < 365) {
      final months = diff.inDays ~/ 30;
      if (months == 1) return 'منذ شهر';
      if (months == 2) return 'منذ شهرين';
      if (months <= 10) return 'منذ $months أشهر';
      return 'منذ $months شهر';
    }

    final years = diff.inDays ~/ 365;
    if (years == 1) return 'منذ سنة';
    if (years == 2) return 'منذ سنتين';
    if (years <= 10) return 'منذ $years سنوات';
    return 'منذ $years سنة';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Extension لتحويل النص إلى تاريخ
extension DateStringExtension on String {
  /// تحويل العمر إلى تاريخ ميلاد
  String get ageToBirthDate {
    try {
      final age = int.parse(this);
      final today = DateTime.now();
      var birthDate = DateTime(today.year - age, today.month, today.day);

      if (age != birthDate.toAge) {
        birthDate = DateTime(birthDate.year + 1, birthDate.month, birthDate.day);
      }

      return birthDate.toDateString;
    } catch (_) {
      return this;
    }
  }
}
