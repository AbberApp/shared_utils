/// مكتبة أدوات مشتركة للمشاريع
library;

// ═══════════════════════════════════════════════════════════════════════════
// Network - الشبكة
// ═══════════════════════════════════════════════════════════════════════════

// Connectivity - حالة الاتصال
export 'src/network/connectivity/connection_status.dart';

// API Models - نماذج API
export 'src/network/api/models/failure.dart';
export 'src/network/api/models/response_code.dart';
export 'src/network/api/models/response_message.dart';

// API Handlers - معالجات API
export 'src/network/api/handlers/error_handler.dart';
export 'src/network/api/handlers/response_handler.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Extensions - الإضافات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/extensions/date/date_format_extension.dart';
export 'src/extensions/string/string_extension.dart';
export 'src/extensions/number/currency_extension.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Formatters - المنسقات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/formatters/number_formatter.dart';
export 'src/formatters/card_formatter.dart';
export 'src/formatters/text_formatter.dart';
export 'src/formatters/phone_formatter.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Pickers - منتقيات الملفات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/pickers/file/file_picker_manager.dart';
export 'src/pickers/image/image_picker_manager.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Widgets - عناصر الواجهة
// ═══════════════════════════════════════════════════════════════════════════

export 'src/widgets/toast.dart';
export 'src/widgets/page_indicator.dart';
export 'src/widgets/responsive_grid_view.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Device Info - معلومات الجهاز
// ═══════════════════════════════════════════════════════════════════════════

export 'src/device_info/device_info_manager.dart';
export 'src/device_info/models/device_info_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Services - الخدمات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/services/update/app_update_checker.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Utils - الأدوات المساعدة
// ═══════════════════════════════════════════════════════════════════════════

export 'src/utils/helpers.dart';
export 'src/utils/delay_handler.dart';
export 'src/utils/phone/intl_phone_utils.dart';
