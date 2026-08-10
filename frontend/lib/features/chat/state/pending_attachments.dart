import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../../../core/contract/attachment.dart';
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
    this.preparation,
    this.preparationBusy = false,
    this.preparationSlow = false,
  });

  final String localId;
  final String filename;
  final int sizeBytes;
  final String? mimeType;
  final String status; // uploading | ready | failed
  final String? attachmentId;
  final List<int>? bytes; // retained for retry 重试留存
  final AttachmentPreparation? preparation;
  final bool preparationBusy;
  final bool preparationSlow;

  bool get isImage => (mimeType ?? '').startsWith('image/');

  PendingAttachment _with({
    String? status,
    String? attachmentId,
    bool dropBytes = false,
    AttachmentPreparation? preparation,
    bool? preparationBusy,
    bool? preparationSlow,
  }) => PendingAttachment(
    localId: localId,
    filename: filename,
    sizeBytes: sizeBytes,
    mimeType: mimeType,
    status: status ?? this.status,
    attachmentId: attachmentId ?? this.attachmentId,
    bytes: dropBytes ? null : bytes,
    preparation: preparation ?? this.preparation,
    preparationBusy: preparationBusy ?? this.preparationBusy,
    preparationSlow: preparationSlow ?? this.preparationSlow,
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
  List<PendingAttachment> build() {
    ref.onDispose(() {
      for (final timer in _preparationPollTimers.values) {
        timer.cancel();
      }
      _preparationPollTimers.clear();
      _preparationPollAttempts.clear();
      _preparationRefreshing.clear();
    });
    return const [];
  }

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
  final Map<String, Timer> _preparationPollTimers = {};
  final Map<String, int> _preparationPollAttempts = {};
  final Set<String> _preparationRefreshing = {};

  static const _preparationFastPollInterval = Duration(milliseconds: 800);
  static const _preparationSlowPollInterval = Duration(seconds: 2);
  static const _preparationFastPollCount = 10;

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
          preparation: meta.preparation,
          dropBytes: !p.isImage,
        ),
      );
      if (_isActivePreparation(meta.preparation)) {
        _startPreparationPoll(localId);
      }
    } catch (_) {
      _patch(localId, (p) => p._with(status: 'failed'));
    } finally {
      _inFlight.remove(localId);
    }
  }

  Future<void> cancelPreparation(String localId) async => _mutatePreparation(
    localId,
    ref.read(chatRepositoryProvider).cancelAttachmentPreparation,
  );

  Future<void> retryPreparation(String localId) async => _mutatePreparation(
    localId,
    ref.read(chatRepositoryProvider).retryAttachmentPreparation,
  );

  Future<void> _mutatePreparation(
    String localId,
    Future<AttachmentPreparation> Function(String attachmentID) action,
  ) async {
    final a = state.where((a) => a.localId == localId).firstOrNull;
    final id = a?.attachmentId;
    if (a == null || id == null || a.preparationBusy) return;
    _patch(
      localId,
      (p) => p._with(preparationBusy: true, preparationSlow: false),
    );
    try {
      final prep = await action(id);
      _patch(
        localId,
        (p) => p._with(preparation: prep, preparationBusy: false),
      );
      if (_isActivePreparation(prep)) {
        _startPreparationPoll(localId);
      } else {
        _stopPreparationPoll(localId);
      }
    } catch (_) {
      _patch(localId, (p) => p._with(preparationBusy: false));
    }
  }

  void _startPreparationPoll(String localId) {
    if (_preparationPollTimers.containsKey(localId) ||
        _preparationRefreshing.contains(localId)) {
      return;
    }
    _preparationPollAttempts[localId] = 0;
    _schedulePreparationPoll(localId);
  }

  // Preparation may legitimately take longer than the first few UI seconds (large images are the
  // real example). Stop only at a server terminal state: poll quickly while the chip is fresh, then
  // back off so a long-running preparation stays truthful without creating a request storm. 媒体准备
  // 可能确实超过最初几秒(大图就是实证)。只有服务端终态才停止:前几秒快轮询,之后降频,既不让长任务
  // 停在假状态,也不制造请求风暴。
  void _schedulePreparationPoll(String localId) {
    if (_preparationPollTimers.containsKey(localId)) return;
    final attempts = _preparationPollAttempts[localId] ?? 0;
    final interval = attempts < _preparationFastPollCount
        ? _preparationFastPollInterval
        : _preparationSlowPollInterval;
    _preparationPollTimers[localId] = Timer(interval, () async {
      _preparationPollTimers.remove(localId);
      final a = state.where((a) => a.localId == localId).firstOrNull;
      final id = a?.attachmentId;
      if (a == null || id == null || !_isActivePreparation(a.preparation)) {
        _stopPreparationPoll(localId);
        return;
      }
      if (!_preparationRefreshing.add(localId)) {
        _schedulePreparationPoll(localId);
        return;
      }
      _preparationPollAttempts[localId] = attempts + 1;
      try {
        final meta = await ref.read(chatRepositoryProvider).getAttachment(id);
        _patch(localId, (p) => p._with(preparation: meta.preparation));
      } catch (_) {
        // A transient read failure must not turn a live server job into a permanent stale chip. The
        // next pass keeps the same honest active state and retries with the current cadence. 一次读取
        // 失败不能把仍在服务端运行的任务变成永久陈旧 chip;下一轮保持诚实活态并按当前节奏重试。
      } finally {
        _preparationRefreshing.remove(localId);
      }
      final current = state.where((a) => a.localId == localId).firstOrNull;
      if (current == null || !_isActivePreparation(current.preparation)) {
        _stopPreparationPoll(localId);
        return;
      }
      if ((_preparationPollAttempts[localId] ?? 0) >=
          _preparationFastPollCount) {
        _patch(localId, (p) => p._with(preparationSlow: true));
      }
      _schedulePreparationPoll(localId);
    });
  }

  void _stopPreparationPoll(String localId) {
    _preparationPollTimers.remove(localId)?.cancel();
    _preparationPollAttempts.remove(localId);
    _preparationRefreshing.remove(localId);
  }

  bool _isActivePreparation(AttachmentPreparation? p) =>
      p != null && (p.status == 'pending' || p.status == 'running');

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
    _stopPreparationPoll(localId);
    state = [
      for (final p in state)
        if (p.localId != localId) p,
    ];
  }

  /// After a successful send — local only (the message references the uploads). 发送成功后清本地。
  void clear() {
    for (final localId in _preparationPollTimers.keys.toList()) {
      _stopPreparationPoll(localId);
    }
    _preparationPollAttempts.clear();
    state = const [];
  }

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
