import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../network/api/models/response_code.dart';

/// الملفّ لم يعد موجوداً في مُخزّن الوسائط.
///
/// يُميَّز عن أخطاء الشبكة لأنّه **لا يُصلَح بإعادة المحاولة**: المحتوى ذهب.
/// المستدعي يعرض رسالة مفهومة («لم يعد متاحاً») بدل خطأٍ غامض، ولا يُرسله
/// إلى تتبّع الأخطاء — فليس عطباً نملك إصلاحه.
class FileNoLongerAvailableException implements Exception {
  const FileNoLongerAvailableException(this.url, this.statusCode);

  final String url;
  final int statusCode;

  @override
  String toString() => 'FileNoLongerAvailableException($statusCode): $url';
}

/// مدير تخزين الملفات المؤقت
///
/// يجب استدعاء [init] مرة واحدة عند بداية التطبيق بعد تسجيل الـ DI
/// ```dart
/// FileCacheManager.init(
///   download: api.download,
///   containsKey: box.containsKey,
///   getFile: (key) => box.getData(key: key),
///   saveFile: (key, file) => box.saveData(key: key, value: file),
///   deleteKey: (key) => box.deleteData(key: key),
/// );
/// ```
class FileCacheManager {
  FileCacheManager._({
    required this._download,
    required this._containsKey,
    required this._getFile,
    required this._saveFile,
    required this._deleteKey,
  });

  static FileCacheManager? _instance;
  static FileCacheManager get instance => _instance!;

  final Future<Response> Function(String url) _download;
  final bool Function(String key) _containsKey;
  final File Function(String key) _getFile;
  final void Function(String key, File file) _saveFile;
  final void Function(String key) _deleteKey;

  /// الطلبات الجارية: رابطٌ واحد ← تنزيلٌ واحد.
  final Map<String, Future<File>> _inFlight = <String, Future<File>>{};

  /// تهيئة المدير بربط الدوال من الـ DI الخاص بالمشروع
  static void init({
    required Future<Response> Function(String url) download,
    required bool Function(String key) containsKey,
    required File Function(String key) getFile,
    required void Function(String key, File file) saveFile,
    required void Function(String key) deleteKey,
  }) {
    _instance = FileCacheManager._(
      download: download,
      containsKey: containsKey,
      getFile: getFile,
      saveFile: saveFile,
      deleteKey: deleteKey,
    );
  }

  /// تنزيل وتخزين ملف مع دعم الكاش
  Future<File> saveAndGetFile(
    String url, {
    String fileCache = 'audio_cache',
  }) async {
    if (url.isEmpty) throw Exception('URL is empty');

    // طلبٌ واحد لكلّ رابط: نداءان متزامنان (تشغيلٌ وتحميلٌ مسبق، أو ضغطتان)
    // كانا يُنزّلان معاً ويكتبان على المسار نفسه فيحذف أحدهما ملفّ الآخر.
    // التسجيل هنا متزامن — لا await قبله — فلا تفلت نافذةُ سباق.
    //
    // المفتاح هو الرابط وحده بلا [fileCache]: الصندوق نفسه مُفهرَس بالرابط
    // وحده (`_containsKey(url)` و`_saveFile(url, …)`)، فلو دخل [fileCache] في
    // المفتاح لانفلت نداءان لنفس الرابط بصندوقَين مختلفين إلى تنزيلين
    // متوازيين إلى مسارين، ثمّ كتب كلاهما على المدخلة نفسها فيبقى أحد
    // الملفّين يتيماً على القرص لا يشير إليه شيء.
    final String key = url;
    final Future<File>? pending = _inFlight[key];
    if (pending != null) return pending;

    final Future<File> request = _downloadAndSave(url, fileCache: fileCache);
    _inFlight[key] = request;
    return request.whenComplete(() => _inFlight.remove(key));
  }

