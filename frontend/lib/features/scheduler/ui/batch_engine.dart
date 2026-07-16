import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/design/tokens.dart';
import '../../../core/ui/ui.dart';
import '../state/scheduler_rail_provider.dart';

/// The Scheduler's shared per-zone selection + sequential-batch machinery (WRK-069 判决② — born in
/// S2b's Overview zones, upstreamed feature-wide for S3's big table): hover swaps a row's status dot
/// for a checkbox; ≥2 selected floats the AnBatchBar; a batch is FRONT-END SEQUENTIAL dispatch with
/// explicit per-row settling (pending spinner → settle → slide out — never fake atomicity); a lost
/// first-wins race (422) earns an honest summary toast. Row keys are zone-defined strings.
///
/// Scheduler 共享的选择+逐发批量机器(判决②——S2b Overview 出生,S3 大表复用故上收 feature 级):
/// hover 换选择框;选中≥2 浮出批量条;批量=前端逐发+显式挂账(绝不装原子);first-wins 输家 422 得
/// 诚实汇总 toast。行键由区定义。
mixin BatchZone<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final Set<String> selected = {};
  final Set<String> pending = {};
  final Set<String> leaving = {};
  String? hoveredKey;
  bool batchBusy = false;

  /// Drop state for rows that left the data (post-refetch reconcile). 数据退场后修剪本地态。
  void pruneTo(Set<String> liveKeys) {
    selected.retainWhere(liveKeys.contains);
    pending.retainWhere(liveKeys.contains);
    leaving.retainWhere(liveKeys.contains);
    if (hoveredKey != null && !liveKeys.contains(hoveredKey)) hoveredKey = null;
  }

  /// Refetch AFTER the slide-out has played (the collapse is the user-visible settle; the refetch
  /// then removes the row from truth). 滑出播完再对账(动画先行,truth 随后收行)。
  Future<void> settleRefetch() async {
    await Future<void>.delayed(AnMotion.mid + const Duration(milliseconds: 60));
    if (!mounted) return;
    await ref.read(schedulerRailProvider.notifier).refresh();
  }

  /// One sequential batch: per-row pending → op → settle (slide out) / count a lost race (422) /
  /// count a failure. Returns (ok, lost, failed). 一次逐发批量,返回三桶计数。
  Future<(int, int, int)> runBatch<R>(
      List<R> items, String Function(R) keyOf, Future<void> Function(R) op) async {
    setState(() => batchBusy = true);
    var ok = 0, lost = 0, failed = 0;
    for (final it in items) {
      final k = keyOf(it);
      if (!mounted) break;
      setState(() => pending.add(k));
      try {
        await op(it);
        ok++;
        if (mounted) setState(() => leaving.add(k));
      } on ApiException catch (e) {
        e.httpStatus == 422 ? lost++ : failed++;
      } catch (_) {
        failed++;
      } finally {
        if (mounted) setState(() => pending.remove(k));
      }
    }
    if (mounted) {
      setState(() {
        batchBusy = false;
        selected.clear();
      });
    }
    return (ok, lost, failed);
  }

  /// The batch summary toast «已批准 2 · 1 条已被别处处理» — parts only for non-zero buckets; the
  /// worst bucket picks the tone. 汇总 toast:非零桶才入句;最坏桶定声调。
  void summaryToast({required String? okPart, required String? lostPart, required String? failedPart}) {
    final parts = [?okPart, ?lostPart, ?failedPart];
    if (parts.isEmpty) return;
    final tone = failedPart != null
        ? AnTone.danger
        : lostPart != null
            ? AnTone.warn
            : AnTone.ok;
    ref.read(overlayProvider.notifier).showToast(parts.join(' · '), tone: tone);
  }
}
