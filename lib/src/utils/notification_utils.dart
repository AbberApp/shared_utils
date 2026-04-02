import 'dart:convert';
import 'dart:developer';

/// تحويل بيانات الإشعار الخام إلى Map قابل للاستخدام.
/// تعالج Python booleans و single quotes تلقائياً.
Map<String, dynamic> confirmExtraData(String rawData) {
  try {
    final cleanedData = rawData
        .replaceAll('True', 'true')
        .replaceAll('False', 'false')
        .replaceAll("'", '"');

    final Map<String, dynamic> extraData =
        cleanedData.isEmpty ? {} : jsonDecode(cleanedData);

    return extraData;
  } catch (e) {
    log('Failed to parse notification data: $e', name: 'NotificationManager');
    return {};
  }
}
