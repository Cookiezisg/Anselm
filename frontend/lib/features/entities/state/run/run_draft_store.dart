import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../selected_entity.dart';

/// Session-lived run-input drafts (调试台参数记忆, 用户 0719 拍板 session 级): the terminal
/// controller is an autoDispose family, so its in-memory draft dies on deselect — this store keeps
/// the typed values alive for the whole app session instead, WITHOUT persisting to disk (a debug
/// scratchpad is not configuration). Buckets keep kind-specific dimensions apart: a handler
/// remembers per METHOD, a workflow per SOURCE — switching back restores exactly what you typed
/// there. [revision] bumps on a reproduce so the form's uncontrolled inputs re-seed.
///
/// session 级运行草稿库:终端 controller 是 autoDispose family,切走即弃内存草稿——本库把输入值养
/// 到整个 app 会话(刻意不落盘:调试草稿不是配置)。分桶隔离维度:handler 按方法、workflow 按来源,
/// 切回即原样。[revision] 在重现时自增,让非受控输入框重播种。
class RunDraftStore extends ChangeNotifier {
  final Map<String, Map<String, Object?>> _buckets = {};

  /// Bumped by [reproduce] — the form keys its inputs on this so a fill-back forces a re-seed
  /// (uncontrolled inputs otherwise keep their own text). 重现自增,表单据此强制重播。
  int revision = 0;

  /// The draft bucket for one (entity, dimension) coordinate. fn/ag = ref alone; hd = ref+method;
  /// wf = ref+source. 一个 (实体,维度) 坐标的草稿桶。
  Map<String, Object?> bucket(String key) => _buckets.putIfAbsent(key, () => {});

  /// Fill a bucket from a past execution's input (重现钥匙): values land in the exact shape the
  /// form seeds from — scalars as text, bools as bools, structures as pretty JSON. Bumps
  /// [revision] and notifies so an open form re-seeds immediately.
  /// 用某次执行的输入回填桶:标量成文本、布尔成布尔、结构成 JSON 文本;自增 revision 并通知,
  /// 开着的表单立即重播。
  void reproduce(String key, Map<String, Object?> values) {
    _buckets[key] = Map.of(values);
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

/// The bucket coordinate for an entity's CURRENT dimension. [dimension] is '' for fn/ag, the
/// method for hd, the source (triggerId or 'manual') for wf. 桶坐标。
String runDraftKey(EntityRef ref, [String dimension = '']) =>
    dimension.isEmpty ? '$ref' : '$ref/$dimension';
