import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/model_capability.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/conversation_header.dart';
import '../state/selected_conversation.dart';
import '../state/title_reveals.dart';

/// The chat ocean's floating-head content. On a THREAD: the title (in-place renameable — the same PATCH
/// as the rail's ⋯ rename) then the per-thread MODEL picker nudged right by it. On the LANDING: the
/// model picker alone sits at the far left — the choice is sticky ([landingModelProvider]) and the first
/// send stamps it onto the new thread, so the picker never disappears between the two states. Auto-title
/// lands here LIVE via the header controller's lifecycle re-read.
///
/// chat 海洋浮层头。线程态:标题(就地改名,同 rail PATCH)+ 被标题挤到右侧一点的线程级**模型选择器**。
/// landing 态:模型选择器独占最左——选择粘性(landingModelProvider),首发盖章到新线程,两态之间选择器
/// 不消失。自动命名经头部控制器的生命周期重读**活着**落进来。
class ChatHead extends ConsumerWidget {
  const ChatHead({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedConversationProvider);
    final t = Translations.of(context);
    final caps = ref.watch(modelCapabilitiesProvider).value ?? const [];

    // Landing: the sticky next-thread choice, far left. landing:粘性选择,最左。
    if (selected == null) {
      final choice = ref.watch(landingModelProvider);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modelMenu(
            t: t,
            caps: caps,
            current: choice,
            onSelect: (v) => ref.read(landingModelProvider.notifier).set(v),
          ),
        ],
      );
    }

    final id = selected.id;
    final header = ref.watch(conversationHeaderProvider(id));
    final conv = header.value;
    if (conv == null) return const SizedBox.shrink();

    // A FRESH auto-title lands as a one-shot typewriter (the rail row plays the same title in sync);
    // done → back to the renameable title. 新自动命名以一次性打字机落地(rail 行同播);完→可改名标题。
    final revealing =
        ref.watch(titleRevealsProvider).contains(id) && conv.title.trim().isNotEmpty;

    final override = conv.modelOverride;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title — in-place rename, hugging its content (AnInlineEdit is min-sized under a loose host)
        // so the model button sits right after it; Flexible still caps runaway titles.
        // 标题:就地改名,收紧到内容宽(AnInlineEdit loose 下 min),模型钮贴题;Flexible 仍封超长。
        // The title is the content area's identity — the 15/w400 content rung (readingH3), not the
        // 13 chrome body; the reveal typewriter MUST ride the same style or the finish flashes 13→15.
        // 标题=内容区身份:15/w400 内容档(readingH3),非 13 chrome;打字机揭示必须同式,否则收尾闪号。
        Flexible(
          child: revealing
              ? SizedBox(
                  height: AnSize.control, // the AnInlineEdit footprint — swap never jumps 同定高,切换不跳
                  // widthFactor pins the box to the typed width (Align would fill the loose slot and
                  // shove the model button to the far edge) — the button rides the typing instead.
                  // widthFactor 收紧到已打出的宽(Align 会撑满 loose 槽把模型钮顶到最右)——钮随打字右移。
                  child: Center(
                    widthFactor: 1,
                    child: AnTypewriter(
                      [conv.title],
                      loop: false,
                      textStyle: AnText.readingH3.copyWith(color: context.colors.ink),
                      onDone: () => ref.read(titleRevealsProvider.notifier).remove(id),
                    ),
                  ),
                )
              : AnInlineEdit(
                  key: ValueKey('chat-head-title-$id'),
                  value: conv.title.isEmpty ? t.chat.kNew : conv.title,
                  style: AnText.readingH3,
                  affordanceSize: AnButtonSize.md,
                  onCommit: (v) => ref.read(conversationHeaderProvider(id).notifier).rename(v),
                ),
        ),
        const SizedBox(width: AnSpace.s8),
        _modelMenu(
          t: t,
          caps: caps,
          current: override == null ? null : (apiKeyId: override.apiKeyId, modelId: override.modelId),
          onSelect: (v) => ref.read(conversationHeaderProvider(id).notifier).setModel(v),
        ),
        // Quiet hint while the reply streams — mirrors the rail's blue dot for the OPEN thread. 打开线程的蓝点镜像。
        if (conv.isGenerating) ...[
          const SizedBox(width: AnSpace.s6),
          const AnStatusDot(AnStatus.run),
        ],
      ],
    );
  }

  /// The one model menu both states share: Auto (clear) + one entry per capability. 两态共用的模型菜单。
  Widget _modelMenu({
    required Translations t,
    required List<ModelCapability> caps,
    required ({String apiKeyId, String modelId})? current,
    required ValueChanged<({String apiKeyId, String modelId})?> onSelect,
  }) {
    // The anchor lives at the head's LEFT (landing: far left; thread: right after the title), so the
    // menu opens DOWN-RIGHT (start-aligned — AnMenu defaults to end); the popover flips on overflow.
    // The anchor shows the capability's DISPLAY NAME (same label the menu row shows — a picked
    // 'DeepSeek Chat' must not echo back as 'deepseek-chat'), falling back to the raw id for an
    // override whose capability is gone. md tier: the 13 label rung beside the 15 title (sm's meta
    // 12 sat a rung too low and a 24 box mis-centred in the 44 head band).
    // 锚在头部左区,菜单**右下**展开(start 对齐)、越界自翻。锚显 displayName(与菜单行同名——选了
    // 「DeepSeek Chat」不能回显 raw id;能力已失才回落 id)。md 档:15 标题旁的 13 标签档。
    final anchorLabel = current == null
        ? t.chat.modelAuto
        : caps
                .where((cap) => cap.modelId == current.modelId && cap.apiKeyId == current.apiKeyId)
                .map((cap) => cap.displayName.isEmpty ? cap.modelId : cap.displayName)
                .firstOrNull ??
            current.modelId;
    return AnMenu(
      alignEnd: false,
      anchorBuilder: (context, toggle, isOpen) => AnButton(
        label: anchorLabel,
        onPressed: toggle,
      ),
      entries: [
        AnMenuItem(
          label: t.chat.modelAuto,
          checked: current == null,
          onTap: () => onSelect(null),
        ),
        for (final cap in caps)
          AnMenuItem(
            label: cap.displayName.isEmpty ? cap.modelId : cap.displayName,
            meta: cap.keyName.isEmpty ? cap.provider : cap.keyName,
            checked: current?.modelId == cap.modelId && current?.apiKeyId == cap.apiKeyId,
            onTap: () => onSelect((apiKeyId: cap.apiKeyId, modelId: cap.modelId)),
          ),
      ],
    );
  }
}
