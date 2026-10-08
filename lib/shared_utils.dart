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
// Share - ورقة المشاركة والحافظة
// ═══════════════════════════════════════════════════════════════════════════

export 'src/services/share/share_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// File open - فتح الملفات بتطبيق النظام
// ═══════════════════════════════════════════════════════════════════════════

export 'src/services/file_open/file_open_service.dart';

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

export 'package:animate_do/animate_do.dart';
export 'package:bloc_concurrency/bloc_concurrency.dart';
export 'package:confetti/confetti.dart';
export 'package:connectivity_plus/connectivity_plus.dart';
export 'package:credit_card_type_detector/credit_card_type_detector.dart';
export 'package:credit_card_type_detector/models.dart';
export 'package:custom_timer/custom_timer.dart';
export 'package:dio/dio.dart';
export 'package:equatable/equatable.dart';
export 'package:flutter_bloc/flutter_bloc.dart';
export 'package:flutter_dotenv/flutter_dotenv.dart';
export 'package:flutter_svg/flutter_svg.dart';
export 'package:get_it/get_it.dart';
export 'package:grouped_list/grouped_list.dart';
// adapters.dart تشمل hive_flutter.dart وhive_ce نفسها.
export 'package:hive_ce_flutter/adapters.dart';
export 'package:ip_country_lookup/ip_country_lookup.dart';
export 'package:json_annotation/json_annotation.dart';
export 'package:jwt_decoder/jwt_decoder.dart';
export 'package:lottie/lottie.dart';
export 'package:open_file/open_file.dart';
export 'package:path_provider/path_provider.dart';
export 'package:photo_view/photo_view.dart';
export 'package:pinput/pinput.dart';
export 'package:share_plus/share_plus.dart';
export 'package:showcaseview/showcaseview.dart';
export 'package:skeletonizer/skeletonizer.dart';
export 'package:solar_community_icons/solar_community_icons.dart';
export 'package:url_launcher/url_launcher.dart';
export 'package:uuid/uuid.dart';

// وهذه بـ`show` لا كاملةً: كلٌّ منها يحمل أسماءً عامّة تصطدم بما في التطبيقات،
// والاصطدام بين استيرادين لا يظهر إلّا عند الاستعمال — في شاشةٍ لم يلمسها أحد.
//
// - `intl` تُعرّف `TextDirection` باسم صنف `dart:ui` نفسه، وكلّ تطبيقاتنا عربيّة
//   تكتب `TextDirection.rtl` في عشرات الملفّات؛ تصديرها كاملةً يجعلها كلّها
//   استيراداً ملتبساً.
// - `sentry_flutter` تُعرّف `User` و`Device` و`App` و`Scope`، وهي أسماء كيانات
//   في تطبيقاتنا.
// - `dartz` تُعرّف `State` (موناد الحالة) باسم صنف Flutter الذي يرثه كلّ ودجتٍ
//   ذي حالة — تصديرها كاملةً يكسر كلّ `extends State<…>` في ملفٍّ يستورد المكتبة.
// - `pointycastle` تُعرّف `Padding` (حشو التشفير) باسم ودجت Flutter نفسه.
// - `audio_session` و`file_picker` و`basic_utils`: ما تستعمله التطبيقات منها
//   فقط، لا عشرات الأنواع التي تجيء معه (و`basic_utils` تُعرّف `DateUtils`).

export 'package:audio_session/audio_session.dart'
    show AVAudioSession, AVAudioSessionPort, AVAudioSessionPortOverride, AVAudioSessionRouteChange;
export 'package:basic_utils/basic_utils.dart' show CryptoUtils;
export 'package:dartz/dartz.dart' show Either, Left, Right, Unit, unit;
export 'package:file_picker/file_picker.dart' show FilePicker, FileType, PlatformFile;
export 'package:intl/intl.dart' show DateFormat, NumberFormat;
export 'package:sentry_flutter/sentry_flutter.dart' show Sentry, SentryNavigatorObserver;
export 'package:pointycastle/export.dart'
    show
        AEADParameters,
        AESEngine,
        GCMBlockCipher,
        KeyParameter,
        OAEPEncoding,
        PublicKeyParameter,
        RSAEngine,
        RSAPublicKey;
