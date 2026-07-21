import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/pending_attachments.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The pending-attachment funnel: bytes upload → ready (id), scripted failure → failed → retry heals,
// removing a ready chip fire-and-forgets the server delete, clear is local-only.
// 待发附件漏斗:上传→ready;脚本失败→failed→重试自愈;移除 ready 顺手删服务端;clear 只清本地。

void main() {
  (ProviderContainer, FixtureChatRepository) setup() {
    final repo = FixtureChatRepository(conversations: [], messages: {});
    final c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return (c, repo);
  }

  test(
    'addBytes uploads and lands ready with the server id (bytes: images keep, others drop)',
    () async {
      final (c, repo) = setup();
      final n = c.read(pendingAttachmentsProvider('k').notifier);
      await n.addBytes([1, 2, 3], filename: 'a.png', mimeType: 'image/png');
      await n.addBytes([4], filename: 'b.pdf', mimeType: 'application/pdf');
      final rows = c.read(pendingAttachmentsProvider('k'));
      expect(rows.every((a) => a.status == 'ready'), isTrue);
      expect(
        rows.first.bytes,
        isNotNull,
      ); // image keeps bytes — the chip thumbnail 图留字节供缩略
      expect(rows.last.bytes, isNull); // non-image drops the dead weight 非图弃字节
      expect(n.readyIds, [repo.uploads[0].id, repo.uploads[1].id]);
    },
  );

  test(
    'a scripted failure lands failed (bytes kept); retry heals to ready',
    () async {
      final (c, repo) = setup();
      repo.failNextUpload = true;
      final n = c.read(pendingAttachmentsProvider('k').notifier);
      await n.addBytes([9], filename: 'b.bin');
      expect(c.read(pendingAttachmentsProvider('k')).single.status, 'failed');

      await n.retry(c.read(pendingAttachmentsProvider('k')).single.localId);
      expect(c.read(pendingAttachmentsProvider('k')).single.status, 'ready');
    },
  );

  test(
    'removing a READY chip deletes server-side; clear is local-only',
    () async {
      final (c, repo) = setup();
      final n = c.read(pendingAttachmentsProvider('k').notifier);
      await n.addBytes([1], filename: 'a.txt');
      await n.addBytes([2], filename: 'b.txt');
      final first = c.read(pendingAttachmentsProvider('k')).first;
      n.remove(first.localId);
      await Future<void>.delayed(Duration.zero);
      expect(repo.deletedAttachments, [first.attachmentId]);
      expect(c.read(pendingAttachmentsProvider('k')), hasLength(1));

      n.clear();
      expect(c.read(pendingAttachmentsProvider('k')), isEmpty);
      expect(
        repo.deletedAttachments,
        hasLength(1),
      ); // clear never deletes server-side 不删服务端
    },
  );

  test('an unreadable path lands an honest failed chip', () async {
    final (c, _) = setup();
    final n = c.read(pendingAttachmentsProvider('k').notifier);
    await n.addPath('/nonexistent/definitely/missing.bin');
    expect(c.read(pendingAttachmentsProvider('k')).single.status, 'failed');
  });
}
