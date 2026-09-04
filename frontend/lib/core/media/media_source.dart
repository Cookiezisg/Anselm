import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/attachment.dart';
import 'package:dio/dio.dart';
import '../net/api_client.dart';
import '../runtime.dart';

/// The backend accepts one read-aloud utterance up to this many Unicode runes. Keep the
/// presentation gate aligned with the API so an impossible speaker action is never offered.
///
/// 后端单次朗读最多接受这么多个 Unicode rune。展示闸与 API 共用同一个事实，避免给出必然失败的喇叭动作。
const readAloudMaxRunes = 4000;

/// The shared seam every surface reads media through (WRK-082 批B'). Attachments are a PLATFORM
/// resource, not chat's: a flowrun node result, a debug-console result and an approval payload all
/// carry the same MediaRef and must resolve it without importing another feature (features 互不依赖).
/// Chat keeps its own richer repository; this port is the narrow slice the card family needs.
///
/// 各面读媒体的共享缝(批B')。附件是**平台**资源、不是 chat 的:flowrun 节点结果、调试台结果、
/// approval payload 携带同一种 MediaRef,且必须在不 import 另一个 feature 的前提下解析它
/// (features 互不依赖)。chat 保留自己更厚的仓储;本端口只是卡族需要的那一薄片。
abstract class MediaSource {
  /// One attachment's row (`GET /attachments/{id}`) — the truth about a ref.
  ///
  /// 一条附件行——引用的真相。
  Future<AttachmentMeta> meta(String id);

  /// Raw bytes (`GET /attachments/{id}/content`, non-envelope) — what image cards decode.
  ///
  /// 原始字节(非 envelope)——图卡解码的来源。
  Future<List<int>> bytes(String id);

  /// Where a NATIVE player should fetch this attachment from, plus the headers it must send.
  /// Video does not go through [bytes]: libmpv streams it itself (WRK-082 H5.5).
  ///
  /// 原生播放器该从哪里取这份附件,以及它必须送的头。视频**不走** [bytes]:libmpv 自己流式拉(H5.5)。
  NativeFetchTarget nativeTarget(String id);

  /// Lands bytes as a first-class attachment and returns its row. This is the WRITE half of the
  /// platform media seam: the document editor needs to insert a picture, and it must not reach into
  /// chat's repository to do it (features 互不依赖). The seam exists exactly so every surface that
  /// touches media talks to one port.
  ///
  /// 把字节落成一等附件并返回它的行。这是平台媒体缝的**写**那一半:文档编辑器要插一张图,而它**不能**
  /// 为此伸进 chat 的 repository(features 互不依赖)。这层缝的存在,正是为了让每个碰媒体的面都对同一个
  /// 端口说话。
  Future<AttachmentMeta> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  });

  /// Whether read-aloud can run at all (`GET /read-aloud/availability`). Honest absence: with no
  /// speech-capable key the affordance must not exist, rather than exist and always fail.
  ///
  /// 朗读是否根本可用。诚实缺席:没有能说话的 key 时,入口就**不该存在**,而不是存在且必失败。
  Future<bool> readAloudAvailable();

  /// Synthesize [text] and return the resulting attachment (`POST /read-aloud:read`). Zero-token:
  /// no LLM is involved. A repeat of the same text+voice is served from the backend cache.
  ///
  /// 合成 [text] 并返回产物附件。零 token:没有 LLM 参与。同文本同音色重复请求由后端缓存供给。
  Future<ReadAloudResult> readAloud(String text, {String? voice});
}

/// One read-aloud outcome. [cached] is the money fact — the UI renders identically either way, but
/// a test can prove a second listen never reached a provider.
///
/// 一次朗读的结果。[cached] 是**钱**的事实——两种情形 UI 渲得一样,但测试可以据它证明第二次听
/// 根本没走到 provider。
class ReadAloudResult {
  const ReadAloudResult({
    required this.attachmentId,
    required this.mimeType,
    this.cached = false,
  });

