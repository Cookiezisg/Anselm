import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/colors.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/new_conversation.dart';
import '../state/selected_conversation.dart';
import 'chat_composer.dart';
import 'chat_transcript.dart';

/// The chat CENTER — landing (no selection) or transcript + docked composer (a thread selected via
/// `/chat/:id`). Keyed per conversation so the composer re-inits with the right draft and the transcript
/// pipeline swaps cleanly on selection change.
///
/// chat 中心——无选区=landing;有选区(`/chat/:id`)=transcript + 停靠 composer。按会话 key,切换时 composer
/// 拿对草稿、transcript 管道干净换台。
class ChatOcean extends ConsumerWidget {
  const ChatOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedConversationProvider);
    if (selected == null) return const _ChatLanding();
    final id = selected.id;
    return Column(
      children: [
        Expanded(child: ChatTranscriptView(conversationId: id, key: ValueKey('transcript-$id'))),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AnSize.content),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AnSpace.s24, AnSpace.s4, AnSpace.s24, AnSpace.s16),
              child: ChatComposer(conversationId: id, key: ValueKey('composer-$id')),
            ),
          ),
        ),
      ],
    );
  }
}

/// The New-chat landing: a typewriter greeting over a centered floating composer (heart ≈ upper-middle,
/// the 2:3 split). The FIRST send creates the thread + sends + navigates — the rail row appears via the
/// notifications echo and auto-titles in place.
///
/// 新对话 landing:打字机问候 + 居中浮起 composer(心口 ≈ 上中,2:3)。首发建线程+发送+导航——rail 行经
/// notifications 回声出现并原位自动命名。
class _ChatLanding extends ConsumerWidget {
  const _ChatLanding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    return Column(
      children: [
        const Spacer(flex: 2),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AnSize.content),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AnSpace.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: DefaultTextStyle(
                      style: AnText.h3.copyWith(color: c.ink),
                      child: AnTypewriter([t.chat.landingGreeting], loop: false),
                    ),
                  ),
                  const SizedBox(height: AnSpace.s24),
                  ChatComposer(
                    onSubmitNew: (text) async {
                      final start = ref.read(startConversationProvider);
                      final id = await start(text);
                      if (context.mounted) context.go(conversationLocation(id));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}
