/// مكتبة أدوات مشتركة للمشاريع
library;

// ═══════════════════════════════════════════════════════════════════════════
// Socket - WebSocket
// ═══════════════════════════════════════════════════════════════════════════

export 'src/realtime/socket/socket_manager.dart';
export 'src/realtime/socket/socket_registry.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SSE - Server-Sent Events
// ═══════════════════════════════════════════════════════════════════════════

export 'src/realtime/sse/sse_manager.dart';
export 'src/realtime/sse/sse_registry.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Network - الشبكة
// ═══════════════════════════════════════════════════════════════════════════

// Connectivity - حالة الاتصال
export 'src/network/connectivity/connection_status.dart';

// API Models - نماذج API
export 'src/network/api/models/failure.dart';
export 'src/network/api/models/response_code.dart';
export 'src/network/api/models/response_message.dart';

// API Consumer - مستهلك API
export 'src/network/api/api_consumer.dart';
export 'src/network/api/dio_consumer.dart';

// API Handlers - معالجات API
export 'src/network/api/handlers/error_handler.dart';
export 'src/network/api/handlers/response_handler.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Extensions - الإضافات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/utils/extensions/date_format_extension.dart';
export 'src/utils/extensions/string_extension.dart';
export 'src/utils/extensions/currency_extension.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Formatters - المنسقات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/ui/formatters/number_formatter.dart';
export 'src/ui/formatters/card_formatter.dart';
export 'src/ui/formatters/text_formatter.dart';
export 'src/ui/formatters/phone_formatter.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Pickers - منتقيات الملفات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/services/pickers/file_picker_manager.dart';
export 'src/services/pickers/image_picker_manager.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Widgets - عناصر الواجهة
// ═══════════════════════════════════════════════════════════════════════════

export 'src/ui/widgets/toast.dart';
export 'src/ui/widgets/page_indicator.dart';
export 'src/ui/widgets/responsive_grid_view.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Device Info - معلومات الجهاز
// ═══════════════════════════════════════════════════════════════════════════

export 'src/device/device_info_manager.dart';
export 'src/device/models/device_info_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Services - الخدمات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/services/cache/file_cache_manager.dart';
export 'src/services/update/app_update_checker.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Utils - الأدوات المساعدة
// ═══════════════════════════════════════════════════════════════════════════

export 'src/utils/helpers.dart';
export 'src/utils/delay_handler.dart';
export 'src/utils/phone/intl_phone_utils.dart';
export 'src/utils/parse_to_map.dart';


// ═══════════════════════════════════════════════════════════════════════════
// Entities - البيانات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/data/base_entity.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Agora - المكالمات والبث المباشر
// ═══════════════════════════════════════════════════════════════════════════

export 'src/realtime/agora/call/agora_call_service.dart';
export 'src/realtime/agora/live/agora_live_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Call Services - خدمات المكالمات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/realtime/agora/call/microphone_service.dart';
export 'src/realtime/agora/call/speaker_service.dart';