  factory ReadAloudResult.fromJson(Map<String, dynamic> json) =>
      ReadAloudResult(
        attachmentId: json['attachmentId'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
        cached: json['cached'] as bool? ?? false,
      );

  final String attachmentId;
  final String mimeType;
  final bool cached;
}

/// Live implementation over the platform API client.
///
/// 接平台 API client 的实现。
class ApiMediaSource implements MediaSource {
  const ApiMediaSource(this._api);

  final ApiClient _api;

  @override
  Future<AttachmentMeta> meta(String id) =>
      _api.getEntity('/api/v1/attachments/$id', AttachmentMeta.fromJson);

  @override
  Future<List<int>> bytes(String id) =>
      _api.getBytes('/api/v1/attachments/$id/content');

  @override
  NativeFetchTarget nativeTarget(String id) =>
      _api.nativeFetchTarget('/api/v1/attachments/$id/content');

  @override
  Future<AttachmentMeta> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) => _api.postEntity(
    '/api/v1/attachments',
    AttachmentMeta.fromJson,
    body: FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: mimeType.isEmpty ? null : DioMediaType.parse(mimeType),
      ),
    }),
  );

  @override
  Future<bool> readAloudAvailable() async {
    final data = await _api.getEntity<Map<String, dynamic>>(
      '/api/v1/read-aloud/availability',
      (json) => json,
    );
    return data['available'] as bool? ?? false;
  }

  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) =>
      _api.postEntity(
        '/api/v1/read-aloud:read',
        ReadAloudResult.fromJson,
        body: {
          'text': text,
          if (voice != null && voice.isNotEmpty) 'voice': voice,
        },
      );
}

/// The seam. Demo / gallery / tests override THIS one provider (same discipline as every feature
/// repository provider).
///
/// 缝。demo / gallery / 测试 override 这唯一 provider(与各 feature 仓储 provider 同纪律)。
final mediaSourceProvider = Provider<MediaSource>(
  (ref) => ApiMediaSource(ref.watch(apiClientProvider)),
);

/// One attachment's metadata by id. SUCCESS-ONLY keepAlive: attachment rows are immutable so a
/// resolved row never goes stale, but caching a FAILURE would freeze one timeout into a permanent
/// tombstone with no retry path (the lesson chat's twin already paid for).
///
/// 按 id 取附件元数据。**成功才** keepAlive:附件行不可变,解析结果永不过期;而缓存**失败**会把一次
/// 超时焊成永久墓碑、再无重试路径(chat 的孪生件已经付过这笔学费)。
/// Whether the read-aloud affordance should exist. keepAlive: the answer changes only when a key
/// is added or removed, and a per-turn refetch would put one request behind every hovered row.
///
/// 朗读入口该不该存在。keepAlive:这个答案只在增删 key 时变,而逐回合重取会在每一个 hover 过的行
/// 背后各挂一个请求。
final readAloudAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    final ok = await ref.watch(mediaSourceProvider).readAloudAvailable();
    ref.keepAlive();
    return ok;
  } catch (_) {
    // A failed probe answers "no button", not an error state. Letting the failure through would
    // arm Riverpod's auto-retry and put a backoff loop behind an affordance whose whole job is to
    // be absent when it cannot work — an offline sidecar would spend the session retrying a
    // question whose honest answer is already "not now".
    // 探测失败的答案是「没有按钮」,不是错误态。让失败透出去会上膛 Riverpod 的自动重试,在一个
    // 「不能用就该缺席」的入口背后挂一条退避循环——sidecar 离线时,整场会话都在重问一个诚实答案
    // 早已是「现在不行」的问题。
    return false;
  }
});

final mediaMetaProvider = FutureProvider.autoDispose
    .family<AttachmentMeta, String>((ref, id) async {
      final m = await ref.watch(mediaSourceProvider).meta(id);
      ref.keepAlive();
      return m;
    });
