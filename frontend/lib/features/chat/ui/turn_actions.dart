import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/contract/model_capability.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_hover_region.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import 'chat_head.dart';

/// The faint icon row that hugs the bottom edge of a transcript turn (§3.2 动作排).
///
/// Two visibility rules, and the difference matters: the LAST turn's row is always there in pale grey,
/// because that is the turn a reader acts on and a row that has to be discovered is a row that isn't
/// found; a HISTORICAL turn's row appears on hover, because dozens of always-on rows down a long
/// transcript would read as clutter and compete with the prose. A turn that is still GENERATING shows no
/// row at all — there is nothing to copy yet, and the only meaningful action mid-stream is Stop, which
/// lives in the composer.
///
/// Fork's tooltip differs by role, because the two mean different things to a reader: on an ASSISTANT
/// turn it is "branch from here", i.e. keep everything up to and including this reply; on a USER turn
/// it is "branch before I said this", i.e. keep the thread up to the previous reply and hand the
/// sentence back as editable draft text. The widget only reports the tap — the caller owns which
/// message the fork cuts at and whether a prefill rides along (it is the one holding the turn list).
///
/// Retry, edit-resend and version paging (CH-c) are each present ONLY where they are true (§3.2): retry on
/// the last ASSISTANT turn, edit-resend on the last USER turn, and the pager on any turn that actually has
/// more than one version. None of them is rendered-but-disabled the way the CH-b placeholders were: a
/// placeholder tells a reader "this exists and is coming", whereas a permanently-disabled retry on a
/// historical turn would say "this could work here" about something that never can.
///
/// transcript 回合下沿那排浅灰小图标(§3.2 动作排)。
///
/// 两条可见性规则,其区别是有意义的:**最后一轮**的动作排恒在(浅灰)——那是读者要动手的那一轮,而需要被发现的
/// 动作排就是找不到的动作排;**历史轮**hover 才现——长 transcript 上几十排常显图标读作杂乱,并与正文抢注意力。
/// **正在生成**的回合完全不显示动作排:此刻没有可复制的东西,而流中唯一有意义的动作是「停止」,它住在 composer。
///
/// 分叉的 tooltip **按角色不同**,因为这两件事对读者的含义不同:在 **assistant** 回合上是「从这里分叉」——
/// 留下直到这条回复(含)的一切;在 **user** 回合上是「在我说出这句之前分叉」——线程留到上一条回复,而这句话
/// 作为可编辑草稿还给你。本 widget 只上报点击——切在哪条消息、是否带预填由**调用方**拥有(手上有回合列表的是它)。
///
/// 重试、编辑重发、版本翻页(CH-c)各只在**为真**之处出现(§3.2):重试在末条 **assistant** 回合、编辑重发在末条
/// **user** 回合、翻页只在真有多个版本的回合上。三者都**不**像 CH-b 的占位那样「渲出来但禁用」:占位是告诉读者
/// 「它存在且在路上」,而一个历史回合上永久禁用的重试则是在对一件**永远**不可能的事说「这里也许能行」。
class TurnActions extends StatefulWidget {
  const TurnActions({
    required this.copyText,
    required this.role,
    required this.alwaysVisible,
    this.onFork,
    this.onRetry,
    this.retryCaps = const [],
    this.onEdit,
    this.versionIndex = 0,
    this.versionCount = 1,
    this.onVersion,
    this.readAloudSlot,
    super.key,
  });

  /// The prose to put on the clipboard — from the MODEL, never from the rendered widgets
  /// (`ConversationTranscript.turnCopyText`). 放进剪贴板的正文——取自 **model**、绝不取自渲出来的 widget。
  final String copyText;

  /// A user turn's row aligns right under its bubble; an assistant turn's aligns left under its column.
  /// 用户回合的排右对齐(贴气泡);助手回合左对齐(贴内容列)。
  final TurnActionsRole role;

  /// The last turn's row is always shown; a historical turn's appears on hover. 末轮恒显、历史 hover 现。
  final bool alwaysVisible;

  /// Branch from this turn into a new conversation. Null disables the button (kept rendered, so the
  /// row's shape never moves). The Future keeps the action visibly busy until navigation or an error
  /// settles it, so a slow network never looks like a dead tap. 从本回合分叉出新对话;null 即禁用(仍渲出,故动作排
  /// 形状恒定)。Future 让动作直到导航或错误收口前保持可见忙碌态,慢网络不再像「点了没反应」。
  final FutureOr<void> Function()? onFork;

  /// Regenerate this answer, optionally with a different model (null = keep whatever the thread is set to).
  /// Null omits the retry affordance entirely — only the last assistant turn can be retried.
  /// 重生成这个回答,可选换模型(null = 用线程现有的设置)。本回调为 null 时整个重试入口不出现——只有末条 assistant
  /// 回合可重试。
  final void Function(({String apiKeyId, String modelId})? modelOverride)?
  onRetry;

  /// The models offered by「换模型重试」— the same capability list the head's picker shows. 换模型重试的可选模型。
  final List<ModelCapability> retryCaps;

