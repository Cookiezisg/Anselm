import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/media/attachment_image_provider.dart';
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
///
/// generate_image 族体(批B,代拍 B7):产物是一等附件,本体走 transcript 用户附件的同一条管线——
/// 元数据经 keepAlive provider、字节经按 id 缓存的图源、解码封顶显示宽。一族卡、零新媒体原语
/// (不变量④的第一个工具卡消费者)。
Widget generatedImageBody(BuildContext context, ToolCardState state) {
  final r = parseGeneratedImage(state.resultText);
  if (r == null) return const SizedBox.shrink();
  return _GeneratedImageBody(receipt: r);
}

class _GeneratedImageBody extends ConsumerWidget {
  const _GeneratedImageBody({required this.receipt});

  final ({
    String attachmentId,
    String? mime,
    int? width,
    int? height,
    String? provider,
    String? model,
  })
  receipt;

  /// The widest the artifact renders inside a card body — a deliberate step above the transcript
  /// thumb (the generated image IS the deliverable), still decode-capped to what the slot shows.
  /// 卡体内产物最宽档——刻意高于 transcript 缩略档(生成图就是交付物),解码仍封顶槽位所需。
  static const double _maxW = 360;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = receipt.attachmentId;
    final meta = ref.watch(attachmentMetaProvider(id));
    final c = context.colors;
    // hasError, not the AsyncError class pattern: Riverpod 3 auto-retries a failed provider, and
    // during each retry window the state is AsyncLoading again — the class pattern would flicker
    // the honest line back into a skeleton forever. hasError stays true across retries.
    // 用 hasError 而非 AsyncError 类模式:Riverpod 3 对失败 provider 自动重试,重试窗内状态又是
    // AsyncLoading——类模式会让诚实行永远闪回骨架。hasError 跨重试恒真。
    if (meta.hasError) {
      // The attachment row is the truth; a missing row is said out loud, never a broken image.
      // 附件行是真相;行缺失明说,绝不渲一张破图。
      return Text(id, style: AnText.label.copyWith(color: c.inkFaint));
    }
    return switch (meta) {
      AsyncData(value: final m) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AnRadius.button),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxW),
              child: Image(
                image: AttachmentImageProvider(
                  id,
                  fetch: () =>
                      ref.read(chatRepositoryProvider).getAttachmentBytes(id),
                  targetWidth: (_maxW * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                ),
                fit: BoxFit.contain,
                // While bytes stream in, hold layout with the receipt's real aspect so the card
                // never jumps when pixels arrive (dims ride the receipt precisely for this).
                // 字节到达前按 receipt 真实比例占位,像素落地卡不跳(receipt 带尺寸正为此)。
                frameBuilder: (context, child, frame, wasSync) {
                  if (frame != null || wasSync) return child;
                  final w = receipt.width, h = receipt.height;
                  final ratio = (w != null && h != null && w > 0 && h > 0)
                      ? w / h
                      : 1.0;
                  return AspectRatio(
                    aspectRatio: ratio,
                    child: ColoredBox(color: c.surfaceSubtle),
                  );
                },
                errorBuilder: (context, _, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
                  child: Text(
                    m.filename,
                    style: AnText.label.copyWith(color: c.inkMuted),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AnSpace.s4),
          Text(
            _metaLine(m.filename),
            style: AnText.label.copyWith(color: c.inkMuted),
          ),
        ],
      ),
      _ => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxW),
        child: AspectRatio(
          aspectRatio: 1,
          child: ColoredBox(color: c.surfaceSubtle),
        ),
      ),
    };
  }

  String _metaLine(String filename) {
    final parts = <String>[filename];
    final w = receipt.width, h = receipt.height;
    if (w != null && h != null && w > 0 && h > 0) parts.add('$w×$h');
    final model = receipt.model;
    if (model != null && model.isNotEmpty) parts.add(model);
    return parts.join(' · ');
  }
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

/// generate_video family body (WRK-082 批D). The artifact renders as the kit's FILE CARD, not an
/// inline player: adding one would mean adopting a desktop video stack (`media_kit` /
/// `video_player` and their native dependencies), which is a dependency decision of its own and
/// does not belong to this batch (代拍 D1). The card still says what the file is, how big it is,
/// and can be opened outside the app — honest about what exists rather than pretending to play it.
///
/// generate_video 族体(批D)。产物渲成 kit 的**文件卡**、不是内联播放器:加播放器意味着引入桌面
/// 视频栈(`media_kit`/`video_player` 及其原生依赖),那是一次独立的依赖决策、不属于本批(代拍 D1)。
/// 卡仍然说清它是什么文件、多大、可在应用外打开——对**存在的东西**诚实,而不是假装能播它。
Widget generatedVideoBody(BuildContext context, ToolCardState state) {
  final r = parseGeneratedVideo(state.resultText);
  if (r == null) return const SizedBox.shrink();
  return _GeneratedVideoBody(attachmentId: r.attachmentId, seconds: r.seconds);
}

class _GeneratedVideoBody extends ConsumerWidget {
  const _GeneratedVideoBody({required this.attachmentId, this.seconds});

  final String attachmentId;
  final int? seconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(attachmentMetaProvider(attachmentId));
    final c = context.colors;
    if (meta.hasError) {
      return Text(
        attachmentId,
        style: AnText.label.copyWith(color: c.inkFaint),
      );
    }
    return switch (meta) {
      AsyncData(value: final m) => AnAttachmentCard(
        kind: m.kind.isEmpty ? 'video' : m.kind,
        filename: m.filename.isEmpty ? attachmentId : m.filename,
        metaLine: _metaLine(m.sizeBytes),
      ),
      _ => const AnAttachmentCard(
        kind: 'video',
        filename: '',
        metaLine: '',
        state: AnAttachmentState.resolving,
      ),
    };
  }

  String _metaLine(int sizeBytes) {
    final parts = <String>[];
    if (seconds != null && seconds! > 0) parts.add('${seconds}s');
    if (sizeBytes > 0) {
      parts.add(
        sizeBytes < 1024 * 1024
            ? '${(sizeBytes / 1024).toStringAsFixed(0)} KB'
            : '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      );
    }
    return parts.join(' · ');
  }
}
