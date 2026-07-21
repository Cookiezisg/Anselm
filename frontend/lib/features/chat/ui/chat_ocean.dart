import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/colors.dart';
import '../../../i18n/strings.g.dart';
import '../../../core/ui/ui.dart';
import '../state/chat_drafts.dart';
import '../state/new_conversation.dart';
import '../state/pending_attachments.dart';
import '../state/selected_conversation.dart';
import 'chat_composer.dart';
import 'chat_transcript.dart';

/// The chat CENTER — landing (no selection) or transcript + docked composer (a thread selected via
/// `/chat/:id`). Keyed per conversation so the composer re-inits with the right draft and the transcript
/// pipeline swaps cleanly on selection change.
///
/// chat 中心——无选区=landing;有选区(`/chat/:id`)=transcript + 停靠 composer。按会话 key,切换时 composer
/// 拿对草稿、transcript 管道干净换台。
class ChatOcean extends ConsumerStatefulWidget {
  const ChatOcean({super.key});

  @override
  ConsumerState<ChatOcean> createState() => _ChatOceanState();
}

class _ChatOceanState extends ConsumerState<ChatOcean> {
  bool _dragging = false; // drop-overlay visibility 拖放浮层显隐

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedConversationProvider);
    final id = selected?.id;
    final Widget content;
    if (id == null) {
      content = const _ChatLanding();
    } else {
      content = Column(
        children: [
          Expanded(
            child: ChatTranscriptView(
              conversationId: id,
              key: ValueKey('transcript-$id'),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AnSize.content),
              child: Padding(
                // top = AnGap.block (12): the transcript↔composer boundary was the tightest gap in chat (s4). 转录↔输入边界(原 s4 最紧)。
                padding: const EdgeInsets.fromLTRB(
                  AnInset.pageX,
                  AnGap.block,
                  AnInset.pageX,
                  AnSpace.s16,
                ),
                child: ChatComposer(
                  conversationId: id,
                  key: ValueKey('composer-$id'),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // The whole center is the DROP TARGET (Slack's big-surface convention) — hovering shows a
    // translucent overlay, a drop funnels every file into the pending strip of the CURRENT draft
    // (thread / landing). 整个中心=drop 区(Slack 惯例):悬停显半透明浮层,落下全喂当前草稿的待发条。
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        final key = id ?? ChatDrafts.landingKey;
        final att = ref.read(pendingAttachmentsProvider(key).notifier);
        for (final f in detail.files) {
          att.addPath(f.path, filename: f.name);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (_dragging)
            AnDropVeil(
              icon: AnIcons.attach,
              label: Translations.of(context).chat.dropToAttach,
            ),
        ],
      ),
    );
  }
}

/// The New-chat landing: a STATIC greeting over a centered floating composer (heart ≈ upper-middle,
/// the 2:3 split). ChatGPT/Claude/Gemini all render the greeting static — a typewriter delays the
/// interactive moment and re-plays on every new chat; the streaming metaphor belongs to the reply. So:
/// h2 (24px, ChatGPT's value), primary ink, one gentle fade-and-rise on entry. The FIRST send creates
/// the thread + sends + navigates — the rail row appears via the notifications echo and auto-titles.
///
/// 新对话 landing:**静态**问候 + 居中浮起 composer(心口 ≈ 上中,2:3)。三家皆静态——打字机拖慢可交互时刻、
/// 每次新建重播成噪音,流式隐喻留给回答本身。h2(24,ChatGPT 值)/主墨/一次轻淡入上移。首发建线程+发送+导航。
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
                    child: AnFadeRiseIn(
                      child: Text(
                        t.chat.landingGreeting,
                        style: AnText.h2.copyWith(color: c.ink),
                      ),
                    ),
                  ),
                  const SizedBox(height: AnSpace.s24),
                  ChatComposer(
                    onSubmitNew: (text, mentions, attachmentIds) async {
                      final start = ref.read(startConversationProvider);
                      final id = await start(
                        text,
                        mentions: mentions,
                        attachmentIds: attachmentIds,
                      );
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
