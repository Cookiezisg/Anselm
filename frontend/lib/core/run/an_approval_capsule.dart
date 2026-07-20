import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import '../ui/an_button.dart';
import '../ui/an_a11y.dart';
import '../ui/an_interactive.dart';
import '../ui/an_notice_close_affordance.dart';
import '../ui/an_notice_island_frame.dart';
import '../ui/text_measure.dart';
import '../ui/tone.dart';

/// The APPROVAL band capsule — the block-shaped sibling of the pill notice (用户 0720:「别的展开成条,
/// 这个展开成块」, 灵动岛来电卡式). One CONTINUOUS line, three overlapping beats on one controller:
///
///  1. birth — a pixel grows into the circle, the WARN (amber) dot at its center — the same dot the
///     tray's approval card wears (每个等级的点色不同:审批=琥珀,失败=红);
///  2. bar — the circle pulls open sideways into the title bar («等待审批 · name» + ✕);
///  3. block — the bar grows DOWNWARD into the card: the question sweeps out under the title, then the
///     in-place Approve / Reject row. Radius rides 18→16 across the beat (the bar's pill radius and the
///     block's card radius almost coincide — the morph is continuous by construction).
///
/// It NEVER auto-dismisses (an approval awaits a human decision — a timer would lose the errand);
/// ✕ or a decision plays the same line in reverse. Content is measured before ignition and remains
/// stable while one controller drives the small local shell's width/height/clip/transform.
/// Pure props, zero Riverpod (the host wires the decide chain).
///
/// 审批顶带胶囊——药丸的块形亲属。一条连续线三个交叠拍:像素→圆(琥珀点圆心,与托盘审批卡同色——分级点色
/// 铁律)→横拉成标题条(等待审批·名+✕)→纵长成块(问题句被下缘扫出,再到就地批/拒行);半径 18→16 全程近恒定,
/// 形变构造性连续。**不自动收**(等人决策,计时器会丢事)——✕/决策后同线倒放。内容开拍前预测量并
/// 保持稳定,单 controller 只驱动小壳的局部宽高/layout/clip/transform。纯 prop 零 Riverpod,决策链宿主接。
class AnApprovalCapsule extends StatefulWidget {
  const AnApprovalCapsule({
    required this.title,
    required this.question,
    required this.pendingLabel,
    required this.busyLabel,
    required this.approveLabel,
    required this.rejectLabel,
    this.busy = false,
    this.decisionsEnabled = true,
    this.verdict,
    this.verdictTone = AnTone.ok,
    this.errorLabel,
    required this.onApprove,
    required this.onReject,
    required this.onClose,
    this.onExitStarted,
    required this.onDismissed,
    this.dismissRequested = false,
    this.closeLabel,
    super.key,
  });

  /// The workflow / approval display name on the title bar. 标题条上的名字。
  final String title;

  /// The rendered approval prompt (markdown source; shown as plain two-line text here — the full
  /// formatting lives in the tray card). 问题句(此处两行纯文本,全格式在托盘卡)。
  final String question;

  final String pendingLabel;
  final String busyLabel;
  final String approveLabel;
  final String rejectLabel;

  /// A decision in flight — both buttons pressed down. 决断在途,双钮压下。
  final bool busy;

  /// False while the parked-node address is resolving; the block keeps its visual identity but cannot
  /// issue a decision without a pinned target. 停车节点解析中为 false;块形不变,但无钉住目标时绝不裁决。
  final bool decisionsEnabled;

  /// Non-null once decided ("已批准"/"已否决") — the title verb swaps to it and the capsule retreats
  /// on its own shortly after. 判词:非空即显示并稍后自动倒放收回。
  final String? verdict;

  /// Approved is ok; rejected is deliberately neutral — declining is not a failure.
  /// 批准=成功,驳回=中性;人的否决不是系统错误。
  final AnTone verdictTone;

  /// A failed decision is shown IN THIS title bar (the sticky card would otherwise hide feedback
  /// queued behind itself). A retry clears it. 决策失败就地显示在标题条;sticky 卡后的排队反馈用户看不到。
  final String? errorLabel;

  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// Manual ✕ — the host decides (usually reverse+pop). 手动关闭。
  final VoidCallback onClose;

