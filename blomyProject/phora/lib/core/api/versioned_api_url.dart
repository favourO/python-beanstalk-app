import 'package:dio/dio.dart';

String buildVersionedApiUrl(Dio dio, String path) {
  final baseUrl = dio.options.baseUrl;
  final match = RegExp(r'^(https?://[^/]+)').firstMatch(baseUrl);
  final origin = match?.group(1);
  if (origin == null) {
    return path;
  }
  return '$origin$path';
}
