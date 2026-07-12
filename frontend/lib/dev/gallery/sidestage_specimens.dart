import 'package:flutter/widgets.dart';

import '../../core/contract/touchpoint.dart';
import '../../core/design/tokens.dart';
import '../../core/perf/pulse_clock.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// W1 sidestage primitives (WRK-061 §9) — the Cast row across freshness/verbs/tombstone/raw-id, the
// channel strip, the follow/gate pills, the honesty ribbon. Stage choreography itself is a live
// behaviour (director-driven) — verified in the real shell, not poseable here.
// W1 侧幕原语——演员表行(新鲜度/多动词/墓碑/裸 id)、频道条、跟随/人闸药丸、诚实丝带。编排是活行为
// (导演器驱动),在真壳验证、不摆拍。

DateTime _ago(Duration d) => DateTime.now().subtract(d);

const _demoCode = '''import json

@retry(times=3, backoff=[1, 2, 4])
def sync_inventory():
    rows = fetch_all("inventory")
    for row in rows:
        normalize(row)
    return {"count": len(rows), "ok": True}

def normalize(row):
    row["sku"] = row["sku"].strip().upper()
    row["qty"] = max(0, int(row["qty"]))
''';

final List<GallerySpecimen> sidestageSpecimens = [
  GallerySpecimen(
      'Tooltip 提示条 — 500ms 悬停现,岛面+发丝边+meta 档(企业级克制,无箭头)',
      (_) => Row(mainAxisSize: MainAxisSize.min, children: [
            AnTooltip(
                message: '跳到发生处',
                child: AnButton.iconOnly(AnIcons.locate, semanticLabel: '跳到发生处', onPressed: () {})),
            const SizedBox(width: 8),
            AnTooltip(
                message: '自动登台 · 每次都跟',
                child: AnButton.iconOnly(AnIcons.eye, semanticLabel: '自动登台', onPressed: () {})),
          ])),
  GallerySpecimen(
      'AnCodeEditor.live 活代码脸(族二:同壳同高亮同行号,贴底跟随)',
      (_) => const AnCodeEditor(
          code: '$_demoCode    row["price"] = rou',
          lang: 'python', reading: true, live: true, maxHeight: AnSize.codeViewportSm),
      span: true),
  GallerySpecimen(
      'AnCodeEditor.live 长码贴尾(有界视口钉底)',
      (_) => AnCodeEditor(
          code: List.generate(60, (i) => 'line_${i + 1} = compute(${i + 1})').join('\n'),
          lang: 'python', reading: true, live: true, maxHeight: AnSize.codeViewport),
      span: true,
      stress: true),
  GallerySpecimen(
      'MinimapSpine 书脊三态 — 新墨/快进前缀+分叉/近完成前沿',
      (_) => SizedBox(
            height: 160,
            child: Row(children: [
              const AnMinimapSpine(totalUnits: 1000, inkedUnits: 300, paragraphOffsets: [200, 500, 800]),
              const SizedBox(width: 24),
              const AnMinimapSpine(totalUnits: 1000, inkedUnits: 620, prefixUnits: 400, paragraphOffsets: [200, 500, 800]),
              const SizedBox(width: 24),
              const AnMinimapSpine(totalUnits: 1000, inkedUnits: 930, prefixUnits: 150, paragraphOffsets: [200, 500, 800]),
            ]),
          ),
      span: true),
  GallerySpecimen(
      'CelGrow 判别式 — 点路径引用凝 accent 药囊',
      (_) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnCelGrow(expression: 'input.total > 100 && payload.sku != ""'),
            SizedBox(height: 8),
            AnCelGrow(expression: 'normalize.result + input.cap * 2'),
            SizedBox(height: 8),
            AnCelGrow(expression: 'has(payload.retry) ? payload.retry.count : 0', compact: true),
          ]),
      span: true),
  GallerySpecimen(
      'RadarSweep 诚实等待环(共享钟扫描;reduced 静态)',
      (_) => Row(children: [
            AnRadarSweep(size: 16, clock: PulseClock()),
            const SizedBox(width: 16),
            AnRadarSweep(size: 24, clock: PulseClock()),
          ]),
      span: true),
  GallerySpecimen(
      'LayerDiff 旧真相地层 — 「改之前的它」低墨垫底',
      (_) => const AnLayerDiff(oldText: _demoCode, versionLabel: 'v3 · 改之前', maxLines: 6),
      span: true),
  GallerySpecimen(
      'CastRow 新鲜四档(光晕→沉灰)',
      (_) => Column(children: [
            AnCastRow(kind: 'function', name: 'sync_inventory', verb: TouchpointVerb.created, lastAt: _ago(const Duration(seconds: 30))),
            AnCastRow(kind: 'document', name: '季度复盘', verb: TouchpointVerb.edited, count: 3, lastAt: _ago(const Duration(minutes: 20))),
            AnCastRow(kind: 'workflow', name: 'nightly_rollup', verb: TouchpointVerb.executed, lastAt: _ago(const Duration(hours: 5))),
            AnCastRow(kind: 'agent', name: 'auditor', verb: TouchpointVerb.viewed, lastAt: _ago(const Duration(days: 3))),
          ]),
      span: true),
  GallerySpecimen(
      'CastRow 多动词 + 主角脉冲 + 墓碑 + 裸 id',
      (_) => Column(children: [
            AnCastRow(
                kind: 'function',
                name: 'quarterly_rollup',
                verb: TouchpointVerb.edited,
                secondaryVerbs: const [TouchpointVerb.executed, TouchpointVerb.created],
                pulsing: true,
                lastAt: _ago(const Duration(minutes: 1))),
            AnCastRow(kind: 'trigger', name: 'daily_9am', verb: TouchpointVerb.deleted, tombstoned: true, lastAt: _ago(const Duration(hours: 2))),
            AnCastRow(kind: 'memory', name: 'mem_a1b2c3d4e5f6a7b8', nameIsRawId: true, verb: TouchpointVerb.created, lastAt: _ago(const Duration(minutes: 9))),
          ]),
      span: true),
  GallerySpecimen(
      'CastRow 超长名截断',
      (_) => AnCastRow(
          kind: 'document',
          name: '一份标题长得离谱到必须被省略号温柔拦截的季度财务复盘与预算重排会议纪要档案',
          verb: TouchpointVerb.edited,
          count: 12,
          secondaryVerbs: const [TouchpointVerb.viewed],
          lastAt: _ago(const Duration(minutes: 2))),
      span: true,
      stress: true,
      maxWidth: 280),
  GallerySpecimen(
      'ChannelStrip 并行频道(选中/未读/失败/溢出)',
      (_) => AnChannelStrip(
            channels: const [
              AnChannel(id: 'a', kind: 'function', live: true, unread: 3),
              AnChannel(id: 'b', kind: 'workflow', live: true),
              AnChannel(id: 'c', kind: 'subagent', live: false, failed: true, unread: 120),
              AnChannel(id: 'd', kind: 'document', live: false),
              AnChannel(id: 'e', kind: 'mcp', live: true),
              AnChannel(id: 'f', kind: 'agent', live: true),
            ],
            activeId: 'a',
            onTap: (_) {},
          ),
      span: true),
  GallerySpecimen(
      'FollowPill 跟随药丸(live) — poke 后共享钟呼吸',
      (_) => Row(children: [
            AnFollowPill(
                kind: AnFollowPillKind.live,
                subjectName: 'sync_inventory',
                clock: PulseClock(),
                onTap: () {}),
          ]),
      span: true),
  GallerySpecimen(
      'FollowPill 人闸琥珀 — 突破一切静默',
      (_) => Row(children: [
            AnFollowPill(kind: AnFollowPillKind.gate, clock: PulseClock(), onTap: () {}),
            const SizedBox(height: AnSpace.s8),
            // jump 静态回场脸(批5:收编 viewport/transcript 两处手搓) static jump-back face
            AnFollowPill.jump(label: '回到最新', onTap: () {}),
            const SizedBox(height: AnSpace.s8),
            AnFollowPill.jump(label: '回到现场', elevated: true, onTap: () {}),
          ]),
      span: true),
  GallerySpecimen(
      'HonestyRibbon 三触发(live/缺口/失败)',
      (_) => const Column(children: [
            AnHonestyRibbon(AnHonesty.live),
            SizedBox(height: 4),
            AnHonestyRibbon(AnHonesty.gap),
            SizedBox(height: 4),
            AnHonestyRibbon(AnHonesty.failed),
          ]),
      span: true),
];
