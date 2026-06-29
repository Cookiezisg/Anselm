import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'net/api_client.dart';
import 'process/backend_controller.dart';
import 'sse/sse_gateway.dart';

/// DI assembly for the Phase-4.0 runtime backbone: it wires the sidecar supervisor → contract/net →
/// SSE gateway into Riverpod. Lives in `core` (no upward deps); the app root mounts the ProviderScope
/// and features read these providers. Per ADR 0004 the workspace + baseUrl + per-launch token are
/// runtime-injected, and the net/sse layers stay Riverpod-free — they receive their inputs through the
/// callbacks read here, so a frame/request always sees the CURRENT workspace + token.
///
/// Phase 4.0 运行时骨干的 DI 装配(sidecar 监督器 → 契约/net → SSE 网关 接入 Riverpod)。住 core、无上行
/// 依赖;workspace/baseUrl/每次启动 token 运行时注入,net/sse 层不沾 Riverpod、经此处回调拿输入。

/// The active workspace id — the single auth axis (`X-Anselm-Workspace-ID`). null until a workspace is
/// selected (the cold-start feature sets it via [ActiveWorkspace.set]). A modern [Notifier] (NOT the
/// legacy StateProvider, which lives in riverpod/legacy.dart — same stance as G6). 活动 workspace id
/// (唯一鉴权轴),选区前 null;经 set 设置;用现代 Notifier(非 legacy StateProvider)。
class ActiveWorkspace extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
  void clear() => state = null;
}

final activeWorkspaceProvider =
    NotifierProvider<ActiveWorkspace, String?>(ActiveWorkspace.new);

/// The active workspace's DISPLAY NAME — for the sidebar footer. Set alongside the id by the cold-start
/// bootstrap; null until then (the footer falls back to a default label). Kept SEPARATE from
/// [activeWorkspaceProvider] (the id = the auth axis, read as a `String?` by net/sse callbacks) so those
/// call sites stay untyped-by-name. 活动 workspace 显示名(底栏用),由冷启动 bootstrap 与 id 一并设;
/// 设前为 null(底栏回退默认)。与 id provider 分开(id 是鉴权轴、被 net/sse 当 String? 读)。
class ActiveWorkspaceName extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? name) => state = name;
}

final activeWorkspaceNameProvider =
    NotifierProvider<ActiveWorkspaceName, String?>(ActiveWorkspaceName.new);

/// The sidecar supervisor. A plain Provider so tests can override it with a fake-launcher controller.
/// sidecar 监督器;Provider 便于测试 override 假 launcher。
final backendControllerProvider = Provider<BackendController>((ref) => BackendController());

/// Bridges the controller's [BackendState] ValueNotifier into a reactive provider so the WHOLE app gates
/// on one phase (starting / ready / crashed) — features never each handle "backend down". Kicks off
/// start() on first read; stops the child on dispose.
///
/// 把 controller 的 BackendState ValueNotifier 桥成响应式 provider,全 app 据单一 phase 门控;首读即
/// start()、dispose 时关停子进程。
class BackendStartup extends Notifier<BackendState> {
  @override
  BackendState build() {
    final c = ref.watch(backendControllerProvider);
    void sync() => state = c.state.value;
    c.state.addListener(sync);
    ref.onDispose(() {
      c.state.removeListener(sync);
      unawaited(c.stop());
    });
    unawaited(c.start());
    return c.state.value;
  }

  /// Re-attempt startup after a crash (the crashed screen's Retry). 崩溃后重试。
  void retry() => unawaited(ref.read(backendControllerProvider).start());
}

final backendStartupProvider =
    NotifierProvider<BackendStartup, BackendState>(BackendStartup.new);

/// A Dio bound to the live backend base URL — rebuilt when it appears/changes. dio,绑活动 baseUrl(变则重建)。
final dioProvider = Provider<Dio>((ref) {
  final st = ref.watch(backendStartupProvider);
  return Dio(BaseOptions(baseUrl: st.baseUrl ?? ''));
});

/// The single HTTP boundary, wired with the workspace header + per-launch bearer token (both read
/// lazily so every request sees the current value). 唯一 HTTP 边界(workspace + bearer 懒读,每请求取当前值)。
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    dio: ref.watch(dioProvider),
    workspaceId: () => ref.read(activeWorkspaceProvider),
    authToken: () => ref.read(backendStartupProvider).authToken,
  );
});

/// Owner of the three keepAlive SSE streams — null until the backend is READY (no base URL before
/// then). Started on creation, disposed with the scope. Features consume it via the gateway's demuxed
/// per-scope streams. SSE 网关:就绪前 null;创建即 start、随 scope dispose;feature 经其 demux 流消费。
final sseGatewayProvider = Provider<SseGateway?>((ref) {
  final st = ref.watch(backendStartupProvider);
  if (!st.isReady) return null;
  final gw = SseGateway(
    baseUrl: st.baseUrl!,
    workspaceId: () => ref.read(activeWorkspaceProvider),
    authToken: () => ref.read(backendStartupProvider).authToken,
  );
  gw.start();
  ref.onDispose(gw.dispose);
  return gw;
});
