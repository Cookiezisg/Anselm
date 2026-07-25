import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/strings.g.dart';
import '../contract/workspace.dart';
import '../runtime.dart';
import 'set_active_workspace.dart';

/// Cold-start workspace resolution — the single auth axis every workspace-scoped API needs (without it
/// they all 401 UNAUTH_NO_WORKSPACE). After the backend is ready: list `/workspaces`; use the first if
/// any, else create a default one (`/workspaces` is onboarding-exempt, so this runs with no workspace
/// header yet); then set [activeWorkspaceProvider] so every later request carries it. This is the
/// minimal bootstrap — the full onboarding (create/switch/name UI) is a later phase. Auto-retry off; the
/// gate offers an explicit retry.
///
/// 冷启动工作区解析——唯一鉴权轴(缺它所有 workspace 域 API 都 401)。后端就绪后:列 /workspaces,有则取首
/// 个、无则建默认(该端点 onboarding 豁免、此刻无 workspace 头也可),再设 activeWorkspaceProvider 使后续
/// 请求都带它。最小 bootstrap,完整 onboarding 后续阶段。关自动重试,gate 提供显式重试。
class WorkspaceBootstrap extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    // read, NOT watch — this notifier PRODUCES the active workspace, and apiClientProvider now
    // rebuilds on workspace change (S3-pre). Watching it would close a reactive loop that re-runs
    // the bootstrap after every switch and yanks the selection back to the first workspace.
    // read 而非 watch——本 notifier 是 activeWorkspace 的生产者,而 apiClientProvider 已随切换重建;
    // watch 会闭合响应环:每次切换后 bootstrap 重跑,把选区拽回第一个 workspace。
    final api = ref.read(apiClientProvider);
    final page = await api.getPage('/api/v1/workspaces', Workspace.fromJson);
    final ws = page.items.isNotEmpty
        ? page.items.first
        : await api.postEntity(
            '/api/v1/workspaces',
            Workspace.fromJson,
            body: {
              'name': t.coldStart.defaultWorkspace,
              'language': LocaleSettings.currentLocale.languageTag,
            },
          );
    // After the await — past the synchronous build, so setting another provider is safe. 过同步 build 后设。
    // Goes through [setActiveWorkspace], which settles the runtime chain in the same breath: the id
    // change dirties dio, and leaving that dirt for a widget's first watch to flush is WRK-083 L2 (an
    // assertion on every single cold start). 走 setActiveWorkspace,顺手把运行时链摊平:id 一变 dio 就脏,
    // 把这份脏留给某个 widget 的首次 watch 去刷,就是 WRK-083 L2(每次冷启动必抛的那条断言)。
    setActiveWorkspace(ref, ws.id);
    ref
        .read(activeWorkspaceNameProvider.notifier)
        .set(ws.name); // for the sidebar footer 供底栏显示
    return ws.id;
  }
}

final workspaceBootstrapProvider =
    AsyncNotifierProvider<WorkspaceBootstrap, String>(
      WorkspaceBootstrap.new,
      retry: (_, _) => null,
    );
