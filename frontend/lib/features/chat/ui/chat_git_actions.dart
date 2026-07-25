import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_card.dart';
import '../../../core/ui/an_dialog.dart';
import '../../../core/ui/an_input.dart';
import '../../../i18n/strings.g.dart';

/// One field and one sentence wide. Narrower than the install flow's 520 (which lists candidates) and than
/// the tool picker's 460 (which lists tools): this panel holds a single-line name, so extra width would only
/// stretch the explainer into an awkward one-and-a-bit lines. Inline as those two are — a modal's own width is
/// its own composition, not a shared metric.
///
/// 一个输入框加一句话的宽度。比安装流的 520（它列候选）与工具选择器的 460（它列工具）都窄:本面板装的是一行名字，
/// 多出来的宽度只会把说明句拉成尴尬的一行半。与那两处一样内联——一个模态自己的宽度是它自己的构图、不是共享度量。
const double _panelWidth = 420;

/// The residency's two NAMING actions — «new branch» (WD2) and «open a worktree» (WD3) — share one modal,
/// because they are the same shape: type one name, run one git action, and if git refuses, say what to do next
/// and STAY OPEN so the name can be fixed.
///
/// Why a modal at all, when every other residency action is a menu row: these two need a name that does not
/// exist yet, and a menu cannot take dictation. A modal is also the only surface with room for the FAILURE —
/// «that directory already exists» is a sentence the user answers by typing a different name, and a
/// one-line notice that dismisses itself takes the field away with it.
///
/// The panel closes on success only. A refusal is not a dead end: the error sits under the field, the name is
/// still there, and the next attempt is one edit away.
///
/// 驻地那两个需要**起名字**的动作——「新建分支」（WD2）与「为此对话开一个 worktree」（WD3）——共用一个模态，因为它们
/// 是同一个形状:输入一个名字、跑一个 git 动作，而如果 git 拒绝，就说出下一步、并**保持打开**以便改名。
///
/// 为什么要用模态（而其余每个驻地动作都是菜单行）:这两个需要一个**还不存在**的名字，而菜单没法听写。模态也是唯一放得下
/// **失败**的地方——「那个目录已存在」是一句用户靠**改名**来回答的话，而一条会自己消失的单行提示会把输入框一起带走。
///
/// 面板**仅在成功时**关闭。一次拒绝不是死路:错误停在输入框下方、名字还在那里、下一次尝试只差一次编辑。
class ChatGitNameDialog extends StatefulWidget {
  const ChatGitNameDialog({
    required this.title,
    required this.explainer,
    required this.placeholder,
    required this.confirmLabel,
    required this.onSubmit,
    super.key,
  });

  final String title;

  /// What this will DO, before the point of no return — a worktree writes a directory on disk, and a person
  /// deserves to know that before naming it. 在不可回头之前说清它**会做什么**——一个 worktree 会在盘上写出一个目录，
  /// 而人应当在给它起名之前就知道这件事。
  final String explainer;
  final String placeholder;
  final String confirmLabel;

  /// Runs the action. It THROWS on refusal (the repository does not swallow git's answer), which is what lets
  /// this dialog render the next step instead of closing on a failure.
  ///
  /// 跑那个动作。它在被拒时**抛出**（repository 不吞掉 git 的回答），正是这一点让本对话框能渲出下一步、而不是在失败时
  /// 关掉。
  final Future<void> Function(String name) onSubmit;

  @override
  State<ChatGitNameDialog> createState() => _ChatGitNameDialogState();
}

