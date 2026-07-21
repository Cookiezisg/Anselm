import 'package:flutter/widgets.dart';

import '../../../../../core/contract/entities/trigger.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_format.dart';
import '../detail_sections.dart';

/// Trigger 概览(支撑 kind,非可执行四大,UNVERSIONED):说明 + KV → 配置(每源一个可复制的 headline spec
/// [cron 表达式 / webhook URL / fsnotify 路径 / sensor 条件]+ 统一 KV 明细,4 源共一套视觉模板)→ 运行时
/// (listening / 监听者数 / 最近·下次触发)→ Fire 载荷(下游可读的声明字段)。运行时观测=活动/派发两 tab。
/// 朴素 KV 文档,零 bespoke。
class TriggerOverview extends StatelessWidget {
  const TriggerOverview({required this.trigger, super.key});

  final TriggerEntity trigger;

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        identitySection(d.kv.desc, trigger.description, [
          (d.kv.id, trigger.id),
          (d.trigger.source, trigger.kind.name),
          (d.kv.updated, fmtTime(trigger.updatedAt)),
        ]),
        _config(context),
        AnSection(
          label: d.sec.listener,
          variant: AnSectionVariant.plain,
          children: [
            // State words are CONTENT (15, like every sibling status value); counts/timestamps
            // are metadata (13) — split lists, one visual stack. 状态词=内容 15(与他类 status 一致);
            // 计数/时间戳=元数据 13——分两列表、视觉同栈。
            kvList([
              (d.trigger.listening, trigger.listening ? d.val.yes : d.val.no),
            ]),
            kvList([
              (d.trigger.refCount, '${trigger.refCount}'),
              (
                d.trigger.lastFired,
                trigger.lastFiredAt == null
                    ? d.val.never
                    : fmtTime(trigger.lastFiredAt),
              ),
              // Next scheduled fire only makes sense for cron. 下次触发仅 cron 有意义。
              if (trigger.kind == TriggerSource.cron)
                (
                  d.trigger.nextFire,
                  trigger.nextFireAt == null
                      ? '—'
                      : fmtTime(trigger.nextFireAt),
                ),
            ], meta: true),
          ],
        ),
        AnSection(
          label: d.sec.firePayload,
          variant: AnSectionVariant.plain,
          children: [fieldList(trigger.outputs, emptyTitle: d.val.none)],
        ),
      ],
    );
  }

  // The config section — ONE uniform shape across all 4 source kinds: a copyable headline spec (the
  // kind's primary technical string) + a KV list of its secondary settings. 4 源共一套:headline + KV。
  Widget _config(BuildContext context) {
    final d = context.t.entities.detail;
    final cfgMap = trigger.config;
    String cfg(String k) => cfgMap[k]?.toString() ?? '';
    String? opt(String k) => cfg(k).isEmpty ? null : cfg(k);
    // sensor cadence is stored as intervalSec (int seconds, config.go:47) — format it back with the unit.
    // sensor 探测间隔后端存 intervalSec(int 秒),补上单位显示。
    String? intervalStr() =>
        cfgMap['intervalSec'] == null ? null : '${cfgMap['intervalSec']}s';
    // sensor probes `<targetKind> <targetId>.<method>` (config.go:44-46). 探测目标 = 种类 + id。
    String? sensorTarget() {
      final s = '${cfg('targetKind')} ${cfg('targetId')}'.trim();
      return s.isEmpty ? null : s;
    }

    // events is a free author-supplied list — guard the cast (a non-list author error must not crash). is List 守卫。
    String? eventList() {
      final e = cfgMap['events'];
      return e is List && e.isNotEmpty
          ? e.map((x) => x.toString()).join(', ')
          : null;
    }

    final (
      String code,
      String lang,
      List<(String, String?)> rows,
    ) = switch (trigger.kind) {
      // cron config is just the expression — the backend reads nothing else (config.go:56). cron 只读 expression。
      TriggerSource.cron => (
        cfg('expression'),
        'cron',
        const <(String, String?)>[],
      ),
      // The mounted path an external caller POSTs to (copy it to configure the caller). 外部调用方 POST 的挂载路径。
      TriggerSource.webhook => (
        '/api/v1/webhooks/${trigger.id}/${cfg('path')}',
        'url',
        [
          (d.trigger.signatureAlgo, opt('signatureAlgo')),
          (d.trigger.signatureHeader, opt('signatureHeader')),
        ],
      ),
      TriggerSource.fsnotify => (
        cfg('path'),
        'path',
        [(d.trigger.events, eventList()), (d.trigger.pattern, opt('pattern'))],
      ),
      TriggerSource.sensor => (
        cfg('condition'),
        'cel',
        [
          (d.trigger.target, sensorTarget()),
          (d.kv.method, opt('method')),
          (d.trigger.interval, intervalStr()),
        ],
      ),
      // Forward-compat: an unknown kind falls back to a raw config KV dump. 未知源:原始 config 兜底铺 KV。
      TriggerSource.unknown => (
        '',
        '',
        [for (final e in cfgMap.entries) (e.key, e.value?.toString())],
      ),
    };
    final hasRows = rows.any((r) => (r.$2 ?? '').isNotEmpty);
    return AnSection(
      label: d.sec.config,
      variant: AnSectionVariant.plain,
      children: [
        if (code.isNotEmpty)
          AnCodeEditor(code: code, lang: lang, wrap: true, reading: true),
        if (code.isNotEmpty && hasRows) const SizedBox(height: AnSpace.s8),
        if (hasRows) kvList(rows),
      ],
    );
  }
}
