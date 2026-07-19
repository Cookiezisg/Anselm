import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/attachment.dart';
import '../data/chat_providers.dart';

/// One attachment's metadata by id — how the bubble turns the id-only `attrs.attachments` snapshot
/// into filename/kind/size. KEPT ALIVE: attachment rows are immutable, so a resolved meta never goes
/// stale and re-fetching per scroll would be waste. 按 id 的附件元数据——泡把纯 id 快照解析成名/类/大小。
/// keepAlive:附件行不可变,解析结果永不过期、逐滚重取是浪费。
final attachmentMetaProvider = FutureProvider.family<AttachmentMeta, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).getAttachment(id),
);
