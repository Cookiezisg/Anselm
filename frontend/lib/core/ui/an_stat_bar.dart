import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_badge.dart';

/// One stat in the ' · ' metadata chain. [tabular] = numeric (tabular figures); [tone] colours the
/// text (env 三色 etc.). ' · ' 链中的一节;tabular=数字;tone 上色(env 三色等)。
class AnStat {
  const AnStat(this.text, {this.tabular = false, this.tone = AnTone.none});

  final String text;
  final bool tabular;
  final AnTone tone;
}

/// The BAR family head (WRK-066「同轨」族五) — the ONE settled result/status bar, converging the four
/// hand-rolled bars (RunStatBar / ExecResultBar / _InvokeStatBar / _RunFooter) and every hand-joined
/// ' · ' InlineSpan chain. Slots: a [status] word badge (colour = AnStatus.tone, the ONE status→colour
/// source), the [stats] chain, trailing [chips] (chip family: ref pills / copies), and a [note] line
/// below (envError red / restartNote amber).
///
/// 条族当家件(「同轨」族五)——唯一落定结果/状态条,收敛四条手搓条与一切手拼 ' · ' 链。槽:status 状态词徽
/// (色=AnStatus.tone,状态→色唯一源)、stats 链、尾随 chips(芯片族凭据)、下挂 note 行(envError 红/
/// restartNote 琥珀)。
class AnStatBar extends StatelessWidget {
  const AnStatBar({
    this.status,
    this.statusLabel,
    this.stats = const [],
    this.chips = const [],
    this.note,
    this.noteTone = AnTone.danger,
    super.key,
  });

  /// Universal status → word (i18n `status.*`) + tone badge. 通用态→词+声调徽。
  final AnStatus? status;

  /// Domain word override (e.g. «超时» where the fold would say 失败) — tone still from [status].
  /// 域词覆盖(如「超时」),声调仍取 status。
  final String? statusLabel;

  final List<AnStat> stats;
  final List<Widget> chips;

  /// A note line under the bar (env error / restart warning). 条下注记行。
  final String? note;
  final AnTone noteTone;

  String _word(BuildContext context, AnStatus s) => switch (s) {
        AnStatus.idle => context.t.status.idle,
        AnStatus.run => context.t.status.run,
        AnStatus.wait => context.t.status.wait,
        AnStatus.err => context.t.status.err,
        AnStatus.done => context.t.status.done,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final faint = AnText.meta.copyWith(color: c.inkFaint);

    Color inkOf(AnTone tone) => switch (tone) {
          AnTone.ok => c.ok,
          AnTone.warn => c.warn,
          AnTone.danger => c.danger,
          AnTone.accent => c.accent,
          AnTone.none => c.inkMuted,
        };

    final spans = <InlineSpan>[];
    for (final s in stats) {
      if (spans.isNotEmpty) spans.add(TextSpan(text: ' · ', style: faint));
      spans.add(TextSpan(
        text: s.text,
        style: (s.tabular ? AnText.metaTabular() : AnText.meta).copyWith(color: inkOf(s.tone)),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Wrap(
          spacing: AnSpace.s6,
          runSpacing: AnSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (status != null)
              AnBadge(statusLabel ?? _word(context, status!), tone: status!.tone),
            if (spans.isNotEmpty) Text.rich(TextSpan(children: spans)),
            ...chips,
          ],
        ),
        if (note != null && note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Text(note!, style: AnText.code.copyWith(color: inkOf(noteTone))),
          ),
      ]),
    );
  }
}
