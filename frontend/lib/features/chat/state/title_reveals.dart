import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runtime.dart';

/// Threads whose FRESH auto-title should land as a one-shot typewriter (the "fake stream") — in the
/// rail row AND the head, together. Fed by ONE detector: the list notifier's fold-in (title went
/// empty→non-empty AND `autoTitled`; a user rename never matches — the row being renamed already has a
/// title, and rename responses carry autoTitled=false). Both consumers remove the id when their
/// typewriter finishes (idempotent — they finish in the same frame). Detection lives with the rail's
/// provider, so a title landing while another ocean is open simply appears static later — the "first
/// appearance" moment has passed.
///
/// 「新自动命名以一次性打字机落地(假流式)」的线程集——rail 行与浮层头同播。**单一检测点**:列表 notifier
/// 折入处(title 空→非空 且 `autoTitled`;用户改名不命中——被改的行已有名,且改名响应 autoTitled=false)。
/// 两个消费者播完各自 remove(幂等,同帧完成)。检测随 rail provider 活——别的海洋期间落的标题回来即静态
/// (「第一次出现」的时刻已过)。
class TitleReveals extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // A workspace switch empties the queue — the ids are the old workspace's threads (S3-pre).
    // 切 workspace 清队:id 是旧 workspace 的线程。
    ref.watch(activeWorkspaceProvider);
    return const {};
  }

  void add(String id) => state = {...state, id};

  void remove(String id) {
    if (!state.contains(id)) return;
    state = {...state}..remove(id);
  }
}

final titleRevealsProvider = NotifierProvider<TitleReveals, Set<String>>(TitleReveals.new);