  Future<File> _downloadAndSave(String url, {required String fileCache}) async {
    // التحقق من الكاش
    if (_containsKey(url)) {
      final File file = _getFile(url);
      if (file.existsSync() && file.lengthSync() > 100) {
        return file;
      } else {
        _deleteKey(url);
        if (file.existsSync()) file.deleteSync();
      }
    }

    final directory = await getApplicationDocumentsDirectory();

    final String urlHash = _stableHash(url);
    String extension = getFileType(url);
    final String fileName =
        '$urlHash${extension.isNotEmpty ? '.$extension' : ''}';
    String filePath = '${directory.path}/$fileCache/$fileName';

    // التأكد من وجود دليل التخزين
    final Directory cacheDir = Directory('${directory.path}/$fileCache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    // تنزيل الملف
    final Response response = await _download(url);

    // استخراج الامتداد من content-type إذا لم يكن بالرابط
    if (extension.isEmpty) {
      // القائمة لا `headers.value`: الأخيرة ترمي Exception متى كان طول قائمة
      // الترويسة غير الواحد — ترويسة مكرَّرة من CDN أو proxy، أو قائمة فارغة —
      // فيسقط التنزيل كلّه بخطإٍ عامّ بدل أن يُكمل بامتدادٍ افتراضي.
      final List<String>? contentTypes = response.headers['content-type'];
      final String contentType = (contentTypes == null || contentTypes.isEmpty)
          ? ''
          : contentTypes.first;
      extension = _extensionFromContentType(contentType);
      filePath = '$filePath.$extension';
    }

    // كلّ 2xx نجاح لا 200 وحدها: مُخزّنات الوسائط تردّ 206 على طلبٍ بمدى،
    // وبعض الوسطاء يردّ 203، وكلّها تحمل الملفّ كاملاً في الجسم.
    final int? statusCode = response.statusCode;
    if (!ResponseCode.isSuccessful(statusCode ?? 0)) {
      // 403/404 من مُخزّن الوسائط تعني ملفّاً لم يعد موجوداً، لا عطباً.
      // S3 يُخفي وجود المفاتيح: من لا يملك `s3:ListBucket` يرى AccessDenied
      // (403) بدل NoSuchKey (404) — فالرسالة تقول «ممنوع» وتعني «غير موجود».
      if (statusCode == ResponseCode.forbidden ||
          statusCode == ResponseCode.notFound) {
        throw FileNoLongerAvailableException(url, statusCode!);
      }
      throw Exception('Failed to download: $statusCode');
    }

    Uint8List bytes;
    if (response.data is Uint8List) {
      bytes = response.data;
    } else if (response.data is List<int>) {
      bytes = Uint8List.fromList(response.data);
    } else {
      throw Exception(
        'Unexpected response data type: ${response.data.runtimeType}',
      );
    }

    if (bytes.length < 100) {
      throw Exception('Downloaded file is too small: ${bytes.length} bytes');
    }

    // كتابة ذرّية: نكتب في ملفّ مؤقّت ثمّ نُعيد تسميته فوق الوجهة. لا يُحذف
    // ملفٌّ صالح قبل اكتمال بديله، ولا يقع مشغّلٌ على ملفٍّ نصفَ مكتوب.
    final File tempFile = File('$filePath.part');
    if (tempFile.existsSync()) tempFile.deleteSync();
    await tempFile.writeAsBytes(bytes, flush: true);
    final File file = await tempFile.rename(filePath);

    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      throw Exception('File was not saved successfully');
    }

    _saveFile(url, file);
    return file;
  }

  /// استخراج امتداد الملف من الرابط
  static String getFileType(String url) {
    final cleanUrl = url.split('?').first;
    // tryParse لا parse: رابطٌ مشوَّه يرمي FormatException، وهذه دالّة
    // استعلامٍ يُبنى عليها [getFileMimeType] أيضاً فلا يليق بها الرمي.
    final uri = Uri.tryParse(cleanUrl);
    final name = uri == null
        ? cleanUrl.split('/').last
        : (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '');
    if (!name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  /// استخراج MIME type من الرابط
  static String getFileMimeType(String url) {
    // الامتداد من آخر مقطعٍ في المسار عبر [getFileType]، لا بقسمة الرابط
    // كلّه على النقطة: «…/song.mp3#t=1» كان يُعطي `mp3#t=1` فنوعاً مجهولاً.
    return switch (getFileType(url)) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'doc' => 'application/msword',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'xls' => 'application/vnd.ms-excel',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'zip' => 'application/zip',
      'rar' => 'application/x-rar-compressed',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'mp3' => 'audio/mpeg',
      _ => 'application/octet-stream',
    };
  }

  /// تجزئة مستقرّة (FNV-1a بـ 64 بت) يُشتقّ منها اسم الملفّ.
  ///
  /// `String.hashCode` لا يضمن ثباته بين إصدارات الـ VM ولا يتجاوز مداه
  /// 32 بت عملياً، فرابطان مختلفان يقعان على اسمٍ واحد ← يُسمع صوتُ رسالةٍ
  /// مكان أخرى. 64 بت تُبعد التصادم إلى ما لا يُبلَغ عملياً.
  static String _stableHash(String value) {
    int hash = 0xcbf29ce484222325;
    for (final int byte in utf8.encode(value)) {
      hash ^= byte;
      // الالتفاف على 64 بت مقصود — هو تعريف الخوارزمية لا حادثَ فيضان.
      hash = hash * 0x100000001b3;
    }
    // نصفان بلا إشارة: toUnsigned(64) لا يُجدي على عدد Dart الموقَّع.
    final int high = (hash >> 32) & 0xFFFFFFFF;
    final int low = hash & 0xFFFFFFFF;
    return '${high.toRadixString(16).padLeft(8, '0')}'
        '${low.toRadixString(16).padLeft(8, '0')}';
  }

  static String _extensionFromContentType(String contentType) {
    final type = contentType.split(';').first.trim().toLowerCase();
    return switch (type) {
      'image/png' => 'png',
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/svg+xml' => 'svg',
      'audio/mpeg' => 'mp3',
      'audio/mp4' || 'audio/m4a' => 'm4a',
      'audio/aac' => 'aac',
      'application/pdf' => 'pdf',
      _ => 'bin',
    };
  }

  /// حذف ملف من الكاش
  void deleteFileCache(String url) {
    if (_containsKey(url)) {
      final File cachedFile = _getFile(url);
      if (cachedFile.existsSync()) cachedFile.deleteSync();
      _deleteKey(url);
    }
  }
}
