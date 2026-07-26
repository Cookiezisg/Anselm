import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/attachment.dart';
import '../net/api_client.dart';
import '../runtime.dart';

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
final mediaMetaProvider = FutureProvider.autoDispose
    .family<AttachmentMeta, String>((ref, id) async {
      final m = await ref.watch(mediaSourceProvider).meta(id);
      ref.keepAlive();
      return m;
    });
