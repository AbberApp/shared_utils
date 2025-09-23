import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Extension to format [DateTime] objects.
extension DateFormatExtension on DateTime {
  /// Returns the date formatted as "yyyy-MM-dd".
  String get formattedToDate {
    return DateFormat('yyyy-MM-dd').format(dateTimeWithTimeZone);
  }

  /// Returns the date formatted as "MMMM d, yyyy, h:mm a" in Arabic.
  String get formatToFullDateTime {
    initializeDateFormatting('ar', null); // تهيئة اللغة العربية
    final formatter = DateFormat('MMMM d, yyyy, h:mm a', 'ar');
    return formatter.format(dateTimeWithTimeZone);
  }

  /// Returns the date formatted as "d MMMM" in Arabic (day and month only).
  String get formatToDayMonth {
    initializeDateFormatting('ar', null); // تهيئة اللغة العربية
    final formatter = DateFormat('d MMMM', 'ar');
    return formatter.format(dateTimeWithTimeZone);
  }

  /// Formats date in WhatsApp style: اليوم, أمس, day name, or full date.
  String get formatToWhatsAppStyleDate {
    initializeDateFormatting('ar', null); // تهيئة اللغة العربية

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime dateToCheck = DateTime(
      dateTimeWithTimeZone.year,
      dateTimeWithTimeZone.month,
      dateTimeWithTimeZone.day,
    );

    // تحقق ما إذا كان التاريخ هو اليوم - مقارنة التاريخ فقط دون الوقت
    if (dateToCheck.year == today.year &&
        dateToCheck.month == today.month &&
        dateToCheck.day == today.day) {
      return 'اليوم';
    }

    // تحقق ما إذا كان التاريخ هو الأمس - مقارنة التاريخ فقط دون الوقت
    if (dateToCheck.year == yesterday.year &&
        dateToCheck.month == yesterday.month &&
        dateToCheck.day == yesterday.day) {
      return 'أمس';
    }

    // تحقق إذا كان ضمن الأسبوع الحالي (آخر 7 أيام)
    if (today.difference(dateToCheck).inDays < 7) {
      // اسم اليوم بالعربية
      final List<String> arabicDaysOfWeek = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      // الحصول على اليوم (0-6 حيث 0 هو الاثنين)
      final int dayIndex = dateToCheck.weekday - 1;
      return arabicDaysOfWeek[dayIndex];
    }

    // إذا كان في نفس السنة، نعرض الشهر واليوم والوقت
    // if (dateToCheck.year == now.year) {
    //   final String dateFormat = DateFormat('MM/dd', 'ar').format(this.dateTimeWithTimeZone);
    //   return dateFormat;
    // }

    // إذا كان في سنة مختلفة، نعرض السنة والشهر واليوم والوقت
    final String fullDateFormat = DateFormat('yyyy/MM/dd', 'ar').format(dateTimeWithTimeZone);
    return fullDateFormat;
  }

  /// Returns the date formatted as "d MMMM yyyy" in Arabic for chat headers.
  String get formatToChatHeaderDate {
    initializeDateFormatting('ar', null); // تهيئة اللغة العربية
    final formatter = DateFormat('d MMMM yyyy', 'ar');
    return formatter.format(dateTimeWithTimeZone);
  }

  /// Returns the time formatted as "h:mm a" in Arabic for chat messages.
  String get formatToChatMessageTime {
    initializeDateFormatting('ar', null); // تهيئة اللغة العربية
    final formatter = DateFormat('h:mm a', 'ar');
    return formatter.format(dateTimeWithTimeZone);
  }

  /// تنسيق الوقت للرسائل:
  /// - رسائل اليوم تظهر الوقت فقط (5:20)
  /// - رسائل هذا العام تظهر التاريخ والوقت (02/20 9:00)
  /// - رسائل السنوات الأخرى تظهر السنة والتاريخ والوقت (2024/02/20 9:00)
  String get formatToShortDateTime {
    initializeDateFormatting('ar', null); // تهيئة اللغة العربية

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime dateToCheck = DateTime(
      dateTimeWithTimeZone.year,
      dateTimeWithTimeZone.month,
      dateTimeWithTimeZone.day,
    );

    // تنسيق الوقت (hh:mm)
    final String timeFormat = DateFormat('H:mm', 'ar').format(dateTimeWithTimeZone);

    // إذا كان اليوم، نعرض الوقت فقط
    if (dateToCheck.isAtSameMomentAs(today)) {
      return timeFormat;
    }

    // إذا كان في نفس السنة، نعرض الشهر واليوم والوقت
    if (dateToCheck.year == now.year) {
      final String dateFormat = DateFormat('MM/dd', 'ar').format(dateTimeWithTimeZone);
      // return '$dateFormat $timeFormat';
      return '$timeFormat $dateFormat';
    }

    // إذا كان في سنة مختلفة، نعرض السنة والشهر واليوم والوقت
    final String fullDateFormat = DateFormat('yyyy/MM/dd', 'ar').format(dateTimeWithTimeZone);
    // return '$fullDateFormat $timeFormat';
    return '$timeFormat $fullDateFormat';
  }

  /// تحسب العمر من تاريخ الميلاد وحتى اليوم الحالي
  int get calculateAgeFromBirthDate {
    final DateTime today = DateTime.now();
    int age = today.year - dateTimeWithTimeZone.year;

    if (today.month < dateTimeWithTimeZone.month ||
        (today.month == dateTimeWithTimeZone.month && today.day < dateTimeWithTimeZone.day)) {
      age--; // لم يصل إلى عيد ميلاده هذه السنة بعد
    }

    return age;
  }

  /// Helper method to get DateTime with timezone offset
  DateTime get dateTimeWithTimeZone {
    final Duration duration = DateTime.now().timeZoneOffset;
    return add(Duration(hours: duration.inHours));
  }

  String get formattedToCustomTimeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 10) return 'الآن';
    if (diff.inSeconds < 60) return '${diff.inSeconds} ث';

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} د';
    }

    if (diff.inHours < 24) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return minutes > 0 ? '$hours س و $minutes د' : '$hours س';
    }

    if (diff.inDays < 30) {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      return hours > 0 ? '$days ي و $hours س' : '$days ي';
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
}

extension DateStringExtension on String {
  /// تحويل العمر الى تاريخ الميلاد
  String get convertAgeToBirthDate {
    try {
      final int age = int.parse(this);
      final DateTime ref = DateTime.now();
      DateTime birthDate = DateTime(ref.year - age, ref.month, ref.day);

      /// إذا العمر الناتج أقل من العمر المفترض (يعني عيد ميلاده ما جا بعد)، نضيف سنة
      if (age != birthDate.calculateAgeFromBirthDate) {
        birthDate = DateTime(birthDate.year + 1, birthDate.month, birthDate.day);
      }

      return birthDate.formattedToDate;
    } catch (e) {
      return this;
    }
  }
}
