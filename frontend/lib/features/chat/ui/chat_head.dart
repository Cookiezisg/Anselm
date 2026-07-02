import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/model_capability.dart';
import '../../../core/design/tokens.dart';
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
                      onDone: () => ref.read(titleRevealsProvider.notifier).remove(id),
                    ),
                  ),
                )
              : AnInlineEdit(
                  key: ValueKey('chat-head-title-$id'),
                  value: conv.title.isEmpty ? t.chat.kNew : conv.title,
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
    // menu opens rightward; the popover flips if it would overflow. 锚在头部左区,菜单向右展开,越界自翻。
    return AnMenu(
      anchorBuilder: (context, toggle, isOpen) => AnButton(
        label: current?.modelId ?? t.chat.modelAuto,
        size: AnButtonSize.sm,
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
