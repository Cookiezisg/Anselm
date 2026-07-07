import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A robust correlation-id request/response bridge over a [WebViewController] (research report 5).
///
/// Why not the naive path: `JavaScriptChannel` is fire-and-forget (JS→Dart, no return value);
/// `runJavaScriptReturningResult` is platform-divergent and quirky for structured data. Instead we use
/// ONE JS→Dart channel (`AnselmHost`) for replies + events, and fire-and-forget `runJavaScript` for
/// Dart→JS requests, matched by `{id}` + [Completer]. Payloads are double-JSON-encoded (no escaping
/// bugs). READY is a handshake (JS sends `{t:'ready'}` after the editor mounts), NOT `onPageFinished`.
///
/// 健壮桥:单条 JS→Dart 通道承载 reply/event;Dart→JS 走 runJavaScript(__anselmDispatch);id+Completer
/// 配对 + 超时;ready 靠 JS 挂载后握手,非 onPageFinished。
class DocBridge {
  DocBridge(this._controller);

  final WebViewController _controller;
  final _pending = <String, Completer<Object?>>{};
  final _ready = Completer<void>();
  int _seq = 0;

  /// Editor content changed (debounced JS-side). markdown payload.
  void Function(String markdown)? onChange;

  /// Document header (title/description) edited in the webview.
  void Function(Map<String, dynamic> meta)? onMeta;

  /// The active heading index changed on scroll (drives the outline's live focus). -1 = none.
  void Function(int index)? onActiveHeading;

  /// The webview scroll offset changed (drives the floating-head collapse).
  void Function(double offset)? onScroll;

  /// The `@` picker needs candidates for a query — answer via [resolveMention] with the same reqId.
  void Function(String query, String reqId)? onMentionSearch;

  Future<void> get ready => _ready.future;
  bool get isReady => _ready.isCompleted;

  /// Register the channel BEFORE loadFlutterAsset so the `ready` handshake is never missed.
  /// 通道须先于 loadFlutterAsset 注册,否则 ready 握手可能漏。
  Future<void> attach() async {
    await _controller.addJavaScriptChannel(
      'AnselmHost',
      onMessageReceived: _onMessage,
    );
  }

  void _onMessage(JavaScriptMessage m) {
    Map<String, dynamic> env;
    try {
      env = jsonDecode(m.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (env['t']) {
      case 'ready':
        if (!_ready.isCompleted) _ready.complete();
      case 'reply':
        final c = _pending.remove(env['id'] as String?);
        if (c == null || c.isCompleted) return; // late/duplicate — ignore
        if (env['ok'] == true) {
          c.complete(env['result']);
        } else {
          c.completeError(DocBridgeException(env['error'] as String? ?? 'unknown'));
        }
      case 'event':
        switch (env['name']) {
          case 'change':
            onChange?.call(env['payload'] as String? ?? '');
          case 'meta':
            onMeta?.call((env['payload'] as Map?)?.cast<String, dynamic>() ?? const {});
          case 'active':
            onActiveHeading?.call((env['payload'] as num?)?.toInt() ?? -1);
          case 'scroll':
            onScroll?.call((env['payload'] as num?)?.toDouble() ?? 0);
          case 'mentionSearch':
            final p = (env['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
            onMentionSearch?.call(p['query'] as String? ?? '', p['reqId'] as String? ?? '');
        }
    }
  }

  /// Call a JS-side method and await its reply. Times out so awaiters never hang.
  Future<Object?> call(String method, [Object? params]) {
    final id = '${_seq++}';
    final c = _pending[id] = Completer<Object?>();
    final req = jsonEncode({'t': 'call', 'id': id, 'method': method, 'params': params});
    // Double-encode: jsonEncode(req) yields a safe, fully-escaped JS string literal argument.
    _controller.runJavaScript('window.__anselmDispatch(${jsonEncode(req)})');
    return c.future.timeout(const Duration(seconds: 8), onTimeout: () {
      _pending.remove(id);
      throw DocBridgeException('bridge "$method" timed out');
    });
  }

  Future<String> getMarkdown() async => (await call('getMarkdown')) as String? ?? '';
  Future<void> setMarkdown(String md) => call('setMarkdown', md);
  Future<void> setMeta(Map<String, dynamic> meta) => call('setMeta', meta);
  Future<void> setTheme(bool dark) => call('setTheme', dark ? 'dark' : 'light');
  Future<void> injectFont(String family, String base64) =>
      call('injectFont', {'family': family, 'base64': base64});
  Future<List<dynamic>> headingRects() async => (await call('headingRects')) as List? ?? const [];
  Future<void> scrollToHeading(int index) => call('scrollToHeading', index);
  Future<void> scrollToTop() => call('scrollToTop');

  /// Answer a pending `@` search (same reqId the [onMentionSearch] fired with).
  Future<void> resolveMention(String reqId, List<Map<String, dynamic>> results) =>
      call('mentionResolve', {'reqId': reqId, 'results': results});

  /// Prime id→{kind,label} so `[[id]]` pills render name+icon on load.
  Future<void> primeMentionCache(List<Map<String, dynamic>> entries) =>
      call('primeMentionCache', {'entries': entries});

  /// Fail all in-flight calls on teardown so awaiters never hang after dispose.
  void dispose() {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(DocBridgeException('disposed'));
    }
    _pending.clear();
  }
}

@immutable
class DocBridgeException implements Exception {
  const DocBridgeException(this.message);
  final String message;
  @override
  String toString() => 'DocBridgeException: $message';
}
