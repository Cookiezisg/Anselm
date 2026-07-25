import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/design/tokens.dart';
import '../../../core/ui/an_hover_region.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';

/// The faint icon row that hugs the bottom edge of a transcript turn (§3.2 动作排).
///
/// Two visibility rules, and the difference matters: the LAST turn's row is always there in pale grey,
/// because that is the turn a reader acts on and a row that has to be discovered is a row that isn't
/// found; a HISTORICAL turn's row appears on hover, because dozens of always-on rows down a long
/// transcript would read as clutter and compete with the prose. A turn that is still GENERATING shows no
/// row at all — there is nothing to copy yet, and the only meaningful action mid-stream is Stop, which
/// lives in the composer.
///
/// Copy is wired here. Fork, retry and version paging are declared as PLACEHOLDERS (rendered, disabled,
/// tooltip says so) — they need the backend work in CH-b / CH-c. Rendering them disabled rather than
/// hiding them is deliberate: the row's shape stops moving between batches, and a reader who looks for
/// "fork" learns it exists and is coming rather than concluding it doesn't.
///
/// transcript 回合下沿那排浅灰小图标(§3.2 动作排)。
///
/// 两条可见性规则,其区别是有意义的:**最后一轮**的动作排恒在(浅灰)——那是读者要动手的那一轮,而需要被发现的
/// 动作排就是找不到的动作排;**历史轮**hover 才现——长 transcript 上几十排常显图标读作杂乱,并与正文抢注意力。
/// **正在生成**的回合完全不显示动作排:此刻没有可复制的东西,而流中唯一有意义的动作是「停止」,它住在 composer。
///
/// 复制**已接通**。分叉、重试、版本翻页是**占位**(渲出来、禁用、tooltip 明说)——它们要等 CH-b / CH-c 的后端
/// 工作。渲成禁用而不是隐藏是刻意的:动作排的形状在批次之间不再变动,而来找「分叉」的读者会知道它存在且在路上,
/// 不会以为没有。
class TurnActions extends StatefulWidget {
  const TurnActions({
    required this.copyText,
    required this.role,
    required this.alwaysVisible,
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

  @override
  State<TurnActions> createState() => _TurnActionsState();
}

/// Which side the row hugs. 排贴哪一侧。
enum TurnActionsRole { user, assistant }

class _TurnActionsState extends State<TurnActions> {
  bool _hovered = false;
  bool _copied = false;
  bool _copyFailed = false;

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
              icon: AnIcons.control,
              tip: t.chat.actions.forkComing,
              onTap: null,
            ),
            if (widget.role == TurnActionsRole.assistant) ...[
              const SizedBox(width: AnSpace.s4),
              _action(
                icon: AnIcons.refresh,
                tip: t.chat.actions.retryComing,
                onTap: null,
              ),
            ],
          ],
        ),
      ),
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
