import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pending settings-item JUMP target — a one-shot item anchor id ([SettingsItem.*]) that a
/// search-result click sets AFTER selecting the target panel. The matching [SettingsAnchor] in the
/// now-mounted panel scrolls ITSELF into view + one-shot washes, then clears this. Held here (not by
/// the anchor) so the click site and the anchor never need to know each other — the chat transcript's
/// `transcriptJumpProvider` pattern.
///
/// 设置项跳转的待办目标——一次性 item 锚 id:结果点击先选面板、再设它;目标面板里匹配的 SettingsAnchor
/// 自滚入视 + 一次性洗亮后清空。目标外置(锚不持有)——点击处与锚互不相识,同 chat 的 transcriptJumpProvider。
class SettingsJumpController extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String anchor) => state = anchor;

  /// Clear only while still pointing at [anchor] — a LATER request must not be stomped by an earlier
  /// anchor's post-frame cleanup. 仅当仍指向 anchor 时清:晚到的请求不被早锚的收尾抹掉。
  void clear(String anchor) {
    if (state == anchor) state = null;
  }
}

final settingsJumpProvider =
    NotifierProvider<SettingsJumpController, String?>(SettingsJumpController.new);
