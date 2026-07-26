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
    return ws.id;
  }

  /// Create the first workspace through the onboarding-exempt standard client, then release the gate.
  /// The backend's free-tier provisioning hook is best-effort and asynchronous; creation never waits on
  /// network provisioning, so this method intentionally treats the durable Workspace row as success.
  ///
  /// 经 onboarding 豁免的标准 client 创建首个 workspace,再放 gate。后端免费档 hook 是 best-effort
  /// 异步过程;创建绝不拿外网 provisioning 当闸,故这里以 durable Workspace 行落盘为成功。
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
    state = AsyncData(ws.id);
    return ws;
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
