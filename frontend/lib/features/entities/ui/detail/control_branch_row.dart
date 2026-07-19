import 'package:flutter/widgets.dart';

import '../../../../core/contract/entities/control.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/status_state.dart';
import '../../../../core/ui/an_chip.dart';
import '../../../../i18n/strings.g.dart';

/// The ONE control routing-branch row (WRK-066 批6, A-054 — the overview and the editor inspector
/// wore two faces): a port chip (catch-all = neutral, else accent) + the when-CEL in full (mono,
/// wrapping — a single-line ellipsis loses the condition) + the emit summary (透传 when empty).
/// The inspector's old single-line face also hung a WARN badge on emit — a tone violation (warn =
/// half-success, an emit reshape isn't a warning; 文法 #6), retired with it.
///
/// 唯一 control 路由分支行(批6 A-054——概览与编辑器检查器曾两张脸):port 徽(兜底=中性,余 accent)+
/// when-CEL 全文(mono 可换行——单行省略丢条件)+ emit 摘要(空=透传)。检查器旧单行脸的 emit warn 徽
/// =声调违例(warn=半成功,emit 重塑非警告,文法 #6),随脸退役。
class ControlBranchRow extends StatelessWidget {
  const ControlBranchRow({required this.branch, super.key});

  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    final c = context.colors;
    final b = branch;
    final isDefault = b.when == 'true';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnChip(b.port, tone: isDefault ? AnTone.none : AnTone.accent),
          const SizedBox(width: AnSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content-column tier: when-CEL rides mono 13 (the inline-machine-text rung, same
                // as the tool-card target), the emit summary label 13 — never 12 inside content.
                // 内容列档:when-CEL 走 mono 13(行内机器文,同 tool 卡 target),emit 摘要 label 13。
                Text(
                  isDefault ? d.editor.branchDefault : b.when,
                  style: AnText.mono.copyWith(color: isDefault ? c.inkFaint : c.inkMuted),
                ),
                Text(
                  b.emit.isEmpty ? d.val.passthrough : '${d.editor.branchEmit}: ${b.emit.keys.join(', ')}',
                  style: AnText.label.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
