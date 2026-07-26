import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/navigation.dart';
import '../runtime.dart';
import '../shell/inspector_memory.dart';
import 'set_active_workspace.dart';

/// The workspace HOT-SWITCH action (WRK-062 S3-pre, 拍板 #17). One choreography, three beats:
/// ① LEAVE the old world — `go('/')` (every selection is URL-derived, so this clears them all) AND
/// clear the shell's remembered chat thread ([lastChatThreadProvider], the binding that keeps the
/// sidestage mounted past its route); ② one frame later, set the new id+name on the two runtime
/// notifiers; ③ everything else is the reactive cascade: [apiClientProvider] and [sseGatewayProvider]
/// watch the id, every Live repository watches them, every server-state provider watches its
/// repository — the whole tree re-fetches and the three SSE streams reconnect under the new workspace.
///
/// Beat ② is a POST-FRAME callback because «leave first» means leave by a FRAME, not by statement
/// order (WRK-083 L1): widgets release their conversation-keyed providers only when the frame after
/// `go('/')` unmounts them, and provider rebuilds flush BEFORE the next widget frame — so anything
/// still listened-to at flip time re-runs with the old id under the new workspace (the backend
/// correctly answers 404). Both halves of beat ① are needed for that frame to actually free
/// everything: the deep link releases the transcript, the memory clear releases the kept-alive right
/// island. Feature-local sticky state that must NOT survive a switch (chat's landing model, title
/// reveals) self-heals by watching the id itself — this action never reaches into features (the
/// memory it clears is core/shell).
///
/// workspace 热切换动作(S3-pre,拍板 #17)。一次编排三拍:①**离开旧世界**——`go('/')`(选区全部 URL 派生、
/// 一步清空)**并**清壳的 chat 线程记忆([lastChatThreadProvider],让侧幕活过路由的那个绑定);②一帧之后,
/// 在两个 runtime notifier 上设新 id+name;③其余交给响应级联:apiClient/SSE 网关 watch id、全部 Live repo
/// watch 它们、全部 server-state watch repo——整树重取、三流重连。
///
/// 第②拍走 **post-frame**,因为「先离开」指的是先一**帧**、不是先一条语句(WRK-083 L1):widget 要等 `go('/')`
/// 之后那一帧卸载才放掉对话域 provider,而 provider 重建在下一个 widget 帧**之前** flush——翻转瞬间仍被监听的
/// 一切都会带旧 id 在新 workspace 下重跑(后端完全正确地答 404)。第①拍的两半缺一不可,那一帧才真正放干净:
/// 深链放掉 transcript,记忆清除放掉保活的右岛。不该跨切换存活的 feature 粘性态(landing 模型/打字机队列)各自
/// watch id 自愈——本动作绝不伸手进 features(它清的记忆在 core/shell)。
class WorkspaceSwitch {
  WorkspaceSwitch(this._ref);

  final Ref _ref;

  void switchTo({required String id, required String name}) {
    if (_ref.read(activeWorkspaceProvider) == id) return; // already there 已在此
    _ref.read(goRouterProvider).go('/');
    // AFTER the navigation: the shell latches the memory on every entry INTO a conversation and never
    // on the way out, so this order cannot be re-latched — but keep it explicit all the same.
    // 在导航**之后**:壳只在进入对话时上闩、离开绝不上闩,故此序不会被重新闩上——仍显式保持。
    _ref.read(lastChatThreadProvider.notifier).clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setActiveWorkspace(_ref, id);
      _ref.read(activeWorkspaceNameProvider.notifier).set(name);
    });
  }
}

final workspaceSwitchProvider = Provider<WorkspaceSwitch>(WorkspaceSwitch.new);
