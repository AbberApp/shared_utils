import 'package:dio/dio.dart';

abstract class ApiConsumer {
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool useToken = false,
  });

  Future<Response> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool formDataIsEnabled = false,
  });

  Future<Response> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool formDataIsEnabled = false,
  });

  Future<Response> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool formDataIsEnabled = false,
  });

  Future<Response> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool formDataIsEnabled = false,
  });

  Future<Response> download(
    String url, {
    Function(int, int)? onReceiveProgress,
    Duration receiveTimeout = const Duration(minutes: 5),
  });

  Future<Response> upload(
    String path, {
    required Map<String, dynamic> body,
    Map<String, dynamic>? queryParameters,
    Function(int, int)? onSendProgress,
    Duration timeout = const Duration(minutes: 5),
  });
}
