import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  static const Duration _timeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final resp = await http.get(_uri(path, query)).timeout(_timeout);
    return _decode(resp);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final resp = await http
        .post(
          _uri(path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decode(resp);
  }

  Future<dynamic> delete(String path) async {
    final resp = await http.delete(_uri(path)).timeout(_timeout);
    return _decode(resp);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final resp = await http
        .patch(
          _uri(path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decode(resp);
  }

  Future<dynamic> postMultipart(
    String path, {
    required String fileField,
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
    Map<String, String>? fields,
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    if (fields != null && fields.isNotEmpty) {
      req.fields.addAll(fields);
    }
    if (kIsWeb) {
      if (fileBytes == null) {
        throw ArgumentError('Web 环境必须提供 fileBytes，不能使用 filePath');
      }
      req.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName ?? 'upload.bin',
        ),
      );
    } else if (fileBytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName ?? 'upload.bin',
        ),
      );
    } else if (filePath != null && filePath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    } else {
      throw ArgumentError('filePath 或 fileBytes 至少提供一项');
    }
    final streamed = await req.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamed).timeout(_timeout);
    return _decode(resp);
  }

  String resolveUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final base = Uri.parse(baseUrl);
    return base.resolve(raw).toString();
  }

  dynamic _decode(http.Response resp) {
    final payload = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400 || payload['success'] != true) {
      final detail = payload['detail'];
      if (detail is String && detail.isNotEmpty) {
        throw Exception(detail);
      }
      if (detail is List && detail.isNotEmpty) {
        throw Exception(detail.map((e) => e.toString()).join('; '));
      }
      throw Exception(payload['message'] ?? 'request failed');
    }
    return payload['data'];
  }
}
