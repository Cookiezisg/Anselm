import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/conversation_header.dart';
import '../state/selected_conversation.dart';

/// The chat ocean's floating-head content: the thread title (in-place renameable — the same PATCH as the
/// rail's ⋯ rename) and the per-thread MODEL picker (a menu over `GET /model-capabilities`; "Auto" =
/// clear the override, the workspace's dialogue default runs). Auto-title lands here LIVE via the header
/// controller's lifecycle re-read. Nothing renders on the landing (no selection).
///
/// chat 海洋浮层头:线程标题(就地改名,同 rail 的 PATCH)+ 线程级**模型选择器**(菜单吃 model-capabilities;
/// 「Auto」=清覆写、走 workspace 对话默认)。自动命名经头部控制器的生命周期重读**活着**落进来。landing 无选区不渲。
class ChatHead extends ConsumerWidget {
  const ChatHead({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedConversationProvider);
    if (selected == null) return const SizedBox.shrink();
    final id = selected.id;
    final t = Translations.of(context);
    final header = ref.watch(conversationHeaderProvider(id));
    final conv = header.value;
    if (conv == null) return const SizedBox.shrink();

    final overrideId = conv.modelOverride?.modelId ?? '';
    final modelLabel = overrideId.isEmpty ? t.chat.modelAuto : overrideId;
    final caps = ref.watch(modelCapabilitiesProvider).value ?? const [];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title — in-place rename, sized to the compact head band. 标题:就地改名,紧凑头带尺寸。
        Flexible(
          child: AnInlineEdit(
            key: ValueKey('chat-head-title-$id'),
            value: conv.title.isEmpty ? t.chat.kNew : conv.title,
            onCommit: (v) => ref.read(conversationHeaderProvider(id).notifier).rename(v),
          ),
        ),
        const SizedBox(width: AnSpace.s8),
        AnMenu(
          alignEnd: true,
          anchorBuilder: (context, toggle, isOpen) => AnButton(
            label: modelLabel,
            size: AnButtonSize.sm,
            onPressed: toggle,
          ),
          entries: [
            AnMenuItem(
              label: t.chat.modelAuto,
              checked: overrideId.isEmpty,
              onTap: () => ref.read(conversationHeaderProvider(id).notifier).setModel(null),
            ),
            for (final cap in caps)
              AnMenuItem(
                label: cap.displayName.isEmpty ? cap.modelId : cap.displayName,
                meta: cap.keyName.isEmpty ? cap.provider : cap.keyName,
                checked: overrideId == cap.modelId && conv.modelOverride?.apiKeyId == cap.apiKeyId,
                onTap: () => ref
                    .read(conversationHeaderProvider(id).notifier)
                    .setModel((apiKeyId: cap.apiKeyId, modelId: cap.modelId)),
              ),
          ],
        ),
        // Quiet hint while the reply streams — mirrors the rail's blue dot for the OPEN thread. 打开线程的蓝点镜像。
        if (conv.isGenerating) ...[
          const SizedBox(width: AnSpace.s6),
          const AnStatusDot(AnStatus.run),
        ],
      ],
    );
  }
}
