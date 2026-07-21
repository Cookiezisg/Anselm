import 'package:freezed_annotation/freezed_annotation.dart';

part 'network.freezed.dart';
part 'network.g.dart';

/// The outbound-proxy config — `GET/PATCH /network` (WRK-062 工单⑩). Machine-level (one per
/// settings.json). Empty fields = direct. Takes full effect only after a sidecar restart (the
/// backend caches the proxy in its HTTP transports) — the panel says so.
///
/// 出站代理配置。机器级;空=直连;完整生效须重启 sidecar(后端 HTTP transport 缓存代理)。
@freezed
abstract class NetworkConfig with _$NetworkConfig {
  const factory NetworkConfig({
    @Default('') String httpProxy,
    @Default('') String httpsProxy,
    @Default('') String noProxy,
  }) = _NetworkConfig;

  factory NetworkConfig.fromJson(Map<String, dynamic> json) =>
      _$NetworkConfigFromJson(json);
}
