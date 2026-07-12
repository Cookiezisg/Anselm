import 'package:flutter/widgets.dart';

import '../../../core/design/tokens.dart';
import '../../../core/ui/an_sunken_panel.dart';

/// Which side of the conversation a turn belongs to. 回合归属方。
enum ChatRole { user, assistant }

/// One transcript turn — the conversation's rhythm atom. The asymmetry IS the design: a USER turn is a
/// right-aligned soft-gray bubble (≤80% of the reading column, chip radius, no avatar / label / timestamp);
/// an ASSISTANT turn is full-width bare content (no bubble, no label, no left rail) so its rich blocks
/// (markdown, code, tool cards — later modules) breathe across the whole column. The asymmetry alone carries
/// "who is speaking" with zero chrome. Every value here is DERIVED from a design-system standard, not picked
/// by feel: the fill is [AnColors.surfaceSunken] — the dedicated neutral fill for contained non-interactive
/// regions (added for this; NOT a borrowed hover/selected STATE colour, which would mis-signal
/// interactivity); on the white ocean it reads as a gentle notch below the surface (a white-on-white bubble
/// would vanish). Radius [AnRadius.chip] + padding h12/v8 mirror AnCard / AnCallout's contained-surface
/// metrics. Purely presentational: the caller supplies [child] (a user turn's text, or an assistant turn's
/// block column); the transcript owns the reading-column centering + the inter-turn gap. [sending] dims a
/// user turn's optimistic bubble until its echo lands.
///
/// 一条 transcript 回合(对话韵律的原子)。**不对称即设计**:用户=右对齐浅灰气泡(≤阅读列 80%、chip 圆角、无
/// 头像/标签/时间);助手=全宽裸内容(无泡无标签无左轨),让其富块(markdown/代码/工具卡——后续模块)在整列铺开。
/// 仅靠不对称零 chrome 编码「谁在说」。**每个值都从设计系统标准推算、非手感**:泡填 [AnColors.surfaceSunken]——
/// 为此新增的、供 contained 非交互区域的专用中性填充(**非**借来的 hover/选中状态色,那会误示可交互);白海洋上
/// 读作比面轻降一档(白上白泡会隐形)。圆角 [AnRadius.chip] + 内距 h12/v8 镜像 AnCard/AnCallout 的 contained 面
/// 度量。纯呈现:child 由调用方给;阅读列居中 + 轮间距由 transcript 拥有。sending 淡显乐观泡。
class ChatTurn extends StatelessWidget {
  const ChatTurn({required this.role, required this.child, this.sending = false, super.key});

  final ChatRole role;
  final Widget child;

  /// User turn only — dim the optimistic bubble while the send is in flight (echo not yet reconciled).
  /// 仅用户回合——发送在途(回声未对账)时淡显乐观气泡。
  final bool sending;

  // The user bubble caps at 80% of the reading column, so a long turn wraps rather than spanning
  // edge-to-edge (which would read like an assistant turn). 气泡上限=阅读列 80%,超了换行、不占满宽。
  static const double _userMaxFraction = 0.8;

  @override
  Widget build(BuildContext context) {
    if (role == ChatRole.assistant) {
      // ASSISTANT: full-width bare content — blocks stack in a stretch column (later modules fill real blocks).
      // 助手:全宽裸内容——块在 stretch 列里堆叠。
      return SizedBox(width: double.infinity, child: child);
    }
    // USER: right-aligned bubble on the design system's neutral sunken fill (surfaceSunken), ≤80% of the column.
    // 用户:右对齐气泡,填设计系统的中性凹陷填充(surfaceSunken),≤阅读列 80%。
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AnSize.content * _userMaxFraction),
        child: Opacity(
          opacity: sending ? AnOpacity.sending : 1,
          child: AnSunkenPanel(inset: AnInset.bubble, child: child),
        ),
      ),
    );
  }
}
