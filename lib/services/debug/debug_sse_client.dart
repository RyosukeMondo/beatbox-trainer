import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../models/classification_result.dart';
import 'i_debug_service.dart';

/// Lightweight SSE client for consuming the debug HTTP classification stream.
class DebugSseClient {
  DebugSseClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  HttpClientRequest? _activeRequest;

  /// Connect to the `/classification-stream` SSE endpoint exposed by the
  /// debug HTTP server.
  Stream<ClassificationResult> connectClassificationStream({
    required Uri baseUri,
    required String token,
  }) {
    final controller = StreamController<ClassificationResult>();
    () async {
      try {
        final uri = _buildUri(baseUri, '/classification-stream', token);
        final request = await _httpClient.getUrl(uri);
        _activeRequest = request;
        request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
        request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        request.headers.set('X-Debug-Token', token);

        final response = await request.close();
        if (response.statusCode >= 400) {
          throw DebugException(
            'HTTP ${response.statusCode} connecting to ${uri.path}',
          );
        }

        final lines = response
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        var payloadBuffer = '';
        await for (final line in lines) {
          if (line.startsWith('data:')) {
            final payload = line.substring(5).trimLeft();
            payloadBuffer += payload;
          } else if (line.isEmpty && payloadBuffer.isNotEmpty) {
            controller.add(_decodeClassification(payloadBuffer));
            payloadBuffer = '';
          }
        }
        if (payloadBuffer.isNotEmpty) {
          controller.add(_decodeClassification(payloadBuffer));
        }
        await controller.close();
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(
            DebugException('Failed to connect to SSE stream', error),
            stackTrace,
          );
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  /// Dispose of HTTP resources and cancel any pending request.
  Future<void> dispose() async {
    try {
      await _activeRequest?.close();
    } catch (_) {
      // Ignored
    }
    _httpClient.close(force: true);
  }

  ClassificationResult _decodeClassification(String payload) {
    final data = jsonDecode(payload);
    if (data is Map<String, dynamic>) {
      return ClassificationResult.fromJson(data);
    }
    if (data is Map) {
      return ClassificationResult.fromJson(Map<String, dynamic>.from(data));
    }
    throw DebugException('Unexpected SSE payload shape: $data');
  }

  Uri _buildUri(Uri base, String suffix, String token) {
    final normalizedPath = suffix.startsWith('/') ? suffix : '/$suffix';
    final existing = Map<String, String>.from(base.queryParameters);
    existing.putIfAbsent('token', () => token);
    return base.replace(
      path: _joinPaths(base.path, normalizedPath),
      queryParameters: existing,
    );
  }

  String _joinPaths(String base, String suffix) {
    final sanitizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return '$sanitizedBase$suffix';
  }
}
