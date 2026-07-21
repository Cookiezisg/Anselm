import 'package:freezed_annotation/freezed_annotation.dart';

import 'values.dart'; // Field

part 'trigger.freezed.dart';
part 'trigger.g.dart';

/// Trigger source kind — the SEALED 4-source closed set (trigger.go:24). `manual` is intentionally
/// absent (running a workflow by hand is the workflow's own ability). `unknown` is the forward-compat
/// fallback should the backend ever widen the set. 4 源封闭集 + unknown 兜底。
@JsonEnum()
enum TriggerSource { cron, webhook, fsnotify, sensor, unknown }

/// The firing lifecycle + disposition closed set — the SEALED status enum (backend `FiringStatuses`,
/// **7 values**, firing.go:93). The backend 422s an out-of-set `?status=` filter
/// (`TRIGGER_FIRING_INVALID_STATUS`, details carrying `allowed`), so the client only ever SENDS the
/// real seven; `unknown` is inbound-only forward-compat.
///
/// `missed` (WRK-069 工单⑨/判决⑥) is the misfire ledger row: a cron tick that came due while the app
/// was stopped/asleep, booked on wake and deliberately NOT caught up — its `createdAt` is the MISSED
/// TICK ITSELF (the backend rewinds it), not the wake moment, so a missed row already sits at its
/// honest place on a timeline; its `flowrunId` is always absent (no run was ever created) and its
/// `activationId` is empty (booking is not an action).
///
/// firing 生命周期+处置封闭集(后端 **7 值**,过滤只发真七种);missed=睡过头的刻度醒来记账不补跑,
/// createdAt 是**错过的刻度本身**(后端回拨过)故天然坐落在时间轴正确位置,flowrunId 恒空(从未建 run)、
/// activationId 为空(记账不是一次动作)。
@JsonEnum()
enum FiringStatus {
  pending,
  claimed,
  started,
  skipped,
  superseded,
  shed,
  missed,
  unknown,
}

/// Trigger entity — a standalone signal source that fires when its source condition is met (cron tick /
/// webhook hit / file change / sensor probe), fanning the signal to every active workflow listening to
/// it. A CONFIG entity: NOT versioned, no sandbox/env, no tags (unlike function/workflow). [config] is a
/// free per-kind settings map; [outputs] declares the fire-payload fields downstream nodes read.
/// [refCount]/[listening]/[lastFiredAt]/[nextFireAt] are READ-DERIVED (not stored) — the number of
/// active workflows referencing it, whether its listener is hot, when it last fired, and (cron only) its
/// next scheduled fire. trigger.go:82。
@freezed
abstract class TriggerEntity with _$TriggerEntity {
  const factory TriggerEntity({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @JsonKey(unknownEnumValue: TriggerSource.unknown)
    @Default(TriggerSource.unknown)
    TriggerSource kind,
    @Default(<String, dynamic>{}) Map<String, dynamic> config,
    @Default(<Field>[]) List<Field> outputs,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int refCount,
    @Default(false) bool listening,
    // The persisted runtime stop-the-bleeding switch (:pause/:resume, scheduler 工单⑦) — paused=true
    // reads with nextFireAt absent and listening=false. 持久化止血开关;暂停时 nextFireAt 缺席。
    @Default(false) bool paused,
    DateTime? lastFiredAt,
    DateTime? nextFireAt,
  }) = _TriggerEntity;
  factory TriggerEntity.fromJson(Map<String, dynamic> json) =>
      _$TriggerEntityFromJson(json);
}

/// Activation — the per-action audit log (触发面): ONE row every time a trigger acts, FIRED OR NOT (a
/// sensor probe that evaluated false still records [returnValue] + why via [error]/[detail]). A non-fired
/// activation produces 0 firings; a fired one produces [firingCount] (its fan-out width). activation.go:16。
@freezed
abstract class Activation with _$Activation {
  const factory Activation({
    required String id,
    @Default('') String triggerId,
    @JsonKey(unknownEnumValue: TriggerSource.unknown)
    @Default(TriggerSource.unknown)
    TriggerSource kind,
    @Default(false) bool fired,
    @Default(<String, dynamic>{}) Map<String, dynamic> returnValue,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
    @Default('') String error,
    @Default('') String detail,
    @Default(0) int firingCount,
    required DateTime createdAt,
  }) = _Activation;
  factory Activation.fromJson(Map<String, dynamic> json) =>
      _$ActivationFromJson(json);
}

/// Firing — the durable inbox row (运行面, persist-before-act): written the moment a trigger fires, one
/// per listening workflow, before any flowrun starts. [status] is the sealed lifecycle + disposition
/// (why a fire did / didn't run: skipped/superseded/shed); [flowrunId] is set once a run is created.
/// firing.go:18。
@freezed
abstract class Firing with _$Firing {
  const factory Firing({
    required String id,
    @Default('') String triggerId,
    @Default('') String workflowId,
    @Default('') String activationId,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
    @Default('') String dedupKey,
    @JsonKey(unknownEnumValue: FiringStatus.unknown)
    @Default(FiringStatus.unknown)
    FiringStatus status,
    @Default('') String flowrunId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Firing;
  factory Firing.fromJson(Map<String, dynamic> json) => _$FiringFromJson(json);
}
