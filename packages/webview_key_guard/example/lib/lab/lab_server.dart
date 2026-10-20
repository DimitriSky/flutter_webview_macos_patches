import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'key_matrix.dart';

class LabServer {
  LabServer({required this.snapshot, required this.onReport});
  final Map<String, Object?> Function() snapshot;
  final void Function(Map<String, dynamic>) onReport;
  HttpServer? _server;

  String get baseUrl => 'http://127.0.0.1:${_server!.port}';

  Future<void> start() async {
    final html = await rootBundle.loadString('assets/keyboard.html');
    final script = await rootBundle.loadString('assets/keyboard.js');
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      final response = request.response;
      response.headers.set('Cache-Control', 'no-store');
      try {
        switch ((request.method, request.uri.path)) {
          case ('GET', '/keys'):
            response.headers.contentType = ContentType.html;
            response.write(html);
          case ('GET', '/keyboard.js'):
            response.headers.contentType = ContentType('text', 'javascript');
            response.write(script);
          case ('GET', '/state'):
            response.headers.contentType = ContentType.json;
            response.write(jsonEncode(snapshot()));
          case ('GET', '/matrix'):
            response.headers.contentType = ContentType.json;
            response.write(
              jsonEncode(buildKeyMatrix().map((e) => e.toJson()).toList()),
            );
          case ('POST', '/events'):
            final bytes = <int>[];
            await for (final chunk in request) {
              bytes.addAll(chunk);
              if (bytes.length > 250000) {
                throw const FormatException('Too large');
              }
            }
            onReport(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
            response.statusCode = HttpStatus.noContent;
          default:
            response.statusCode = HttpStatus.notFound;
        }
      } catch (_) {
        response.statusCode = HttpStatus.badRequest;
      } finally {
        await response.close();
      }
    });
    // Local diagnostics only; no model calls or application backend.
    stdout.writeln('KEY_LAB_URL=$baseUrl');
  }

  Future<void> close() async => _server?.close(force: true);
}
