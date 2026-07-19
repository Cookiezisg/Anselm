import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/navigation.dart';
import '../runtime.dart';

/// The workspace HOT-SWITCH action (WRK-062 S3-pre, 拍板 #17). One choreography, three beats:
/// ① leave the old workspace's deep link (`go('/')` — every selection is URL-derived, so this clears
/// them all); ② set the new id+name on the two runtime notifiers; ③ everything else is the reactive
/// cascade: [apiClientProvider] and [sseGatewayProvider] watch the id, every Live repository watches
/// them, every server-state provider watches its repository — the whole tree re-fetches and the three
/// SSE streams reconnect under the new workspace. Feature-local sticky state that must NOT survive a
/// switch (chat's landing model, title reveals) self-heals by watching the id itself — this action
/// never reaches into features.
///
/// workspace 热切换动作(S3-pre,拍板 #17)。一次编排三拍:①先离开旧 workspace 深链(go('/'),选区全部
/// URL 派生、一步清空);②在两个 runtime notifier 上设新 id+name;③其余交给响应级联:apiClient/SSE 网关
/// watch id、全部 Live repo watch 它们、全部 server-state watch repo——整树重取、三流重连。不该跨切换
/// 存活的 feature 粘性态(landing 模型/打字机队列)各自 watch id 自愈——本动作绝不伸手进 features。
class WorkspaceSwitch {
  WorkspaceSwitch(this._ref);

  final Ref _ref;

  void switchTo({required String id, required String name}) {
    if (_ref.read(activeWorkspaceProvider) == id) return; // already there 已在此
    // Navigate FIRST: the old deep link must be gone before the cascade re-fetches, or a still-mounted
    // detail page briefly queries the old id under the new workspace (a 404 flash).
    // 先导航:级联重取前旧深链必须先离场,否则未卸载的详情页会在新 workspace 下查旧 id(404 闪)。
    _ref.read(goRouterProvider).go('/');
    _ref.read(activeWorkspaceProvider.notifier).set(id);
    _ref.read(activeWorkspaceNameProvider.notifier).set(name);
  }
}

final workspaceSwitchProvider = Provider<WorkspaceSwitch>(WorkspaceSwitch.new);
