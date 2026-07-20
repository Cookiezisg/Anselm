import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/an_button.dart';
import '../ui/an_interactive.dart';
import '../ui/icons.dart';
import '../ui/text_measure.dart';

/// The APPROVAL band capsule — the block-shaped sibling of the pill notice (用户 0720:「别的展开成条,
/// 这个展开成块」, 灵动岛来电卡式). One CONTINUOUS line, three overlapping beats on one controller:
///
///  1. birth — a pixel grows into the circle, the WARN (amber) dot at its center — the same dot the
///     tray's approval card wears (每个等级的点色不同:审批=琥珀,失败=红);
///  2. bar — the circle pulls open sideways into the title bar («等待审批 · name» + ✕);
///  3. block — the bar grows DOWNWARD into the card: the question sweeps out under the title, then the
///     in-place Approve / Reject row. Radius rides 14→12 across the beat (the bar's pill radius and the
///     block's card radius almost coincide — the morph is continuous by construction).
///
/// It NEVER auto-dismisses (an approval awaits a human decision — a timer would lose the errand);
/// ✕ or a decision plays the same line in reverse. All content is measured/laid out ONCE — every
/// frame is clip + transform (the smoothness the user demanded is structural, not tuned).
/// Pure props, zero Riverpod (the host wires the decide chain).
///
/// 审批顶带胶囊——药丸的块形亲属。一条连续线三个交叠拍:像素→圆(琥珀点圆心,与托盘审批卡同色——分级点色
/// 铁律)→横拉成标题条(等待审批·名+✕)→纵长成块(问题句被下缘扫出,再到就地批/拒行);半径 14→12 全程近恒定,
/// 形变构造性连续。**不自动收**(等人决策,计时器会丢事)——✕/决策后同线倒放。内容排版一次,每帧仅裁切+
/// 变换(丝滑是结构性的)。纯 prop 零 Riverpod,决策链宿主接。
class AnApprovalCapsule extends StatefulWidget {
  const AnApprovalCapsule({
    required this.title,
    required this.question,
    required this.pendingLabel,
    required this.approveLabel,
    required this.rejectLabel,
    this.busy = false,
    this.verdict,
    required this.onApprove,
    required this.onReject,
    required this.onClose,
    required this.onDismissed,
    this.closeLabel,
    super.key,
  });

  /// The workflow / approval display name on the title bar. 标题条上的名字。
  final String title;

  /// The rendered approval prompt (markdown source; shown as plain two-line text here — the full
  /// formatting lives in the tray card). 问题句(此处两行纯文本,全格式在托盘卡)。
  final String question;

  final String pendingLabel;
  final String approveLabel;
  final String rejectLabel;

  /// A decision in flight — both buttons pressed down. 决断在途,双钮压下。
  final bool busy;

  /// Non-null once decided ("已批准"/"已否决") — the title verb swaps to it and the capsule retreats
  /// on its own shortly after. 判词:非空即显示并稍后自动倒放收回。
  final String? verdict;

  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// Manual ✕ — the host decides (usually reverse+pop). 手动关闭。
  final VoidCallback onClose;

  /// Fired once after the exit animation completes. 退场完成回调一次。
  final VoidCallback onDismissed;

  final String? closeLabel;

  @override
  State<AnApprovalCapsule> createState() => _AnApprovalCapsuleState();
}

class _AnApprovalCapsuleState extends State<AnApprovalCapsule> with SingleTickerProviderStateMixin {
  static const double _barH = AnSize.control; // the bar beat's height (= newborn circle) 条高=圆径
  static const double _blockW = 340;

  late final AnimationController _c;
  late final Animation<double> _birth;
  late final Animation<double> _stretchW;
  late final Animation<double> _stretchH;

  double _blockH = 120;
  double _questionH = 20;
  bool _started = false;
  bool _exiting = false;

