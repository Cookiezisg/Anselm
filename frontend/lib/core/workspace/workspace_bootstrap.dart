import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/strings.g.dart';
import '../contract/workspace.dart';
import '../runtime.dart';
import 'set_active_workspace.dart';

/// Cold-start workspace resolution — the single auth axis every workspace-scoped API needs. After
/// the backend is ready: list `/workspaces`; activate the first existing row, or return `null` and let
/// [WorkspaceGate] hold the router on the one-page onboarding. Creating from that page uses [create],
/// then settles the same runtime axis before the gate releases the shell. The decision comes only from
/// server truth — no first-run preference can drift from a factory reset or an externally restored DB.
/// Auto-retry is off; the gate offers an explicit retry.
///
/// 冷启动工作区解析——workspace-scoped API 的唯一鉴权轴。后端就绪后列 `/workspaces`:有行则激活首行;
/// 空集返 null,由 WorkspaceGate 把 router 扣在单页 onboarding。该页经 [create] 创建后先摊平同一
/// runtime 轴、再放壳。是否首启只认服务端真相,不另存会与出厂重置/外部恢复漂移的 preference。关自动
/// 重试,gate 提供显式 retry。
class WorkspaceBootstrap extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    // read, NOT watch — this notifier PRODUCES the active workspace, and apiClientProvider now
    // rebuilds on workspace change (S3-pre). Watching it would close a reactive loop that re-runs
    // the bootstrap after every switch and yanks the selection back to the first workspace.
    // read 而非 watch——本 notifier 是 activeWorkspace 的生产者,而 apiClientProvider 已随切换重建;
    // watch 会闭合响应环:每次切换后 bootstrap 重跑,把选区拽回第一个 workspace。
    final api = ref.read(apiClientProvider);
    final page = await api.getPage('/api/v1/workspaces', Workspace.fromJson);
    if (page.items.isEmpty) return null;
    final ws = page.items.first;
    _activate(ws);
    if (ws.defaultDialogue == null) await _prepareManagedDefault();
    return ws.id;
  }

  /// Create a workspace, then wait for the existing managed provision action before releasing Chat.
  /// The backend hook remains best-effort for API callers, but the desktop's first-run path must not
  /// let the user send a message into the short window before the default model is seeded.
  ///
  /// 创建 workspace 后先等待既有受管开通动作再放 Chat。后端 hook 对 API caller 仍是 best-effort；
  /// 但桌面首启不能让用户在默认模型播种前发消息，撞上短暂的无模型窗口。
  Future<Workspace> create(String name) async {
    final ws = await ref
        .read(apiClientProvider)
        .postEntity(
          '/api/v1/workspaces',
          Workspace.fromJson,
          body: {
            'name': name,
            'language': LocaleSettings.currentLocale.languageTag,
          },
        );
    _activate(ws);
    if (ws.defaultDialogue == null) await _prepareManagedDefault();
    state = AsyncData(ws.id);
    return ws;
  }

  Future<void> _prepareManagedDefault() async {
    // Provisioning is intentionally a foreground readiness check here, not a second implementation
    // of the gateway flow. Offline/degraded free tier still releases the local app after the request
    // returns; a later model setup can recover it through Settings.
    // 这里是前台就绪检查，不复制网关开通逻辑。免费档离线/降级时请求返回后仍放本地 app，之后可从设置恢复。
    try {
      await ref
          .read(apiClientProvider)
          .postData('/api/v1/freetier:provision')
          .timeout(const Duration(seconds: 20));
    } on Object {
      // The backend keeps provisioning best-effort. The shell must remain usable for BYOK and
      // explicit model setup even when the managed gateway is unavailable.
      // 后端开通保持 best-effort；网关不可用时仍让用户进入壳，通过 BYOK/设置显式配模。
    }
  }

  void _activate(Workspace ws) {
    // After the await — past the synchronous build, so setting another provider is safe. 过同步 build 后设。
    // Goes through [setActiveWorkspace], which settles the runtime chain in the same breath: the id
    // change dirties dio, and leaving that dirt for a widget's first watch to flush is WRK-083 L2 (an
    // assertion on every single cold start). 走 setActiveWorkspace,顺手把运行时链摊平:id 一变 dio 就脏,
    // 把这份脏留给某个 widget 的首次 watch 去刷,就是 WRK-083 L2(每次冷启动必抛的那条断言)。
    setActiveWorkspace(ref, ws.id);
    ref
        .read(activeWorkspaceNameProvider.notifier)
        .set(ws.name); // for the sidebar footer 供底栏显示
  }
}

final workspaceBootstrapProvider =
    AsyncNotifierProvider<WorkspaceBootstrap, String?>(
      WorkspaceBootstrap.new,
      retry: (_, _) => null,
    );
