/// Mention position derivation for the sent user bubble — PURE Dart (no Flutter import; unit-tested like
/// BlockTreeReducer). The backend freezes mention SNAPSHOTS ({type,id,name}, order preserved) but stores NO
/// character offsets, so the bubble derives pill positions itself: consume the text left→right, matching
/// each snapshot's literal `@name` with `indexOf` from the previous match's end (never a regex — names may
/// contain `.` `*` `(` freely). A hit becomes a pill segment; a miss (renamed source text edited, or an
/// unavailable snapshot) leaves the literal text untouched — honest degradation, nothing pretends to be
/// tappable. Consumption makes overlaps/out-of-range impossible by construction and maps same-name
/// mentions one-to-one in order.
///
/// 提及定位推导(用户泡)——纯 Dart(零 Flutter import,同 BlockTreeReducer 待遇单测)。后端只冻结快照
/// ({type,id,name},保序)、**不存字符偏移**,泡自己推位:从上次匹配终点起左→右消耗式 `indexOf` 字面
/// `@name`(非正则——名字可含 `.` `*` `(`)。命中→pill 段;未命中(原文被改/快照 unavailable)→字面原样保留,
/// 诚实降级、不假装可点。消耗式令重叠/越界按构造不可能,同名提及按序一一对应。
library;

/// A frozen mention snapshot off `attrs.mentions` (or the composer's local state pre-echo). The name is the
/// SEND-TIME name — the bubble always shows it (the sentence was said about *that* thing); tapping navigates
/// to the live entity by [id]. [available] = the send-time resolution succeeded (an unavailable snapshot
/// never matches, so it degrades to literal text for free).
///
/// 冻结提及快照(attrs.mentions / composer 本地)。name=发送时刻名——泡永远显它(话是对「当时那个」说的);
/// 点按凭 id 跳活体。available=发送时解析成功(不可用快照永不匹配→免费降级为字面)。
class MentionSnapshot {
  const MentionSnapshot({
    required this.type,
    required this.id,
    required this.name,
    this.available = true,
  });

  final String type; // backend EntityKind wire value 后端 kind 线缆值
  final String id;
  final String name;
  final bool available;
}

/// One run of the bubble text: either plain text or an inline mention pill. 泡文本的一段:纯文字或提及药丸。
sealed class MentionSegment {
  const MentionSegment();
}

class MentionTextSegment extends MentionSegment {
  const MentionTextSegment(this.text);

  final String text;
}

class MentionPillSegment extends MentionSegment {
  const MentionPillSegment(this.snapshot);

  final MentionSnapshot snapshot;
}

/// Split [text] into text/pill segments by consuming-matching each snapshot's `@name` left→right.
/// Empty text → empty list (the caller skips the text region entirely).
/// 按快照序消耗式匹配 `@name`,把 text 切成 文字/药丸 段;空文本→空列表(调用方跳过文本区)。
List<MentionSegment> resolveMentionSegments(
  String text,
  List<MentionSnapshot> snapshots,
) {
  if (text.isEmpty) return const [];
  final segments = <MentionSegment>[];
  var cursor = 0;
  for (final s in snapshots) {
    if (!s.available || s.name.isEmpty) continue;
    final index = text.indexOf('@${s.name}', cursor);
    if (index < 0) {
      continue; // no literal match → the raw @name text stays as-is 未命中→字面保留
    }
    if (index > cursor) {
      segments.add(MentionTextSegment(text.substring(cursor, index)));
    }
    segments.add(MentionPillSegment(s));
    cursor = index + s.name.length + 1; // +1 for the '@' 消耗 @+名字
  }
  if (cursor < text.length) {
    segments.add(MentionTextSegment(text.substring(cursor)));
  }
  return segments;
}
