import 'package:flutter/widgets.dart';

import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// AnBatchBar (WRK-069 判决② S2b) — the multi-select batch-operation bar («已选 N · [动作…] ✕») that
// floats in above a list at ≥2 selected, plus its companion AnBatchCheck (the hover row-selection
// checkbox). Batch semantics live with the caller (front-end sequential dispatch + explicit per-row
// settling); busy freezes the bar mid-batch. AnBatchBar 批量操作条 + 配套 AnBatchCheck 行选择框。

Widget _checks() => Row(mainAxisSize: MainAxisSize.min, children: [
      AnBatchCheck(checked: false, semanticLabel: 'row A', onChanged: (_) {}),
      const SizedBox(width: AnSpace.s8),
      AnBatchCheck(checked: true, semanticLabel: 'row B', onChanged: (_) {}),
    ]);

final anBatchBarGalleryItem = GalleryItem(
  'AnBatchBar 批量操作条',
  '多选浮出「已选 N · [动作…] ✕」;配套 AnBatchCheck 行首 hover 选择框;批量=调用方逐发+显式挂账,busy 冻结批中之条',
  [
    GallerySpecimen(
        '两动作(批准 primary / 拒绝 danger)',
        (c) => AnBatchBar(count: 3, actions: [
              BatchAction(label: '批量批准', icon: AnIcons.check, tone: AnTone.accent, onRun: () {}),
              BatchAction(label: '批量拒绝', tone: AnTone.danger, onRun: () {}),
            ], onClear: () {}),
        span: true),
    GallerySpecimen(
        '单 danger 动作(批量取消)',
        (c) => AnBatchBar(count: 2, actions: [
              BatchAction(label: '批量取消', icon: AnIcons.stop, tone: AnTone.danger, onRun: () {}),
            ], onClear: () {}),
        span: true),
    GallerySpecimen(
        'busy(批量在途,全钮冻结)',
        (c) => AnBatchBar(count: 5, busy: true, actions: [
              BatchAction(label: '批量批准', tone: AnTone.accent, onRun: () {}),
              BatchAction(label: '批量拒绝', tone: AnTone.danger, onRun: () {}),
            ], onClear: () {}),
        span: true),
    GallerySpecimen('AnBatchCheck 选择框(未选/已选)', (c) => _checks()),
    GallerySpecimen(
        'count=0 渲空(无选无条)',
        (c) => Row(children: [
              Text('count: 0 →', style: AnText.meta.copyWith(color: c.colors.inkFaint)),
              AnBatchBar(count: 0, actions: const [], onClear: () {}), // renders nothing 渲空
              Text('(空)', style: AnText.meta.copyWith(color: c.colors.inkFaint)),
            ]),
        stress: true),
    GallerySpecimen(
        '压力:海量计数 + 超长动作标签(窄宿主内裁切不溢)',
        (c) => AnBatchBar(count: 99999, actions: [
              BatchAction(
                  label: '把选中的全部重新排队并等待下一个调度窗口再统一执行这个非常长的动作标签',
                  tone: AnTone.none,
                  onRun: () {}),
              BatchAction(label: '批量拒绝', tone: AnTone.danger, onRun: () {}),
            ], onClear: () {}),
        stress: true,
        maxWidth: 360),
  ],
);
