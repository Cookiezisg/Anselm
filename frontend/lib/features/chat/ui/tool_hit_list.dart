import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/router/panel_registry.dart';
import '../../../core/model/status_state.dart';
import '../../../core/ui/an_chip.dart';
import '../../../core/ui/an_hover_surface.dart';
import '../../../core/ui/an_interactive.dart';
import '../../../core/ui/an_json_tree.dart';
import '../../../core/ui/an_window.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import 'tool_card_reveal.dart';

/// One row of a [ToolHitList] — an entity/hit line. 一行命中。
class ToolHitRow {
  const ToolHitRow({
    required this.glyph,
    required this.title,
    this.subtitle,
    this.trailing,
    this.kind,
    this.id,
    this.onOpen,
  });

  /// The leading glyph (usually [AnIcons.entityKindGlyph] of [kind]). 前导字形。
  final IconData glyph;

  /// The primary text (a name) — content value tier (15 w400). 主文(名字),内容值档。
  final String title;

  /// The optional second line (a snippet / description) — 13 muted, one line, ellipsis. 次行。
  final String? subtitle;

  /// The optional tail meta slot (a mono id / a badge / a ref). 尾 meta 槽。
  final Widget? trailing;

  /// The backend wire kind — decides tappability via the panel registry (a kind with no panel makes
  /// the row inert, NEVER a dead link). null → inert. 线缆 kind:据面板注册表决定可点否;无面板→惰性。
  final String? kind;

  /// An EXTERNAL open action (a web hit's URL) — the second tap channel beside the panel deep link
  /// (批6 A-078: web hits used to bypass the shared gate for lack of this). Takes precedence over
  /// kind/id navigation. 外链动作(网页命中)——面板深链旁的第二通道(当年 _WebHits 绕门的真因);
  /// 优先于 kind/id 导航。
  final VoidCallback? onOpen;

  /// The entity id — the navigation intent target AND the «当前» badge match. null → inert.
  final String? id;
}

/// A HIT / ENUMERATION LIST inside a machine window (WRK-056 #10) — the ONE shared body for search
/// hits, directory listings, web results (F02 / F07 / F10 / F17). Each row is `glyph + title(15) +
/// subtitle(13) + tail-meta`; rows CASCADE-fade-in exactly once when [animate] (the settle-only
/// family's «grows its directory» motion — a family with no live body still gets a reveal), else they
/// appear instantly (history reload / reduced motion / a re-mount after the one play).
///
/// Capped at [cap] with TWO DISTINCT footer states that must never be conflated:
///   • LOCAL over-cap ([rows] longer than [cap] — a fallback full-list): an escape-hatch footer
///     «前 N · 共 M» that, tapped, swaps the list for the full result in a bounded [AnJsonTree]
///     ([rawJson]); nothing is lost.
///   • SERVER truncated ([serverTruncated] — the engine page cut at its limit, rows ≤ cap): a
///     display-only note «前 N · 共 M(服务端截断)» — NOT tappable, because rows N+1.. are not in the
///     result at all (only a nextCursor the card can't page). Honest note, never a fake door.
///
/// A row is tappable iff its [ToolHitRow.kind] has a navigable panel ([hasPanelFor]) AND [onRowTap] is
/// wired — else inert (the «never a dead link» rule lives here, in one place). The row whose id equals
/// [currentId] wears a «当前» marker.
///
/// 机器窗内命中/枚举行列:glyph+主文15+次行13+尾 meta;[animate] 时级联淡入一次(settle-only 族的
/// 「目录生长」),否则即显。封顶 [cap];两种截断态不可混同(本地超封顶=逃生口换全量 JSON / 服务端截断=
/// 只读注记);行可点当且仅当 kind 有面板(无面板惰性、绝不死链);currentId 行戴「当前」记。
class ToolHitList extends StatefulWidget {
  const ToolHitList({
    required this.rows,
    required this.cap,
    this.total,
    this.serverTruncated = false,
    this.rawJson,
    this.onRowTap,
    this.currentId,
    this.animate = false,
    super.key,
  });

  final List<ToolHitRow> rows;
  final int cap;

  /// The server-reported grand total (engine path). Drives the footer's «共 M». 服务端总数。
  final int? total;

  /// The engine page was cut at its limit (rows ≤ cap, more exist only behind a cursor). 服务端截断。
  final bool serverTruncated;

  /// The raw result JSON for the local-over-cap escape hatch (a bounded tree). 逃生口全量 JSON。
  final String? rawJson;

  /// Navigate to a hit (host calls `context.go(panelLocationFor(kind, id))`). 行导航。
  final void Function(String kind, String id)? onRowTap;

  /// The id of the entity currently open in a panel → that row gets a «当前» marker. 当前打开的实体。
  final String? currentId;

  /// Play the one-time cascade reveal (host sets this only when it WITNESSED the running→settled
  /// transition this session — never on history reload). 是否播一次级联(仅亲历落定时)。
  final bool animate;

  @override
  State<ToolHitList> createState() => _ToolHitListState();
}

class _ToolHitListState extends State<ToolHitList> with SingleTickerProviderStateMixin {
  static const Duration _stagger = AnMotion.stagger;
  static const Duration _fade = AnMotion.mid;

  late final AnimationController _c;
  bool _started = false;
  bool _showAll = false;

  int get _visibleCount => widget.rows.length < widget.cap ? widget.rows.length : widget.cap;

