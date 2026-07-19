import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runtime.dart';
import 'entity_repository.dart';

/// The Entities feature's data seam, as a provider. Defaults to [LiveEntityRepository] over the
/// Phase-4.0 pipeline (apiClient + the nullable sseGateway); the zero-backend demo, the gallery, and
/// every feature test override THIS ONE provider with a [FixtureEntityRepository] via ProviderScope —
/// the whole feature swaps backends at a single seam.
///
/// 实体 feature 的数据缝(provider)。默认 Live(接 apiClient + 可空 sseGateway);零后端 demo / gallery /
/// 每个 feature 测试经 ProviderScope override 此唯一 provider 成 fixture——整 feature 单点切换后端。
final entityRepositoryProvider = Provider<EntityRepository>((ref) {
  return LiveEntityRepository(
    api: ref.watch(apiClientProvider),
    sse: ref.watch(sseGatewayProvider),
  );
});
