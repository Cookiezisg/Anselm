import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime.dart';

/// The right island's remembered chat thread — the binding that keeps the sidestage mounted (offstage)
/// while the user peeks at another ocean, so its scenes / scroll state survive the round trip. A
/// SHELL-level concern like [rightPanelCollapsedProvider]: the shell composition reads it, the app
/// layer writes it on every selection change, and the workspace hot-switch clears it in beat ① —
/// synchronously, in the same instant as `go('/')` — so the panel unmounts a full frame BEFORE the
/// axis flips. That order is load-bearing: provider rebuilds flush before the next widget frame, so a
/// memory still latched at flip time keeps four old-conversation providers listened — they re-run
/// under the new workspace and the backend correctly answers 404 (WRK-083 L1). The
/// [activeWorkspaceProvider] watch is the local invariant, not the fix: it wipes the latch on ANY
/// workspace flip (a future non-choreography path degrades to one stale flush instead of a permanent
/// cross-world binding), but it is a frame too late to prevent the flush — only the choreography's
/// explicit [clear] is early enough.
///
/// 右岛记住的 chat 线程——正是这个绑定让侧幕在用户去别的海洋看一眼时保持挂载(offstage),场次/滚动态活过往返。
/// 壳级关注点(同 [rightPanelCollapsedProvider] 一族):壳组合读它、app 层在每次选区变更时写它、workspace 热切换
/// 在第①拍清它——与 `go('/')` 同瞬同步清,面板因此在轴翻转**前一整帧**卸载。这个顺序是承重的:provider 重建在下
/// 一个 widget 帧之前 flush,翻转时仍闩着的记忆会让四个旧对话 provider 保持被监听——它们在新 workspace 下重跑,
/// 后端完全正确地答 404(WRK-083 L1)。watch [activeWorkspaceProvider] 是局部不变量、不是修法本身:它在**任何**
/// workspace 翻转时弃闩(未来若出现绕过编舞的切换路径,退化为一次陈旧 flush 而非永久跨世界绑定),但它晚了一帧、
/// 拦不住那次 flush——只有编舞里显式的 [clear] 够早。
class LastChatThread extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(activeWorkspaceProvider);
    return null;
  }

  void remember(String id) => state = id;

  void clear() => state = null;
}

final lastChatThreadProvider = NotifierProvider<LastChatThread, String?>(
  LastChatThread.new,
);
