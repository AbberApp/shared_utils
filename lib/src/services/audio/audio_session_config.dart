import 'dart:developer';
import 'dart:io';

import 'package:audio_session/audio_session.dart';

/// يضبط جلسة الصوت مرّةً واحدة عند الإقلاع.
///
/// التطبيق لم يكن يضبطها إطلاقاً، فيتّكل على افتراض `just_audio`: فئة
/// `playback` بوصولٍ **حصريّ**. ومتى أمسك الصوتَ طرفٌ آخر — مكالمة أجورا،
/// أو بثّ، أو تسجيل، أو مكالمة هاتفية — رفض النظام التفعيل بالخطأ
/// `560557684` (`'!act'`)، فتفشل رسالةٌ صوتية أو قصّة بلا سبب ظاهر للمستخدم.
///
/// رصده Sentry في «عبر» بـ٢٦٨ حدثاً لدى ٦٥ مستخدماً؛ والعطب مشترك بين كل
/// تطبيقات المجموعة التي تُشغّل صوتاً.
///
/// الضبط هنا يطلب `mixWithOthers` على iOS: نُشغّل صوتاً قصيراً (رسالة أو
/// قصّة) ولا نطلب إسكات غيرنا — فلا سبب لطلب حصرٍ يُرفض. والفئة
/// `playback` تُبقي الصوت يعمل مع مفتاح الصامت، وهو المتوقَّع في الرسائل
/// الصوتية.
abstract final class AudioSessionConfig {
  static bool _configured = false;

  /// ميزة تكميلية: تفشل صامتةً ولا تُعطّل الإقلاع.
  static Future<void> configure() async {
    if (_configured) return;
    try {
      final AudioSession session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionSetActiveOptions:
              AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: true,
        ),
      );
      _configured = true;
    } on Object catch (e) {
      log('audio session configure failed: $e', name: 'AudioSessionConfig');
    }
  }

  /// هل المنصّة تحتاج هذا الضبط أصلاً — للاختبارات والتوثيق.
  static bool get isApplicable => Platform.isIOS || Platform.isAndroid;
}