  /// Put this turn back into an editable state and resend it as a new version. Null omits the affordance —
  /// only the last user turn can be edit-resent.
  /// 把本回合放回可编辑态、作为新版本重发。null 即入口不出现——只有末条 user 回合可编辑重发。
  final VoidCallback? onEdit;

  /// Which version of this turn is on screen, and how many there are. [versionCount] ≤ 1 omits the pager
  /// entirely — a turn with one version has nothing to page. 屏上是第几版 / 共几版;versionCount ≤ 1 时不渲翻页。
  final int versionIndex;
  final int versionCount;

  /// Show version [index] (already clamped by the caller). 显示第 index 版(调用方已钳制)。
  final ValueChanged<int>? onVersion;

  /// The read-aloud affordance (WRK-082 批C, P10), handed in as a SLOT rather than callbacks: it
  /// owns its own availability + playback subscriptions, and that is what keeps a transcript ROW
  /// from rebuilding every time either of those moves (the BuildSpy gate catches exactly that).
  /// Null — or a slot that renders nothing — means this row simply has no speaker: honest absence,
  /// the same rule that keeps retry off historical turns.
  ///
  /// 朗读入口(批C,P10),以**插槽**而非回调传入:它自己持有可用性与播放的订阅,正是这一点让
  /// transcript 的**行**不会因这两者任一变化而重建(BuildSpy 闸抓的正是这个)。null——或一个什么都
  /// 不渲的插槽——即这一行没有喇叭:诚实缺席,与重试不出现在历史回合上同一条规矩。
  final Widget? readAloudSlot;

  @override
  State<TurnActions> createState() => _TurnActionsState();
}

/// Which side the row hugs. 排贴哪一侧。
enum TurnActionsRole { user, assistant }

class _TurnActionsState extends State<TurnActions> {
  bool _hovered = false;
  bool _copied = false;
  bool _copyFailed = false;
  bool _forking = false;

  Future<void> _runFork() async {
    if (_forking || widget.onFork == null) return;
    setState(() => _forking = true);
    try {
      await widget.onFork!();
    } finally {
      if (mounted) setState(() => _forking = false);
    }
  }

