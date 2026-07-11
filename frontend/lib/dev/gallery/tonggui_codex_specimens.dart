import 'package:flutter/widgets.dart';

import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

// WRK-066「同轨」法典六族当家件 — the codex draft's REAL frames for the per-family 拍板 (convergence-codex.md).
// Each item shows one family head with its hot-pluggable variants; call-site migration is P4.
// 「同轨」六族当家件真帧(供逐族拍板);调用点迁移归 P4。

const _esc = '\x1B';
final _term = '$_esc[32m✓$_esc[0m compiled 42 modules\n'
    '$_esc[33m⚠$_esc[0m 2 warnings\n'
    'linking…\n[=========>     ] 63%';
const _code = 'def sync_inventory():\n    for attempt in range(3):\n        try:\n'
    '            return _pull_and_merge()\n        except SyncError:\n            time.sleep(2 ** attempt)';
const _prose = '归因先行:issue_date 未做时区归一,跨年边界上 Q4 与次年 Q1 混桶。'
    '修法是先归一到本位时区,再按季度聚合;顺手把展示层的季度徽标改读聚合结果。';

final tongguiCodexCategory = GalleryCategory('同轨法典(草案)', AnIcons.entities, [
  GalleryItem(
    '族一 · AnWindow 窗',
    '唯一容器,两张脸:sunken(灰凹面=机器原料)/card(白底描边=成品排版);header/actions 槽 + AnSize 档钳高 + 可折叠。',
    [
      GallerySpecimen('sunken · header(命令回显)+ copy 动作', (c) => AnWindow(
            header: Text('\$ npm test', style: AnText.code.copyWith(color: c.colors.ink)),
            actions: [AnChip('copy', icon: AnIcons.copy, copyValue: 'npm test')],
            child: Text(_term.replaceAll(RegExp('\\x1B\\[[0-9;]*m'), ''),
                style: AnText.code.copyWith(color: c.colors.inkMuted)),
          ), span: true),
      GallerySpecimen('card · 成品排版(标题头 + prose)', (c) => AnWindow(
            look: AnWindowLook.card,
            header: Text('审批信笺 · 预览'),
            child: Text(_prose, style: AnText.reading.copyWith(color: c.colors.inkMuted)),
          ), span: true),
      GallerySpecimen('sunken · 钳高+折叠(超高 FadeCollapse)', (c) => AnWindow(
            maxHeight: AnSize.proseClamp,
            collapsible: true,
            child: Text(List.filled(18, _prose).join('\n\n'),
                style: AnText.reading.copyWith(color: c.colors.inkMuted)),
          ), span: true),
    ],
  ),
  GalleryItem(
    '族二 · 代码 live 形态(换脸不换壳)',
    'AnCodeEditor.live:同框同栏同 copy 位,流入期纯 mono 尾无行号;AnVersionDiff.live:两幕手术(−old→+new)同 diff 壳。',
    [
      GallerySpecimen('AnCodeEditor 落定脸(高亮+行号)', (c) => AnCodeEditor(code: _code, lang: 'python', reading: true), span: true),
      GallerySpecimen('AnCodeEditor live 脸(同壳,mono 尾 4 行)', (c) => AnCodeEditor(code: _code, lang: 'python', live: true, tailLines: 4), span: true),
      GallerySpecimen('AnVersionDiff live 两幕(−切什么 → +换什么)', (c) => const AnVersionDiff(
            live: true,
            before: 'return _pull_and_merge()',
            after: 'for attempt in range(3):\n    try:\n        return _pull_and_merge()',
          ), span: true),
      GallerySpecimen('AnVersionDiff 落定脸(unified)', (c) => const AnVersionDiff(
            before: 'return _pull_and_merge()',
            after: 'for attempt in range(3):\n    return _pull_and_merge()',
            lang: 'python',
          ), span: true),
    ],
  ),
  GalleryItem(
    '族三 · AnChip 芯片',
    '唯一小标签单元,两形(filled 软底/outlined 细边)× 热插拔(icon/mono/copy ✓闪/nav/划线);truncate 三档清 15+ 手搓三元式。',
    [
      GallerySpecimen('filled 五声调', (c) => Wrap(spacing: AnSpace.s6, runSpacing: AnSpace.s4, children: const [
            AnChip('metadata'),
            AnChip('running', tone: AnTone.accent),
            AnChip('ready', tone: AnTone.ok),
            AnChip('pre-authorized', tone: AnTone.warn),
            AnChip('crashed', tone: AnTone.danger),
          ])),
      GallerySpecimen('outlined(腰带/花名册形)+ 划线删除态', (c) => Wrap(spacing: AnSpace.s6, runSpacing: AnSpace.s4, children: [
            AnChip('pull_invoices', look: AnChipLook.outlined, icon: AnIcons.function, mono: true),
            AnChip('amount_gate', look: AnChipLook.outlined, icon: AnIcons.control, mono: true, tone: AnTone.warn),
            AnChip('legacy_sync', look: AnChipLook.outlined, mono: true, tone: AnTone.danger, strikethrough: true),
          ])),
      GallerySpecimen('copy(点击✓闪)+ mono id + truncate 档', (c) => Wrap(spacing: AnSpace.s6, runSpacing: AnSpace.s4, children: [
            AnChip('fr_demo_8f3a92', mono: true, copyValue: 'fr_demo_8f3a92c41b77e5d2', icon: AnIcons.copy),
            AnChip(truncate('exec_0123456789abcdef0123456789abcdef', AnTrunc.id), mono: true),
            AnChip(truncate('这个标题实在太长必须按 word 档截断展示才不至于撑破', AnTrunc.word)),
          ])),
    ],
  ),
  GalleryItem(
    '族四 · 行(AnKv / AnFieldSection / AnLedgerRow)',
    '仅两种标签排布(AnKv 键值对 · AnFieldSection 标签在上)+ 唯一台账/命中行(lead 一律居左);第三种排布=违反文法 #2。',
    [
      GallerySpecimen('AnKv(键值对,既有)', (c) => const AnKv(dense: true, rows: [
            AnKvRow('id', 'fn_8f3a92', mono: true),
            AnKvRow('版本', 'v4'),
            AnKvRow('环境', 'ready'),
          ])),
      GallerySpecimen('AnFieldSection(标签在上,吃 IO 段/意图行)', (c) => AnFieldSection(
            label: '输出',
            child: AnWindow(child: Text('{"ok": true, "rows": 128}', style: AnText.code.copyWith(color: c.colors.inkMuted))),
          )),
      GallerySpecimen('AnLedgerRow ×3(状态点一律居左)', (c) => Column(children: [
            AnLedgerRow(lead: const AnStatusDot(AnStatus.done), primary: 'exec_01H8…f2', chips: const [AnChip('42ms', tone: AnTone.none)], meta: '2 分钟前'),
            AnLedgerRow(lead: const AnStatusDot(AnStatus.err), primary: 'exec_01H8…e9', chips: const [AnChip('SyncError', tone: AnTone.danger)], meta: '5 分钟前'),
            AnLedgerRow(lead: const AnStatusDot(AnStatus.wait), primary: 'node.approval_gate', meta: '等待审批'),
          ]), span: true),
    ],
  ),
  GalleryItem(
    '族五 · AnStatBar 条',
    '唯一结果/状态条(吃四条手搓):状态词徽(色=AnStatus.tone 单源)+ 点分链 + 尾随芯片凭据 + 下挂注记。',
    [
      GallerySpecimen('成功:词徽+链+凭据 pill', (c) => AnStatBar(
            status: AnStatus.done,
            stats: const [AnStat('v4', tabular: true), AnStat('env ready', tone: AnTone.ok), AnStat('1.2s', tabular: true)],
            chips: [AnChip('sync_inventory', mono: true, icon: AnIcons.function, look: AnChipLook.outlined)],
          ), span: true),
      GallerySpecimen('失败+红注记行', (c) => const AnStatBar(
            status: AnStatus.err,
            stats: [AnStat('3 步', tabular: true), AnStat('↑1840 ↓620', tabular: true)],
            note: 'ModuleNotFoundError: no module named requests',
          ), span: true),
      GallerySpecimen('域词覆盖(timeout 声调仍单源)', (c) => const AnStatBar(
            status: AnStatus.err, statusLabel: '超时',
            stats: [AnStat('60s 上限', tabular: true)],
          ), span: true),
    ],
  ),
  GalleryItem(
    '族六 · AnLiveTail 活尾',
    '唯一滚动活尾,三张脸:term(ANSI+原地折叠+顶缘渐隐)/mono(纯等宽)/prose(阅读排版贴底钳);空白守卫内建。代码流不住这(归族二)。',
    [
      GallerySpecimen('term(ANSI 色+折叠)', (c) => AnLiveTail(_term, tailLines: 4), span: true),
      GallerySpecimen('mono(便笺逐笔)', (c) => const AnLiveTail('先拉最近十条失败记录\n按错误码分桶\n再对时间轴找共因', style: AnLiveTailStyle.mono), span: true),
      GallerySpecimen('prose(蒸馏流,贴底钳高)', (c) => AnLiveTail(List.filled(6, _prose).join(' '), style: AnLiveTailStyle.prose), span: true),
      GallerySpecimen('空白守卫(纯 \\n 渲空,右侧应无窗)', (c) => Row(children: [
            Text('AnLiveTail("\\n") →', style: AnText.meta.copyWith(color: c.colors.inkFaint)),
            const AnLiveTail('\n'), // renders nothing — the built-in empty-shell guard 内建空壳守卫
            Text('(空)', style: AnText.meta.copyWith(color: c.colors.inkFaint)),
          ]), stress: true),
    ],
  ),
]);
