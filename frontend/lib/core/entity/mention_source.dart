import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One candidate the composer's @ picker can offer. [type] is the WIRE kind string (function / handler /
/// agent / workflow — the mention vocabulary the send contract takes), never a feature enum: this seam
/// lives in core so chat (the consumer) and entities (the supplier) stay decoupled.
///
/// composer @ picker 的候选。[type] 是**线缆 kind 字符串**(function/handler/agent/workflow——发送契约的
/// mention 词表),不是 feature 枚举:缝在 core,chat(消费)与 entities(供给)互不依赖。
class MentionCandidate {
  const MentionCandidate({
    required this.type,
    required this.id,
    required this.name,
    this.description = '',
  });

  final String type;
  final String id;
  final String name;
  final String description;
}

/// The @ picker's data seam. [search] with an empty query returns the browse list (everything, capped);
/// a non-empty query filters by name server-side. Implementations live in the APP layer (it may import
/// both chat and entities) and are injected via [mentionSourceProvider].
///
/// @ picker 数据缝。空 query = 浏览列表(全部、封顶);非空 = 服务端按名过滤。实现放 app 层(可同时 import
/// chat 与 entities),经 [mentionSourceProvider] 注入。
abstract class MentionSource {
  Future<List<MentionCandidate>> search(String query);
}

/// DIP seam — the app layer overrides this (mirrors the repository-seam pattern). app 层 override(镜像仓储缝)。
final mentionSourceProvider = Provider<MentionSource>(
  (_) => throw UnimplementedError('mentionSourceProvider must be overridden by the app assembly'),
);
