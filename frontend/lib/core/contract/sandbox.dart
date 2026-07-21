import 'package:freezed_annotation/freezed_annotation.dart';

part 'sandbox.freezed.dart';
part 'sandbox.g.dart';

/// Sandbox wire contracts (references/backend/domains, S5-⑦). Runtimes are machine-wide (no
/// workspace); envs are per-owner (function|handler|mcp|skill|conversation). Bootstrap health gates
/// the panel; the disk figure + GC keep it tidy.
///
/// 沙箱线上契约(S5-⑦)。运行时全机共享;环境按 owner 分。
@freezed
abstract class SandboxRuntime with _$SandboxRuntime {
  const factory SandboxRuntime({
    required String id,
    required String kind,
    @Default('') String version,
    @Default(0) int sizeBytes,
    DateTime? installedAt,
  }) = _SandboxRuntime;

  factory SandboxRuntime.fromJson(Map<String, dynamic> json) =>
      _$SandboxRuntimeFromJson(json);
}

@freezed
abstract class RuntimeAvailability with _$RuntimeAvailability {
  const factory RuntimeAvailability({
    required String kind,
    @JsonKey(name: 'default') @Default('') String defaultVersion,
    @Default([]) List<String> versions,
    @Default(false) bool pinned,
  }) = _RuntimeAvailability;

  factory RuntimeAvailability.fromJson(Map<String, dynamic> json) =>
      _$RuntimeAvailabilityFromJson(json);
}

@freezed
abstract class SandboxEnv with _$SandboxEnv {
  const factory SandboxEnv({
    required String id,
    @Default('') String ownerKind,
    @Default('') String ownerId,
    @Default('') String ownerName,
    @Default('') String runtimeId,
    @Default([]) List<String> deps,
    @Default(0) int sizeBytes,
    @Default('') String status,
    String? errorMsg,
    DateTime? lastUsedAt,
    int? runningPid,
  }) = _SandboxEnv;

  factory SandboxEnv.fromJson(Map<String, dynamic> json) =>
      _$SandboxEnvFromJson(json);
}

@freezed
abstract class SandboxBootstrap with _$SandboxBootstrap {
  const factory SandboxBootstrap({@Default(false) bool ok, String? error}) =
      _SandboxBootstrap;

  factory SandboxBootstrap.fromJson(Map<String, dynamic> json) =>
      _$SandboxBootstrapFromJson(json);
}
