import 'package:flutter/widgets.dart';

import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../i18n/strings.g.dart';
import 'scheduler_home_model.dart';

/// The ONE run phrase grammar (需求⑤/⑦ 0717-晚): a run is spoken as «source word · start instant»
/// everywhere — table rows, matrix column tooltips, the flagship's big title — never as a bare id.
/// The source word joins the trigger where it has more to say (webhook path / fsnotify·sensor
/// trigger name); cron's old per-row HH:mm detail is folded into the unified time suffix.
/// 唯一 run 短语文法:一次 run 处处念作「来源词 · 开始时刻」——大表行/矩阵列 tooltip/旗舰大标题,绝不
/// 念裸 id。来源词在 trigger 有话说时并入(webhook path / fsnotify·sensor 名);cron 旧 HH:mm 摘要并入
/// 统一时刻后缀。
String runBasePhrase(BuildContext context, RunSource source) {
  final t = context.t.scheduler.home;
  return switch (source.origin) {
    'manual' => t.srcManual,
    'chat' => t.srcChat,
    'cron' => t.srcCronBare,
    'webhook' =>
      source.detail != null
          ? t.srcWithName(kind: t.srcWebhookBare, name: source.detail!)
          : t.srcWebhookBare,
    'fsnotify' =>
      source.detail != null
          ? t.srcWithName(kind: t.originFsnotify, name: source.detail!)
          : t.originFsnotify,
    'sensor' =>
      source.detail != null
          ? t.srcWithName(kind: t.originSensor, name: source.detail!)
          : t.originSensor,
    _ => t.srcUnknown,
  };
}

/// Base phrase + start instant («cron · 19:14»). No start stamp → the base alone (a pre-provenance
/// row must not invent a time). 短语+时刻;无开始戳只念词(旧行绝不编时刻)。
String runPhrase(
  BuildContext context,
  Flowrun run,
  Map<String, TriggerEntity> triggersById,
  DateTime now,
) {
  final base = runBasePhrase(context, runSourceOf(run, triggersById));
  final at = run.startedAt;
  return at == null ? base : '$base · ${fmtDayTime(at, now)}';
}
