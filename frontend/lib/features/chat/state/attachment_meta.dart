import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/attachment.dart';
import '../data/chat_providers.dart';

/// One attachment's metadata by id — how the bubble turns the id-only `attrs.attachments` snapshot
/// into filename/kind/size. SUCCESS-ONLY keepAlive (G10/A3-39): attachment rows are immutable, so a
/// resolved meta never goes stale — but the old blanket keepAlive cached the first FAILURE for the
/// whole session (one timeout → «已删除» forever, no retry path). 成功才 keepAlive:解析结果不可变、
/// 缓存合理;旧全量 keepAlive 把首个失败也焊死一整会话(一次超时→永远「已删除」)。
final attachmentMetaProvider = FutureProvider.autoDispose
    .family<AttachmentMeta, String>((ref, id) async {
      final m = await ref.watch(chatRepositoryProvider).getAttachment(id);
      ref.keepAlive();
      return m;
    });
