import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
    required Future<Response> Function(String url) download,
    required bool Function(String key) containsKey,
    required File Function(String key) getFile,
    required void Function(String key, File file) saveFile,
    required void Function(String key) deleteKey,
  })  : _download = download,
        _containsKey = containsKey,
        _getFile = getFile,
        _saveFile = saveFile,
        _deleteKey = deleteKey;

  static FileCacheManager? _instance;
  static FileCacheManager get instance => _instance!;

  final Future<Response> Function(String url) _download;
  final bool Function(String key) _containsKey;
  final File Function(String key) _getFile;
  final void Function(String key, File file) _saveFile;
  final void Function(String key) _deleteKey;

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

    final String urlHash = url.hashCode.abs().toString();
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
      final contentType = response.headers.value('content-type') ?? '';
      extension = _extensionFromContentType(contentType);
      filePath = '$filePath.$extension';
    }

    // حذف الملف القديم إذا كان موجوداً
    final File file = File(filePath);
    if (file.existsSync()) file.deleteSync();

    if (response.statusCode != 200) {
      throw Exception('Failed to download: ${response.statusCode}');
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

    await file.writeAsBytes(bytes, flush: true);

    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      throw Exception('File was not saved successfully');
    }

    _saveFile(url, file);
    return file;
  }

  /// استخراج امتداد الملف من الرابط
  static String getFileType(String url) {
    final cleanUrl = url.split('?').first;
    final uri = Uri.parse(cleanUrl);
    final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (!name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  /// استخراج MIME type من الرابط
  static String getFileMimeType(String url) {
    final String cleanUrl = url.split('?').first;
    return switch (cleanUrl.split('.').last.toLowerCase()) {
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
