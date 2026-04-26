import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'api_consumer.dart';

class DioConsumer implements ApiConsumer {
  final Dio client;

  DioConsumer({
    required this.client,
    required Interceptor appInterceptors,
    required String baseUrl,
    required int internalServerErrorCode,
  }) {
    (client.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final HttpClient client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return client;
    };

    client.options
      ..baseUrl = baseUrl
      ..responseType = ResponseType.plain
      ..followRedirects = false
      ..validateStatus = (status) {
        return status! < internalServerErrorCode;
      };

    client.interceptors.clear();

    client.interceptors.add(appInterceptors);
    if (kDebugMode) {
      client.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
    // تعيين قيم timeout هنا
    // 15 ثانية للاتصال
    client.options.connectTimeout = const Duration(seconds: 15);
    // 30 ثانية لاستقبال البيانات
    client.options.receiveTimeout = const Duration(seconds: 30);
    // 30 ثانية لإرسال البيانات
    client.options.sendTimeout = const Duration(seconds: 30);
  }

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool useToken = false,
  }) async {
    return await client.get(path, queryParameters: queryParameters);
  }

  @override
  Future<Response<dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool formDataIsEnabled = false,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await client.post(
      path,
      queryParameters: queryParameters,
      data: formDataIsEnabled ? FormData.fromMap(body!) : body,
    );
  }

  @override
  Future<Response<dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool formDataIsEnabled = false,
    Map<String, dynamic>? queryParameters,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return await client.put(
      path,
      queryParameters: queryParameters,
      data: formDataIsEnabled ? FormData.fromMap(body!) : body,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
  }

  @override
  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool formDataIsEnabled = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return await client.delete(
      path,
      queryParameters: queryParameters,
      data: formDataIsEnabled ? FormData.fromMap(body!) : body,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
  }

  @override
  Future<Response<dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool formDataIsEnabled = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return await client.patch(
      path,
      queryParameters: queryParameters,
      data: formDataIsEnabled ? FormData.fromMap(body!) : body,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
  }

  @override
  Future<Response> download(
    String url, {
    Function(int, int)? onReceiveProgress,
    Duration receiveTimeout = const Duration(minutes: 5),
  }) async {
    try {
      final options = Options(
        responseType: ResponseType.bytes,
        receiveTimeout: receiveTimeout,
      );

      final response = await client.get(
        url,
        options: options,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }

  @override
  Future<Response<dynamic>> upload(
    String path, {
    required Map<String, dynamic> body,
    Map<String, dynamic>? queryParameters,
    Function(int, int)? onSendProgress,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    return await client.post(
      path,
      queryParameters: queryParameters,
      data: FormData.fromMap(body),
      onSendProgress: onSendProgress,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
  }
}
