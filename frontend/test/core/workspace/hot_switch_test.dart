import 'dart:convert';

import 'package:anselm/core/process/backend_controller.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/workspace/workspace_bootstrap.dart';
import 'package:anselm/core/workspace/workspace_switch.dart';
import 'package:anselm/features/chat/state/conversation_header.dart';
import 'package:anselm/features/chat/state/title_reveals.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// WRK-062 S3-pre hot-switch pulse: the ApiClient/SSE gateway rebuild when the active workspace
// changes (the cascade every Live repo rides), the bootstrap PRODUCES the workspace without closing
// a reactive loop (a switch must never be yanked back), feature sticky state self-heals, and the
// switch action leaves the old deep link. S3-pre 热切换电池:脉搏级联/生产者出环/粘性自愈/动作离深链。

class _FakeStartup extends BackendStartup {
  @override
  BackendState build() => const BackendState(
    BackendPhase.ready,
    baseUrl: 'http://127.0.0.1:1',
    authToken: 'tk',
  );
}

/// A Dio adapter serving a fixed two-workspace list — the bootstrap's world. 双 ws 固定世界。
class _WorkspacesAdapter implements HttpClientAdapter {
  int listCalls = 0;

  static Map<String, dynamic> _ws(String id, String name) => {
    'id': id,
    'name': name,
    'language': 'zh-CN',
    'createdAt': '2026-07-01T00:00:00Z',
    'updatedAt': '2026-07-01T00:00:00Z',
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    listCalls++;
    return ResponseBody.fromString(
      jsonEncode({
        'data': [_ws('ws_1', 'One'), _ws('ws_2', 'Two')],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container({Dio? dio, GoRouter? router}) {
  final c = ProviderContainer(
    overrides: [
      backendStartupProvider.overrideWith(_FakeStartup.new),
      if (dio != null) dioProvider.overrideWith((ref) => dio),
      if (router != null) goRouterProvider.overrideWithValue(router),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the hot-switch pulse: a workspace change rebuilds the ApiClient', () {
    final c = _container();
    final before = c.read(apiClientProvider);
    c.read(activeWorkspaceProvider.notifier).set('ws_2');
    expect(
      identical(before, c.read(apiClientProvider)),
      isFalse,
      reason: '客户端重建=全部 Live repo 级联重取的脉搏',
    );
  });

  test(
    'a workspace change tears down and rebuilds the SSE gateway (reconnect all three)',
    () {
      final c = _container();
      final before = c.read(sseGatewayProvider);
      expect(before, isNotNull);
      c.read(activeWorkspaceProvider.notifier).set('ws_2');
      final after = c.read(sseGatewayProvider);
      expect(
        identical(before, after),
        isFalse,
        reason: 'SSE 按连接时 workspace 定域,必须重连',
      );
    },
  );

  test(
    'bootstrap PRODUCES the workspace and stays out of the loop — a switch is never yanked back',
    () async {
      final adapter = _WorkspacesAdapter();
      final c = _container(
        dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'))
          ..httpClientAdapter = adapter,
      );
      final first = await c.read(workspaceBootstrapProvider.future);
      expect(first, 'ws_1');
      expect(c.read(activeWorkspaceProvider), 'ws_1');
      final listsAfterBoot = adapter.listCalls;

      c.read(activeWorkspaceProvider.notifier).set('ws_2');
      await c.pump();
      await Future<void>.delayed(Duration.zero);
      expect(
        c.read(activeWorkspaceProvider),
        'ws_2',
        reason: 'watch(apiClient) 的响应环会把选区拽回 ws_1——bootstrap 必须 read',
      );
      expect(adapter.listCalls, listsAfterBoot, reason: '切换不得重跑 bootstrap');

      // REGRESSION PIN (S3 first real-machine run): after a switch the REBUILT client must serve
      // requests. With the pulse on a shared Dio, the stale client's interceptor (closing over a
      // disposed Ref) stayed installed and killed every call. The pulse lives on the Dio itself now.
      // 回归钉:切换后重建的客户端必须能发请求——脉搏若在共享 Dio 上,旧拦截器(捏着已废 Ref)会杀掉
      // 所有调用;脉搏已下沉到 Dio 层。
      final page = await c
          .read(apiClientProvider)
          .getPage('/api/v1/workspaces', (j) => j['id'] as String);
      expect(page.items, isNotEmpty, reason: '切换后的请求绝不能死在旧拦截器里');
    },
  );

  test(
    'chat sticky state self-heals: landing model + title reveals reset on switch',
    () {
      final c = _container();
      c.read(landingModelProvider.notifier).set((
        apiKeyId: 'ak_1',
        modelId: 'm',
      ));
      c.read(titleRevealsProvider.notifier).add('cv_1');
      expect(c.read(landingModelProvider), isNotNull);
      expect(c.read(titleRevealsProvider), isNotEmpty);

      c.read(activeWorkspaceProvider.notifier).set('ws_2');
      expect(
        c.read(landingModelProvider),
        isNull,
        reason: '键对属旧 workspace 的 key 集',
      );
      expect(
        c.read(titleRevealsProvider),
        isEmpty,
        reason: '打字机队列是旧 workspace 的线程',
      );
    },
  );

  testWidgets(
    'the switch action: leave the deep link first, then set the axis',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/library/:id', builder: (_, _) => const SizedBox()),
        ],
        initialLocation: '/library/doc_old',
      );
      final c = _container(router: router);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      c.read(workspaceSwitchProvider).switchTo(id: 'ws_2', name: 'Two');
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/',
        reason: '旧 workspace 的深链必须先离场(选区全 URL 派生)',
      );
      expect(c.read(activeWorkspaceProvider), 'ws_2');
      expect(c.read(activeWorkspaceNameProvider), 'Two');

      // Same-id switch is a no-op (no navigation). 同 id 切换不动路由。
      router.go('/library/doc_new');
      await tester.pumpAndSettle();
      c.read(workspaceSwitchProvider).switchTo(id: 'ws_2', name: 'Two');
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/library/doc_new',
      );
    },
  );
}