  /// Any exit first asks the host to hide the candidate tail. 任一退场先让宿主收候场尾。
  final VoidCallback? onExitStarted;

  /// Fired once after the exit animation completes. 退场完成回调一次。
  final VoidCallback onDismissed;

  /// External `+N → X` snapshot clear asks the still-mounted block to reverse. 外部清场请求块倒放。
  final bool dismissRequested;

  final String? closeLabel;

  @override
  State<AnApprovalCapsule> createState() => _AnApprovalCapsuleState();
}

class _AnApprovalCapsuleState extends State<AnApprovalCapsule>
    with SingleTickerProviderStateMixin {
  static const double _barH =
      AnSize.noticeBar; // shared 36px crown (= newborn circle) 共用 36 冠部=出生圆径
  static const double _blockW = AnSize.noticeMaxWidth;

  late final AnimationController _c;
  late final Animation<double> _birth;
  late final Animation<double> _stretchW;
  late final Animation<double> _stretchH;

  double _blockH = 120;
  double _questionH = 20;
  bool _started = false;
  bool _exiting = false;
  bool _entered = false;
  bool _announced = false;
  bool _verdictExitScheduled = false;
  Timer? _verdictExitTimer;

  bool get _reduced => AnMotionPref.reduced(context);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: AnMotion.capsuleBlockIn,
      reverseDuration: AnMotion.capsuleBlockOut,
    );
    // Three OVERLAPPING beats — the seams between beats are where smoothness lives (a beat finishing
    // exactly as the next starts reads as a stutter; a 4% overlap reads as one gesture).
    // 三拍交叠:拍缝即丝滑所在——严丝合缝读作卡顿,4% 交叠读作一次手势。
    _birth = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.16, curve: Curves.easeOutBack),
    );
    _stretchW = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.14, 0.48, curve: Curves.easeOutCubic),
    );
    _stretchH = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.44, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _measure();
    if (widget.dismissRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _exit());
      return;
    }
    _enter();
    if (!_announced) {
      _announced = true;
      final initial =
          widget.errorLabel ?? widget.verdict ?? widget.pendingLabel;
      _announce(
        '$initial: ${widget.title}',
        assertive: widget.errorLabel != null || widget.verdict == null,
      );
    }
  }

  Future<void> _enter() async {
    if (_reduced) {
      _c.value = 1;
    } else {
      await _c.forward();
    }
    if (!mounted || _exiting) return;
    _entered = true;
    if (widget.verdict != null) _scheduleVerdictExit();
  }

  @override
  void dispose() {
    _verdictExitTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnApprovalCapsule old) {
    super.didUpdateWidget(old);
    // A verdict landed — show it a beat, then retreat along the same line. 判词落地:亮一拍,同线倒放。
    if (old.verdict == null && widget.verdict != null) {
      _announce(widget.verdict!);
      if (_entered) _scheduleVerdictExit();
    } else if (old.errorLabel != widget.errorLabel &&
        widget.errorLabel != null) {
      _announce(widget.errorLabel!, assertive: true);
    } else if (!old.busy && widget.busy) {
      _announce(widget.busyLabel);
    }
    if (!old.dismissRequested && widget.dismissRequested) _exit();
  }

  void _scheduleVerdictExit() {
    if (_verdictExitScheduled || _exiting) return;
    _verdictExitScheduled = true;
    _verdictExitTimer = Timer(AnMotion.verdictDwell, () {
      _verdictExitTimer = null;
      _exit();
    });
  }

  void _announce(String message, {bool assertive = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AnA11y.announce(
        context,
        message,
        assertiveness: assertive
            ? Assertiveness.assertive
            : Assertiveness.polite,
      );
    });
  }

  /// Every rung of the block is measured ONCE — the height animation needs its destination before the
  /// first frame; the paragraph does not reflow during the local shell animation.
  /// 块的每一级预量一次——高度动画开拍前就知道终点,正文在局部壳动画中不重排。
  void _measure() {
    _questionH = measureText(
      TextSpan(text: _plainQuestion, style: AnText.body),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
      maxWidth: _blockW - AnInset.noticeCoast * 2,
      read: (p) => p.height,
    );
    _blockH =
        _barH + // shared title crown 共用标题冠部
        AnGap.stack + // crown → question 冠部→问题
        _questionH +
        AnGap.block +
        AnSize.controlSm + // button row
        AnInset.noticeCoast; // bottom coast 底海岸
  }

  /// The prompt is markdown source — strip the light inline markers for this two-line plain preview
  /// (the tray card renders it properly; a naked `**v2.4.0**` here would be the 星号 bug all over).
  /// 去轻量行内记号作两行纯文本预览(托盘卡渲全格式;裸星号=星号 bug 重演)。
  String get _plainQuestion => widget.question
      .replaceAll('**', '')
      .replaceAll('`', '')
      .replaceAll('*', '');

  Future<void> _exit() async {
    if (_exiting || !mounted) return;
    _exiting = true;
    _verdictExitTimer?.cancel();
    _verdictExitTimer = null;
    widget.onExitStarted?.call();
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
    final statusTone = widget.errorLabel != null
        ? AnTone.danger
        : widget.verdict != null
        ? widget.verdictTone
        : AnTone.warn;
    final status =
        widget.errorLabel ??
        widget.verdict ??
        (widget.busy ? widget.busyLabel : widget.pendingLabel);
    final statusColor = widget.errorLabel != null || widget.verdict != null
        ? statusTone.fg(c)
        : c.inkMuted;
    // Laid out ONCE at final block size; the animated shell clips it (top-start anchored: the right
    // edge sweeps the title out, the bottom edge sweeps the question + buttons out).
    // 按终尺寸排版一次,动画壳裁切;左上锚定=右缘扫标题、下缘扫问题与按钮。
    final content = SizedBox(
      width: _blockW,
      height: _blockH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _barH,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AnInset.noticeCoast,
                end: AnInset.noticeActionEdge,
              ),
              child: Row(
                children: [
                  Container(
                    width: AnSize.dot,
                    height: AnSize.dot,
                    decoration: BoxDecoration(
                      color: statusTone.fg(c),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AnGap.inline),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: status,
                        style: AnText.meta.copyWith(color: statusColor),
                        children: <InlineSpan>[
                          TextSpan(
                            text: '  ·  ${widget.title}',
                            style: AnText.body
                                .weight(AnText.emphasisWeight)
                                .copyWith(color: c.ink),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                  const SizedBox(width: AnGap.inlineLoose),
                  AnNoticeCloseAffordance(
                    semanticLabel: widget.closeLabel ?? widget.rejectLabel,
                    onPressed: _close,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AnGap.stack),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AnInset.noticeCoast,
            ),
            child: Text(
              _plainQuestion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AnText.body.copyWith(color: c.ink),
            ),
          ),
          const SizedBox(height: AnGap.block),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AnInset.noticeCoast,
            ),
            child: Row(
              children: [
                AnButton(
                  label: widget.approveLabel,
                  variant: AnButtonVariant.primary,
                  size: AnButtonSize.sm,
                  onPressed:
                      !widget.decisionsEnabled ||
                          widget.busy ||
                          widget.verdict != null
                      ? null
                      : widget.onApprove,
                ),
                const SizedBox(width: AnGap.inlineLoose),
                AnButton(
                  label: widget.rejectLabel,
                  size: AnButtonSize.sm,
                  onPressed:
                      !widget.decisionsEnabled ||
                          widget.busy ||
                          widget.verdict != null
                      ? null
                      : widget.onReject,
                ),
              ],
            ),
          ),
          const SizedBox(height: AnInset.noticeCoast),
        ],
      ),
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: AnInteractive(
          onTap: null,
          builder: (context, states) => content,
        ),
        builder: (context, child) {
          final birth = _birth.value;
          final sw = _stretchW.value;
          final sh = _stretchH.value;
          final w = _barH + (_blockW - _barH) * sw;
          final h = _barH + (_blockH - _barH) * sh;
          // The compact 36px crown is r18; as the body grows, it settles to the card-family r16.
          // 冠部 r18,身体长出时只收至卡族 r16,全程同心连续。
          final r = _barH / 2 + (AnRadius.card - _barH / 2) * sh;
          return Opacity(
            opacity: (birth * 3).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.15 + 0.85 * birth,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: w,
                height: h,
                child: AnNoticeIslandFrame(
                  radius: r,
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
          );
        },
      ),
    );
  }
}