  Future<void> _copy() async {
    final text = widget.copyText;
    if (text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) setState(() => _copied = true);
    } catch (_) {
      // A clipboard write can genuinely fail (no platform channel, a locked pasteboard). Saying so is
      // better than a check-mark that lies about what is on the clipboard.
      // 剪贴板写入确实可能失败(无平台通道、pasteboard 被锁)。说出来,好过一个对剪贴板内容撒谎的对勾。
      if (mounted) setState(() => _copyFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final shown = widget.alwaysVisible || _hovered;

    final copyTip = _copied
        ? t.feedback.copied
        : (_copyFailed ? t.feedback.copyFailed : t.action.copy);

    return AnHoverRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _copied = false;
        _copyFailed = false;
      }),
      // Opacity, not a conditional subtree: the row must keep its element identity (and so its
      // "copied" state) across every hover, and a wrapper that comes and goes remounts it
      // (CLAUDE.md 禁止条件包装). It also keeps the transcript's height stable, so revealing a row
      // never nudges the reading position.
      // 用不透明度、不用条件子树:动作排必须跨每一次 hover 保住 element 身份(从而保住「已复制」态),而来来去去
      // 的包装层会把它重挂(CLAUDE.md 禁止条件包装)。这也让 transcript 高度恒定,故显示动作排绝不会顶动阅读位置。
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: AnMotion.fast,
        child: Row(
          mainAxisAlignment: widget.role == TurnActionsRole.user
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            _action(
              icon: _copied ? AnIcons.check : AnIcons.copy,
              tip: copyTip,
              onTap: widget.copyText.isEmpty ? null : _copy,
            ),
            const SizedBox(width: AnSpace.s4),
            _action(
              icon: _forking ? AnIcons.spin : AnIcons.control,
              tip: _forking
                  ? t.chat.actions.forking
                  : (widget.role == TurnActionsRole.user
                        ? t.chat.actions.forkBefore
                        : t.chat.actions.fork),
              onTap: widget.onFork == null || _forking
                  ? null
                  : () => unawaited(_runFork()),
            ),
            if (widget.onEdit != null) ...[
              const SizedBox(width: AnSpace.s4),
              _action(
                icon: AnIcons.edit,
                tip: t.chat.actions.editResend,
                onTap: widget.onEdit,
              ),
            ],
            if (widget.onRetry != null) ...[
              const SizedBox(width: AnSpace.s4),
              _retryMenu(t),
            ],
            if (widget.readAloudSlot != null) widget.readAloudSlot!,
            if (widget.versionCount > 1) ...[
              const SizedBox(width: AnSpace.s8),
              _pager(context, t),
            ],
          ],
        ),
      ),
    );
  }

  /// Retry as a MENU rather than a bare button, because「可换模型」has to live somewhere and a second icon
  /// beside the first would say nothing about the relationship between them. The first row is the plain retry
  /// (one pick — the common case, and it means "keep whatever this thread is set to"); the model list
  /// underneath is the head's own picker, reused.
  ///
  /// No row is check-marked and there is no Auto: a per-turn model cannot CLEAR the thread's override, and
  /// knowing which model is current would cost a subscription to the one provider CH-b found re-polls a
  /// failed read forever (see the caller's note).
  ///
  /// 重试做成**菜单**而非裸按钮,因为「可换模型」总得有个地方住,而在第一个图标旁再加一个图标说不出两者的关系。
  /// 首行是朴素重试(一次点击——常见情形,含义是「用这条线程现有的设置」);下方的模型列表就是头部那个选择器本身、复用之。
  ///
  /// 没有任何一行被打勾、也没有 Auto:逐回合的模型无法**清除**线程的 override,而「当前是哪个模型」要付一次订阅——订的正是
  /// CH-b 查明「失败的读会永远重轮询」的那个 provider(见调用处注释)。
  Widget _retryMenu(Translations t) {
    final onRetry = widget.onRetry!;
    return chatModelMenu(
      t: t,
      caps: widget.retryCaps,
      current: null,
      includeAuto: false,
      leadingEntries: [
        AnMenuItem(
          label: t.chat.actions.retry,
          icon: AnIcons.refresh,
          onTap: () => onRetry(null),
        ),
        if (widget.retryCaps.isNotEmpty)
          AnMenuSection(t.chat.actions.retryWithModel),
      ],
      onSelect: (ref) => onRetry(ref),
      anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
        AnIcons.refresh,
        size: AnButtonSize.sm,
        semanticLabel: t.chat.actions.retry,
        onPressed: toggle,
      ),
    );
  }

  /// `‹ 2/2 ›` — the version pager, plus the one thing it must not leave unsaid: which version everything
  /// AFTER this turn was generated from. While the reader is looking at the current version there is nothing
  /// to disclaim, so the note is absent; the moment they page back, the note appears and says so. A pager
  /// that silently showed an old answer inside a thread built on a newer one would be the lie this whole
  /// feature has to avoid.
  ///
  /// `‹ 2/2 ›`——版本翻页,外加它绝不能不说的那件事:本回合**之后**的一切是据**哪一版**生成的。读者在看现行版时没有
  /// 什么要声明,故注记缺席;他一往回翻,注记就出现并说明。一个默默显示旧回答、而线程其实建立在更新一版之上的翻页,
  /// 正是整个 feature 必须避免的那个谎。
  Widget _pager(BuildContext context, Translations t) {
    final c = context.colors;
    final i = widget.versionIndex;
    final n = widget.versionCount;
    final onVersion = widget.onVersion;
    // Named, not inlined twice: it reads better, and it keeps the arithmetic off the EdgeInsets line —
    // the convergence ratchet flags a bare number there, and it is right to (spacing must come from
    // tokens, and a `- 1` sitting inside a padding call is exactly how a private size tier starts).
    // 起个名、不内联两遍:更好读,且把算术从 EdgeInsets 那一行挪开——收敛棘轮会判该行的裸数字,而它判得对
    // (间距必须来自代币,而一个 `- 1` 坐在 padding 调用里正是私铸尺寸档的起头)。
    final isCurrent = i == n - 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnButton.iconOnly(
          AnIcons.chevronLeft,
          size: AnButtonSize.sm,
          semanticLabel: t.chat.actions.versionPrev,
          onPressed: i > 0 && onVersion != null ? () => onVersion(i - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4),
          child: Text(
            '${i + 1}/$n',
            style: AnText.meta.copyWith(color: c.inkMuted),
          ),
        ),
        AnButton.iconOnly(
          AnIcons.chevronRight,
          size: AnButtonSize.sm,
          semanticLabel: t.chat.actions.versionNext,
          onPressed: i < n - 1 && onVersion != null
              ? () => onVersion(i + 1)
              : null,
        ),
        // The note occupies zero width on the current version rather than being conditionally wrapped, so
        // paging never remounts the pager (CLAUDE.md 禁止条件包装).
        // 在现行版上注记占零宽、而非被条件包装,故翻页绝不重挂翻页器本身(CLAUDE.md 禁止条件包装)。
        Padding(
          padding: EdgeInsets.only(left: isCurrent ? AnSpace.s0 : AnSpace.s8),
          child: Text(
            isCurrent ? '' : t.chat.actions.versionBasedOn(n: n),
            style: AnText.meta.copyWith(color: c.inkFaint),
          ),
        ),
      ],
    );
  }

  // AnButton.iconOnly + AnTooltip is the kit's small-icon-button grammar (the code editor's bar uses the
  // same pair) — reused rather than hand-rolled on AnInteractive, which is what 原则 #8 asks for. It also
  // brings the disabled treatment and `chrome: true` for free.
  // 小图标钮的套件文法就是 AnButton.iconOnly + AnTooltip(代码编辑器工具条用的是同一对)——复用而非在
  // AnInteractive 上手搓,这正是原则 #8 的要求;顺带白拿禁用态处理与 `chrome: true`。
  Widget _action({
    required IconData icon,
    required String tip,
    required VoidCallback? onTap,
  }) => AnButton.iconOnly(
    icon,
    size: AnButtonSize.sm,
    semanticLabel: tip,
    onPressed: onTap,
  );
}
