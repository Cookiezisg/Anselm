import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../data/chat_providers.dart';

/// One attachment waiting in the composer: local identity + upload lifecycle. [status] is a tiny closed
/// set — uploading (spinner chip) / ready (id in hand) / failed. A failed UPLOAD keeps its bytes and is
/// retryable; a failed INTAKE (unreadable path — bytes null) is not, and the chip renders it
/// remove-only. composer 里的待发附件:本地身份+上传生命周期。uploading(转圈)/ready(拿到 id)/failed——
/// 上传失败留字节可重试;入口不可读(无字节)不可重试,chip 只给移除。
class PendingAttachment {
  const PendingAttachment({
    required this.localId,
    required this.filename,
    required this.sizeBytes,
    this.mimeType,
    this.status = 'uploading',
    this.attachmentId,
    this.bytes,
  });

  final String localId;
  final String filename;
  final int sizeBytes;
  final String? mimeType;
  final String status; // uploading | ready | failed
  final String? attachmentId;
  final List<int>? bytes; // retained for retry 重试留存

  bool get isImage => (mimeType ?? '').startsWith('image/');

  PendingAttachment _with({
    String? status,
    String? attachmentId,
    bool dropBytes = false,
  }) => PendingAttachment(
    localId: localId,
    filename: filename,
    sizeBytes: sizeBytes,
    mimeType: mimeType,
    status: status ?? this.status,
    attachmentId: attachmentId ?? this.attachmentId,
    bytes: dropBytes ? null : bytes,
  );
}

/// The composer's pending-attachment strip, keyed by draft key (thread id / the landing) — the SAME
/// lifetime as the text draft, so switching away and back keeps both. All three intakes (📎 picker,
/// paste, drop) funnel through [addBytes]/[addPath]; each uploads immediately (`POST /attachments`)
/// and the chip tracks it. Removing a READY chip fire-and-forgets the server delete (the backend has
/// no GC — dangling uploads would pile up forever). [readyIds] is what a send takes; [clear] after a
/// successful send drops local state only (the message now references the uploads).
///
/// composer 待发附件条,按草稿键(线程 id / landing)——与文字草稿同寿命。三入口(📎/粘贴/拖放)全经
/// addBytes/addPath 汇入;立即上传、chip 跟踪。移除 **ready** chip 时顺手删服务端(后端无 GC,悬挂会
/// 永久堆积)。发送取 readyIds;成功后 clear 只清本地(消息已引用上传物)。
class PendingAttachments extends Notifier<List<PendingAttachment>> {
  PendingAttachments(this.draftKey);

  final String draftKey;
  int _seq = 0;

  @override
  List<PendingAttachment> build() => const [];

  bool get hasUploading => state.any((a) => a.status == 'uploading');
  int get failedCount => state.where((a) => a.status == 'failed').length;
  List<String> get readyIds => [
    for (final a in state)
      if (a.status == 'ready' && a.attachmentId != null) a.attachmentId!,
  ];

  Future<void> addBytes(
    List<int> bytes, {
    required String filename,
    String? mimeType,
  }) async {
    final localId = 'pa_${_seq++}';
    final mime = mimeType ?? lookupMimeType(filename);
    state = [
      ...state,
      PendingAttachment(
        localId: localId,
        filename: filename,
        sizeBytes: bytes.length,
        mimeType: mime,
        bytes: bytes,
      ),
    ];
    await _upload(localId);
  }

  /// A picked/dropped/pasted FILE path — read + funnel into [addBytes]. An unreadable path (sandbox
  /// denies a pasted-but-never-granted file) surfaces as a FAILED chip, honest + removable.
  /// 文件路径入口——读完汇入 addBytes;读不动(沙箱未授权的粘贴路径)落诚实 failed chip、可移除。
  Future<void> addPath(String path, {String? filename}) async {
    final name = filename ?? path.split(Platform.pathSeparator).last;
    final List<int> bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      state = [
        ...state,
        PendingAttachment(
          localId: 'pa_${_seq++}',
          filename: name,
          sizeBytes: 0,
          mimeType: lookupMimeType(name),
          status: 'failed',
        ),
      ];
      return;
    }
    await addBytes(
      bytes,
      filename: name,
      mimeType: lookupMimeType(name, headerBytes: bytes.take(64).toList()),
    );
  }

  Future<void> retry(String localId) => _upload(localId);

  /// In-flight guard — a double retry-tap must not run two concurrent uploads for one chip (the
  /// second result would overwrite the first attachmentId and orphan it server-side, the exact
  /// leak class the late-completion delete guards against). 在途守卫:连点重试不得并发双上传(后到
  /// 结果覆盖先到 id=服务端孤儿,与迟到完成守卫同一泄漏类)。
  final Set<String> _inFlight = {};

  Future<void> _upload(String localId) async {
    if (_inFlight.contains(localId)) return;
    final a = state.where((a) => a.localId == localId).firstOrNull;
    final bytes = a?.bytes;
    if (a == null || bytes == null) return;
    _inFlight.add(localId);
    _patch(localId, (p) => p._with(status: 'uploading'));
    try {
      final meta = await ref
          .read(chatRepositoryProvider)
          .uploadAttachment(
            bytes: bytes,
            filename: a.filename,
            mimeType: a.mimeType,
          );
      // The chip may have been REMOVED while the upload was in flight — nobody would ever hold the
      // fresh id, so delete it server-side right away (the backend has no GC; a silent drop is a
      // permanent orphan). 上传期间 chip 可能已被移除——新 id 无人持有,立刻反手删掉(后端无 GC,
      // 静默丢弃=永久孤儿)。
      if (!state.any((p) => p.localId == localId)) {
        ref.read(chatRepositoryProvider).deleteAttachment(meta.id).ignore();
        return;
      }
      // Bytes drop on ready EXCEPT for images — the chip's thumbnail renders straight from memory
      // (a few MB per pending image, bounded by the strip). 非图 ready 即弃字节;图留作 chip 缩略图。
      _patch(
        localId,
        (p) => p._with(
          status: 'ready',
          attachmentId: meta.id,
          dropBytes: !p.isImage,
        ),
      );
    } catch (_) {
      _patch(localId, (p) => p._with(status: 'failed'));
    } finally {
      _inFlight.remove(localId);
    }
  }

  void remove(String localId) {
    final a = state.where((a) => a.localId == localId).firstOrNull;
    if (a == null) return;
    if (a.status == 'ready' && a.attachmentId != null) {
      // Fire-and-forget hygiene — a failed delete just leaves a dangling row, never blocks the UI.
      // 顺手卫生——删失败只留悬挂行,绝不挡 UI。
      ref
          .read(chatRepositoryProvider)
          .deleteAttachment(a.attachmentId!)
          .ignore();
    }
    state = [
      for (final p in state)
        if (p.localId != localId) p,
    ];
  }

  /// After a successful send — local only (the message references the uploads). 发送成功后清本地。
  void clear() => state = const [];

  void _patch(String localId, PendingAttachment Function(PendingAttachment) f) {
    state = [for (final p in state) p.localId == localId ? f(p) : p];
  }
}

final pendingAttachmentsProvider =
    NotifierProvider.family<
      PendingAttachments,
      List<PendingAttachment>,
      String
    >(PendingAttachments.new);
