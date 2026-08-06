/// The MediaRef grammar's front-end half (WRK-082 批B' 不变量①) — the exact twin of the backend's
/// `pkg/mediaref`. A MediaRef is any JSON object carrying an `attachmentId` whose value is an
/// `att_<16hex>` id: the ONE currency media uses to travel through tool results, flowrun node rows,
/// agent payloads and approval payloads. Anything that renders such a payload asks this file what is
/// in it, and hands the answer to [AnMediaCard] — one grammar, one card family, zero per-surface
/// guessing.
///
/// MediaRef 文法的前端半(批B' 不变量①)——后端 `pkg/mediaref` 的孪生件。MediaRef = 任何携
/// `attachmentId`(值为 `att_<16hex>`)的 JSON 对象:媒体流经 tool result / flowrun 节点行 /
/// agent payload / approval payload 的唯一货币。凡渲这类 payload 的面都问本文件「里面有什么」,
/// 再把答案交给 [AnMediaCard]——一份文法、一族卡、零逐面猜测。
library;

import 'dart:convert';

/// The grammar's one field name. A closed vocabulary — never a second spelling.
///
/// 文法唯一字段名。封闭词表——绝无第二种拼法。
const String kMediaRefKey = 'attachmentId';

/// How many refs one payload may expand into cards. Mirrors the backend's `mediaref.MaxRefs`: a
/// degenerate payload must not turn one node result into a hundred image decodes.
///
/// 一个 payload 最多展开几张卡。镜像后端 `mediaref.MaxRefs`:退化 payload 不得把一条节点结果
/// 变成一百次图像解码。
const int kMediaRefMax = 8;

final RegExp _idShape = RegExp(r'^att_[0-9a-f]{16}$');

/// Whether [s] is a well-formed attachment id.
///
/// [s] 是否合法附件 id 形。
bool isAttachmentId(String s) => _idShape.hasMatch(s);

/// One media reference found in a payload, plus whatever the producing receipt volunteered.
/// Everything except [attachmentId] is a HINT: the attachment row is the truth, and the card
/// resolves it. The hints exist so a card can hold its layout (aspect) and say something honest
/// (filename/mime) BEFORE the row lands — never to replace it.
///
/// payload 里找到的一条媒体引用,外加产出 receipt 自愿附上的信息。除 [attachmentId] 外全是**提示**:
/// 附件行才是真相、卡自己去解析。提示的用处是让卡在行落地**之前**就能占住版面(比例)、能诚实说话
/// (文件名/mime)——绝不是替代它。
class AnMediaRef {
  const AnMediaRef({
    required this.attachmentId,
    this.mime,
    this.filename,
    this.aspect,
    this.width,
    this.height,
    this.sizeBytes,
    this.source,
  });

  final String attachmentId;
  final String? mime;
  final String? filename;

  /// Producer-supplied frame shape hint, used only before the attachment row arrives.
  /// 产出方提供的画幅提示,只在附件行到达前占位使用。
  final String? aspect;
  final int? width;
  final int? height;
  final int? sizeBytes;

  /// Which producer minted the receipt (`generate_image` / `mcp_media` / …) — provenance for the
  /// card's meta line, never a rendering switch (mime decides that).
  ///
  /// 哪个产地铸的 receipt(`generate_image` / `mcp_media` / …)——卡 meta 行的溯源,绝不作渲染开关
  /// (那是 mime 的事)。
  final String? source;

  @override
  bool operator ==(Object other) =>
      other is AnMediaRef && other.attachmentId == attachmentId;

  @override
  int get hashCode => attachmentId.hashCode;
}

/// Walks a decoded JSON value and returns every well-formed MediaRef, first-seen order, deduped by
/// id, capped at [kMediaRefMax].
///
/// A STRING scalar containing the grammar key gets one decode attempt and its value walked too —
/// receipts routinely travel as text (an agent's answer becomes a node's `text`, a tool result is a
/// JSON string). This mirrors the backend collector exactly; the two must agree or a payload the
/// model can see would render as nothing, or the reverse.
///
/// 走一个已解码 JSON 值,返回全部合法 MediaRef(首见序、按 id 去重、[kMediaRefMax] 封顶)。含文法键的
/// **字符串**标量得一次解码并继续走其值——receipt 常以文本流动(agent 终答成节点 `text`、tool result
/// 本身就是 JSON 串)。这与后端收集器逐字对齐:两边不一致,就会出现「模型看得见而界面渲不出」或反过来。
List<AnMediaRef> collectMediaRefs(Object? json) {
  final out = <AnMediaRef>[];
  final seen = <String>{};

  void walk(Object? v) {
    if (out.length >= kMediaRefMax) return;
    if (v is Map) {
      final id = v[kMediaRefKey];
      if (id is String && isAttachmentId(id) && seen.add(id)) {
        out.add(
          AnMediaRef(
            attachmentId: id,
            mime: _str(v['mime']) ?? _str(v['mimeType']),
            filename: _str(v['filename']),
            aspect: _str(v['aspect']),
            width: _int(v['width']),
            height: _int(v['height']),
            sizeBytes: _int(v['sizeBytes']),
            source: _str(v['source']),
          ),
        );
      }
      for (final val in v.values) {
        walk(val);
      }
    } else if (v is List) {
      for (final val in v) {
        walk(val);
      }
    } else if (v is String && v.contains(kMediaRefKey)) {
      // Gate on the bare key, not `"key"` — a receipt nested one level deep arrives with its quotes
      // escaped, and a quote-anchored gate would miss exactly that case (same reasoning as the Go
      // side). A decode failure is normal: prose that merely mentions the word collects nothing.
      // 闸只看裸键、不看 `"键"`——嵌一层的 receipt 引号是转义的(与 Go 侧同理)。解码失败是常态:
      // 只是提到这个词的散文收集不到东西。
      final decoded = _tryDecode(v);
      if (decoded != null) walk(decoded);
    }
  }

  walk(json);
  return out;
}

Object? _tryDecode(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

int? _int(Object? v) => switch (v) {
  final int i => i,
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};
