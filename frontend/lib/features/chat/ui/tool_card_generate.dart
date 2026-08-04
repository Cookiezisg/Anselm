import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/media/media_ref.dart';
import '../../../core/media/media_cards.dart';

import '../data/chat_providers.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import '../model/user_attachment.dart';
import '../../../i18n/strings.g.dart';
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
    mediaRef: AnMediaRef(
      attachmentId: r.attachmentId,
      mime: r.mime,
      filename: r.filename,
      width: r.width,
      height: r.height,
      sizeBytes: r.sizeBytes,
      source: r.source,
    ),
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
  return _GeneratedSpeechBody(
    attachmentId: r.attachmentId,
    mime: r.mime,
    filenameHint: r.filename,
    sizeBytesHint: r.sizeBytes,
    durationMsHint: r.durationMs,
  );
}

class _GeneratedSpeechBody extends ConsumerWidget {
  const _GeneratedSpeechBody({
    required this.attachmentId,
    this.mime,
    this.filenameHint,
    this.sizeBytesHint,
    this.durationMsHint,
  });

  final String attachmentId;
  final String? mime;
  final String? filenameHint;
  final int? sizeBytesHint;
  final int? durationMsHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(attachmentMetaProvider(attachmentId));
    final playback = ref.watch(attachmentAudioPlaybackProvider);
    final t = Translations.of(context);
    final hintedFilename = filenameHint?.trim() ?? '';
    final hintedMeta = attachmentMetaLine(
      filename: hintedFilename,
      mimeType: mime,
      sizeBytes: sizeBytesHint,
    );
    final hintedDuration = _durationLabel(durationMsHint);

    // The receipt is enough to paint a stable first frame. The attachment row remains authoritative
    // after it arrives; while it is in flight we keep the audio geometry instead of swapping in a
    // shorter generic file skeleton and moving the transcript.
    // 收据足以画出稳定首帧；附件行到达后覆盖它。在途期间保持音频几何，不换成更矮的通用文件骨架把 transcript 顶动。
    if (meta.hasError) {
      return AnAudioAttachmentCard(
        filename: hintedFilename,
        metaLine: hintedMeta,
        state: AnAttachmentState.failed,
        durationLabel: hintedDuration,
        onTap: () => ref.invalidate(attachmentMetaProvider(attachmentId)),
      );
    }
    return switch (meta) {
      AsyncData(value: final m) => AnAudioAttachmentCard(
        filename: m.filename.isEmpty ? hintedFilename : m.filename,
        metaLine: attachmentMetaLine(
          filename: m.filename.isEmpty ? hintedFilename : m.filename,
          mimeType: m.mimeType.isEmpty ? mime : m.mimeType,
          sizeBytes: m.sizeBytes > 0 ? m.sizeBytes : sizeBytesHint,
        ),
        durationLabel: _durationLabel(
          playback.durationFor(attachmentId)?.inMilliseconds ?? durationMsHint,
        ),
        busy: playback.isLoading(attachmentId),
        progress: playback.progressFor(attachmentId),
        playing: playback.isPlaying(attachmentId),
        statusLine: _playbackStatusLine(t, playback.errorFor(attachmentId)),
        state:
            playback.errorFor(attachmentId) ==
                AttachmentAudioError.attachmentMissing
            ? AnAttachmentState.missing
            : AnAttachmentState.ready,
        onPlayTap:
            playback.errorFor(attachmentId) ==
                AttachmentAudioError.attachmentMissing
            ? null
            : () => ref
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
      _ => AnAudioAttachmentCard(
        filename: hintedFilename,
        metaLine: hintedMeta,
        durationLabel: hintedDuration,
        busy: true,
        statusLine: t.attach.loadingAudio,
      ),
    };
  }

  String? _durationLabel(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return null;
    return audioDurationLabel(durationMs);
  }

  String? _playbackStatusLine(Translations t, String? error) => switch (error) {
    AttachmentAudioError.playbackFailed => t.attach.audioPlaybackFailed,
    AttachmentAudioError.attachmentOffline => t.attach.audioPlaybackOffline,
    _ => null,
  };
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
