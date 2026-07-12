import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/router/panel_registry.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import 'tool_card_nav.dart';

// F09 run-log ledger primitives (B5.6) — the archive family's shared body furniture. A RunBeadStrip is a
// health-at-a-glance dot row (this page's runs, new→old); a RunLedger is the record list (one row per
// execution: status dot · mono id · chips · elapsed · absolute stamp), bounded with an expand-all
// escape, rows tappable iff they deep-link. Slim projection ONLY — input/output/logs/transcript NEVER
// render here (a search page carries them all in memory; rendering them would be a size disaster).
// F09 台账原语:珠串一眼看健康 + RunLedger 记录列(slim 投影,绝不渲 input/output/logs)。

/// One bead — a run's status as a semantic status dot with a hover tooltip (id · status · time). The
/// raw→state fold is [AnStatus.fromRaw] (批7 B-037/038 — this file's parallel colour map retired). 一颗珠。
class RunBead {
  const RunBead({required this.status, required this.tooltip});
  final AnStatus status;
  final String tooltip;
}

/// A horizontal bead strip (new→old), health-at-a-glance. A [pageScoped] strip prefixes «本页» — the
/// flowruns/firings/activations searches have no global aggregate, so their strip speaks only for the
/// page. 珠串(新→旧);pageScoped 前置「本页」(无全局聚合的族)。
class RunBeadStrip extends StatelessWidget {
  const RunBeadStrip({required this.beads, this.pageScoped = false, super.key});
  final List<RunBead> beads;
  final bool pageScoped;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (beads.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (pageScoped) ...[
        Text(Translations.of(context).chat.tool.beadPageScope, style: AnText.meta.copyWith(color: c.inkFaint)),
        const SizedBox(width: AnSpace.s6),
      ],
      Flexible(
        child: Wrap(spacing: AnSpace.s4, runSpacing: AnSpace.s4, children: [
          for (final b in beads)
            Tooltip(
              message: b.tooltip,
              waitDuration: AnMotion.dwell,
              child: AnStatusDot(b.status),
            ),
        ]),
      ),
    ]);
  }
}

/// A ledger row's leading mark — a status dot (raw status → color), or a «fired?» mark (activations).
/// 行首标记:状态点 或 fire 标记(活化)。
class RunLeading {
  const RunLeading.status(this.status) : fired = null;
  const RunLeading.fired(bool this.fired) : status = '';
  final String status;
  final bool? fired;
}

/// One ledger row — a slim execution projection. [monoId] OR [text] fills the primary slot; [chips] are
/// small inline badges (method / tool / disposition); [elapsed]/[stamp] trail; [expandContent] (non-null)
/// makes the row an inline disclosure (search_activations' returnValue tree); [tapKind]/[tapId] make it
/// navigable iff a panel exists. 一条台账行:slim 投影。
class RunLedgerRow {
  const RunLedgerRow({
    required this.leading,
    this.monoId,
    this.text,
    this.chips = const [],
    this.elapsed,
    this.stamp,
    this.subText,
    this.expandContent,
    this.tapKind,
    this.tapId,
  });
  final RunLeading leading;
  final String? monoId;
  final String? text;
  final List<Widget> chips;
  final String? elapsed;
  final String? stamp;
  final String? subText;
  final Widget? expandContent;
  final String? tapKind;
  final String? tapId;
}

/// The RunLedger — a bounded record list inside its machine window (the caller wraps it). The cap
/// escape is the family list shell's (批6 A-071 — the hand-rolled «show all» retires); a row
/// deep-links iff its kind has a panel. RunLedger 记录列(逃生口=族列表壳)。
class RunLedger extends StatelessWidget {
  const RunLedger({required this.rows, this.cap = 14, super.key});
  final List<RunLedgerRow> rows;
  final int cap;

  @override
  Widget build(BuildContext context) =>
      AnLedgerList(cap: cap, children: [for (final r in rows) _RunRow(row: r)]);
}

class _RunRow extends StatefulWidget {
  const _RunRow({required this.row});
  final RunLedgerRow row;
  @override
  State<_RunRow> createState() => _RunRowState();
}

class _RunRowState extends State<_RunRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = widget.row;
    final navigable = row.tapKind != null && row.tapId != null && hasPanelFor(row.tapKind!);
    final expandable = row.expandContent != null;

    Widget lead;
    if (row.leading.fired != null) {
      // fired → a green check; not-fired (a sensor probe that didn't fire) → a hollow grey dot. fire 标记。
      lead = row.leading.fired!
          ? Icon(AnIcons.check, size: AnSize.iconSm, color: c.ok)
          : const AnStatusDot.raw(null, hollow: true);
    } else {
      lead = AnStatusDot(AnStatus.fromRaw(row.leading.status));
    }

    // The family ledger row (批6 A-070/072 — the hand-rolled line and its indent arithmetic retire).
    // 族台账行(手拼行与缩进算术退役)。
    return AnLedgerRow(
      lead: lead,
      primary: row.monoId ?? row.text ?? '',
      mono: row.monoId != null,
      chips: row.chips,
      sub: row.subText,
      measure: row.elapsed,
      meta: row.stamp,
      onTap: expandable
          ? () => setState(() => _open = !_open)
          : (navigable ? () => toolNavTo(context, row.tapKind!, row.tapId!) : null),
      expandChild: row.expandContent,
      expanded: _open,
    );
  }
}