  bool get _reduced => AnMotionPref.reduced(context);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this,
        duration: AnMotion.capsuleBlockIn,
        reverseDuration: AnMotion.capsuleBlockOut);
    // Three OVERLAPPING beats — the seams between beats are where smoothness lives (a beat finishing
    // exactly as the next starts reads as a stutter; a 4% overlap reads as one gesture).
    // 三拍交叠:拍缝即丝滑所在——严丝合缝读作卡顿,4% 交叠读作一次手势。
    _birth = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.16, curve: Curves.easeOutBack));
    _stretchW = CurvedAnimation(parent: _c, curve: const Interval(0.14, 0.48, curve: Curves.easeOutCubic));
    _stretchH = CurvedAnimation(parent: _c, curve: const Interval(0.44, 1.0, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _measure();
    if (_reduced) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnApprovalCapsule old) {
    super.didUpdateWidget(old);
    // A verdict landed — show it a beat, then retreat along the same line. 判词落地:亮一拍,同线倒放。
    if (old.verdict == null && widget.verdict != null) {
      Future<void>.delayed(AnMotion.verdictDwell, _exit);
    }
  }

  /// Every rung of the block is measured ONCE — the height animation needs its destination before the
  /// first frame (structural smoothness: no mid-flight relayout, ever).
  /// 块的每一级预量一次——高度动画开拍前就知道终点(结构性丝滑:全程零中途重排)。
  void _measure() {
    _questionH = measureText(
      TextSpan(text: _plainQuestion, style: AnText.body),
      maxLines: 2,
      maxWidth: _blockW - AnSpace.s12 * 2,
      read: (p) => p.height,
    );
    _blockH = AnSpace.s8 + // top pad
        _barH + // title bar
        AnSpace.s4 +
        _questionH +
        AnSpace.s8 +
        AnSize.control + // button row
        AnSpace.s12; // bottom pad
  }

  /// The prompt is markdown source — strip the light inline markers for this two-line plain preview
  /// (the tray card renders it properly; a naked `**v2.4.0**` here would be the 星号 bug all over).
  /// 去轻量行内记号作两行纯文本预览(托盘卡渲全格式;裸星号=星号 bug 重演)。
  String get _plainQuestion =>
      widget.question.replaceAll('**', '').replaceAll('`', '').replaceAll('*', '');

  Future<void> _exit() async {
    if (_exiting || !mounted) return;
    _exiting = true;
    if (_reduced) {
      _c.value = 0;
    } else {
      await _c.reverse();
    }
    if (mounted) widget.onDismissed();
  }

  void _close() {
    widget.onClose();
    _exit();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Laid out ONCE at final block size; the animated shell clips it (top-start anchored: the right
    // edge sweeps the title out, the bottom edge sweeps the question + buttons out).
    // 按终尺寸排版一次,动画壳裁切;左上锚定=右缘扫标题、下缘扫问题与按钮。
    final content = SizedBox(
      width: _blockW,
      height: _blockH,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AnSpace.s12, AnSpace.s8, AnSpace.s8, AnSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _barH,
              child: Row(
                children: [
                  Container(
                    width: AnSize.dot,
                    height: AnSize.dot,
                    // The approval tier's dot is WARN amber — never the danger red (分级点色铁律).
                    decoration: BoxDecoration(color: c.warn, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AnSpace.s6),
                  Text(widget.verdict ?? widget.pendingLabel,
                      style: AnText.meta.copyWith(color: c.inkMuted)),
                  const SizedBox(width: AnSpace.s6),
                  Flexible(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink),
                    ),
                  ),
                  const Spacer(),
                  AnButton.iconOnly(AnIcons.close,
                      size: AnButtonSize.sm,
                      semanticLabel: widget.closeLabel ?? widget.rejectLabel,
                      onPressed: _close),
                ],
              ),
            ),
            const SizedBox(height: AnSpace.s4),
            Padding(
              padding: const EdgeInsets.only(right: AnSpace.s4),
              child: Text(
                _plainQuestion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AnText.body.copyWith(color: c.ink),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                AnButton(
                  label: widget.approveLabel,
                  variant: AnButtonVariant.primary,
                  size: AnButtonSize.sm,
                  onPressed: widget.busy || widget.verdict != null ? null : widget.onApprove,
                ),
                const SizedBox(width: AnSpace.s8),
                AnButton(
                  label: widget.rejectLabel,
                  size: AnButtonSize.sm,
                  onPressed: widget.busy || widget.verdict != null ? null : widget.onReject,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: AnInteractive(onTap: null, builder: (context, states) => content),
        builder: (context, child) {
          final birth = _birth.value;
          final sw = _stretchW.value;
          final sh = _stretchH.value;
          final w = _barH + (_blockW - _barH) * sw;
          final h = _barH + (_blockH - _barH) * sh;
          // Pill radius at bar height (14) ≈ card radius (12): lerp the two and the whole morph keeps
          // a near-constant corner — continuity by construction. 半径 14→12 近恒定,连续性来自构造。
          final r = _barH / 2 + (AnRadius.card - _barH / 2) * sh;
          return Opacity(
            opacity: (birth * 3).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.15 + 0.85 * birth,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: w,
                height: h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(r),
                    border: Border.all(color: c.line, width: AnSize.hairline),
                    boxShadow: c.shadowIsland,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(r),
                    child: OverflowBox(
                      minWidth: _blockW,
                      maxWidth: _blockW,
                      minHeight: _blockH,
                      maxHeight: _blockH,
                      alignment: AlignmentDirectional.topStart,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
