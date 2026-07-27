import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/media/media_ref.dart';
import '../../../core/media/media_cards.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../data/chat_providers.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import '../../../core/ui/an_attachment_card.dart';
import '../../../core/ui/an_audio_attachment_card.dart';
import '../state/attachment_audio_player.dart';
import '../state/attachment_meta.dart';

/// generate_image family body (WRK-082 批B, 代拍 B7): the artifact is a FIRST-CLASS attachment, so
/// this body rides the exact same pipeline the transcript's user attachments use — meta via the
/// kept-alive provider, bytes via the id-keyed image cache, decode capped to the display width.
/// One card family, zero new media primitives (不变量④的第一个工具卡消费者).

/// Widest a generated artifact renders in a tool card — the card family also uses it as the decode
/// cap, so a 4000px image never parks a full-size bitmap for this slot.
/// 生成产物在工具卡里的最宽档——一族卡同时拿它当**解码**上限,故 4000px 的图不会为这个槽停一张全尺寸位图。
const double _maxW = 320;

/// The three generate_* tool-card bodies. Each artifact is a first-class attachment, so each body is
/// a THIN wrapper over [AnMediaRefCard] — the ONE card family, dispatching on the attachment ROW's
/// mime (不变量④).
///
/// This file used to hand-roll image rendering and video rendering itself, while its own comment
/// claimed to be "the family's first tool-card consumer". It was not: it was a second and a third
/// copy. The cost was invisible until video gained inline playback in H5.5 and did not reach the
/// place a user actually looks — the chat tool card still drew a file card, because it had its own
/// branch (WRK-082 H5.5R). A surface that grows its own media branch quietly opts out of every
/// future modality.
///
/// 三个 generate_* 工具卡体。产物都是一等附件,故每个体都只是 [AnMediaRefCard] 的**薄包装**——**一族卡**,
/// 按附件**行的 mime** 分发(不变量④)。
///
/// 本文件过去**自己手搓**了图像渲染与视频渲染,而它自己的注释却写着「一族卡、不变量④的第一个工具卡
/// 消费者」。**它不是**:它是第二份和第三份拷贝。代价一直看不见,直到 H5.5 给视频加了内联播放、而那个
/// 播放**没能到达用户真正会看的地方**——chat 工具卡仍然画着一张文件卡,因为它有自己的分支(H5.5R)。
/// 一个自己长出媒体分支的面,等于静默退出了此后每一个新模态。
Widget generatedImageBody(BuildContext context, ToolCardState state) {
  final r = parseGeneratedImage(state.resultText);
  if (r == null) return const SizedBox.shrink();
  return AnMediaRefCard(
    mediaRef: AnMediaRef(attachmentId: r.attachmentId),
    maxWidth: _maxW,
  );
}

/// generate_speech family body (WRK-082 批C): the artifact is a first-class AUDIO attachment, so
/// the body is the SAME card the transcript uses for a sent voice note, driven by the SAME
/// playback controller. One player, one set of loading/playing states — a second audio widget
/// here would be a second place for "two things playing at once" to become possible.
///
/// generate_speech 族体(批C):产物是一等**音频**附件,故本体就是 transcript 渲一条已发语音用的
/// **同一张卡**、由**同一个**播放控制器驱动。一个播放器、一套加载/播放态——在这里再写一个音频
/// widget,就是给「两个东西同时在响」多开一个可能发生的地方。
Widget generatedSpeechBody(BuildContext context, ToolCardState state) {
  final r = parseGeneratedSpeech(state.resultText);
  if (r == null) return const SizedBox.shrink();
  return _GeneratedSpeechBody(attachmentId: r.attachmentId, mime: r.mime);
}

class _GeneratedSpeechBody extends ConsumerWidget {
  const _GeneratedSpeechBody({required this.attachmentId, this.mime});

  final String attachmentId;
  final String? mime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(attachmentMetaProvider(attachmentId));
    final playback = ref.watch(attachmentAudioPlaybackProvider);
    final c = context.colors;
    // hasError, not the AsyncError class pattern (Riverpod auto-retries — see the image twin).
    if (meta.hasError) {
      return Text(
        attachmentId,
        style: AnText.label.copyWith(color: c.inkFaint),
      );
    }
    return switch (meta) {
      AsyncData(value: final m) => AnAudioAttachmentCard(
        filename: m.filename.isEmpty ? attachmentId : m.filename,
        metaLine: _metaLine(m.sizeBytes),
        busy: playback.isLoading(attachmentId),
        progress: playback.progressFor(attachmentId),
        playing: playback.isPlaying(attachmentId),
        onPlayTap: () => ref
            .read(attachmentAudioPlaybackProvider.notifier)
            .toggleUrl(
              attachmentId,
              loadUrl: () => ref
                  .read(chatRepositoryProvider)
                  .createAttachmentPlaybackLease(attachmentId)
                  .then((lease) => lease.url),
              mimeType: m.mimeType.isEmpty ? mime : m.mimeType,
            ),
      ),
      _ => const AnAudioAttachmentCard(
        filename: '',
        metaLine: '',
        state: AnAttachmentState.resolving,
      ),
    };
  }

  String _metaLine(int sizeBytes) {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// generate_video family body. Inline playback arrives for free through the family — this body does
/// not know a player exists, and did not change when the playback backend was swapped (ADR 0018).
///
/// generate_video 族体。内联播放**经一族卡免费到达**——本体**不知道**有播放器这回事,而在播放底座被
/// 更换时(ADR 0018)它一行都没动。
Widget generatedVideoBody(BuildContext context, ToolCardState state) {
  final r = parseGeneratedVideo(state.resultText);
  if (r == null) return const SizedBox.shrink();
  return AnMediaRefCard(
    mediaRef: AnMediaRef(attachmentId: r.attachmentId),
    maxWidth: _maxW,
  );
}
