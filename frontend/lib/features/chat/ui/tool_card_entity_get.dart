import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_code_editor.dart';
import '../../../core/ui/an_disclosure.dart';
import '../../../core/ui/an_fade_collapse.dart';
import '../../../core/ui/an_field_section.dart';
import '../../../core/ui/an_json_tree.dart';
import '../../../core/ui/an_window.dart';
import '../../../core/ui/an_ref_pill.dart';
import '../../../i18n/strings.g.dart';
import '../../../core/run/run_nav.dart';

/// The content window's hard char cap — beyond it the window shows the head + a truncation note that
/// points to the entity panel for the full text (AnCodeEditor has no virtualization). 内容窗字符硬顶。
const int kEntityContentCap = 6000;

/// The F06 entity-get FOUR-PART SKELETON (WRK-056 #31) — every get card is «what the model saw», an
/// honest little exhibit: ① an identity row, ② dense key/value vitals, ③ big content folded into a
/// machine window, ④ the raw ledger, disclosed. Each get tool writes only its projection (the KV rows,
/// the content sections); this composes them. get 族四段骨架:身份行 / KV 命脉 / 大内容折叠 / 原始底账。
class EntityGetBody extends StatelessWidget {
  const EntityGetBody({
    required this.header,
    required this.rawJson,
    this.badges,
    this.kv,
    this.content = const [],
    super.key,
  });

  /// ① The identity row (pill + id + version/updated meta). 身份行。
  final ToolEntityHeader header;

  /// An optional status-badge row directly under the header (env / lifecycle / config×runtime). 状态徽章行。
  final Widget? badges;

  /// ② The key/value vitals (row-level mono for ids/CEL/signatures). null → no KV block. 关键字段。
  final Widget? kv;

  /// ③ Big-content windows (code / prompt / template) — already fold-wrapped by the caller. 大内容窗。
  final List<Widget> content;

  /// ④ The raw result JSON — «the full ledger the model saw», NEVER filtered. 原始底账,永不过滤。
  final String rawJson;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        if (badges != null)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s6),
            child: badges!,
          ),
        if (kv != null)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s8),
            child: kv!,
          ),
        for (final w in content)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s8),
            child: w,
          ),
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s8),
          child: RawResultDisclosure(rawJson: rawJson),
        ),
      ],
    );
  }
}

/// ① The identity row: an [AnRefPill] (kind + name, tappable to the entity panel via the registry —
/// inert if the kind has none) + a mono id + a right-edge meta (`vN · updated`). 身份行:可点 pill+id+meta。
class ToolEntityHeader extends StatelessWidget {
  const ToolEntityHeader({
    required this.kind,
    required this.name,
    required this.id,
    this.meta,
    super.key,
  });

  final String kind;
  final String name;
  final String id;

  /// Right-edge metadata (e.g. `v3 · 2026-07-01 09:00`). Rendered on the chrome 12 tier. 右缘元数据。
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: toolNavPill(context, kind: kind, label: name, id: id),
        ),
        const SizedBox(width: AnSpace.s6),
        Flexible(
          child: Text(
            id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AnText.mono.copyWith(color: c.inkFaint),
          ),
        ),
        if (meta != null) ...[
          const Spacer(),
          Text(
            meta!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AnText.meta.copyWith(color: c.inkFaint),
          ),
        ],
      ],
    );
  }
}

/// ③ A code content window: the entity's stored source (code / prompt), verbatim, in the reading-tier
/// code editor — AnCodeEditor IS the frame (its own AnCodeSurface + copy bar; never a second ToolWindow
/// shell, WRK-066 族二叶子律), folded past [AnFadeCollapse]'s height. Over [kEntityContentCap] chars
/// the DISPLAY shows the head + an honest truncation note (the full text lives in the entity panel —
/// AnCodeEditor has no virtualization) while COPY carries the FULL stored field (machine-window rule).
/// 代码内容窗:真实存储字段原文住编辑器壳(自带框,绝不再套 ToolWindow);显示超顶截头+诚实注记,copy 保全量。
class EntityCodeWindow extends StatelessWidget {
  const EntityCodeWindow({
    required this.code,
    this.lang,
    this.label,
    super.key,
  });

  final String code;
  final String? lang;

  /// An optional grey section label above the window (imports / __init__ / shutdown) — the ONE
  /// 13-tier label primitive ([AnFieldSection]). 窗上灰小节标签(唯一 13 档标签原语)。
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final over = code.length > kEntityContentCap;
    final shown = over ? code.substring(0, kEntityContentCap) : code;
    final lineCount = '\n'.allMatches(code).length + 1;
    final window = AnFadeCollapse(
      collapsible: lineCount > 50,
      expandLabel: t.chat.tool.proseExpand,
      collapseLabel: t.chat.tool.proseCollapse,
      // The fade blends to the editor's own WHITE surface (the grey sunken shell is retired). 渐隐融白面。
      fadeColor: c.surface,
      child: AnCodeEditor(
        code: shown,
        copyPayload: code,
        lang: lang,
        reading: true,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          AnFieldSection(label: label!, child: window)
        else
          window,
        if (over)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Text(
              t.chat.tool.contentTruncated,
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
          ),
      ],
    );
  }
}

/// ④ The RAW RESULT disclosure — a collapsed «原始返回» section revealing the UNFILTERED result JSON in
/// a bounded [AnJsonTree] (the full ledger the model saw + an escape hatch). The body may abridge or
/// mask its projection, but the raw is never field-filtered (WRK-056 §F07.5④). 原始返回披露:未过滤全量。
class RawResultDisclosure extends StatefulWidget {
  const RawResultDisclosure({required this.rawJson, super.key});

  final String rawJson;

  @override
  State<RawResultDisclosure> createState() => _RawResultDisclosureState();
}

class _RawResultDisclosureState extends State<RawResultDisclosure> {
  bool _open = false;

  // Auto-detect: a JSON object/array → the tree; anything else (a read_document / read_attachment
  // string template) → capped mono text. 自动辨:JSON→树;否则(read 串模板)→ capped mono。
  bool get _isJson {
    final s = widget.rawJson.trimLeft();
    if (s.isEmpty) return false;
    final c = s.codeUnitAt(0);
    return c == 0x7B || c == 0x5B; // { or [
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return AnDisclosure(
      label: t.chat.tool.rawResult,
      open: _open,
      onToggle: () => setState(() => _open = !_open),
      child: !_open
          ? null
          : _isJson
          ? SizedBox(
              height: AnSize.jsonViewport,
              child: AnJsonTree(jsonString: widget.rawJson, showRoot: false),
            )
          : AnWindow(
              child: Text(
                widget.rawJson,
                maxLines: 200,
                overflow: TextOverflow.ellipsis,
                style: AnText.code.copyWith(color: context.colors.inkMuted),
              ),
            ),
    );
  }
}
