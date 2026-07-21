import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_prefs_providers.dart';
import '../../../core/settings/follow_mode.dart';
import '../../../core/shell/right_panel.dart';
import 'sidestage_activity_provider.dart';
import 'stage_director_provider.dart';

/// The sidestage AUTO-REVEAL (缺口A, 用户 0719 改判) — under a FOLLOWING [FollowMode] a conversation's FIRST
/// staged activity auto-opens the chat right island. The chat bucket of [rightPanelCollapsedProvider] defaults
/// COLLAPSED (WRK-065「运行中绝不自动弹窗」was the prior stance); the follow three-notch now governs the
/// island the same way it governs staging:
///  - `always` / `firstPerConversation` → the first staged activity opens the island;
///  - `never` → it never opens (the toggle still lights; the user opens it explicitly).
///
/// The [StageDirector] ALREADY gates STAGING by the same mode (`_followAllowed`) — a `never` thread never sets
/// `stageOpen`, a `firstPerConversation` thread stages exactly once — so watching `stageOpen` false→true rides
/// that gate; the explicit `never` guard just makes the「从不档不开」contract self-evident and future-proof.
///
/// RESPECTS a manual close (WRK-065「别做成关不掉的弹窗」): once the user collapses a VISIBLE sidestage for a
/// conversation this session, it never auto-pops again for that conversation ([sidestageManualCloseProvider],
/// keep-alive so it outlives the auto-dispose reveal watcher). Manual-close is only recorded when the panel was
/// actually on screen (activity present) so an ocean switch flipping the bucket never counts as a close.
///
/// 侧幕自动揭示(缺口A):跟随档(always/首次)下,会话首个登台活动自动开右岛;never 不开(toggle 照亮、用户显式
/// 点开)。chat 桶默认收起。导演器已按同档 gate 登台,故观 stageOpen false→true 即随该 gate;显式 never 守卫
/// 让「从不档不开」自明。尊重手动关闭:用户本会话把可见侧幕关过后,该会话不再自动弹(手动关集 keep-alive);仅在
/// 面板确在屏上(有 activity)时记为手动关,故切海洋翻桶不误记。
class SidestageManualClose extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// Remember a conversation the user manually collapsed the sidestage for (idempotent). 记住手动关的会话。
  void mark(String conversationId) {
    if (state.contains(conversationId)) return;
    state = {...state, conversationId};
  }
}

/// Conversation ids the user manually collapsed the sidestage for THIS session — never auto-re-popped.
/// keep-alive (NOT autoDispose) so it survives the per-conversation reveal watcher coming and going.
/// 用户本会话手动关过侧幕的会话集(不再自动弹),keep-alive。
final sidestageManualCloseProvider =
    NotifierProvider<SidestageManualClose, Set<String>>(
      SidestageManualClose.new,
    );

/// Drives缺口A for one conversation — the shell BARE-WATCHES it while a chat thread is selected, so it runs
/// whether the island is open OR closed (exactly when a collapsed island must react to the first activity). It
/// holds no state; it only wires two listeners tied to its own (autoDispose) lifecycle. 由壳保活,只接线两监听。
final sidestageAutoRevealProvider = Provider.autoDispose.family<void, String>((
  ref,
  conversationId,
) {
  void revealIfAllowed() {
    if (ref.read(followModeProvider) == FollowMode.never) {
      return; // 从不档不开
    }
    if (ref.read(sidestageManualCloseProvider).contains(conversationId)) {
      return; // 手动关过不弹
    }
    ref.read(rightPanelCollapsedProvider.notifier).set(false);
  }

  // First staged activity (false→true) → open the island — mode-gated + manual-close-respected. 首个登台→开岛。
  ref.listen<bool>(
    stageDirectorProvider(conversationId).select((s) => s.stageOpen),
    (prev, next) {
      if (prev == true || !next) {
        return; // only the false→true stage entrance 仅登台入场
      }
      // The fire-immediate callback runs while this provider itself is building. Riverpod correctly
      // forbids mutating another provider on that stack, so defer only this catch-up write by one
      // microtask; normal later entrances still reveal synchronously. fire-immediate 回调在本 provider
      // build 栈内，Riverpod 禁止它直接改别的 provider；仅补偿写延后一微任务，正常后续登台仍同步。
      if (prev == null) {
        Future<void>.microtask(() {
          if (ref.mounted) revealIfAllowed();
        });
        return;
      }
      revealIfAllowed();
    },
    // Cold startup can hydrate / replay the first tool stream before AppShell mounts this watcher.
    // Reconcile the current true state too, otherwise that one entrance is permanently missed.
    // 冷启动首条流可能先于壳挂本监听到达；也须对齐当前 true，免首场永久漏展开。
    fireImmediately: true,
  );
  // A user collapse (false→true) of a VISIBLE panel = a manual close: remember it so we never fight them.
  // 用户关掉可见面板=手动关,记住,绝不再抢。
  ref.listen<bool>(rightPanelCollapsedProvider, (prev, next) {
    if (prev == false &&
        next == true &&
        ref.read(sidestageActivityProvider(conversationId))) {
      ref.read(sidestageManualCloseProvider.notifier).mark(conversationId);
    }
  });
});
