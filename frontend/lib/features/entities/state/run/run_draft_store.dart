import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../selected_entity.dart';

/// Session-lived run-input drafts (调试台参数记忆, 0719 拍板 session 级 + JSON-first): the terminal
/// controller is an autoDispose family, so its in-memory draft dies on deselect — this store keeps the
/// edited JSON TEXT alive for the whole app session instead, WITHOUT persisting to disk (a debug
/// scratchpad is not configuration). Buckets keep kind-specific dimensions apart: a handler remembers
/// per METHOD, a workflow per SOURCE — switching back restores exactly what you typed there. Editing
/// writes text quietly ([setText] does NOT notify — a keystroke must not rebuild the lifecycle); a FILL
/// ([fill] — «示例» / «用这份输入» / a source switch) overwrites and bumps [revision] so an open editor
/// re-seeds.
///
/// session 级运行草稿库(JSON-first):把编辑的 JSON 文本养到整个 app 会话(刻意不落盘)。分桶隔离维度:
/// handler 按方法、workflow 按来源,切回即原样。打字 [setText] 静默写入(逐键不重建生命周期);一次「填充」
/// ([fill]:示例/用这份输入/切来源)覆盖并自增 [revision],让开着的编辑器重播种。
class RunDraftStore extends ChangeNotifier {
  final Map<String, String> _text = {};

  /// Bumped by [fill] — the editor keys its instance on this so a fill forces a fresh re-seed
  /// (a seamless editor otherwise keeps its own focused text). 填充自增,编辑器据此强制重播种。
  int revision = 0;

  /// The stored JSON text for a bucket, or null if never seeded/edited. 桶内 JSON 文本(未种/未编辑→null)。
  String? textFor(String key) => _text[key];

  /// Seed a bucket ONCE if empty (the generated example/template) — idempotent, no notify (the seed
  /// isn't a user action). 首次种入(生成的示例/模板),幂等、不通知。
  void seed(String key, String text) => _text.putIfAbsent(key, () => text);

  /// A quiet per-keystroke write — no notify (an uncontrolled editor owns its own text; the lifecycle
  /// must not rebuild on typing). 逐键静默写入,不通知。
  void setText(String key, String text) => _text[key] = text;

  /// Overwrite a bucket from a FILL action («示例» / «用这份输入» / a source switch), bump [revision]
  /// and notify so an open editor re-seeds immediately. 一次填充:覆盖桶、自增 revision、通知重播种。
  void fill(String key, String text) {
    _text[key] = text;
    revision++;
    notifyListeners();
  }
}

/// One store per app session (keepAlive by default — this is the point). 会话单例。
final runDraftStoreProvider = Provider<RunDraftStore>((ref) {
  final store = RunDraftStore();
  ref.onDispose(store.dispose);
  return store;
});

/// The bucket coordinate for an entity's CURRENT dimension. [dimension] is '' for fn/ag, the method for
/// hd, the source (triggerId or 'manual') for wf. 桶坐标。
String runDraftKey(EntityRef ref, [String dimension = '']) =>
    dimension.isEmpty ? '$ref' : '$ref/$dimension';
