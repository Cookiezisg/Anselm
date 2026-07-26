import 'dart:convert';

import 'package:anselm/core/process/backend_controller.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/shell/inspector_memory.dart';
import 'package:anselm/core/workspace/workspace_bootstrap.dart';
import 'package:anselm/core/workspace/workspace_switch.dart';
import 'package:anselm/features/chat/state/conversation_header.dart';
import 'package:anselm/features/chat/state/conversation_stream_provider.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
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

/// Records every request path so a guard can ask "did anything ask about X after the switch".
/// 记录每条请求路径,好让守卫能问「切换之后还有没有谁问过 X」。
class _RecordingAdapter implements HttpClientAdapter {
  final paths = <String>[];

  int hits(String needle) => paths.where((p) => p.contains(needle)).length;
  void reset() => paths.clear();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    // A conversation-shaped body for `/conversations/<id>`, an empty page for everything else. The
    // first draft answered `{data: []}` to EVERYTHING, `getConversation` could not parse it, and the
    // controller's error path issued a second read — which the guard then took as evidence of the very
    // thing it was hunting. A control run with NO switch at all is what exposed that; without it this
    // test would have "proved" a defect that was its own fixture.
    // `/conversations/<id>` 给对话形状的响应体,其余给空页。初稿对**一切**都答 `{data: []}`,
    // `getConversation` 解析不了、控制器的错误路径又读了一次——而守卫把那一次当成了它正在追捕的东西的证据。
    // 是一次**完全不切换**的对照跑把这件事暴露出来的;没有它,本测试会「证明」一个由它自己的夹具制造的缺陷。
    final m = RegExp(r'/conversations/([^/]+)$').firstMatch(options.path);
    final body = m == null
        ? {'data': <dynamic>[]}
        : {
            'data': {
              'id': m.group(1),
              'title': 'T',
              'autoTitled': false,
              'createdAt': '2026-07-01T00:00:00Z',
              'updatedAt': '2026-07-01T00:00:00Z',
              'lastMessageAt': '2026-07-01T00:00:00Z',
            },
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The open-thread stand-in: it does the one thing that matters here — keep an `autoDispose.family`
/// provider keyed by the selected conversation alive for as long as the route is mounted.
/// 打开线程的替身:它只做这里唯一要紧的事——只要该路由还挂着,就让一个按选中对话分家的
/// `autoDispose.family` provider 活着。
class _OpenThread extends ConsumerWidget {
  const _OpenThread();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedConversationProvider);
    if (sel != null) {
      // BOTH selection-scoped families, because they die at different speeds. The header alone
      // under-reports: the first fix cut the real machine from three 404s to one, and the survivor
      // was the transcript stream — which holds SSE subscriptions and therefore lingers longer.
      // **两个**选区域 family 都要,因为它们死得不一样快。只挂 header 会**少报**:第一版修复在真机上把三条
      // 404 砍到一条,而幸存的那一条正是 transcript 流——它握着 SSE 订阅,故活得更久。
      ref.watch(conversationHeaderProvider(sel.id));
      ref.watch(conversationStreamProvider(sel.id));
    }
    return const SizedBox();
  }
}

/// The right-island stand-in: it holds the conversation-keyed providers for the LIVE selection *or*
/// the shell's remembered thread — and it is mounted at the ROOT, beside the router, exactly like the
/// real inspector. So `go('/')` alone never releases it; only clearing the memory does. The latch
/// mirrors AppShell's wiring verbatim (remember on every entry INTO a conversation).
/// 右岛替身:为**活选区或壳的线程记忆**握住对话域 provider——且挂在**根**上、与路由并排,和真 inspector 一样。
/// 于是单靠 `go('/')` 永远放不掉它;只有清记忆才放。上闩逻辑逐字镜像 AppShell(每次**进入**对话时 remember)。
class _KeepAliveInspector extends ConsumerWidget {
  const _KeepAliveInspector();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(selectedConversationProvider, (prev, next) {
      if (next != null) {
        ref.read(lastChatThreadProvider.notifier).remember(next.id);
      }
    });
    final sel = ref.watch(selectedConversationProvider);
    final id = sel?.id ?? ref.watch(lastChatThreadProvider);
    if (id != null) {
      ref.watch(conversationHeaderProvider(id));
      ref.watch(conversationStreamProvider(id));
    }
    return const SizedBox();
  }
}

