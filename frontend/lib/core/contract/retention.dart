import 'package:freezed_annotation/freezed_annotation.dart';

part 'retention.freezed.dart';
part 'retention.g.dart';

/// The run-history retention line — `GET/PATCH /retention` (WRK-069 工单⑬/判决④). Machine-level (the
/// settings.json `retention` section, beside limits/network — no workspace dimension).
///
/// **`0` = keep forever** (the sweeper never runs). The wire value is ALWAYS a concrete number — a
/// fresh install reads back the server-held default, never null — so **the client must never hardcode
/// a default**; the `@Default` below is a fromJson floor only, and the panel hydrates from the wire.
/// PATCH is a PARTIAL MERGE over the current value (so `{}` is a faithful no-op, not «forever») and
/// returns the merged whole — write back what it returns.
///
/// The only validation is physical: a negative day count is 400 `SETTINGS_RETENTION_INVALID`. The
/// 30/90/180/forever value set is a PRODUCT affordance the FRONT END owns — the backend takes 60
/// happily (rejecting it would be 校验剧场, 设计原则 #6), and there is no `/retention/schema`.
///
/// Two consumers, one truth: the settings storage panel edits it, and the scheduler's run table reads
/// it to render its honest tombstone row（«更早的运行已按保留策略(Nd)清理»）—— the tombstone is a
/// PRESENTATION decision, so the backend ships no special field for it (工单⑬ 裁量).
///
/// run 历史保留线(⑬):机器级(settings.json retention 段,与 limits/network 并列,无 workspace 维度)。
/// **0=永久**;线缆恒具体值(全新安装读回服务端自持的默认、绝不 null)→ **客户端永不硬编默认**,下面的
/// @Default 只是 fromJson 地板,面板一律水化自线缆。PATCH=对当前值**部分合并**(故 `{}` 是忠实 no-op、
/// 不是「永久」)、返合并后的全量——拿返回值回写。唯一校验是物理的(负数 400);30/90/180/永久 值集是
/// **前端产品**可供性(后端照收 60,拒它是校验剧场 #6),且无 /retention/schema。两个消费者一份真相:
/// 设置存储面板编辑它,scheduler 大表读它渲保留墓碑行(墓碑是**呈现**决策,后端零特殊字段)。
@freezed
abstract class RetentionConfig with _$RetentionConfig {
  const factory RetentionConfig({@Default(0) int runRetentionDays}) =
      _RetentionConfig;

  factory RetentionConfig.fromJson(Map<String, dynamic> json) =>
      _$RetentionConfigFromJson(json);
}

extension RetentionX on RetentionConfig {
  /// `0` = keep forever — no sweeper, and therefore no tombstone to render. 0=永久:不清理,故无墓碑。
  bool get forever => runRetentionDays <= 0;
}
