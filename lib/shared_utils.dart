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
export 'src/utils/extensions/arabic_digits_extension.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Formatters - المنسقات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/ui/forms/field_errors.dart';
export 'src/ui/formatters/number_formatter.dart';
export 'src/ui/formatters/card_formatter.dart';
export 'src/ui/formatters/text_formatter.dart';
export 'src/ui/formatters/phone_formatter.dart';
export 'src/ui/formatters/iban_formatter.dart';

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
export 'src/ui/widgets/skeletonizer_widget.dart';
export 'src/ui/widgets/load_more_widget.dart';
export 'src/ui/widgets/paginated_list_view.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Device Info - معلومات الجهاز
// ═══════════════════════════════════════════════════════════════════════════

export 'src/device/device_info_manager.dart';
export 'src/device/models/device_info_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Services - الخدمات
// ═══════════════════════════════════════════════════════════════════════════

export 'src/services/cache/file_cache_manager.dart';
export 'src/services/update/app_release_info.dart';
export 'src/services/update/app_update_checker.dart';
export 'src/services/update/optional_update_banner.dart';
export 'src/services/update/guarded_navigator.dart';

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

// ═══════════════════════════════════════════════════════════════════════════
// State - حرّاس دورة حياة البلوك
// ═══════════════════════════════════════════════════════════════════════════

export 'src/state/safe_bloc.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Audio - ضبط جلسة الصوت
// ═══════════════════════════════════════════════════════════════════════════

export 'src/services/audio/audio_session_config.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Monitoring - Sentry
// ═══════════════════════════════════════════════════════════════════════════

export 'src/services/monitoring/sentry_bootstrap.dart';
export 'src/services/monitoring/sentry_noise_filter.dart';

// ═══════════════════════════════════════════════════════════════════════════
// حزم المنصّة المشتركة — تُصدَّر من هنا لا تُضاف في كلّ تطبيق
// ═══════════════════════════════════════════════════════════════════════════
//
// موضعها هنا يوحّد إصدارها على كلّ المشاريع: ترقيةٌ واحدة في المكتبة تسري
// على الجميع، بدل ثمانية `pubspec` يتخلّف بعضها عن بعض (كان share_plus
// موزّعًا على 13.0.0 و13.1.0 و13.3.0 في وقتٍ واحد).
//
// ولا تُضف `open_filex` مكان `open_file`: الأولى بلا `Package.swift` فتُبقي
// CocoaPods حيّةً في كلّ مشروعٍ يستعملها.

export 'package:connectivity_plus/connectivity_plus.dart';
export 'package:dio/dio.dart';
export 'package:json_annotation/json_annotation.dart';
export 'package:open_file/open_file.dart';
export 'package:share_plus/share_plus.dart';
export 'package:skeletonizer/skeletonizer.dart';
export 'package:url_launcher/url_launcher.dart';