class _ChatGitNameDialogState extends State<ChatGitNameDialog> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(name);
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      // The refusal is the product here: keep the panel, keep the name, show what to do next.
      // 这次拒绝正是产物:留住面板、留住名字、显示下一步。
      if (mounted) {
        setState(() => _error = gitActionFailure(context.t, e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = context.colors;
    // Material(transparency): this lives in a RawDialogRoute (anPanelRoute), outside any Scaffold, and
    // AnInput's TextField needs a Material ancestor (else the debug underline / no-Material assert). Same fix
    // as skill_install_dialog.dart, for the same reason.
    // Material(transparency):本件活在 RawDialogRoute(anPanelRoute)里、脱离 Scaffold，而 AnInput 的 TextField 需要
    // Material 祖先(否则 debug 下划线 / no-Material 断言)。与 skill_install_dialog.dart 同款修法、同一理由。
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: _panelWidth,
          child: AnCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.title, style: AnText.h3),
                const SizedBox(height: AnSpace.s6),
                Text(
                  widget.explainer,
                  style: AnText.meta.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: AnSpace.s12),
                AnInput(
                  controller: _name,
                  placeholder: widget.placeholder,
                  autofocus: true,
                  block: true,
                  mono: true,
                  enabled: !_busy,
                  onSubmitted: (_) => _submit(),
                ),
                // The error row is ALWAYS mounted and only its text changes — an appearing/disappearing widget
                // here would relayout the panel under the user's cursor mid-typing (禁止条件包装).
                // 错误行**恒挂**、只换文字——此处一个「出现/消失」的组件会在用户打字时把面板重新布局到光标底下
                // (禁止条件包装)。
                const SizedBox(height: AnSpace.s6),
                Text(
                  _error ?? '',
                  style: AnText.meta.copyWith(color: c.danger),
                ),
                const SizedBox(height: AnSpace.s12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnButton(
                      label: t.action.cancel,
                      variant: AnButtonVariant.ghost,
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: AnSpace.s8),
                    AnButton(
                      label: widget.confirmLabel,
                      variant: AnButtonVariant.primary,
                      onPressed: _busy ? null : _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Open [ChatGitNameDialog] on the root navigator — the same route family the skill-install flow uses, so the
/// scrim, focus trap, Escape-dismiss and traversal loop all come from one place.
///
/// 在 root navigator 上打开 ChatGitNameDialog——与安装流同一个路由族，故遮罩、焦点陷阱、Escape 关闭与遍历闭环全部
/// 来自同一处。
Future<void> showChatGitNameDialog(
  BuildContext context, {
  required String title,
  required String explainer,
  required String placeholder,
  required String confirmLabel,
  required Future<void> Function(String name) onSubmit,
}) {
  final nav = Navigator.of(context, rootNavigator: true);
  return nav.push<void>(
    anPanelRoute<void>(
      scrim: context.colors.scrim,
      reduced: AnMotionPref.reduced(context),
      barrierLabel: context.t.feedback.dialogBarrier,
      builder: (_) => ChatGitNameDialog(
        title: title,
        explainer: explainer,
        placeholder: placeholder,
        confirmLabel: confirmLabel,
        onSubmit: onSubmit,
      ),
    ),
  );
}

/// Turn a refused residency git action into a sentence that names the NEXT STEP.
///
/// Every branch here answers "what do I do now", because that is the only thing a refusal is for. The
/// backend's own message is already a next step in English, but it is not localizable, so the wire CODE is
/// what we branch on — the one exception is `CONVERSATION_GIT_FAILED`, whose whole point is that git said
/// something we could not have anticipated: that sentence is forwarded verbatim (it names, for instance, the
/// worktree already holding a branch — the most actionable line anybody has).
///
/// 把一次被拒的驻地 git 动作变成一句点出**下一步**的话。
///
/// 此处每一个分支都在回答「那我现在该干什么」，因为那是一次拒绝**唯一**的用途。后端自己的 message 本就是一句英文的
/// 下一步，但它不可本地化，故我们 branch 的是线缆**码**——唯一的例外是 `CONVERSATION_GIT_FAILED`，它的全部意义就是
/// git 说了一句我们无从预料的话:那句话被**逐字**转发（例如它会点出正占着某条分支的那个 worktree——所有人手上最可
/// 行动的一行）。
String gitActionFailure(Translations t, Object error) {
  final g = t.chat.workDir;
  if (error is! ApiException) return g.errFallback;
  return switch (error.code) {
    'CONVERSATION_WORK_DIR_DIRTY' => g.errDirty,
    'CONVERSATION_WORK_DIR_NOT_GIT_REPO' => g.errNotRepo,
    'CONVERSATION_INVALID_BRANCH' => g.errInvalidBranch,
    'CONVERSATION_BRANCH_NOT_FOUND' => g.errBranchMissing,
    'CONVERSATION_BRANCH_EXISTS' => g.errBranchExists,
    'CONVERSATION_INVALID_WORKTREE_NAME' => g.errWorktreeName,
    'CONVERSATION_WORKTREE_EXISTS' => g.errWorktreeExists,
    'CONVERSATION_GIT_FAILED' => g.errGit(reason: _gitReason(error)),
    _ => g.errFallback,
  };
}

/// git's own stderr, which the backend forwards under `details.git`. Falling back to the envelope message
/// keeps the sentence non-empty when a future server sends the code without the detail.
///
/// git 自己的 stderr——后端在 `details.git` 下转发它。回落到 envelope 的 message，使将来某个只发码不发 detail 的
/// 服务端也不会留下一句空话。
String _gitReason(ApiException e) {
  final details = e.details;
  if (details is Map && details['git'] is String) {
    final raw = (details['git'] as String).trim();
    if (raw.isNotEmpty) return raw.split('\n').first;
  }
  return e.message;
}