ProviderContainer _container({Dio? dio, GoRouter? router, bool sse = true}) {
  final c = ProviderContainer(
    overrides: [
      backendStartupProvider.overrideWith(_FakeStartup.new),
      if (dio != null) dioProvider.overrideWith((ref) => dio),
      if (router != null) goRouterProvider.overrideWithValue(router),
      // A gateway that REBUILDS on a workspace change but never opens a socket.
      //
      // Both halves matter. Keeping the real one leaks its reconnect backoff timer (the fake adapter
      // 400s the three stream requests) and the binding fails the test for a pending timer — a failure
      // about the harness wearing the costume of a failure about the code. But stubbing it to a plain
      // `null` VALUE removes it from the dependency graph, and then the guard below goes vacuously
      // green: the gateway's rebuild is precisely what drags a stale conversation provider back to
      // life, so a gateway that cannot rebuild cannot reproduce the defect. Verified both ways.
      //
      // 一个**会随 workspace 变更重建、但从不开 socket** 的网关。
      //
      // 两半都要紧。留真的会漏它的重连退避定时器(假 adapter 把三条流 400 掉),binding 便以「定时器未清」判负
      // ——一个关于夹具的失败,穿着关于代码的失败的外衣。但把它 stub 成一个 `null` **值**又会把它移出依赖图,
      // 于是下面那条守卫**空绿**:正是网关的重建把陈旧的对话 provider 拽回人间,一个不会重建的网关复现不了这个
      // 缺陷。两个方向都验过。
      if (!sse)
        sseGatewayProvider.overrideWith((ref) {
          ref.watch(activeWorkspaceProvider);
          return null;
        }),
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

  // WRK-083 L1 — «leave first» has to mean «leave BEFORE», and that is a FRAME, not a statement order.
  //
  // The action already navigated first, with a comment naming the exact hazard. It was still wrong:
  // `go('/')` updates the router synchronously, but the widgets watching the selection rebuild on the
  // NEXT frame, and only when the last of them lets go does an `autoDispose.family` provider keyed by
  // the old id actually die. Setting the workspace inside that window fires the repository cascade
  // while those providers are alive — they re-run with the old id under the NEW workspace, and the
  // backend correctly answers 404. Real machine: three 404s in one instant (`/conversations/{old}`,
  // `/messages`, `/workdir`), matching the original log burst exactly.
  //
  // **What this must NOT assert**: "the URL is `/` when the id flips". That was the first version of
  // this guard and it was VACUOUSLY GREEN — `go('/')` updates the configuration synchronously, so the
  // URL is already `/` in the buggy version too. It passed with the fix reverted, which is the only
  // reason it got caught. The property is not about the URL; it is about who is still ALIVE to ask.
  //
  // So the assertion is the WIRE: after the switch, no request may go out for the old conversation.
  // That is exactly what the real machine showed and exactly what the user would have seen.
  //
  // WRK-083 L1——「先离开」必须意味着「**在此之前**离开」,而那是一**帧**、不是语句顺序。
  //
  // 这个动作本来就先导航,注释里还点名了那个风险。它依然是错的:`go('/')` 同步更新 router,但 watch 选区的
  // widget 要**下一帧**才重建,且只有当**最后一个**松手,按旧 id 分家的 `autoDispose.family` 才真正死掉。在那个
  // 窗口里设 workspace,repository 级联就在它们**还活着**时开火——带着旧 id 在新 workspace 下重跑,后端完全正确
  // 地答 404。真机:同一瞬间三条 404,与原始日志那一簇逐字同型。
  //
  // **它绝不该断言什么**:「id 翻转时 URL 是 `/`」。那是本守卫的第一版,而它是**空绿**的——`go('/')` 同步更新
  // 配置,故带病版本里 URL 同样已经是 `/`。它在修复被回滚后照样通过,而这正是它被抓住的唯一原因。这条性质与
  // URL 无关,它关乎**还有谁活着在问**。
  //
  // 故断言落在**线缆**上:切换之后,不得再有任何针对旧对话的请求发出。这正是真机看到的,也正是用户会看到的。
  testWidgets('after a switch, nothing asks about the old conversation', (
    tester,
  ) async {
    final adapter = _RecordingAdapter();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/chat/:id', builder: (_, _) => const _OpenThread()),
      ],
      initialLocation: '/chat/cv_old',
    );
    final c = _container(
      dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'))
        ..httpClientAdapter = adapter,
      router: router,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      adapter.hits('cv_old'),
      greaterThan(0),
      reason: 'precondition: the open thread really did fetch itself',
    );

    adapter.reset();
    // CONTROL: with no switch at all, nothing further is asked. This line is what makes the assertion
    // below mean anything — the first draft's fixture answered `{data: []}` to every path,
    // `getConversation` could not parse it, the error path re-read, and the guard took that retry for
    // the defect. The control caught it.
    // **对照组**:完全不切换时不会再有请求。正是这一行让下面那条断言有意义——初稿夹具对一切路径都答
    // `{data: []}`,`getConversation` 解析不了、错误路径又读一次,而守卫把那次重读当成了缺陷。对照组抓到了它。
    await tester.pumpAndSettle();
    expect(
      adapter.hits('cv_old'),
      0,
      reason: 'control: nothing polls on its own',
    );
    c.read(workspaceSwitchProvider).switchTo(id: 'ws_2', name: 'Two');
    await tester.pumpAndSettle();

    expect(c.read(activeWorkspaceProvider), 'ws_2');
    expect(
      find.byType(_OpenThread),
      findsNothing,
      reason: 'the old thread route really is gone by now',
    );
    expect(
      adapter.hits('cv_old'),
      0,
      reason:
          'a provider keyed by the old conversation re-ran under the new workspace — '
          "that is where L1's 404s come from",
    );

    // (kept) Tear the container down INSIDE the body. The SSE connection answers the fake adapter's 400 by
    // scheduling its reconnect backoff, and the widget binding fails a test that ends with a pending
    // timer. Disposing here retires the gateway while the test still owns the clock. The gateway must
    // stay REAL for this test — with it stubbed out the assertion above goes vacuously green, because
    // the gateway's rebuild is precisely what drags the stale conversation provider back to life.
    // **在 body 内**拆掉容器。SSE 连接对假 adapter 的 400 的回应是排一次重连退避,而 widget binding 会让
    // 「结束时仍有定时器」的测试判负。在这里 dispose,是趁测试还握着时钟把网关退役。本测试的网关必须是**真的**
    // ——把它 stub 掉,上面那条断言就空绿了,因为**正是网关的重建**把那个陈旧的对话 provider 拽回了人间。
    c.dispose();
    await tester.pump(const Duration(seconds: 10));
  });

  // WRK-083 L1, the RESIDUAL — the guard above releases everything when the route leaves, and the real
  // shell does not: the right island REMEMBERS the last thread ([lastChatThreadProvider]) so the
  // sidestage survives an ocean peek, which means `go('/')` alone frees nothing on that island. After
  // the first fix the real machine still showed FOUR old-conversation requests at every switch
  // (`interactions`/`touchpoints`/`todos` 200 + `messages` 404 — only ListMessages checks existence).
  //
  // The property: beat ① of the switch must clear the memory SYNCHRONOUSLY, in the same instant as
  // `go('/')`, so the panel unmounts a frame before the axis flips. A memory that merely self-heals by
  // watching the workspace id resets in the SAME flush that re-runs the stale providers — one frame
  // too late, and this test stays red that way: the wire assertion below caught exactly that when the
  // choreography lacked its explicit clear.
  //
  // WRK-083 L1 **残留**——上一条守卫的一切都随路由离场而释放,真壳不是:右岛**记住**最后的线程
  // ([lastChatThreadProvider]),侧幕因此活过「去别的海洋看一眼」,也因此单靠 `go('/')` 在那座岛上什么都放不掉。
  // 第一轮修复后真机每次切换仍有**四条**旧对话请求(`interactions`/`touchpoints`/`todos` 200 + `messages` 404
  // ——只有 ListMessages 查存在性)。
  //
  // 性质:切换第①拍必须与 `go('/')` **同瞬同步**清记忆,面板才能在轴翻转前一帧卸载。只靠 watch workspace id
  // 自愈的记忆,会在**重跑陈旧 provider 的同一次 flush**里才复位——晚一帧,而那样本测试就是红的:编舞缺显式
  // 清除时,下面那条线缆断言抓到的正是这个。
  testWidgets('the switch also releases the KEPT-ALIVE right island (L1 残留)', (
    tester,
  ) async {
    final adapter = _RecordingAdapter();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/chat/:id', builder: (_, _) => const SizedBox()),
      ],
      initialLocation: '/',
    );
    final c = _container(
      dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'))
        ..httpClientAdapter = adapter,
      router: router,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        // The inspector sits BESIDE the router, not under the route — leaving the route must not be
        // what releases it, or the test is the previous one again. 替身与路由**并排**、不在路由之下——
        // 释放它的不能是离开路由,否则本测试就是上一条的复读。
        child: Stack(
          textDirection: TextDirection.ltr,
          children: [
            MaterialApp.router(routerConfig: router),
            const _KeepAliveInspector(),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate INTO the thread (the rail-click path) so the memory latches like the real shell's.
    // **导航进入**线程(rail 点击径),记忆像真壳一样上闩。
    router.go('/chat/cv_old');
    await tester.pumpAndSettle();
    expect(
      c.read(lastChatThreadProvider),
      'cv_old',
      reason: 'precondition: the shell memory latched on entry',
    );
    expect(
      adapter.hits('cv_old'),
      greaterThan(0),
      reason: 'precondition: the inspector really did fetch the thread',
    );

    adapter.reset();
    await tester.pumpAndSettle();
    expect(
      adapter.hits('cv_old'),
      0,
      reason: 'control: nothing polls on its own',
    );

    c.read(workspaceSwitchProvider).switchTo(id: 'ws_2', name: 'Two');
    await tester.pumpAndSettle();

    expect(c.read(activeWorkspaceProvider), 'ws_2');
    expect(
      c.read(lastChatThreadProvider),
      isNull,
      reason:
          'beat ① must clear the shell memory — it belongs to the old world',
    );
    expect(
      adapter.hits('cv_old'),
      0,
      reason:
          'the kept-alive island held old-conversation providers across the flip — '
          "that is L1's residual four-request burst",
    );

    // Same teardown discipline as the previous test (real gateway + pending backoff timer).
    // 与上一条同款收尾(真网关 + 待清退避定时器)。
    c.dispose();
    await tester.pump(const Duration(seconds: 10));
  });
}