  @override
  void initState() {
    super.initState();
    // Total run = the last row's start (n·stagger) + its fade. 总时长=末行起点+淡入。
    final n = _visibleCount;
    final ms = (n * _stagger.inMilliseconds + _fade.inMilliseconds)
        .clamp(_fade.inMilliseconds, AnMotion.revealCap.inMilliseconds);
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: ms));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // The one-time cascade plays iff EITHER animate is set explicitly (gallery) OR the chassis
    // witnessed the settle this session ([ToolCardReveal]). Else instant. 亲历落定或显式 animate 才播。
    final reveal = widget.animate || (ToolCardReveal.of(context)?.revealOnMount ?? false);
    if (!reveal || AnMotionPref.reducedOrAssistive(context)) {
      _c.value = 1.0;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showAll && widget.rawJson != null) {
      // AnJsonTree is a virtualized TreeSliver — its OWN viewport: bounded height, no outer scroll.
      // AnJsonTree 自带虚拟化 viewport:只需有界高、不外套滚动。
      return AnWindow(
        child: SizedBox(
          height: AnSize.jsonViewport,
          child: AnJsonTree(jsonString: widget.rawJson, showRoot: false),
        ),
      );
    }
    final visible = widget.rows.take(widget.cap).toList();
    final overCap = widget.rows.length > widget.cap;
    return AnWindow(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, row) in visible.indexed) _cascade(i, _row(context, row)),
            if (overCap)
              _localOverCapFooter(context)
            else if (widget.serverTruncated)
              _serverTruncatedNote(context),
          ],
        ),
      ),
    );
  }

  // Per-row staggered fade+rise: row i animates over [i·stagger, i·stagger + fade]. 逐行错峰淡升。
  Widget _cascade(int index, Widget child) {
    final total = _c.duration!.inMilliseconds;
    final start = (index * _stagger.inMilliseconds) / total;
    final end = (index * _stagger.inMilliseconds + _fade.inMilliseconds) / total;
    final t = CurvedAnimation(parent: _c, curve: Interval(start.clamp(0, 1), end.clamp(0, 1), curve: AnMotion.easeOut)).value;
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * AnSpace.s4), child: child),
    );
  }

  Widget _row(BuildContext context, ToolHitRow row) {
    final c = context.colors;
    final tappable = row.onOpen != null ||
        (row.kind != null && row.id != null && hasPanelFor(row.kind!) && widget.onRowTap != null);
    final isCurrent = row.id != null && row.id == widget.currentId;

    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(row.glyph, size: AnSize.iconSm, color: c.inkFaint),
          const SizedBox(width: AnSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(row.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // Tool-card content rides the 13 UI anchor (NOT the 15 content-value tier) — every
                          // string inside a tool card is dense chrome, distinguished from the 13 subtitle by
                          // weight+colour, not size. tool 卡内容一律 13 锚(非 15 值档),靠字重+色分层。
                          style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: AnSpace.s6),
                      // Family chip (批5 A-026 — the hand-rolled accent pill retires). 族芯片。
                      AnChip(Translations.of(context).chat.tool.hitCurrent, tone: AnTone.accent),
                    ],
                  ],
                ),
                if (row.subtitle != null && row.subtitle!.trim().isNotEmpty)
                  Text(row.subtitle!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.body.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          if (row.trailing != null) ...[
            const SizedBox(width: AnSpace.s8),
            // The trailing cell is rigid BY CONTRACT — callers pass short credentials (host, id,
            // ×N · time); anything unbounded must be truncated at the source (AnTrunc — the web
            // raw-URL fallback did exactly this after 批6 复审). A slot-level width cap broke the
            // legitimate wide trailings (conversation badge+time rows), and a loose Flexible would
            // steal the title's flex share even when short. 尾格契约刚性:调用方喂短凭据,无界内容
            // 在源头 AnTrunc 截断;槽级硬顶界砸中合法宽尾,Flexible 又抢标题份额。
            DefaultTextStyle.merge(
                style: AnText.label.copyWith(color: c.inkFaint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: row.trailing!),
          ],
          if (tappable) ...[
            const SizedBox(width: AnSpace.s4),
            Icon(AnIcons.chevronRight, size: AnSize.iconSm, color: c.inkFaint),
          ],
        ],
      ),
    );

    if (!tappable) return body;
    return AnInteractive(
      onTap: row.onOpen ?? () => widget.onRowTap!(row.kind!, row.id!),
      builder: (ctx, states) => AnHoverSurface(active: states.isActive, child: body),
    );
  }


  // LOCAL over-cap: an escape hatch to the full bounded JSON (nothing is lost). 本地超封顶逃生口。
  Widget _localOverCapFooter(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final shown = widget.cap;
    final grand = widget.total ?? widget.rows.length;
    return AnInteractive(
      onTap: widget.rawJson == null ? null : () => setState(() => _showAll = true),
      builder: (ctx, states) => Padding(
        padding: const EdgeInsets.only(top: AnSpace.s6),
        child: Text(t.chat.tool.cappedFooter(n: '$shown', total: '$grand'),
            style: AnText.meta.copyWith(color: states.isActive ? c.accent : c.inkFaint)),
      ),
    );
  }

  // SERVER truncated: a display-only note — the rest isn't in the result. 服务端截断:只读注记。
  Widget _serverTruncatedNote(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s6),
      child: Text(t.chat.tool.serverTruncatedNote(n: '${widget.rows.length}', total: '${widget.total ?? widget.rows.length}'),
          style: AnText.meta.copyWith(color: c.inkFaint)),
    );
  }
}
